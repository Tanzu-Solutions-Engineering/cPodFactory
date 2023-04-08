/* 
 *  atd.c - run jobs queued by at; run with root privileges.
 *  Copyright (C) 1993, 1994, 1996 Thomas Koenig
 *  Copyright (c) 2002, 2005 Ryan Murray
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */


#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

/* System Headers */

#include <sys/types.h>
#include <sys/stat.h>

#ifdef HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif

#ifdef HAVE_FCNTL_H
#include <fcntl.h>
#elif HAVE_SYS_FCNTL_H

#include <sys/fcntl.h>
#endif

#include <ctype.h>

#ifdef HAVE_DIRENT_H
#include <dirent.h>
#elif HAVE_SYS_DIRENT_H
#include <sys/dirent.h>
#elif HAVE_SYS_DIR_H
#include <sys/dir.h>
#endif

#ifdef HAVE_ERRNO_H
#include <errno.h>
#endif

#include <pwd.h>
#include <grp.h>
#include <signal.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifdef HAVE_GETOPT_H
#include <getopt.h>
#endif

#ifdef HAVE_UNISTD_H
#include <syslog.h>
#endif

/* Local headers */

#include "privs.h"
#include "daemon.h"

#ifndef HAVE_GETLOADAVG
#include "getloadavg.h"
#endif

#ifdef WITH_SELINUX
#include <selinux/selinux.h>
#include <selinux/get_context_list.h>
int selinux_enabled = 0;
#endif

/* Macros */

#define BATCH_INTERVAL_DEFAULT 60
#define CHECK_INTERVAL 3600

/* Global variables */

uid_t real_uid, effective_uid;
gid_t real_gid, effective_gid;

uid_t daemon_uid = (uid_t) - 3;
gid_t daemon_gid = (gid_t) - 3;

/* File scope variables */

static char *namep;
static double load_avg = LOADAVG_MX;
static time_t now;
static time_t last_chg;
static int nothing_to_do;
unsigned int batch_interval;
static int run_as_daemon = 0;

static volatile sig_atomic_t term_signal = 0;

#ifdef HAVE_PAM
#include <security/pam_appl.h>

static pam_handle_t *pamh = NULL;

static const struct pam_conv conv = {
	NULL
};

#define PAM_FAIL_CHECK if (retcode != PAM_SUCCESS) { \
	fprintf(stderr,"\n%s\n",pam_strerror(pamh, retcode)); \
	syslog(LOG_ERR,"%s",pam_strerror(pamh, retcode)); \
	pam_end(pamh, retcode); exit(1); \
    }
#define PAM_END { retcode = pam_close_session(pamh,0); \
		pam_end(pamh,retcode); }

#endif /* HAVE_PAM */

/* Signal handlers */
RETSIGTYPE 
set_term(int dummy)
{
    term_signal = 1;
    return;
}

RETSIGTYPE 
sdummy(int dummy)
{
    /* Empty signal handler */
    nothing_to_do = 0;
    return;
}

/* SIGCHLD handler - discards completion status of children */
RETSIGTYPE
release_zombie(int dummy)
{
  int status;
  pid_t pid;

  while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
#ifdef DEBUG_ZOMBIE
    if (WIFEXITED(status))
      syslog(LOG_INFO, "pid %ld exited with status %d.", pid, WEXITSTATUS(status));
    else if (WIFSIGNALED(status))
      syslog(LOG_NOTICE, "pid %ld killed with signal %d.", pid, WTERMSIG(status));
    else if (WIFSTOPPED(status))
      syslog(LOG_NOTICE, "pid %ld stopped with signal %d.", pid, WSTOPSIG(status));
    else
      syslog(LOG_WARNING, "pid %ld unknown reason for SIGCHLD", pid);
#endif
  }
  return;
}
    

/* Local functions */

static int
write_string(int fd, const char *a)
{
    return write(fd, a, strlen(a));
}

static int
isbatch(char queue)
{
    return isupper(queue) || (queue == 'b');
}

#undef DEBUG_FORK
#ifdef DEBUG_FORK
static pid_t
myfork()
{
    pid_t res;
    res = fork();
    if (res == 0)
	kill(getpid(), SIGSTOP);
    return res;
}

#define fork myfork
#endif

