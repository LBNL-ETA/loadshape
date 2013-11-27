# --------------------------------------------------
# Building Energy Baseline Analysis Package
#
# Copyright (c) 2013, The Regents of the University of California, Department
# of Energy contract-operators of the Lawrence Berkeley National Laboratory.
# All rights reserved.
# 
# The Regents of the University of California, through Lawrence Berkeley National
# Laboratory (subject to receipt of any required approvals from the U.S.
# Department of Energy). All rights reserved.
# 
# If you have questions about your rights to use or distribute this software,
# please contact Berkeley Lab's Technology Transfer Department at TTD@lbl.gov
# referring to "Building Energy Baseline Analysis Package (LBNL Ref 2014-011)".
# 
# NOTICE: This software was produced by The Regents of the University of
# California under Contract No. DE-AC02-05CH11231 with the Department of Energy.
# For 5 years from November 1, 2012, the Government is granted for itself and
# others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide
# license in this data to reproduce, prepare derivative works, and perform
# publicly and display publicly, by or on behalf of the Government. There is
# provision for the possible extension of the term of this license. Subsequent to
# that period or any extension granted, the Government is granted for itself and
# others acting on its behalf a nonexclusive, paid-up, irrevocable worldwide
# license in this data to reproduce, prepare derivative works, distribute copies
# to the public, perform publicly and display publicly, and to permit others to
# do so. The specific term of the license can be identified by inquiry made to
# Lawrence Berkeley National Laboratory or DOE. Neither the United States nor the
# United States Department of Energy, nor any of their employees, makes any
# warranty, express or implied, or assumes any legal liability or responsibility
# for the accuracy, completeness, or usefulness of any data, apparatus, product,
# or process disclosed, or represents that its use would not infringe privately
# owned rights.
# --------------------------------------------------

import pytz
import unittest

from loadshape import utils

class TestUtils(unittest.TestCase):
    # for timestamp conversion tests (zone = 'America/Los_Angeles'):
    # unix:             local:                      utc:    
    # 1381561200        2013-10-12 00:00:00 -0700   2013-10-12 07:00:00

    def test_read_timestamp_string(self):
        tz = pytz.timezone('America/Los_Angeles')
        result = utils.read_timestamp("2013-10-12 00:00:00", tz)
        assert result == 1381561200

    def test_read_timestamp_seconds_int(self):
        tz = pytz.timezone('America/Los_Angeles')
        assert utils.read_timestamp("1381561200", tz) == 1381561200
    
    def test_read_timestamp_milliseconds_float(self):
        tz = pytz.timezone('America/Los_Angeles')
        assert utils.read_timestamp("1381561200000.0", tz) == 1381561200

    def test_read_timestamp_datetime(self):
        tz = pytz.timezone('America/Los_Angeles')
        dt = utils.str_to_datetime("2013-10-12 00:00:00", tz)
        assert utils.read_timestamp(dt, tz) == 1381561200
    
    def test_int_to_datetime_seconds(self):
        tz = pytz.timezone('America/Los_Angeles')
        result = utils.int_to_datetime(1381561200, tz)
        assert result.strftime("%Y-%m-%d %H:%M:%S %z") == "2013-10-12 00:00:00 -0700"
    
    def test_int_to_datetime_milliseconds(self):
        tz = pytz.timezone('America/Los_Angeles')
        result = utils.int_to_datetime(1381561200000, tz)
        assert result.strftime("%Y-%m-%d %H:%M:%S %z") == "2013-10-12 00:00:00 -0700"
    
    def test_str_to_datetime(self):
        tz = pytz.timezone('America/Los_Angeles')
        result = utils.str_to_datetime("2013-10-12 00:00:00", tz)
        assert result.strftime("%Y-%m-%d %H:%M:%S %z") == "2013-10-12 00:00:00 -0700"
    
    def test_datetime_to_int(self):
        tz = pytz.timezone('America/Los_Angeles')
        dt = utils.str_to_datetime("2013-10-12 00:00:00", tz)
        assert utils.datetime_to_int(dt) == 1381561200

def main():
    unittest.main()

if __name__ == '__main__':
    main()
