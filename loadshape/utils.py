# --------------------------------------------------
# loadshape - a set of tools for analyzing electric load shapes
#
# Dave Riess
# eetd.lbl.gov
# driess@lbl.gov
#
# License: MIT
# --------------------------------------------------

import pytz
import tzlocal
import calendar
import datetime

def read_timestamp(ts, tz):
    """
    accepts: integer (unix time - seconds or milliseconds)
             string format YYYY-MM-DD HH:MM:SS
    returns: integer (unix time - seconds) 
    """
    if isinstance(ts, datetime.datetime):
        if (ts.tzinfo == None): raise Exception("timestamps must not be naive")
    else:
        try: ts = int(float(ts))
        except: ts = str(ts)

        if isinstance(ts, str):
            ts = str_to_datetime(ts, tz)
        else:
            ts = int_to_datetime(ts, tz)
        
    return datetime_to_int(ts)

def datetime_to_int(ts):
    """
    accepts: datetime object (tz aware)
    returns: integer (unix time - seconds)
    """
    if (ts.tzinfo == None): raise Exception("timestamps must not be naive")
    return int(calendar.timegm(ts.utctimetuple()))

def int_to_datetime(ts, tz):
    """
    accepts: integer (unix time - seconds or milliseconds)
    returns: datetime object (tz aware)
    """
    if len(str(ts)) > 10: ts = ts / 1000
    return datetime.datetime.fromtimestamp(ts, tz)

def str_to_datetime(ts, tz):
    """
    accepts: string format YYYY-MM-DD HH:MM:SS
    returns: datetime object (tz aware)
    """
    if ":" in ts:
        ts = datetime.datetime.strptime(ts, "%Y-%m-%d %H:%M:%S")
    else:
        ts = datetime.datetime.strptime(ts, "%Y-%m-%d")

    return tz.localize(ts)

def get_timezone(tz_name=None):
    """ returns a pytz timezone object
    if no tz_name is provided a pytz object representing the OS timezone is returned
    """
    if tz_name != None:
        return pytz.timezone(tz_name)
    else:
        return tzlocal.get_localzone()
