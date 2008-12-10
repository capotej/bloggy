/*****************************************************************************

$Id: project.h 686 2008-05-14 21:21:10Z francis $

File:     project.h
Date:     06Apr06

Copyright (C) 2006-07 by Francis Cianfrocca. All Rights Reserved.
Gmail: blackhedd

This program is free software; you can redistribute it and/or modify
it under the terms of either: 1) the GNU General Public License
as published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version; or 2) Ruby's License.

See the file COPYING for complete licensing information.

*****************************************************************************/


#ifndef __Project__H_
#define __Project__H_


#ifdef OS_WIN32
#pragma warning(disable:4786)
#endif

#include <iostream>
#include <map>
#include <set>
#include <vector>
#include <deque>
#include <string>
#include <sstream>
#include <stdexcept>


#ifdef OS_UNIX
#include <signal.h>
#include <netdb.h>
#include <time.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/resource.h>
#include <sys/wait.h>
#include <assert.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <pwd.h>
typedef int SOCKET;
#define closesocket close
#define INVALID_SOCKET -1
#define SOCKET_ERROR -1
#ifdef OS_SOLARIS8
#include <strings.h>
#include <sys/un.h>
#ifndef AF_LOCAL
#define AF_LOCAL AF_UNIX
#endif
// INADDR_NONE is undefined on Solaris < 8. Thanks to Brett Eisenberg and Tim Pease.
#ifndef INADDR_NONE
#define INADDR_NONE ((unsigned long)-1)
#endif
#endif
#endif


#ifdef OS_WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <rpc.h>
#include <fcntl.h>
#include <assert.h>
typedef int socklen_t;
typedef int pid_t;
#endif


using namespace std;

#ifdef WITH_SSL
#include <openssl/ssl.h>
#include <openssl/err.h>
#endif

#ifdef HAVE_EPOLL
#include <sys/epoll.h>
#endif

#ifdef HAVE_KQUEUE
#include <sys/event.h>
#include <sys/queue.h>
#endif

#include "binder.h"
#include "em.h"
#include "epoll.h"
#include "sigs.h"
#include "ed.h"
#include "files.h"
#include "page.h"
#include "ssl.h"
#include "eventmachine.h"
#include "eventmachine_cpp.h"




#endif // __Project__H_
