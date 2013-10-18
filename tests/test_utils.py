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