#ifdef WITH_SELINUX
static int
set_selinux_context(const char *name, const char *filename) {
    security_context_t user_context = NULL;
    security_context_t file_context = NULL;
    int retval = 0;
    char *seuser = NULL;
    char *level = NULL;

    if (getseuserbyname(name, &seuser, &level) == 0) {
        retval = get_default_context_with_level(seuser, level, NULL, &user_context);
        free(seuser);
        free(level);
        if (retval < 0) {
            lerr("get_default_context_with_level: couldn't get security context for user %s", name);
            retval = -1;
            goto err;
        }
    }

    /*
     * Since crontab files are not directly executed,
     * crond must ensure that the crontab file has
     * a context that is appropriate for the context of
     * the user cron job.  It performs an entrypoint
     * permission check for this purpose.
     */
    if (fgetfilecon(STDIN_FILENO, &file_context) < 0) {
        lerr("fgetfilecon FAILED %s", filename);
        retval = -1;
        goto err;
    }

    retval = selinux_check_access(user_context, file_context, "file", "entrypoint", NULL);
    freecon(file_context);
    if (retval < 0) {
        lerr("Not allowed to set exec context to %s for user  %s", user_context, name);
        retval = -1;
        goto err;
    }
    if (setexeccon(user_context) < 0) {
        lerr("Could not set exec context to %s for user  %s", user_context, name);
        retval = -1;
        goto err;
    }
err:
    if (retval < 0 && security_getenforce() != 1)
        retval = 0;
    if (user_context)
        freecon(user_context);
    return retval;
}

static int
selinux_log_callback (int type, const char *fmt, ...)
{
    va_list ap;

    va_start(ap, fmt);
    vsyslog (LOG_ERR, fmt, ap);
    va_end(ap);
    return 0;
}

#endif

