# $Id: streamer.rb 668 2008-01-04 23:00:34Z blackhedd $
#
# Author:: Francis Cianfrocca (gmail: blackhedd)
# Homepage::  http://rubyeventmachine.com
# Date:: 16 Jul 2006
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


module EventMachine
	class FileStreamer
		MappingThreshold = 16384
		BackpressureLevel = 50000
		ChunkSize = 16384

		include Deferrable
		def initialize connection, filename, args
			@connection = connection
			@http_chunks = args[:http_chunks]

			if File.exist?(filename)
				@size = File.size?(filename)
				if @size <= MappingThreshold
					stream_without_mapping filename
				else
					stream_with_mapping filename
				end
			else
				fail "file not found"
			end
		end

		def stream_without_mapping filename
			if @http_chunks
				@connection.send_data "#{@size.to_s(16)}\r\n"
				@connection.send_file_data filename
				@connection.send_data "\r\n0\r\n\r\n"
			else
				@connection.send_file_data filename
			end
			succeed
		end
		private :stream_without_mapping

		def stream_with_mapping filename
			ensure_mapping_extension_is_present

			@position = 0
			@mapping = EventMachine::FastFileReader::Mapper.new filename
			stream_one_chunk
		end
		private :stream_with_mapping

		def stream_one_chunk
			loop {
				if @position < @size
					if @connection.get_outbound_data_size > BackpressureLevel
						EventMachine::next_tick {stream_one_chunk}
						break
					else
						len = @size - @position
						len = ChunkSize if (len > ChunkSize)

						@connection.send_data( "#{len.to_s(16)}\r\n" ) if @http_chunks
						@connection.send_data( @mapping.get_chunk( @position, len ))
						@connection.send_data("\r\n") if @http_chunks

						@position += len
					end
				else
					@connection.send_data "0\r\n\r\n" if @http_chunks
					@mapping.close
					succeed
					break
				end
			}
		end

		#--
		# We use an outboard extension class to get memory-mapped files.
		# It's outboard to avoid polluting the core distro, but that means
		# there's a "hidden" dependency on it. The first time we get here in
		# any run, try to load up the dependency extension. User code will see
		# a LoadError if it's not available, but code that doesn't require
		# mapped files will work fine without it. This is a somewhat difficult
		# compromise between usability and proper modularization.
		#
		def ensure_mapping_extension_is_present
			@@fastfilereader ||= (require 'fastfilereaderext')
		end
		private :ensure_mapping_extension_is_present

	end
end

