dnl Process this file with autoconf to produce a configure script.

AC_INIT(at, 3.1.23)
AC_CONFIG_SRCDIR(at.c)

AC_PREFIX_DEFAULT(/usr)
AC_CONFIG_HEADER(config.h)
AC_PREREQ([2.64])

VERSION=AC_PACKAGE_VERSION
if test "X$CFLAGS" = "X"; then
CFLAGS="-O2 -g -Wall"
fi

AC_SUBST(VERSION)

AC_CANONICAL_HOST

dnl Checks for programs.

AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_YACC
AC_PROG_LEX

AC_MSG_CHECKING(HP-UX -Aa)

case "$host" in
  *-*-hpux*)
    # HPUX flags from jgotts@engin.umich.edu
    if test -z "$GCC"; then
      CFLAGS="$CFLAGS -Aa -D_HPUX_SOURCE"
    fi
    AC_MSG_RESULT(yes)
    ;;
  *)
    AC_MSG_RESULT(no)
    ;;
esac

AC_MSG_CHECKING(__attribute__((noreturn)))
AC_TRY_COMPILE([], [void __attribute__((noreturn)) panic(void);],
    AC_MSG_RESULT(yes)
    AC_DEFINE(HAVE_ATTRIBUTE_NORETURN, 1,
              [Define to 1 if compiler supports __attribute__((noreturn))]),
    AC_MSG_RESULT(no)
)
dnl Checks for libraries.

AC_CHECK_LIB(fl,yywrap,
        [],
        AC_DEFINE(NEED_YYWRAP, 1,
                  [Define to 1 if we need to provide our own yywrap()])
)

dnl Checks for header files.
AC_HEADER_DIRENT
AC_HEADER_STDC
AC_HEADER_SYS_WAIT
AC_CHECK_HEADERS(fcntl.h syslog.h unistd.h errno.h sys/fcntl.h getopt.h)
AC_CHECK_HEADERS(stdarg.h)

dnl Checks for typedefs, structures, and compiler characteristics.
AC_C_CONST
AC_TYPE_SIGNAL
AC_TYPE_UID_T
AC_TYPE_MODE_T
AC_TYPE_OFF_T
AC_TYPE_PID_T
AC_TYPE_SIZE_T
AC_STRUCT_TM


dnl Checks for library functions.
AC_FUNC_VPRINTF
AC_FUNC_GETLOADAVG
AC_CHECK_FUNCS(getcwd mktime strftime setreuid setresuid sigaction waitpid)
AC_CHECK_HEADERS(security/pam_appl.h, [
  PAMLIB="-lpam"
  AC_DEFINE(HAVE_PAM, 1, [Define to 1 for PAM support])
])

dnl Checking for programs

AC_PATH_PROG(SENDMAIL, sendmail, , $PATH:/usr/lib:/usr/sbin )
if test "$SENDMAIL" != "" ; then
AC_DEFINE_UNQUOTED(SENDMAIL,"$SENDMAIL", [Define mail command for sending])
MAIL_CMD="$SENDMAIL"
fi

AC_SUBST(MAIL_CMD)
AC_SUBST(PAMLIB)

AC_MSG_CHECKING(etcdir)
AC_ARG_WITH(etcdir,
[  --with-etcdir=PATH      Directory containing permission files (default /etc).],
[ case "$withval" in
  no)
    AC_MSG_ERROR(Need ETCDIR.)
    ;;
  yes)
    ETCDIR=/etc
    AC_MSG_RESULT(/etc)
    ;;
  *)
    ETCDIR="$withval"
    AC_MSG_RESULT($withval)
    ;;
  esac ],
  ETCDIR="/etc"
  AC_MSG_RESULT(/etc)
)
AC_SUBST(ETCDIR)

AC_ARG_WITH(systemdsystemunitdir,
[  --with-systemdsystemunitdir=PATH Directory for systemd service files],
[],
[with_systemdsystemunitdir=no]
)
AC_SUBST(systemdsystemunitdir, [$with_systemdsystemunitdir])

AC_MSG_CHECKING(location of pid file)
if test -d /var/run ; then
    PIDDIR=/var/run
elif test -d /usr/run ; then
    PIDDIR=/usr/run
else
    PIDDIR="$ETCDIR"
fi
AC_DEFINE_UNQUOTED(PIDFILE, "$PIDDIR/atd.pid", [What is the name of our PID file?])
AC_MSG_RESULT($PIDDIR)

AC_MSG_CHECKING(location of spool directory)
if test -d /var/spool/atjobs ; then
  sp=/var/spool
  AC_MSG_RESULT(Using existing /var/spool/at{jobs|run})
elif  test -d /var/spool/cron ; then
  sp=/var/spool/cron
  AC_MSG_RESULT(/var/spool/cron)
elif test -d /usr/spool/cron ; then
  sp=/usr/spool/cron
  AC_MSG_RESULT(/usr/spool/cron)