static void
run_file(const char *filename, uid_t uid, gid_t gid)
{
/* Run a file by by spawning off a process which redirects I/O,
 * spawns a subshell, then waits for it to complete and sends
 * mail to the user.
 */
    pid_t pid;
    int fd_out, fd_in;
    char jobbuf[9];
    char *mailname = NULL;
    int mailsize = 128;
    char *newname;
    FILE *stream;
    int send_mail = 0;
    struct stat buf, lbuf;
    off_t size;
    struct passwd *pentry;
    int fflags;
    int nuid;
    int ngid;
    char queue;
    char fmt[64];
    unsigned long jobno;
    int rc;
#ifdef HAVE_PAM
    int retcode;
#endif

#ifdef _SC_LOGIN_NAME_MAX
    errno = 0;
    rc = sysconf(_SC_LOGIN_NAME_MAX);
    if (rc > 0)
	mailsize = rc;
#else
#  ifdef LOGIN_NAME_MAX
    mailsize = LOGIN_NAME_MAX;
#  endif
#endif
    sscanf(filename, "%c%5lx", &queue, &jobno);
    if ((mailname = malloc(mailsize+1)) == NULL)
	pabort("Job %8lu : out of virtual memory", jobno);

    sprintf(jobbuf, "%8lu", jobno);

    if ((newname = strdup(filename)) == 0)
	pabort("Job %8lu : out of virtual memory", jobno);
    newname[0] = '=';

    /* We try to make a hard link to lock the file.  If we fail, then
     * somebody else has already locked or deleted it (a second atd?); log the
     * fact and return.
     */
    PRIV_START
    rc = link(filename, newname);
    PRIV_END
    if (rc == -1) {
	syslog(LOG_WARNING, "could not lock job %lu: %m", jobno);
	free(mailname);
	free(newname);
	return;
    }
    /* If something goes wrong between here and the unlink() call,
     * the job gets restarted as soon as the "=" entry is cleared
     * by the main atd loop.
     */

    pid = fork();
    if (pid == -1)
	perr("Cannot fork");

    else if (pid != 0) {
	free(mailname);
	free(newname);
	return;
    }
    /* Let's see who we mail to.  Hopefully, we can read it from
     * the command file; if not, send it to the owner, or, failing that,
     * to root.
     */

    pentry = getpwuid(uid);
    if (pentry == NULL) {
	pabort("Userid %lu not found - aborting job %8lu (%.500s)",
	       (unsigned long) uid, jobno, filename);
    }
    PRIV_START

	stream = fopen(filename, "r");

    PRIV_END

    if (stream == NULL)
	perr("Cannot open input file");

    if ((fd_in = dup(fileno(stream))) < 0)
	perr("Error duplicating input file descriptor");

    if (fstat(fd_in, &buf) == -1)
	perr("Error in fstat of input file descriptor");

    if (lstat(filename, &lbuf) == -1)
	perr("Error in fstat of input file");

    if (S_ISLNK(lbuf.st_mode))
	perr("Symbolic link encountered in job %8lu (%.500s) - aborting",
	     jobno, filename);

    if ((lbuf.st_dev != buf.st_dev) || (lbuf.st_ino != buf.st_ino) ||
	(lbuf.st_uid != buf.st_uid) || (lbuf.st_gid != buf.st_gid) ||
	(lbuf.st_size != buf.st_size))
	perr("Somebody changed files from under us for job %8lu (%.500s) - "
	     "aborting", jobno, filename);

    if (buf.st_nlink > 2) {
	perr("Somebody is trying to run a linked script for job %8lu (%.500s)",
	     jobno, filename);
    }
    if ((fflags = fcntl(fd_in, F_GETFD)) < 0)
	perr("Error in fcntl");

    fcntl(fd_in, F_SETFD, fflags & ~FD_CLOEXEC);

    /*
     * If the spool directory is mounted via NFS `atd' isn't able to
     * read from the job file and will bump out here.  The file is
     * opened as "root" but it is read as "daemon" which fails over
     * NFS and works with local file systems.  It's not clear where
     * the bug is located.  -Joey
     */
    sprintf(fmt, "#!/bin/sh\n# atrun uid=%%d gid=%%d\n# mail %%%ds %%d",
	mailsize );

    if (fscanf(stream, fmt,
	       &nuid, &ngid, mailname, &send_mail) != 4)
	pabort("File %.500s is in wrong format - aborting",
	       filename);

    if (mailname[0] == '-')
	pabort("illegal mail name %.300s in job %8lu (%.300s)", mailname,
	       jobno, filename);

    if (nuid != uid)
	pabort("Job %8lu (%.500s) - userid %d does not match file uid %d",
	       jobno, filename, nuid, uid);

    /* We are now committed to executing this script.  Unlink the
     * original.
     */

    unlink(filename);

    fclose(stream);
    if (chdir(ATSPOOL_DIR) < 0)
	perr("Cannot chdir to " ATSPOOL_DIR);

    /* Create a file to hold the output of the job we are about to run.
     * Write the mail header.  Complain in case 
     */

    if (unlink(filename) != -1) {
	syslog(LOG_WARNING,"Warning: for duplicate output file for %.100s (dead job?)",
	       filename);
    }

    if ((fd_out = open(filename,
		    O_RDWR | O_CREAT | O_EXCL, S_IWUSR | S_IRUSR)) < 0)
	perr("Cannot create output file");
    PRIV_START
    if (fchown(fd_out, uid, ngid) == -1)
        syslog(LOG_WARNING, "Warning: could not change owner of output file for job %li to %i:%i: %s",
                jobno, uid, ngid, strerror(errno));
    PRIV_END

    write_string(fd_out, "Subject: Output from your job ");
    write_string(fd_out, jobbuf);
    write_string(fd_out, "\nTo: ");
    write_string(fd_out, mailname);    
    write_string(fd_out, "\n\n");
    fstat(fd_out, &buf);
    size = buf.st_size;

#ifdef HAVE_PAM
    PRIV_START
    retcode = pam_start("atd", pentry->pw_name, &conv, &pamh);
    PAM_FAIL_CHECK;
    retcode = pam_acct_mgmt(pamh, PAM_SILENT);
    PAM_FAIL_CHECK;
    retcode = pam_open_session(pamh, PAM_SILENT);
    PAM_FAIL_CHECK;
    retcode = pam_setcred(pamh, PAM_ESTABLISH_CRED | PAM_SILENT);
    PAM_FAIL_CHECK;
    PRIV_END
#endif

    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);

    pid = fork();
    if (pid < 0)
	perr("Error in fork");

    else if (pid == 0) {
	char *nul = NULL;
	char **nenvp = &nul;

	/* Set up things for the child; we want standard input from the
	 * input file, and standard output and error sent to our output file.
	 */
	if (lseek(fd_in, (off_t) 0, SEEK_SET) < 0)
	    perr("Error in lseek");

	if (dup2(fd_in, STDIN_FILENO) < 0)
	    perr("Error in I/O redirection");

	if (dup2(fd_out, STDOUT_FILENO) < 0)
	    perr("Error in I/O redirection");

	if (dup2(fd_out, STDERR_FILENO) < 0)
	    perr("Error in I/O redirection");

	close(fd_in);
	close(fd_out);

	PRIV_START

	    nice((tolower((int) queue) - 'a' + 1) * 2);

#ifdef WITH_SELINUX
	    if (selinux_enabled > 0) {
	        if (set_selinux_context(pentry->pw_name, filename) < 0)
	            perr("SELinux Failed to set context\n");
	    }
#endif

	    if (initgroups(pentry->pw_name, pentry->pw_gid))
		perr("Cannot initialize the supplementary group access list");

	    if (setgid(ngid) < 0)
		perr("Cannot change group");

	    if (setuid(uid) < 0)
		perr("Cannot set user id");

	    chdir("/");

	    if (execle("/bin/sh", "sh", (char *) NULL, nenvp) != 0)
		perr("Exec failed for /bin/sh");

	PRIV_END
    }
    /* We're the parent.  Let's wait.
     */
    close(fd_in);

    /* We inherited the master's SIGCHLD handler, which does a
       non-blocking waitpid. So this blocking one will eventually
       return with an ECHILD error. 
     */
    waitpid(pid, (int *) NULL, 0);

