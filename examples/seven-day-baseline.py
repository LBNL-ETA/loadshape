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

import json
import datetime
from os import path
from loadshape import Loadshape, utils

# ----- config constants ----- #
BUILDING_NAME = "My Building"
BUILDING_SQ_FT = 5367

EXAMPLES_DIR    = path.dirname(path.abspath(__file__))
LOAD_DATA       = path.join(EXAMPLES_DIR, "data", "load.csv")
TEMP_DATA       = path.join(EXAMPLES_DIR, "data", "temp.csv")
TARIFF          = path.join(EXAMPLES_DIR, "data", "tariff.json")

BASELINE_NAME   = "Seven Day Baseline Test"
WEEK_START      = "2013-09-22"
WEEK_END        = "2013-09-29"

# ----- write JSON output file ----- #
def write_json(data, file_name='output.json'):
    print "writing file: %s" % file_name
    with open(file_name, 'w') as outfile:
        json.dump(data, outfile)
        outfile.close()

# ----- build loadshape object ----- #
my_load_shape = Loadshape(load_data=LOAD_DATA, temp_data=TEMP_DATA,
                          # tariff_schedule=tariff_schedule
                          timezone='America/Los_Angeles',
                          temp_units="F", sq_ft=BUILDING_SQ_FT)

# ----- add exclusions as necessary ----- #
my_load_shape.add_exclusion("2013-09-23 00:00:00", "2013-09-24 00:00:00")
my_load_shape.add_exclusion("2013-09-27 00:00:00", "2013-09-28 00:00:00")
my_load_shape.add_named_exclusion("US_HOLIDAYS")

# ----- generate a 7 day baseline ----- #
seven_day_baseline 	= my_load_shape.baseline(start_at=WEEK_START,
                                             end_at=WEEK_END,
                                             weighting_days=14,
                                             modeling_interval=900,
                                             step_size=900)

# ----- assemble a payload summarizng the seven day baseline ----- #
out = { "power_data": {} }
out["building"]                  = BUILDING_NAME
out["baseline_start_at"]         = WEEK_START
out["baseline_end_at"]           = WEEK_END
out["error_stats"]               = my_load_shape.error_stats
out["power_data"]["actual"]      = my_load_shape.actual_data(WEEK_START, WEEK_END)
out["power_data"]["baseline"]    = my_load_shape.baseline_data(WEEK_START, WEEK_END)

# ----- write output to file ----- #
file_name = path.join(EXAMPLES_DIR, "output", "seven-day-baseline-example.json")
write_json(data=out, file_name=file_name )

print "SEVEN DAY BASELINE EXAMPLE COMPLETE"
