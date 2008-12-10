require 'mkmf'

flags = []

if pkg_config("gnutls")
  flags << '-DHAVE_GNUTLS'
end

flags << '-DEV_USE_MONOTONIC=0'

if have_header('sys/select.h')
  flags << '-DEV_USE_SELECT'
end

if have_header('poll.h')
  flags << '-DEV_USE_POLL'
end

if have_header('sys/epoll.h')
  flags << '-DEV_USE_EPOLL'
end

if have_header('sys/event.h') and have_header('sys/queue.h')
  flags << '-DEV_USE_KQUEUE'
end

if have_header('port.h')
  flags << '-DEV_USE_PORT'
end

if have_header('sys/inotify.h')
  flags << '-DEV_USE_INOTIFY'
end

dir = File.dirname(__FILE__)
libev_dir = File.expand_path(dir + '/../libev')

#$LDFLAGS << " -lefence "
$CFLAGS << " -I#{libev_dir} " << flags.join(' ')
$defs << "-DRUBY_VERSION_CODE=#{RUBY_VERSION.gsub(/\D/, '')}"

$srcs = ['ebb_ffi.c', "ebb.c", "ebb_request_parser.c", "rbtree.c"]
$objs = ['ebb_ffi.o', "ebb.o", "ebb_request_parser.o", "rbtree.o"]

CONFIG['warnflags'] = ""

dir_config('ebb_ffi')
create_makefile('ebb_ffi')