#ifdef HAVE_PAM
    PRIV_START
	pam_setcred(pamh, PAM_DELETE_CRED | PAM_SILENT);
	retcode = pam_close_session(pamh, PAM_SILENT);
	pam_end(pamh, retcode);
    PRIV_END
#endif

    /* Send mail.  Unlink the output file after opening it, so it
     * doesn't hang around after the run.
     */
    fstat(fd_out, &buf);
    lseek(fd_out, 0, SEEK_SET);
    if (dup2(fd_out, STDIN_FILENO) < 0)
        perr("Could not use jobfile as standard input.");

    /* some sendmail implementations are confused if stdout, stderr are
     * not available, so let them point to /dev/null
     */
    if ((fd_in = open("/dev/null", O_WRONLY)) < 0)
	perr("Could not open /dev/null.");
    if (dup2(fd_in, STDOUT_FILENO) < 0)
	perr("Could not use /dev/null as standard output.");
    if (dup2(fd_in, STDERR_FILENO) < 0)
	perr("Could not use /dev/null as standard error.");
    if (fd_in != STDOUT_FILENO && fd_in != STDERR_FILENO)
	close(fd_in);

    if (unlink(filename) == -1)
        syslog(LOG_WARNING, "Warning: removing output file for job %li failed: %s",
                jobno, strerror(errno));

    /* The job is now finished.  We can delete its input file.
     */
    chdir(ATJOB_DIR);
    unlink(newname);
    free(newname);

    if (((send_mail != -1) && (buf.st_size != size)) || (send_mail == 1)) {

	PRIV_START

	    if (initgroups(pentry->pw_name, pentry->pw_gid))
		perr("Cannot initialize the supplementary group access list");

	    if (setgid(gid) < 0)
		perr("Cannot change group");

	    if (setuid(uid) < 0)
		perr("Cannot set user id");

	    chdir ("/");

#if defined(SENDMAIL)
	    execl(SENDMAIL, "sendmail", "-i", mailname, (char *) NULL);
#else
#error      "No mail command specified."
#endif
	    perr("Exec failed for mail command");

	PRIV_END
    }
    exit(EXIT_SUCCESS);
}

