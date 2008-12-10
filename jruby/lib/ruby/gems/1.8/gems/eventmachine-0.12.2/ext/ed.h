/*****************************************************************************

$Id: ed.h 785 2008-09-15 09:46:23Z francis $

File:     ed.h
Date:     06Apr06

Copyright (C) 2006-07 by Francis Cianfrocca. All Rights Reserved.
Gmail: blackhedd

This program is free software; you can redistribute it and/or modify
it under the terms of either: 1) the GNU General Public License
as published by the Free Software Foundation; either version 2 of the
License, or (at your option) any later version; or 2) Ruby's License.

See the file COPYING for complete licensing information.

*****************************************************************************/

#ifndef __EventableDescriptor__H_
#define __EventableDescriptor__H_


class EventMachine_t; // forward reference
#ifdef WITH_SSL
class SslBox_t; // forward reference
#endif

bool SetSocketNonblocking (SOCKET);


/*************************
class EventableDescriptor
*************************/

class EventableDescriptor: public Bindable_t
{
	public:
		EventableDescriptor (int, EventMachine_t*);
		virtual ~EventableDescriptor();

		int GetSocket() {return MySocket;}
		void SetSocketInvalid() { MySocket = INVALID_SOCKET; }
		void Close();

		virtual void Read() = 0;
		virtual void Write() = 0;
		virtual void Heartbeat() = 0;

		// These methods tell us whether the descriptor
		// should be selected or polled for read/write.
		virtual bool SelectForRead() = 0;
		virtual bool SelectForWrite() = 0;

		// are we scheduled for a close, or in an error state, or already closed?
		bool ShouldDelete();
		// Do we have any data to write? This is used by ShouldDelete.
		virtual int GetOutboundDataSize() {return 0;}

		void ScheduleClose (bool after_writing);
		bool IsCloseScheduled();

		void SetEventCallback (void (*cb)(const char*, int, const char*, int));

		virtual bool GetPeername (struct sockaddr*) {return false;}
		virtual bool GetSockname (struct sockaddr*) {return false;}
		virtual bool GetSubprocessPid (pid_t*) {return false;}

		virtual void StartTls() {}
		virtual void SetTlsParms (const char *privkey_filename, const char *certchain_filename) {}

		// Properties: return 0/1 to signify T/F, and handle the values
		// through arguments.
		virtual int GetCommInactivityTimeout (int *value) {return 0;}
		virtual int SetCommInactivityTimeout (int *value) {return 0;}

		#ifdef HAVE_EPOLL
		struct epoll_event *GetEpollEvent() { return &EpollEvent; }
		#endif

	private:
		bool bCloseNow;
		bool bCloseAfterWriting;
		int MySocket;

	protected:
		enum {
			PendingConnectTimeout = 4 // can easily be made an instance variable
		};

		void (*EventCallback)(const char*, int, const char*, int);
    
		time_t CreatedAt;
		time_t LastRead;
		time_t LastWritten;
		bool bCallbackUnbind;

		#ifdef HAVE_EPOLL
		struct epoll_event EpollEvent;
		#endif

		EventMachine_t *MyEventMachine;
};



/*************************
class LoopbreakDescriptor
*************************/

class LoopbreakDescriptor: public EventableDescriptor
{
	public:
		LoopbreakDescriptor (int, EventMachine_t*);
		virtual ~LoopbreakDescriptor() {}

		virtual void Read();
		virtual void Write();
		virtual void Heartbeat() {}

		virtual bool SelectForRead() {return true;}
		virtual bool SelectForWrite() {return false;}
};


/**************************
class ConnectionDescriptor
**************************/

class ConnectionDescriptor: public EventableDescriptor
{
	public:
		ConnectionDescriptor (int, EventMachine_t*);
		virtual ~ConnectionDescriptor();

		static int SendDataToConnection (const char*, const char*, int);
		static void CloseConnection (const char*, bool);
		static int ReportErrorStatus (const char*);

		int SendOutboundData (const char*, int);

		void SetConnectPending (bool f) { bConnectPending = f; }

		void SetNotifyReadable (bool readable) { bNotifyReadable = readable; }
		void SetNotifyWritable (bool writable) { bNotifyWritable = writable; }

		virtual void Read();
		virtual void Write();
		virtual void Heartbeat();

		virtual bool SelectForRead();
		virtual bool SelectForWrite();

		// Do we have any data to write? This is used by ShouldDelete.
		virtual int GetOutboundDataSize() {return OutboundDataSize;}

		virtual void StartTls();
		virtual void SetTlsParms (const char *privkey_filename, const char *certchain_filename);
		void SetServerMode() {bIsServer = true;}

		virtual bool GetPeername (struct sockaddr*);
		virtual bool GetSockname (struct sockaddr*);

		virtual int GetCommInactivityTimeout (int *value);
		virtual int SetCommInactivityTimeout (int *value);


