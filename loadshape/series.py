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
import math
import utils
import numpy
import tempfile

import exclusions

class Series(object):

    def __init__(self, series=[], timezone=None, temp_units='F', data_column=1):
        '''series argument may be:
                - List of Tuples containing timestamps and values
                - filename of a csv containing timestamps and values
            kwargs are stored as Series metadata
        '''
        self.errors = []
        self.exclusions = []
        self.data_column = data_column
        
        self.temp_units = temp_units.upper()

        if isinstance(timezone, str) | (timezone == None):
            self.timezone = utils.get_timezone(timezone)
        else:
            self.timezone = timezone
        
        if isinstance(series, list):
            self.series = self.load_list(series)
        elif isinstance(series, str):
            self.series = self.load_list_from_csv(series)

        self._validate_series()
        self._sort_series()
    
    # --- accessors --- #
    def data(self, start_at=None, end_at=None, step_size=None, exclude=True):
        """raw data accessors, returns a list of tuples
        - a section of the series can be returned by supplying start_at/end_at
        - if no start_at or end_at is supplied, the whole series, except for
        exclusion periods is returned
        - if a step_size argument is present, data will be interpolated first
        """
        data = self.series
        
        # capture start_at / end_at
        if (start_at != None) & (end_at != None):
            slice_data = True
            start_at = utils.read_timestamp(start_at, self.timezone)
            end_at = utils.read_timestamp(end_at, self.timezone)
        else:
            slice_data = False
            start_at    = data[0][0]
            end_at      = data[-1][0]

        # if step_size is specified, interpolate
        if step_size != None:
            output_values = numpy.arange(start_at, (end_at + 1), step_size)
            x_values, y_values = zip(*data)

            interp_vals = numpy.interp(output_values, x_values, y_values)
            data = zip(output_values, interp_vals)
            data = [(e[0], round(e[1], 2)) for e in data]

        # if start_at / end_at were specified, slice data
        if slice_data == True:
            data = self._slice(list(data), start_at, end_at)

        # add in exclusions
        if exclude:
            for exclusion in self.exclusions:
                data = self._exclude(list(data), exclusion)

        return data

    def values(self):
        return [e[1] for e in self.series]
    
    def sum(self):
        return sum(self.values())

    def average(self):
        return self.sum() / len(self.series)

    def start_at(self):
        return self.series[0][0]

    def end_at(self):
        return self.series[-1][0]

    # --- convenience methods --- #        
    def is_farenheit(self):
        return self.temp_units == 'F'
            
    def valid(self):
        return self._validate_series(exception=False)

    # --- data loading --- #
    def load_list(self, data):
        """load list of tuples
        - each tuple must be of the form: (timestamp, value)
        - timestamps may be:
            - unix seconds since epoch
            - unix milliseconds since epoch
            - strings of the form YYYY-MM-DD HH:MM:SS
        - values may be:
            - anything that can be coerced to python float
            - anything else will be ignored
            
        Note on timezones:
        - a tz_utc_offset (hours) should be provided
        - timestamps are stored as seconds since the unix epoch (seconds utc)
        - the tz_utc_offset (hours) will be applied when parsing integer timestamps
        and when converting integer timestamp strings
        """
        series = []

        for entry in data:
            time = utils.read_timestamp(entry[0], self.timezone)
            try: value = float(entry[1])
            except: value = float('nan')
            if math.isnan(value) != True: series.append((time, value))
        
        return series
            
    def load_list_from_csv(self, filename):
        """load CSV data from file"""
        with open(filename, 'r') as f:
            csv_data = [(e[0], e[self.data_column]) for e in csv.reader(f) if e]
        
        return self.load_list(csv_data)

    # --- file writers --- #            
    def write_to_file(self, file_obj=None, file_name='series.csv',
                      start_at=None, end_at=None, exclude=True):
        if file_obj == None: file_obj = open(file_name, 'w')

        for time, value in self.data(start_at=start_at, end_at=end_at, exclude=exclude):
            time = utils.int_to_datetime(time, self.timezone).strftime("%Y-%m-%d %H:%M:%S")
            file_obj.write("%s,%s\n" % (time, value))
        
        file_obj.flush()
        return file_obj

    def write_to_tempfile(self, start_at=None, end_at=None, exclude=True):
        tmp_file = tempfile.NamedTemporaryFile()
        return self.write_to_file(tmp_file, start_at=start_at, end_at=end_at, exclude=exclude)

    # --- exclusion periods --- #
    def add_exclusion(self, exclusion_start, exclusion_end):
        exclusion_start = utils.read_timestamp(exclusion_start, self.timezone)
        exclusion_end = utils.read_timestamp(exclusion_end, self.timezone)
        self.exclusions.append( (exclusion_start, exclusion_end) )
        return True
    
    def add_named_exclusion(self, exclusion_name):
        # try:
        named_exclusion = getattr(exclusions, exclusion_name)
        # except:
        #     raise Exception("unknown named exclusion")

        for exclusion_start in named_exclusion.values():
            exclusion_start = utils.read_timestamp(exclusion_start, self.timezone)
            exclusion_end = exclusion_start + (3600 * 24)
            self.add_exclusion(exclusion_start, exclusion_end)

        return True

    def clear_exclusions(self):
        self.exclusions = []

    def _exclude(self, data, exclusion):
        """exclude an exclusion period
            - assumes exclusion timestamps already converted to unix
            - pretty unintelligent, should be optimized
        """
        return [e for e in data if (e[0] < exclusion[0]) | (e[0] > exclusion[1])]
    
    def _slice(self, data, start_at, end_at):
        """slice data to only include entries between start_at and end_at"""
        return [e for e in data if (e[0] >= start_at) & (e[0] <= end_at)]
        
    # --- series sorter --- #
    def _sort_series(self):
        """sort series data by time
            - this is pretty inefficient should probably change this out
        """
        self.series.sort(key=lambda e: e[0])
        
    # --- series validations --- #
    def _validate_entry_is_tuple(self, entry):
        if not isinstance(entry, tuple):
            self.errors.append("input data must be a List of Tuples")
    
    def _validate_timestamp_is_int(self, timestamp):
        if not isinstance(timestamp, int):
            self.errors.append("first item in each tuple must be an integer timestamp")
            
    def _validate_timestamp_format(self, timestamp):
        if len(str(timestamp)) > 10:
             self.errors.append("timestamps must be in seconds since unix epoch")
    
    def _validate_value_numberness(self, value):
        if (not isinstance(value, int)) & (not isinstance(value, float)) & (value != None):
            self.errors.append("values must be either ints, floats, or None")

    def _validate_series(self, exception=True):
        '''series validation:
            - should be a list of tuples
            - timestamps must be ints
            - timestamps must be unix seconds since epoch
            - values must be floats or ints
        '''
        self.errors = []
        
        for entry in self.series:
            self._validate_entry_is_tuple(entry)            
            self._validate_timestamp_is_int(entry[0])
            self._validate_timestamp_format(entry[0])
            self._validate_value_numberness(entry[1])
            if len(self.errors) > 0: break
        
        if exception & len(self.errors) != 0: raise Exception(self.errors[0])
        return True if len(self.errors) == 0 else False
