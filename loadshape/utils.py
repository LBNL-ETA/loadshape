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
