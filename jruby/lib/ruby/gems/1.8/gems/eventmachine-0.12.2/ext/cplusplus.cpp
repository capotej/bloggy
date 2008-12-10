/*****************************************************************************

$Id: cplusplus.cpp 668 2008-01-04 23:00:34Z blackhedd $

File:     cplusplus.cpp
Date:     27Jul07

Copyright (C) 2006-07 by Francis Cianfrocca. All Rights Reserved.
Gmail: blackhedd

This program is free software; you can redistribute it and/or modify
it under the terms of either: 1) the GNU General Public License
as published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version; or 2) Ruby's License.

See the file COPYING for complete licensing information.

*****************************************************************************/


#include "project.h"


namespace EM {
	static map<string, Eventable*> Eventables;
	static map<string, void(*)()> Timers;
}


/*******
EM::Run
*******/

void EM::Run (void (*start_func)())
{
	evma__epoll();
	evma_initialize_library (EM::Callback);
	if (start_func)
		AddTimer (0, start_func);
	evma_run_machine();
	evma_release_library();
}

/************
EM::AddTimer
************/

void EM::AddTimer (int milliseconds, void (*func)())
{
	if (func) {
		const char *sig = evma_install_oneshot_timer (milliseconds);
		Timers.insert (make_pair (sig, func));
	}
}


/***************
EM::StopReactor
***************/

void EM::StopReactor()
{
	evma_stop_machine();
}


/********************
EM::Acceptor::Accept
********************/

void EM::Acceptor::Accept (const char *signature)
{
	Connection *c = MakeConnection();
	c->Signature = signature;
	Eventables.insert (make_pair (c->Signature, c));
	c->PostInit();
}

/************************
EM::Connection::SendData
************************/

void EM::Connection::SendData (const char *data)
{
	if (data)
		SendData (data, strlen (data));
}


/************************
EM::Connection::SendData
************************/

void EM::Connection::SendData (const char *data, int length)
{
	evma_send_data_to_connection (Signature.c_str(), data, length);
}


/*********************
EM::Connection::Close
*********************/

void EM::Connection::Close (bool afterWriting)
{
	evma_close_connection (Signature.c_str(), afterWriting);
}


/***********************
EM::Connection::Connect
***********************/

void EM::Connection::Connect (const char *host, int port)
{
	Signature = evma_connect_to_server (host, port);
	Eventables.insert( make_pair (Signature, this));
}

/*******************
EM::Acceptor::Start
*******************/

void EM::Acceptor::Start (const char *host, int port)
{
	Signature = evma_create_tcp_server (host, port);
	Eventables.insert( make_pair (Signature, this));
}



/************
EM::Callback
************/

void EM::Callback (const char *sig, int ev, const char *data, int length)
{
	EM::Eventable *e;
	void (*f)();

	switch (ev) {
		case EM_TIMER_FIRED:
			f = Timers [data];
			if (f)
				(*f)();
			Timers.erase (sig);
			break;

		case EM_CONNECTION_READ:
			e = EM::Eventables [sig];
			e->ReceiveData (data, length);
			break;

		case EM_CONNECTION_COMPLETED:
			e = EM::Eventables [sig];
			e->ConnectionCompleted();
			break;

		case EM_CONNECTION_ACCEPTED:
			e = EM::Eventables [sig];
			e->Accept (data);
			break;

		case EM_CONNECTION_UNBOUND:
			e = EM::Eventables [sig];
			e->Unbind();
			EM::Eventables.erase (sig);
			delete e;
			break;
	}
}

