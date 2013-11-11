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
import utils
import tempfile
import logging

from os import path
from series import Series
from tariff import Tariff
from subprocess import Popen, PIPE

class Loadshape(object):
    
    def __init__(self, load_data, temp_data=None, forecast_temp_data=None,
                 timezone=None, temp_units='F', sq_ft=None,
                 tariff=None, log_level=logging.INFO):
        """load_data, temp_data, and forecast_temp_data may be:
                - List of Tuples containing timestamps and values
                - filename of a csv containing timestamps and values
                - Series object
        """
        logging.basicConfig(level=log_level)
        self.logger = logging.getLogger(__name__)

        if timezone == None: self.logger.warn("Assuming timezone is OS default")

        self.timezone   = utils.get_timezone(timezone)
        self.model_dir  = path.join(path.dirname(path.abspath(__file__)), 'r')
        self.temp_units = temp_units
        self.sq_ft      = sq_ft
        self.tariff     = tariff

        self.training_load_series           = self._get_series(load_data)
        self.training_temperature_series    = self._get_series(temp_data)
        self.forecast_temperature_series    = self._get_series(forecast_temp_data)
        
        self._stderr = None
        self._stdout = None

        self._reset_derivative_data()

    # ----- derivative data generators ----- #
    # baseline:             generates the baseline_series for the input data
    # diff:                 generates the diff_series (actual - baseline)
    # event_performance:    uses the diff for a specific time interval to compute
    #                       various performance statistics
    #
    def baseline(self, start_at=None, end_at=None,
                 weighting_days=14, modeling_interval=900, step_size=900):
        """baseline load shape generator: compiles necessary temporary files and
        shells out to R script:
        - training power data: timestamps and kW
        - training temperature data: timestamps and outdoor air temp [optional]
        - prediction times: timestamps only, prediction made for these times
        - prediction temperature data: timestamps and outdoor air temp [optional]
        
        Note: prediction temperature data is optional, but if training temperature
        data is provided but does not include temperatures for the requested
        prediction period, the model will ignore the temperature data. In order
        to get temperature adjusted predictions, temperature data must be available
        for both the training data and the prediction period.
        
        baseline.R
            --loadFile=LOAD_FILE
            --temperatureFile=TRAINING_TEMPERATURE_FILE
            --timeStampFile=PREDICTION_TIME_STAMPS_FILE
            --predictTemperatureFile=PREDICTION_TEMPERATURE_FILE
            --outputBaselineFile=OUTPUT_BASELINE_FILE
            --errorStatisticsFile=ERROR_STATISTICS_FILE
            --fahrenheit=BOOLEAN
            --timescaleDays=TIMESCALEDAYS
            --intervalMinutes=INTERVALMINUTES
        """
        self._reset_derivative_data()
    
        output_times = self._build_output_time_series(start_at, end_at, step_size)
        
        # ----- write temporary files ----- #
        baseline_tmp    = tempfile.NamedTemporaryFile()
        error_stats_tmp = tempfile.NamedTemporaryFile()
        power_tmp       = self.training_load_series.write_to_tempfile()
        prediction_tmp  = output_times.write_to_tempfile()

        # ----- build command ----- #
        cmd = path.join(self.model_dir, 'baseline.R')
        cmd += " --loadFile=%s"                 % power_tmp.name
        cmd += " --timeStampFile=%s"            % prediction_tmp.name
        cmd += " --outputBaselineFile=%s"       % baseline_tmp.name
        cmd += " --errorStatisticsFile=%s"      % error_stats_tmp.name
        cmd += " --timescaleDays=%s"            % weighting_days
        cmd += " --intervalMinutes=%s"          % (modeling_interval / 60)

        # ----- add in available temperature data ----- #
        if self.training_temperature_series != None:
            t_temp_tmp = self.training_temperature_series.write_to_tempfile()
            cmd += " --temperatureFile=%s" % t_temp_tmp.name
            f_flag = str(self.training_temperature_series.is_farenheit()).upper()
            cmd += " --fahrenheit=%s" % f_flag
            
            if self.forecast_temperature_series != None:
                ptemp_temp = self.forecast_temperature_series.write_to_tempfile()
                cmd += " --predictTemperatureFile=%s" % ptemp_temp.name

        # ----- run script ----- #
        self._run_script(cmd)

        # ----- process results ----- #
        self.baseline_series = Series(baseline_tmp.name, self.timezone)
        self.error_stats = self._read_error_stats(error_stats_tmp.name)
        
        return self.baseline_series

    def cost(self, load_data=None, start_at=None, end_at=None, step_count=None):
        """calculate the cost of energy based on the provided tariff

        R script produces one output file:
        timestamp, previous-interval-cost, cumulative-previous-interval-cost

        [tariff.R command]
        ./tariff.R
            --loadFile=LOAD_FILE
            --tariffFile=TARIFF_FILE
            --outputTimestampFile=OUTPUT_TIMES_FILE
            --demandResponseFile=DEMAND_RESPONSE_DATES
            --outputFile=OUTPUT_FILE
        """
        if load_data == None: load_data = self.training_load_series
        
        if not isinstance(load_data, Series):
            raise Exception("load_data argument must be a Series object")
        if not isinstance(self.tariff, Tariff):
            raise Exception("cannot calculate cost - no tariff provided")

        output_times = self._build_output_time_series(start_at, end_at,
                                                      step_size=900,
                                                      step_count=step_count)

        # ----- write temporary files ----- #
        load_tmp            = load_data.write_to_tempfile(exclude=False)
        tariff_tmp          = self.tariff.write_tariff_to_tempfile()
        output_times_tmp    = output_times.write_to_tempfile()
        output_tmp          = tempfile.NamedTemporaryFile()

        # ----- build command ----- #
        cmd = path.join(self.model_dir, 'tariff.R')
        cmd += " --loadFile=%s"             % load_tmp.name
        cmd += " --tariffFile=%s"           % tariff_tmp.name
        cmd += " --outputTimestampFile=%s"  % output_times_tmp.name
        cmd += " --outputFile=%s"           % output_tmp.name

        if len(self.tariff.dr_periods) > 0:
            dr_periods_tmp = self.tariff.write_dr_periods_to_tempfile()
            cmd += " --demandResponseFile=%s" % dr_periods_tmp.name

        self._run_script(cmd)
        
        # ----- process results ----- #
        cost_series             = Series(output_tmp.name, self.timezone, data_column=1)
        cumulative_cost_series  = Series(output_tmp.name, self.timezone, data_column=2)

        return cost_series, cumulative_cost_series
            
    def diff(self, start_at=None, end_at=None, step_size=900, step_count=None):
        """calculate the difference between baseline and actual

        R script produces two output files:
        (1) diff:       timestamp,  kw_diff,    cumulative_kwh_diff
        (2) baseline:   timestamp,  kw_base,    cumulative_kwh_base

        [diff.R command]
        ./diff.R
            --loadFile=LOAD_FILE
            --baselineFile=BASELINE_LOAD_FILE
            --outputTimesFile=OUTPUT_TIMES_FILE
            --outputFile=OUTPUT_DIFF_FILE
            --predictedBaselineOutputFile=OUTPUT_BASE_FILE
        """
        if self.baseline_series == None: self.baseline()
        
        output_times = self._build_output_time_series(start_at, end_at,
                                                      step_size, step_count)

        # ----- write temporary files ----- #
        load_tmp            = self.training_load_series.write_to_tempfile(exclude=False)
        baseline_tmp        = self.baseline_series.write_to_tempfile()
        output_times_tmp    = output_times.write_to_tempfile()
        output_diff_tmp     = tempfile.NamedTemporaryFile()
        output_base_tmp     = tempfile.NamedTemporaryFile()
        
        # ----- build command ----- #
        cmd = path.join(self.model_dir, 'diff.R')
        cmd += " --loadFile=%s"                     % load_tmp.name
        cmd += " --baselineFile=%s"                 % baseline_tmp.name
        cmd += " --outputTimesFile=%s"              % output_times_tmp.name
        cmd += " --outputFile=%s"                   % output_diff_tmp.name
        cmd += " --predictedBaselineOutputFile=%s"  % output_base_tmp.name
        
        # ----- run script ----- #
        self._run_script(cmd)

        # ----- process results ----- #
        kw_diff = Series(output_diff_tmp.name, self.timezone, data_column=1)
        kw_base = Series(output_base_tmp.name, self.timezone, data_column=1)

        cumulative_kwh_diff = Series(output_diff_tmp.name, self.timezone, data_column=2)
        cumulative_kwh_base = Series(output_base_tmp.name, self.timezone, data_column=2)

        return kw_diff, kw_base, cumulative_kwh_diff, cumulative_kwh_base
        
    def event_performance(self, start_at=None, end_at=None):
        """calcualte the event performance for a specific period of time
        returned performance metrics:
            - avg_kw_shed:              (average kW diff)
            - avg_percent_kw_shed       (average kW diff / average kW baseline)
            - kwh_reduction             (cumulative delta kWh)
            - percent_kwh_reduction     (cumulative delta kWh / cumulative kWh baseline)
            - total_savings ($)
            - total_percent_savings ($)
            - avg_w_sq_ft_shed          (average kW shed * 1000 / sq_ft)
        """
        # get diff values for period by diffing over a single interval
        diff_data = self.diff(start_at, end_at, step_count=1)
        kw_diff_series = diff_data[0]
        kw_base_series = diff_data[1]
        cumulative_kwh_diff_series = diff_data[2]
        cumulative_kwh_base_series = diff_data[3]

        # extract data from diff series
        ep = {}
        ep["avg_kw_shed"]           = kw_diff_series.values()[-1] * -1
        avg_kw_base                 = kw_base_series.values()[-1]
        ep["avg_percent_kw_shed"]   = (ep["avg_kw_shed"] / avg_kw_base) * 100
        ep["kwh_reduction"]         = cumulative_kwh_diff_series.values()[-1] * -1
        kwh_base                    = cumulative_kwh_base_series.values()[-1]
        ep["percent_kwh_reduction"] = (ep["kwh_reduction"] / kwh_base) * 100

        # add in W per square feet if square footage was provided
        if self.sq_ft:
            ep["avg_w_sq_ft_shed"]  = (ep["avg_kw_shed"] * 1000) / self.sq_ft

        # calculate $ savings if tariff provided
        if self.tariff != None:
            load_cost, load_cumulative_cost = self.cost(load_data=self.training_load_series,
                                                        start_at=start_at,
                                                        end_at=end_at,
                                                        step_count=1)

            base_cost, base_cumulative_cost = self.cost(load_data=self.baseline_series,
                                                        start_at=start_at,
                                                        end_at=end_at,
                                                        step_count=1)

            total_load_cost = load_cumulative_cost.values()[-1]
            total_base_cost = base_cumulative_cost.values()[-1]

            ep["total_savings"] = total_base_cost - total_load_cost
            ep["total_percent_savings"] = (ep["total_savings"] / total_base_cost) * 100

        # round values to something reasonable
        for key, val in ep.iteritems():
            if isinstance(val, float): ep[key] = round(val, 2)

        return ep
    
    def cumulative_sum(self, start_at=None, end_at=None, step_size=900):
        """return accumulated sum of differences bewetween baseline and actual
        energy. Returns a series.
        """
        if self.baseline_series == None: self.baseline()

        diff_data = self.diff(start_at, end_at, step_size)
        cumulative_kwh_diff_series = diff_data[2]
        return cumulative_kwh_diff_series    

    def _run_script(self, command):
        self.logger.info("Running R script...")

        p = Popen(command, shell=True, stdout=PIPE, stderr=PIPE)
        stdout, stderr = p.communicate()

        self._stdout = stdout
        self._stderr = stderr

        if stderr:
            self.logger.error(" --- R script error: --- ")
            for l in stderr.splitlines(): print " --> %s" % l

        if stdout:
            self.logger.info(" --- R script info: --- ")
            for l in stdout.splitlines(): print " --> %s" % l

        return True

    def actual_data(self, start_at, end_at, exclude=False, step_size=None):
        return self.training_load_series.data(start_at=start_at, end_at=end_at, exclude=exclude, step_size=step_size)

    def baseline_data(self, start_at, end_at, exclude=False, step_size=None):
        return self.baseline_series.data(start_at=start_at, end_at=end_at, exclude=exclude, step_size=step_size)

    def add_exclusion(self, start_at, end_at):
        """proxy add_exclusion to series"""
        self.training_load_series.add_exclusion(start_at, end_at)

    def add_named_exclusion(self, exclusion_name):
        """proxy add_named_exclusion to series"""
        self.training_load_series.add_named_exclusion(exclusion_name)

    def clear_exclusions(self):
        """proxy clear_exclusion to series"""
        self.training_load_series.clear_exclusions()

    def set_tariff(self, tariff):
        """add or replace tariff"""
        self.tariff = tariff

    def _get_series(self, data):
        """returns a series built from the data arg
        - if the data arg is None: return None
        - if the data arg is a Series: return the Series
        - if the data arg is a string: attempt to build Series from file path
        - if the data arg is a List: attempt to build Series from list
        """
        if (isinstance(data, Series)) | (data == None):
            return data
        else:
            return Series(data, self.timezone, self.temp_units)

    def _build_output_time_series(self, start_at=None, end_at=None,
                                  step_size=900, step_count=None):
        """assemble prediction series:
        - this is the series of timestamps for which baseline values will be calculated
        - the prediction series is stored in a Series object to take advantage of some of the Series features
        - default start_at/end is training_load_series.start_at/end_at
        - default prediction step is 900s
        - step_count will trump step_size
        """
        if start_at == None: start_at = self.training_load_series.start_at()
        if end_at == None: end_at = self.training_load_series.end_at()
        
        start_at = utils.read_timestamp(start_at, self.timezone)
        end_at = utils.read_timestamp(end_at, self.timezone)

        if step_count != None:
            duration = end_at - start_at
            step_size = int(float(duration) / step_count)

        p_data = range(start_at, end_at+1, step_size)
        p_data = [(v, 0) for v in p_data]
        
        return Series(p_data, self.timezone)

    def _read_error_stats(self, error_stats_file):
        """read error stats file and return values"""
        error_stats = {}
        
        with open(error_stats_file, 'r') as f:
            for ent in csv.reader(f):
                if ent: error_stats[ent[0].lower()] = float(ent[1])
                
        return error_stats

    def _reset_derivative_data(self):
        self.baseline_series                = None
        self.error_stats                    = None
        self.base_cost_series               = None
        self.load_cost_series               = None