else
  AC_MSG_RESULT(not found)
fi

AC_MSG_CHECKING(jobdir)
AC_ARG_WITH(jobdir,
[  --with-jobdir=PATH      Directory containing at jobs (default SPOOLDIR/atjobs).],
[ case "$withval" in
  no)
    AC_MSG_ERROR(Need JOBDIR.)
    ;;
  yes)
    if test x$sp == x ; then
      AC_MSG_ERROR(Need explicit JOBDIR when SPOOLDIR not found.)
    fi
    ATJBD="$sp/atjobs"
    ;;
  *)
    ATJBD="$withval"
    ;;
  esac ],
  if test x$sp == x ; then
    AC_MSG_ERROR(Need --with-jobdir=PATH when SPOOLDIR not found.)
  fi
  ATJBD="$sp/atjobs"
)
AC_DEFINE_UNQUOTED(ATJOB_DIR, "$ATJBD", [Where do we place out input directories?])
AC_MSG_RESULT($ATJBD)
AC_SUBST(ATJBD)

AC_MSG_CHECKING(atspool)
AC_ARG_WITH(atspool,
[  --with-atspool=PATH    Directory containing at spool (default SPOOLDIR/atspool).],
[ case "$withval" in
  no)
    AC_MSG_ERROR(Need ATSPOOL.)
    ;;
  yes)
    if test x$sp == x ; then
      AC_MSG_ERROR(Need explicit ATSPOOL when SPOOLDIR not found.)
    fi
    ATSPD=$sp/atspool
    ;;
  *)
    ATSPD=$withval
    ;;
  esac ],
  if test x$sp == x ; then
    AC_MSG_ERROR(Need --with-atspool=PATH when SPOOLDIR not found.)
  fi
  ATSPD=$sp/atspool
)
AC_DEFINE_UNQUOTED(ATSPOOL_DIR, "$ATSPD", [Where do we spool our output?])
AC_MSG_RESULT($ATSPD)
AC_SUBST(ATSPD)

AC_MSG_CHECKING(maximum load average for batch to start jobs)
AC_ARG_WITH(loadavg_mx,
[ --with-loadavg_mx=LOADAVG_MX	Default max. load average for batch (default 0.8). ],
[ case "$withval" in
  no)
    AC_MSG_ERROR(Need LOADAVG_MX.)
    ;;
  yes)
    LOADAVG_MX=0.8
    AC_MSG_RESULT(0.8)
    ;;
  *)
    LOADAVG_MX="$withval";
    AC_MSG_RESULT($withval)
    ;;
    esac ],
    LOADAVG_MX=0.8
    AC_MSG_RESULT(0.8)
)
AC_SUBST(LOADAVG_MX)

AC_MSG_CHECKING(username to run under)
AC_ARG_WITH(daemon_username,
[ --with-daemon_username=DAEMON_USERNAME	Username to run under (default daemon) ],
[ case "$withval" in
  no)
    AC_MSG_ERROR(Need DAEMON_USERNAME.)
    ;;
  yes)
    DAEMON_USERNAME=daemon
    AC_MSG_RESULT(daemon)
    ;;
  *)
    DAEMON_USERNAME="$withval";
    AC_MSG_RESULT($withval)
    ;;
    esac ],
    DAEMON_USERNAME=daemon
    AC_MSG_RESULT(daemon)
)
AC_SUBST(DAEMON_USERNAME)

AC_ARG_WITH(selinux,
[ --with-selinux       Define to run with selinux (default=check)],
[],
[with_selinux=check])

if test "x$with_selinux" != xno; then
  AC_CHECK_LIB([selinux], [is_selinux_enabled],
    [SELINUXLIB=-lselinux
     AC_DEFINE(WITH_SELINUX, 1, [Define if you are building with_selinux])
    ],
    [if test "x$with_selinux" != xcheck; then
       AC_MSG_FAILURE([--with-selinux is given, but test for selinux failed $with_selinux])
     fi
    ]
  )
fi
AC_SUBST(SELINUXLIB)
AC_SUBST(WITH_SELINUX)

AC_MSG_CHECKING(groupname to run under)
AC_ARG_WITH(daemon_groupname,
[ --with-daemon_groupname=DAEMON_GROUPNAME	Groupname to run under (default daemon) ],
[ case "$withval" in
  no)
    AC_MSG_ERROR(Need DAEMON_GROUPNAME.)
    ;;
  yes)
    DAEMON_GROUPNAME=daemon
    AC_MSG_RESULT(daemon)
    ;;
  *)
    DAEMON_GROUPNAME="$withval";
    AC_MSG_RESULT($withval)
    ;;
    esac ],
    DAEMON_GROUPNAME=daemon
    AC_MSG_RESULT(daemon)
)
AC_SUBST(DAEMON_GROUPNAME)

AC_CONFIG_FILES(Makefile atrun atd.8 atrun.8 at.1 at.allow.5 batch)
AC_OUTPUT
