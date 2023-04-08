/* 
 *  panic.c - terminate fast in case of error
 *  Copyright (C) 1993  Thomas Koenig
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

#ifdef HAVE_ERRNO_H
#include <errno.h>
#endif

#include <stdio.h>
#include <stdlib.h>

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#ifdef HAVE_STDARG_H
#include <stdarg.h>
#endif

/* Local headers */

#include "panic.h"
#include "privs.h"
#include "at.h"

/* File scope variables */

/* External variables */

/* Global functions */

void
panic(char *a)
{
/* Something fatal has happened, print error message and exit.
 */
    fprintf(stderr, "%s: %s\n", namep, a);
    if (fcreated) {
	setregid(real_gid, effective_gid);
	unlink(atfile);
	setregid(effective_gid, real_gid);
    }

    exit(EXIT_FAILURE);
}

void
perr(const char *fmt,...)
{
/* Some operating system error; print error message and exit.
 */
    char buf[1024];
    va_list args;

    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);

    perror(buf);
    if (fcreated) {
        setregid(real_gid, effective_gid);
	unlink(atfile);
        setregid(effective_gid, real_gid);
    }

    exit(EXIT_FAILURE);
}

void
usage(void)
{
/* Print usage and exit.
 */
    fprintf(stderr, "Usage: at [-V] [-q x] [-f file] [-mMlbv] timespec ...\n"
            "       at [-V] [-q x] [-f file] [-mMlbv] -t time\n"
    	    "       at -c job ...\n"
	    "       atq [-V] [-q x]\n"
	    "       at [ -rd ] job ...\n"
	    "       atrm [-V] job ...\n"
	    "       batch\n");
    exit(EXIT_FAILURE);
}