	protected:
		struct OutboundPage {
			OutboundPage (const char *b, int l, int o=0): Buffer(b), Length(l), Offset(o) {}
			void Free() {if (Buffer) free ((char*)Buffer); }
			const char *Buffer;
			int Length;
			int Offset;
		};

	protected:
		bool bConnectPending;

		bool bNotifyReadable;
		bool bNotifyWritable;

		bool bReadAttemptedAfterClose;
		bool bWriteAttemptedAfterClose;

		deque<OutboundPage> OutboundPages;
		int OutboundDataSize;

		#ifdef WITH_SSL
		SslBox_t *SslBox;
		std::string CertChainFilename;
		std::string PrivateKeyFilename;
		#endif
		bool bIsServer;

		time_t LastIo;
		int InactivityTimeout;

	private:
		void _WriteOutboundData();
		void _DispatchInboundData (const char *buffer, int size);
		void _DispatchCiphertext();
		int _SendRawOutboundData (const char*, int);
		int _ReportErrorStatus();

};


/************************
class DatagramDescriptor
************************/

class DatagramDescriptor: public EventableDescriptor
{
	public:
		DatagramDescriptor (int, EventMachine_t*);
		virtual ~DatagramDescriptor();

		virtual void Read();
		virtual void Write();
		virtual void Heartbeat();

		virtual bool SelectForRead() {return true;}
		virtual bool SelectForWrite();

		int SendOutboundData (const char*, int);
		int SendOutboundDatagram (const char*, int, const char*, int);

		// Do we have any data to write? This is used by ShouldDelete.
		virtual int GetOutboundDataSize() {return OutboundDataSize;}

		virtual bool GetPeername (struct sockaddr*);
		virtual bool GetSockname (struct sockaddr*);

    virtual int GetCommInactivityTimeout (int *value);
    virtual int SetCommInactivityTimeout (int *value);

		static int SendDatagram (const char*, const char*, int, const char*, int);


	protected:
		struct OutboundPage {
			OutboundPage (const char *b, int l, struct sockaddr_in f, int o=0): Buffer(b), Length(l), Offset(o), From(f) {}
			void Free() {if (Buffer) free ((char*)Buffer); }
			const char *Buffer;
			int Length;
			int Offset;
			struct sockaddr_in From;
		};

		deque<OutboundPage> OutboundPages;
		int OutboundDataSize;

		struct sockaddr_in ReturnAddress;

		time_t LastIo;
		int InactivityTimeout;
};


/************************
class AcceptorDescriptor
************************/

class AcceptorDescriptor: public EventableDescriptor
{
	public:
		AcceptorDescriptor (int, EventMachine_t*);
		virtual ~AcceptorDescriptor();

		virtual void Read();
		virtual void Write();
		virtual void Heartbeat();

		virtual bool SelectForRead() {return true;}
		virtual bool SelectForWrite() {return false;}

		virtual bool GetSockname (struct sockaddr*);

		static void StopAcceptor (const char *binding);
};

/********************
class PipeDescriptor
********************/

#ifdef OS_UNIX
class PipeDescriptor: public EventableDescriptor
{
	public:
		PipeDescriptor (int, pid_t, EventMachine_t*);
		virtual ~PipeDescriptor();

		virtual void Read();
		virtual void Write();
		virtual void Heartbeat();

		virtual bool SelectForRead();
		virtual bool SelectForWrite();

		int SendOutboundData (const char*, int);
		virtual int GetOutboundDataSize() {return OutboundDataSize;}

		virtual bool GetSubprocessPid (pid_t*);

	protected:
		struct OutboundPage {
			OutboundPage (const char *b, int l, int o=0): Buffer(b), Length(l), Offset(o) {}
			void Free() {if (Buffer) free ((char*)Buffer); }
			const char *Buffer;
			int Length;
			int Offset;
		};

	protected:
		bool bReadAttemptedAfterClose;
		time_t LastIo;
		int InactivityTimeout;

		deque<OutboundPage> OutboundPages;
		int OutboundDataSize;

		pid_t SubprocessPid;

	private:
		void _DispatchInboundData (const char *buffer, int size);
};
#endif // OS_UNIX


/************************
class KeyboardDescriptor
************************/

class KeyboardDescriptor: public EventableDescriptor
{
	public:
		KeyboardDescriptor (EventMachine_t*);
		virtual ~KeyboardDescriptor();

		virtual void Read();
		virtual void Write();
		virtual void Heartbeat();

		virtual bool SelectForRead() {return true;}
		virtual bool SelectForWrite() {return false;}

	protected:
		bool bReadAttemptedAfterClose;
		time_t LastIo;
		int InactivityTimeout;

	private:
		void _DispatchInboundData (const char *buffer, int size);
};



#endif // __EventableDescriptor__H_


