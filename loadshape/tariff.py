# --------------------------------------------------
# loadshape - a set of tools for analyzing electric load shapes
#
# Dave Riess
# eetd.lbl.gov
# driess@lbl.gov
#
# License: MIT
# --------------------------------------------------

import csv
import json
import utils
import tempfile
import logging

class Tariff(object):

    def __init__(self, tariff_file=None, timezone=None, log_level=logging.INFO):
        """load_data, temp_data, and forecast_temp_data may be:
                - List of Tuples containing timestamps and values
                - filename of a csv containing timestamps and values
                - Series object
        """
        logging.basicConfig(level=log_level)
        self.logger = logging.getLogger(__name__)

        if timezone == None: self.logger.warn("Assuming timezone is OS default")
        self.timezone           = utils.get_timezone(timezone)

        self.tariff_file        = None
        self.tariff_json        = None
        self.rate_structure     = None
        self.rate_schedule      = None
        self.dr_periods          = []

        if tariff_file != None: self.parse(tariff_file)
        
    def parse(self, tariff_file):
        """read tariff file / parse data"""
        self.read_tariff_file(tariff_file)
        self.parse_rate_structure()
        self.parse_rate_schedule()

    def read_tariff_file(self, tariff_file):
        """read tariff file, parse json, save to instnace variable"""
        self.tariff_file = open(tariff_file)
        self.tariff_json = json.load(self.tariff_file)['items'][0]

    def parse_rate_structure(self):
        rate_structure = {}

        for spec, value in self.tariff_json.iteritems():
            if 'energyratestructure' in spec:
                spec = spec.split('/')

                period 		= int(spec[1][-1])
                spec_attr 	= str(spec[2])

                rate_structure.setdefault(period, {})
                rate_structure[period][spec_attr] = value

        self.rate_structure = rate_structure
        return rate_structure

    def parse_rate_schedule(self):
        rate_schedule = {}

        known_schedules = {
                            'energyweekdayschedule':	'weekday',
                            'energyweekendschedule':	'weekend',
                            'energydrdayschedule':		'dr'
                           }

        for key_name, schedule_name in known_schedules.iteritems():
            schedule = self.tariff_json.get(key_name)
            if schedule != None:
                schedule = [str(schedule[i:i+24]) for i in range(0, len(schedule), 24)]
                rate_schedule[schedule_name] = schedule

        self.rate_schedule = rate_schedule
        return rate_schedule

    def weekday_schedule(self):
        return self.rate_schedule.get('weekday', None)

    def weekend_schedule(self):
        return self.rate_schedule.get('weekend', None)

    def dr_day_schedule(self):
        return self.rate_schedule.get('dr', None)

    def add_dr_period(self, start_at, end_at):
        period_start = utils.read_timestamp(start_at, self.timezone)
        period_end = utils.read_timestamp(end_at, self.timezone)
        self.dr_periods.append( (period_start, period_end) )
        return True

    # --- file writers --- #            
    def write_tariff_to_file(self, file_obj=None, file_name='tariff.csv'):
        if file_obj == None: file_obj = open(file_name, 'w')

        # write price structure
        file_obj.write("# rate structure\n")

        for period, rate in self.rate_structure.iteritems():
            file_obj.write("%s,%s,%s\n" % (period, rate["tier1rate"], rate["tier1sell"]))

        # write weekday schedule
        file_obj.write("# weekday schedule\n")
        for day in self.weekday_schedule(): file_obj.write("%s\n" % day)

        # write weekend schedule
        if self.weekend_schedule():
            file_obj.write("# weekend schedule\n")
            for day in self.weekend_schedule(): file_obj.write("%s\n" % day)
        
        if self.dr_day_schedule():
            file_obj.write("# dr day schedule\n")
            for day in self.dr_day_schedule(): file_obj.write("%s\n" % day)

        file_obj.flush()
        return file_obj

    def write_tariff_to_tempfile(self):
        tmp_file = tempfile.NamedTemporaryFile()
        return self.write_tariff_to_file(tmp_file)

    def write_dr_periods_to_file(self, file_obj=None, file_name='dr_periods.csv'):
        if file_obj == None: file_obj = open(file_name, 'w')

        for period in self.dr_periods:
            start_at = utils.int_to_datetime(period[0], self.timezone).strftime("%Y-%m-%d %H:%M:%S")
            end_at = utils.int_to_datetime(period[1], self.timezone).strftime("%Y-%m-%d %H:%M:%S")
            file_obj.write("%s,%s\n" % (start_at, end_at))

        file_obj.flush()
        return file_obj

    def write_dr_periods_to_tempfile(self):
        tmp_file = tempfile.NamedTemporaryFile()
        return self.write_dr_periods_to_file(tmp_file)
