# $Id: stomp.rb 738 2008-07-06 01:01:04Z francis $
#
# Author:: Francis Cianfrocca (gmail: blackhedd)
# Homepage::  http://rubyeventmachine.com
# Date:: 15 November 2006
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



module EventMachine
	module Protocols

		# Implements Stomp (http://docs.codehaus.org/display/STOMP/Protocol).
		#
		module Stomp
			include LineText2

			class Message
				attr_accessor :command, :header, :body
				def initialize
					@header = {}
					@state = :precommand
					@content_length = nil
				end
				def consume_line line
					if @state == :precommand
						unless line =~ /\A\s*\Z/
							@command = line
							@state = :headers
						end
					elsif @state == :headers
						if line == ""
							if @content_length
								yield( [:sized_text, @content_length+1] )
							else
								@state = :body
								yield( [:unsized_text] )
							end
						elsif line =~ /\A([^:]+):(.+)\Z/
							k = $1.dup.strip
							v = $2.dup.strip
							@header[k] = v
							if k == "content-length"
								@content_length = v.to_i
							end
						else
							# This is a protocol error. How to signal it?
						end
					elsif @state == :body
						@body = line
						yield( [:dispatch] )
					end
				end
			end

			def send_frame verb, headers={}, body=""
				ary = [verb, "\n"]
				headers.each {|k,v| ary << "#{k}:#{v}\n" }
				ary << "content-length: #{body.to_s.length}\n"
				ary << "content-type: text/plain; charset=UTF-8\n"
				ary << "\n"
				ary << body.to_s
				ary << "\0"
				send_data ary.join
			end

			def receive_line line
				@stomp_initialized || init_message_reader
				@stomp_message.consume_line(line) {|outcome|
					if outcome.first == :sized_text
						set_text_mode outcome[1]
					elsif outcome.first == :unsized_text
						set_delimiter "\0"
					elsif outcome.first == :dispatch
						receive_msg(@stomp_message) if respond_to?(:receive_msg)
						init_message_reader
					end
				}
			end
			def receive_binary_data data
				@stomp_message.body = data[0..-2]
				receive_msg(@stomp_message) if respond_to?(:receive_msg)
				init_message_reader
			end

			def init_message_reader
				@stomp_initialized = true
				set_delimiter "\n"
				set_line_mode
				@stomp_message = Message.new
			end


			# STOMP verbs
			def connect parms={}
				send_frame "CONNECT", parms
			end
			def send destination, body, parms={}
				send_frame "SEND", parms.merge( :destination=>destination ), body.to_s
			end
			def subscribe dest, ack=false
				send_frame "SUBSCRIBE", {:destination=>dest, :ack=>(ack ? "client" : "auto")}
			end
			def ack msgid
				send_frame "ACK", { :'message-id'=> msgid }
			end

		end
	end
end

