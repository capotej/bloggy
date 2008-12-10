# $Id: test_defer.rb 668 2008-01-04 23:00:34Z blackhedd $
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

class TestDeferUsage < Test::Unit::TestCase

	def setup
	end

	def teardown
	end

	def run_em_with_defers
		n = 0
		n_times = 20
		EM.run {
			n_times.times {
				EM.defer proc {
					sleep 0.1
				}, proc {
					n += 1
					EM.stop if n == n_times
				}
			}
		}
		assert_equal( n, n_times )
	end
	def test_defers
		10.times {
			run_em_with_defers {|n,ntimes|
				assert_equal( n, ntimes )
			}
		}
	end

end

