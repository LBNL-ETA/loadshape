#Loadshape
*A Python module containing tools for analyzing electric load shapes*


Generating baselines for electric loads can be tricky, this module makes it easy:

```
#!python
from loadshape import Loadshape

# electric load data - values are expected to be power (kW)
load_data = [ ("2013-08-01 00:00:00", 5.168),
              ("2013-08-01 00:15:00", 6.235),
              ("2013-08-01 00:30:00", 5.021),
              ...,
              ("2013-09-26 23:45:00", 4.739) ]

my_loadshape = Loadshape(load_data, timezone="America/Los_Angeles")
my_baseline = my_loadshape.baseline()
```

##Installation
To install using pip:
```sh
pip install git+https://bitbucket.org/berkeleylab/eetd-loadshape.git@master
```

##Dependencies
The loadshape module depends on R, and the 'optparse' R module

Install R using homebrew on OSX:
```sh
brew install R
```

[Install R using apt on Ubuntu](http://cran.r-project.org/bin/linux/ubuntu/README):
```sh
sudo apt-get install r-base-core
```

Once you have R installed, open up an R console and install optparse:
```sh
R
> install.packages("optparse")
# ... follow the instructions
```

Table of Contents:
----
+ [**Introduction**](#markdown-header-introduction)
+ [**Input Data:**](#markdown-header-input-data)
    + [Timestamps](#markdown-header-timestamps)
    + [Timezones](#markdown-header-timezones)
    + [Power Data](#markdown-header-power-data)
    + [CSV Inputs](#markdown-header-csv-inputs)
    + [Outdoor Air Temperature Data](#markdown-header-outdoor-air-temperature-data)
+ [**Calculations:**](#markdown-header-calculations)
    + [Baselines](#markdown-header-baselines)
    + [Measurement and Verification](#markdown-header-measurement-and-verification)
    + [Economic Valuation](#markdown-header-economic-valuation)
+ [**Future Development**](#markdown-header-future-development)
+ [**Contribution**](#markdown-header-contribution)

##Introduction
The loadshape module provides a quick and easy way to generate baselines and calculated quantities that are relevant for comparing actual electric loads with predicted (baseline) electric loads. The statistical model that is used by this module to generate baselines is intended to be used for electric loads that are sensitive to outdoor air temperature and which tend to follow trends based on time-of-week.

The Loadshape class that is provided by this module makes it easy to manage time series electric load data, and exposes a simple interface to several underlying R functions, including the function which fits a statistical model to the input load data for the purposes of generating baselines.

##Input Data
The only input data that the loadshape module requires in order to produce useful baselines is a set of time-series electric load data:

```python
# electric load data should be provided as a List of tuples
load_data = [ ("2013-08-01 00:00:00", 5.168),
              ("2013-08-01 00:15:00", 6.235),
              ("2013-08-01 00:30:00", 5.021),
              ...,
              ("2013-09-26 23:45:00", 4.739) ]

my_loadshape = Loadshape(load_data=load_data)
```

As shown in the example above, the load data should be provided in the form of a Python List containing Tuples with two elements each. The first element of each Tuple should be a timestamp, and the second element should be a value representing power (kW).

###Timestamps
For convenience, the timestamps within input data may take several different forms. All of the timestamps below are valid:

```python
valid_load_data = [ ("2013-08-01 00:00:00", 5.168), # string: "YYYY-MM-DD HH:MM:SS"
                    (1375341300, 6.235),            # integer: seconds since Unix epoch
                    (1375342200000, 5.021),         # integer: milliseconds since Unix epoch
                    ("1375343100", 5.046),          # string: seconds since Unix eopoch
                    ...,
                    ("1380264300000", 4.739) ]      # string: milliseconds since Unix epoch
```

###Timezones
It's important that you specify what timezones your timestamps refer to. If no timezone is specified, then the module will assume that you are using the timezone of your operating system, but this isn't necessarily a great assumption. Specify your timezone using the appropriate [timezone name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones) when you create a new instance of the Loadshape class.
```python
my_loadshape = Loadshape(load_data, timezone="America/Los_Angeles")
```
Using the correct timezone is important because the statistical model used to generate baselines makes some assumptions that depend on its ability to make reasonable assumptions regarding time-of-day and also time-of-week.

###Power Data
As noted above, the values within the provided time-series load data are assumed to prepresent power (kW). If the provided values do not represent kW, the unitless values that the module generates, including baselines, should be reasonable. Beware, though, that the units specified by the output of the event_performance method assumes that the power data has been provided in kW.

###Outdoor Air Temperature Data
Passing outdoor air temperature data in addition to electric load data will allow the loadshape module to produce much more accurate baselines. Specify the units of the temperature data by setting the temp_units argument to either "C" or "F".
```python
# electric load data - values are expected to be power (kW)
load_data = [ ("2013-08-01 00:00:00", 5.168),
              ("2013-08-01 00:15:00", 6.235),
              ("2013-08-01 00:30:00", 5.021),
              ...,
              ("2013-09-26 23:45:00", 4.739) ]

# outdoor air temperature data
temp_data = [ ("2013-08-01 00:00:00", 54.23),
              ("2013-08-01 01:00:00", 54.60),
              ("2013-08-01 02:00:00", 54.65),
              ...,
              ("2013-09-26 23:45:00", 58.44) ]

my_loadshape = Loadshape(load_data, temp_data, temp_units="F")
```

###CSV Inputs
As an alternative to passing input data to the Loadshape initializer as a List of Tuples, a reference to an appropriately formatted CSV file may be passed instead:
```python
my_loadshape = Loadshape("path/to/load_data.csv", "path/to/temperature_data.csv")
```
The loadshape module expects CSVs to contain two colums. As with the Tuples, the first element in each column should be a valid timestamp, and the second column should be the corresponding value. Valid timestamps are discussed in the timestamps section above.

##Calculations
The purpose of the Loadshape module is to simply and streamline the process of generating baselines and quantities that compare actual load performance to a calculated baseline. This section discusses this functionality and how to use it.

###Baselines
The core of the Loadshape module is the Baseline calculation. The following section describes the statistical model that is used to generate baselines, as well as some options that are availalbe for generating different types of baselines.

####The Baseline Model
The only input that this module requires is a time series of electric load data to which the baseline load shape model should be fit. If no other data is provided, then the baseline will be very simple: the predicted load for a given time of the week will simply be the weighted average load at that time of the week.

For example, the predicted load for a particular Tuesday at 12:15 would be the weighted average load on all other Tuesdays at 12:15. The weighting_days argument defines how this average is weighted. The default value for weighting_days is 14, which puts more statistical weight on most recent two weeks of data.

If outside air temperature data is provided in addition to the electric load data, a more sophisticated statistical model is fit. The temperature adjusted model assumes that the load data is that of a building with HVAC loads, and attempts to determine what times of the week the building is providing heating or cooling. When heating or cooling are being provided, the building is said to be in "occupied mode." Occupied and unoccupied mode are modeled separately. In each case, the load is predicted to be the sum of a time-of-week effect and a temperature-dependent effect. The temperature dependence is piecewise-linear; within each of several temperature ranges the load is assumed to increase or decrease linearly with temperature.

The model is described in these publications:
    
+ Mathieu et al., [Quantifying Changes in Building Electric Load, With Application to Demand Response.](http://drrc.lbl.gov/publications/quantifying-changes-building-electricity-use-application-demand-response) IEEE Transactions on Smart Grid 2:507-518, 2011  
+ Price P, [Methods for Analyzing Electric Load Shape and its Variability.](http://drrc.lbl.gov/publications/methods-analyzing-electric-load-shape-and-its-variability) Lawrence Berkeley National Laboratory Report LBNL-3713E, May 2010. 

####Generating Baselines

The Loadshape object has a baseline method that compiles the input data, passes the data to the R script that implements the baseline model, and then reads in the result. The baseline method will return an object (a Series object) containing the baseline data. The data method on this object is the preferred method for accessing the list of tuples containing the time series baseline data.

```python
>>> my_baseline = my_loadshape.baseline()
>>> my_baseline.data()
[(1375340400, 5.1), (1375341300, 5.1), (1375342200, 5.26), ..., (1380264300, 4.9)]
```

####Prediction Periods

By default, the baseline method on the Loadshape object will return a baseline for all of the input load data. To calculate the baseline for a specific period, just pass in some additional arguments to the baseline method:
```python
prediction_start = "2013-09-26 00:00:00"
prediction_end = "2013-09-26 23:45:00"

my_baseline = my_loadshape.baseline(prediction_start, prediction_end, step_size=900)
```
The step size argument above is optional, the default is 900 (seconds). Also, note that the prediction_start and prediction_end do not need to be within the date range of your input data. The module may be used to generate forecasted baselines.

####Forecasting with Outdoor Air Temperature Data

It is important to note that in order to produce a temperature adjusted baseline, the module requires outdoor air temperature data that overlaps both the input load data and the prediction period.

If you are generating a forecasted baseline, you may want to consider splitting your temperature data into two steams: one containing historical temperatures that overlaps the historical load data, and one containing forecasted temperatures that overlaps your desired prediction period.

If no temperature data is available for the requested prediction period, then the model will not be temperature adjusted. The resulting baseline will be the same as if no temperature data had been provided.

```python
# electric load data - values are expected to be power (kW)
load_data = [ ("2013-08-01 00:00:00", 5.168),
              ("2013-08-01 00:15:00", 6.235),
              ("2013-08-01 00:30:00", 5.021),
              ...,
              ("2013-09-26 23:45:00", 4.739) ]

# outdoor air temperature data
temp_data = [ ("2013-08-01 00:00:00", 54.23),
              ("2013-08-01 01:00:00", 54.60),
              ("2013-08-01 02:00:00", 54.65),
              ...,
              ("2013-09-26 23:45:00", 58.44) ]

# forecasted outdoor air temperature data
forecast_temp_data = [ ("2013-09-27 00:00:00", 52.15),
                       ("2013-09-27 01:00:00", 52.40),
                       ("2013-09-27 02:00:00", 51.85),
                       ...,
                       ("2013-09-27 23:45:00", 60.31) ]

my_loadshape = Loadshape(load_data, temp_data, forecast_temp_data)
my_loadshape.baseline("2013-09-27 00:00:00", "2013-09-27 23:45:00")
```

####Exclusion Periods

If you know that parts of your load data are anomalous for some reason, registering exclusion periods will omit these periods from the baseline calculation so that your baseline load shape will not be affected by them.  
```python
my_loadshape.add_exclusion(first_exclusion_start, first_exclusion_end)
my_loadshape.add_exclusion(second_exclusion_start, second_exclusion_end)
```
For example, if you have been testing some different energy management strategies and you want to use this baseline to calculate energy savings from a particular strategy, then you'll want to exclude all of the periods during which strategies were being tested, and only include periods that you consider to be "normal" operation.

####Named Exclusion Periods

The Loadshape module also includes a mechanism for excluding periods of data that are likely to be anomolous (ex: Holidays).

```python
my_load_shape.add_named_exclusion("US_HOLIDAYS")
```
Beware that the current implementation of named exclusions is not very sophisticated. Named exclusions currently consist of a hardcoded list of periods that can be found in exclusions.py.

####Modeling Interval

The modeling interval determines the resolution of the model that is used to make predictions. Higher resolution models will run more slowly. By default, the modeling interval is set to 900 seconds. The argument that defines the modeling interval should be passed in to the baseline method.
```python
my_baseline = my_loadshape.baseline(modeling_interval=300)
```

####Weighting

A "weighting_days" argument allows the model to be biased toward more (or less) recent data. The default value for this is 14 days, meaning the most recent 14 days of training data will be weighted more heavily than data that is older than 14 days. To configure the weighting differently, pass a weighting_days argument to the baseline method.
```python
my_baseline = my_loadshape.baseline(weighting_days=30)
```

####Goodness of Fit Statistics
Once a baseline has been generated, some goodness of fit statistics will be available in the form of a dictionary:
```python
>>>my_loadshape.baseline()
>>>my_loadshape.error_stats
{'rmse_interval': 1.723, 'corr_interval_daytime': 0.88, 'rmse_interval_daytime': 2.421, 'mape_hour': 11.343, 'mape_interval': 12.858, 'rmse_hour': 1.553, 'mape_interval_daytime': 19.576, 'corr_interval': 0.908, 'corr_hour': 0.92}
```

###Measurement and Verification
Streamlined caculation of baseline loadshapes is useful, but in most cases, baselines are being calculated for the purposes of comparing the predicted baseline to an actual load shape. The Loadshape module provides several methods that make this comparison simple.

####Difference Method
The Loadshape class includes a diff method that is purpose built for calculating the difference between a baseline and an actual load shape. This method passes a baseline timeseries and a actual load time series to an R script, which interpolates the two streams and outputs four streams of data:

+ kW difference (difference at each interval between actual and baseline)
+ cumulative kWh difference (accumulated kWh difference at each interval between actual and baseline)
+ kW baseline (interpolated baseline kW at each interval)
+ cumulative kwH baseline (cumulative interpolated baseline kWh at each interval)

These output streams might seem strange at first, but the differenc method outputs these to simplify the calculation of the magnitude of the calculated differences relative to the baseline.

####Cumulative Sum Method
The Loadshape class includes a cumulative_sum method that is purpose built for calculating the cumulative difference between a baseline and the actual load shape. The cumulative_sum method is a convenience method that simply wraps the diff method and returns only cumulative kWh difference stream. The cumulative_sum method also ensures that a baseline is available with whcih to compare the actual load shape data; if a baseline is not available, the method automatically generates one using the default arguments.

####Economic Valuation (Event Performance Method)
The Loadshape class includes an event_performance method that is purpose built for comparing the performance of a loadshape to a baseline over a specific period of time. The period over which this comparison is calculated could be an arbitrary length of time, but in practice this method is useful for calculating load performance relative to baseline on specific days when the load may be operating in a particularly energy efficient mode, or when a new optimization is being tested. Below is an example of usage:

```python
my_load_shape = Loadshape(load_data=LOAD_DATA, temp_data=TEMP_DATA,
                          timezone='America/Los_Angeles',
                          temp_units="F", sq_ft=BUILDING_SQ_FT)

# ----- build the baseline to use as a reference for performance ----- #
event_baseline = my_load_shape.baseline(weighting_days=14,
                                        modeling_interval=900,
                                        step_size=900)

# ----- calculate the performance summary for the event period ----- #
event_performance = my_load_shape.event_performance(EVENT_START, EVENT_END)

```
The output of the event performance method will include these calculated quantities:

+ average kW reduction relative to baseline
+ average percent kW reduction relative to baseline
+ average Watts per square foot reduction relative to baseline (if the Loadshape object was instantiated with a sq_ft argument)
+ total kWH reduction relative to baseline
+ percent kWh reduction relative to baseline
+ total savings ($)*
+ total percent savings*

*if the Loadshape object was instantiated with a Tariff

The "dr-event-calc.py" example in the examples directory demonstrates how this event_performance method can be used to caclulate load performance during a demand response event.

###Tariffs
The Loadshape class includes a cost method that enables the calculation of the cost of energy for a load based on a specific tarriff. In order to use this functionality, a tarriff object must be passed into the Loadshape object using the set_tariff method. A Tariff object should be instantiated with a json formatted tariff file from openei.org. An example of a valud tariff file is included in examples/data/tariff.json. The below example demonstrates how a Tariff object should be initialized and passed to the Loadshape object.

```python
tariff = Tariff(tariff_file='example_tariff.json', timezone='America/Los_Angeles')
tariff.add_dr_period("2013-09-23 14:00:00", "2013-09-23 16:00:00")
tariff.add_dr_period("2013-09-27 14:00:00", "2013-09-27 16:15:00")

my_load_shape.set_tariff(tariff)
```
Note that specifying dr periods, as shown above, is optional. Adding these dr periods will ensure that the dr day tariff that is specified in the tariff JSON is used during the periods specified. Also, note that if a Loadshape object has a tariff set, the event_performance method will use the cost method that is described below to calculate the financial savings during the event period. 

After a tariff has been set for a loadshape object, as shown above, the cost method may be used to calculate the cost of energy and the cumulative cost of energy at each interval of the data provied to the load_data argument. If no load_data argument is provided, the input data will default to the actual load data. The example below shows how the cost data for a baseline load shape can be calculated.
```python
my_load_shape.set_tariff(tariff)

#c: cost  cc: cumulative cost
c, cc = my_load_shape.cost(load_data=my_load_shape.baseline_series.data(),
                           start_at=start_at,
                           end_at=end_at)

```

##Future Development
  + add proper R bindings instead of shelling out to the R scripts
  + more sophisticated named exclusion periods
  + more robust timezone handling
  + move series diff functionality from R to python

##Contribution
Contributions are welcome and encouraged. If you find a bug, please file it. If you would like to see a feature added, please request it. If you would like to contribute code, please fork and submit a pull request.