static time_t
run_loop()
{
    DIR *spool;
    struct dirent *dirent;
    struct stat buf;
    unsigned long ctm;
    unsigned long jobno;
    char queue;
    char batch_queue = '\0';
    time_t run_time, next_job;
    char batch_name[] = "z2345678901234";
    char lock_name[] = "z2345678901234";
    uid_t batch_uid;
    gid_t batch_gid;
    int run_batch;
    static time_t next_batch = 0;
    double currlavg[3];

    /* Main loop. Open spool directory for reading and look over all the
     * files in there. If the filename indicates that the job should be run,
     * run a function which sets its user and group id to that of the files
     * and execs a /bin/sh, which executes the shell.  The function will
     * then remove the script (hopefully).
     *
     * Also, pick the oldest batch job to run, at most one per run of
     * the main loop.
     */

    next_job = now + CHECK_INTERVAL;
    if (next_batch == 0)
	next_batch = now;

    /* To avoid spinning up the disk unnecessarily, stat the directory and
     * return immediately if it hasn't changed since the last time we woke
     * up.
     */

    if (stat(".", &buf) == -1)
	perr("Cannot stat " ATJOB_DIR);

    if (nothing_to_do && buf.st_mtime <= last_chg)
	return next_job;
    last_chg = buf.st_mtime;

    if ((spool = opendir(".")) == NULL)
	perr("Cannot read " ATJOB_DIR);

    run_batch = 0;
    nothing_to_do = 1;

    batch_uid = (uid_t) - 1;
    batch_gid = (gid_t) - 1;

    while ((dirent = readdir(spool)) != NULL) {

	/* Avoid the stat if this doesn't look like a job file */
	if (sscanf(dirent->d_name, "%c%5lx%8lx", &queue, &jobno, &ctm) != 3)
	    continue;

	/* Chances are a '=' file has been deleted from under us.
	 * Ignore.
	 */
	if (stat(dirent->d_name, &buf) != 0)
	    continue;

	if (!S_ISREG(buf.st_mode))
	    continue;

	/* We don't want files which at(1) hasn't yet marked executable. */
	if (!(buf.st_mode & S_IXUSR)) {
	    nothing_to_do = 0;  /* it will probably become executable soon */
	    continue;
	}

	run_time = (time_t) ctm *60;

	/* Skip lock files */
	if (queue == '=') {
            /* FIXME: calhariz */
            /* I think the following code is broken, but commenting
               may haven unknow side effects.  Make a release and see
               in the wild how it works. For more information see:
               https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=818508/*

	    /* if ((buf.st_nlink == 1) && (run_time + CHECK_INTERVAL <= now)) { */
	    /*     /\* Remove stale lockfile FIXME: lock the lockfile, if you fail, it's still in use. *\/ */
	    /*     unlink(dirent->d_name); */
	    /* } */
	    continue;
	}
	/* Skip any other file types which may have been invented in
	 * the meantime.
	 */
	if (!(isupper(queue) || islower(queue))) {
	    continue;
	}
	/* Is the file already locked?
	 */
	if (buf.st_nlink > 1) {
	    if (run_time + CHECK_INTERVAL <= now) {

		/* Something went wrong the last time this was executed.
		 * Let's remove the lockfile and reschedule.
		 */
		strncpy(lock_name, dirent->d_name, sizeof(lock_name));
		lock_name[0] = '=';
		unlink(lock_name);
		next_job = now;
		nothing_to_do = 0;
	    }
	    continue;
	}

	/* If we got here, then there are jobs of some kind waiting.
	 * We could try to be smarter and leave nothing_to_do set if
	 * we end up processing all the jobs, but that's risky (run_file
	 * might fail and expect the job to be rescheduled), and it doesn't
	 * gain us much. */
	nothing_to_do = 0;

	/* There's a job for later.  Note its execution time if it's
	 * the earliest so far.
	 */
	if (run_time > now) {
	    if (next_job > run_time) {
		next_job = run_time;
	    }
	    continue;
	}

	if (isbatch(queue)) {

	    /* We could potentially run this batch job.  If it's scheduled
	     * at a higher priority than anything before, keep its
	     * filename.
	     */
	    run_batch++;
	    if (strcmp(batch_name, dirent->d_name) > 0) {
		strncpy(batch_name, dirent->d_name, sizeof(batch_name));
		batch_uid = buf.st_uid;
		batch_gid = buf.st_gid;
		batch_queue = queue;
	    }
	}
	else {
	    if (run_time <= now) {
		run_file(dirent->d_name, buf.st_uid, buf.st_gid);
	    }
	}
    }
    closedir(spool);
    /* run the single batch file, if any
     */
    if (run_batch  && (next_batch <= now)) {
	next_batch = now + batch_interval;
#ifdef GETLOADAVG_PRIVILEGED
	START_PRIV
#endif
	if (getloadavg(currlavg, 1) < 1) {
	    currlavg[0] = 0.0;
	}
#ifdef GETLOADAVG_PRIVILEGED
	END_PRIV
#endif
	if (currlavg[0] < load_avg) {
	    run_file(batch_name, batch_uid, batch_gid);
	    run_batch--;
        }
    }
    if (run_batch && (next_batch < next_job)) {
	nothing_to_do = 0;
	next_job = next_batch;
    }
    return next_job;
}

