# $Id: test_httpclient2.rb 668 2008-01-04 23:00:34Z blackhedd $
#
# Author:: Francis Cianfrocca (gmail: blackhedd)
# Homepage::  http://rubyeventmachine.com
# Date:: 8 April 2006
# 
# See EventMachine and EventMachine::Connection for documentation and
# usage examples.
#
#----------------------------------------------------------------------------
#
# Copyright (C) 2006-07 by Francis Cianfrocca. All Rights Reserved.
# Gmail: blackhedd
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of either: 1) the GNU General Public License
# as published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version; or 2) Ruby's License.
# 
# See the file COPYING for complete licensing information.
#
#---------------------------------------------------------------------------
#
#
#

$:.unshift "../lib"
require 'eventmachine'
require 'test/unit'

class TestHttpClient2 < Test::Unit::TestCase
	Localhost = "127.0.0.1"
	Localport = 9801

	def setup
	end

	def teardown
	end


	class TestServer < EM::Connection
	end

	# #connect returns an object which has made a connection to an HTTP server
	# and exposes methods for making HTTP requests on that connection.
	# #connect can take either a pair of parameters (a host and a port),
	# or a single parameter which is a Hash.
	#
	def test_connect
		EM.run {
			EM.start_server Localhost, Localport, TestServer
			http1 = EM::P::HttpClient2.connect Localhost, Localport
			http2 = EM::P::HttpClient2.connect( :host=>Localhost, :port=>Localport )
			EM.stop
		}
	end


	def test_bad_port
		EM.run {
			EM.start_server Localhost, Localport, TestServer
			assert_raise( ArgumentError ) {
				EM::P::HttpClient2.connect Localhost, "xxx"
			}
			EM.stop
		}
	end

	def test_bad_server
		EM.run {
			http = EM::P::HttpClient2.connect Localhost, 9999
			d = http.get "/"
			d.errback {p d.internal_error; EM.stop }
		}
	end

	def test_get
		EM.run {
			http = EM::P::HttpClient2.connect "www.bayshorenetworks.com", 80
			d = http.get "/"
			d.callback {
				p d.content
				EM.stop
			}
		}
	end

	# Not a pipelined request because we wait for one response before we request the next.
	def test_get_multiple
		EM.run {
			http = EM::P::HttpClient2.connect "www.bayshorenetworks.com", 80
			d = http.get "/"
			d.callback {
				e = http.get "/"
				e.callback {
					p e.content
					EM.stop
				}
			}
		}
	end

	def test_get_pipeline
		EM.run {
			http = EM::P::HttpClient2.connect "www.microsoft.com", 80
			d = http.get("/")
			d.callback {
				p d.headers
			}
			e = http.get("/")
			e.callback {
				p e.headers
			}
			EM::Timer.new(1) {EM.stop}
		}
	end


	def test_authheader
		EM.run {
			EM.start_server Localhost, Localport, TestServer
			http = EM::P::HttpClient2.connect Localhost, 18842
			d = http.get :url=>"/", :authorization=>"Basic xxx"
			d.callback {EM.stop}
			d.errback {EM.stop}
		}
	end


end