/* Global functions */

int
main(int argc, char *argv[])
{
/* Browse through ATJOB_DIR, checking all the jobfiles whether they should
 * be executed and or deleted. The queue is coded into the first byte of
 * the job filename, the next 5 bytes encode the serial number in hex, and
 * the final 8 bytes encode the date (minutes since Eon) in hex.  A file
 * which has not been executed yet is denoted by its execute - bit set.
 * For those files which are to be executed, run_file() is called, which forks
 * off a child which takes care of I/O redirection, forks off another child
 * for execution and yet another one, optionally, for sending mail.
 * Files which already have run are removed during the next invocation.
 */
    int c;
    time_t next_invocation;
    struct sigaction act;
    struct passwd *pwe;
    struct group *ge;

#ifdef WITH_SELINUX
    selinux_enabled=is_selinux_enabled();

    if (selinux_enabled) {
        selinux_set_callback(SELINUX_CB_LOG, (union selinux_callback) selinux_log_callback);
    }
#endif

/* We don't need root privileges all the time; running under uid and gid
 * daemon is fine.
 */

    if ((pwe = getpwnam(DAEMON_USERNAME)) == NULL)
	perr("Cannot get uid for " DAEMON_USERNAME);

    daemon_uid = pwe->pw_uid;

    if ((ge = getgrnam(DAEMON_GROUPNAME)) == NULL)
	perr("Cannot get gid for " DAEMON_GROUPNAME);

    daemon_gid = ge->gr_gid;

    RELINQUISH_PRIVS_ROOT(daemon_uid, daemon_gid)

#ifndef LOG_CRON
#define LOG_CRON	LOG_DAEMON
#endif

    openlog("atd", LOG_PID, LOG_CRON);

    opterr = 0;
    errno = 0;
    run_as_daemon = 1;
    batch_interval = BATCH_INTERVAL_DEFAULT;

    while ((c = getopt(argc, argv, "sdl:b:f")) != EOF) {
	switch (c) {
	case 'l':
	    if (sscanf(optarg, "%lf", &load_avg) != 1)
		pabort("garbled option -l");
	    if (load_avg <= 0.)
		load_avg = LOADAVG_MX;
	    break;

	case 'b':
	    if (sscanf(optarg, "%ud", &batch_interval) != 1)
		pabort("garbled option -b");
	    break;
	case 'd':
	    daemon_debug++;
	    daemon_foreground++;
	    break;

	case 'f':
	    daemon_foreground++;
	    break;

	case 's':
	    run_as_daemon = 0;
	    break;

	case '?':
	    pabort("unknown option");
	    break;

	default:
	    pabort("idiotic option - aborted");
	    break;
	}
    }

    namep = argv[0];
    if (chdir(ATJOB_DIR) != 0)
	perr("Cannot change to " ATJOB_DIR);

    if (optind < argc)
	pabort("non-option arguments - not allowed");

    sigaction(SIGCHLD, NULL, &act);
    act.sa_handler = release_zombie;
    act.sa_flags   = SA_NOCLDSTOP;
    sigaction(SIGCHLD, &act, NULL);

    if (!run_as_daemon) {
	now = time(NULL);
	run_loop();
	exit(EXIT_SUCCESS);
    }
    /* Main loop.  Let's sleep for a specified interval,
     * or until the next job is scheduled, or until we get signaled.
     * After any of these events, we rescan the queue.
     * A signal handler setting term_signal will make sure there's
     * a clean exit.
     */

    sigaction(SIGHUP, NULL, &act);
    act.sa_handler = sdummy;
    sigaction(SIGHUP, &act, NULL);

    sigaction(SIGTERM, NULL, &act);
    act.sa_handler = set_term;
    sigaction(SIGTERM, &act, NULL);

    sigaction(SIGINT, NULL, &act);
    act.sa_handler = set_term;
    sigaction(SIGINT, &act, NULL);

    daemon_setup();

    do {
	now = time(NULL);
	next_invocation = run_loop();
	if (next_invocation > now) {
	    sleep(next_invocation - now);
	}
    } while (!term_signal);
    daemon_cleanup();
    exit(EXIT_SUCCESS);
}
