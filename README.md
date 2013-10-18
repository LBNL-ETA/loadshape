#Loadshape
Tools for analyzing electric load shapes.  

Generating baselines for electric loads can be tricky, this module makes it easy.

```python  
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

The loadshape module provides a quick and easy way to generate baselines from time series electric load data. The module also provides some functionality that makes it easy to calculate quantities and statistics that are useful for comparing loads to their baselines.  

The Loadshape class provided by the module makes it easy to manage time series electric laod data, and exposes a simple interface to several underlying R functions, including the function which fits a statistical model to the input load data for the purposes of generating baselines.

The example above demonstrates the simplest possible use of the module, more advanced usage is described below and on the wiki.

Installation
----
To install using pip:
```sh
pip install git+https://bitbucket.org/berkeleylab/eetd-loadshape.git@master
```

Dependencies
----
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

The Baseline Model
----
The only input that this module requires is a time series of electric load data to which the baseline load shape model should be fit. If no other data is provided, then the baseline will be very simple: the predicted load for a given time of the week will simply be the average load at that time of the week.

For example, the predicted load for a particular Tuesday at 12:15 would be the weighted average load on all other Tuesdays at 12:15. The weighting_days defaults to 14, which puts more statistical weight on most recent two weeks of data.

If outside air temperature data is provided (see below) in addition to the electric load data, a more sophisticated statistical model is fit. The temperature adjusted model assumes that the load data is that of a building with HVAC loads, and attempts to determine what times of the week the building is providing heating or cooling. When heating or cooling are being provided, the building is said to be in "occupied mode." Occupied and unoccupied mode are modeled separately. In each case, the load is predicted to be the sum of a time-of-week effect and a temperature-dependent effect. The temperature dependence is piecewise-linear; within each of several temperature ranges the load is assumed to increase or decrease linearly with temperature.

The model is described in these publications:
    
+ Mathieu et al., [Quantifying Changes in Building Electric Load, With Application to Demand Response.](http://drrc.lbl.gov/publications/quantifying-changes-building-electricity-use-application-demand-response) IEEE Transactions on Smart Grid 2:507-518, 2011  
+ Price P, [Methods for Analyzing Electric Load Shape and its Variability.](http://drrc.lbl.gov/publications/methods-analyzing-electric-load-shape-and-its-variability) Lawrence Berkeley National Laboratory Report LBNL-3713E, May 2010. 


Outdoor Air Temperature Data
----
Outdoor air temperature data will make your baseline much more accurate, so if you have outdoor air temperature data that spans the same period of time that your load data spans, it's a good idea to pass that in:
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

my_baseline = Baseline(load_data, temp_data, temp_units="F")
```
Note the temp_units argument. Temperature data that is passed in is assumed to be in Farenheit unless otherwise stated.

Baseline Generator
----
The Baseline object's generate method compiles the input data, passes the data to the R script, and then reads in the result. The generate method will return a list of tuples containing the time-series baseline data.

```python
>>> my_baseline_data = my_baseline.generate()
>>> my_baseline_data
[(1375340400, 5.1), (1375341300, 5.1), (1375342200, 5.26), ..., (1380264300, 4.9)]
```

Prediction Periods
----

By default, the Baseline object's generate method will return a baseline for all of the input load data. To calculate the Baseline for a specific period, just pass in some additional arguments to the generate method:
```python
prediction_start = "2013-09-26 00:00:00"
prediction_end = "2013-09-26 23:45:00"

my_baseline_data = my_baseline.generate(prediction_start, prediction_end, step_size=900)
```
The step size argument above is optional, the default is 900 (seconds). Also, note that the prediction_start and prediction_end do not need to be within the date range of your input data. The module may be used to generate forecasted baselines.

Forecasting with Outdoor Air Temperature Data
----
It's important to note that in order to produce a temperature adjusted baseline, the module requires outdoor air temperature data that overlaps both the input load data and the prediction period.

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

my_baseline = Baseline(load_data, temp_data, forecast_temp_data)
my_baseline.generate("2013-09-27 00:00:00", "2013-09-27 23:45:00")
```

CSV Inputs
----
For your convenience, instead of passing your raw data in as Lists of Tuples, you can pass in references to CSV files:
```python
my_baseline = Baseline("path/to/load_data.csv", "path/to/temperature_data.csv")
```

CSVs should have timestamps formatted in one of the following ways:  

+ seconds since Epoch starting 1970-01-01
+ milliseconds since Epoch starting 1970-01-01
+ timestamps of the form YYYY-MM-DD HH:MM:SS

CSVs should look like this:
```csv
1379487600, 5.177
1379488500, 5.197
...
1379548800, 6.235
```
... or like this:
```csv
1379487600000, 5.177
1379488500000, 5.197
...
1379548800000, 6.235
```
...or like this:
```CSV
2013-09-18 07:00:00, 5.177
2013-09-18 07:15:00, 5.197
...
2013-09-19 00:00:00, 6.235
```

Exclusion Periods
----
If you know that parts of your load data are anomalous for some reason, registering exclusion periods will omit these periods from the baseline calculation so that your baseline load shape will not be affected by them.  
```python
my_baseline.add_exclusion(first_exclusion_start, first_exclusion_end)
my_baseline.add_exclusion(second_exclusion_start, second_exclusion_end)
```
For example, if you have been testing some different energy management strategies and you want to use this baseline to calculate energy savings from a particular strategy, then you'll want to exclude all of the periods during which strategies were being tested, and only include periods that you consider to be "normal" operation.

Timezone
----
It's important that you specify what timezones your timestamps refer to. If no timezone is specified, then the module will assume that you are using the timezone of your OS, but this isn't necessarily a great assumption. Specify your timezone using the appropriate [timezone name](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).
```python
my_baseline = Baseline(load_data, timezone="America/Los_Angeles")
```

Modeling Interval
----
The modeling interval determines the resolution of the model that is used to make predictions. Higher resolution models will run more slowly. By default, the modeling interval is set to 900 seconds. It can be passed in when you instantiate your Baseline object:
```python
my_baseline = Baseline(load_data, modeling_interval=300)
```

Weighting
----
A "weighting_days" argument allows the model to be biased toward more (or less) recent data. The default value for this is 14 days, meaning the most recent 14 days of training data will be weighted more heavily than data that is older than 14 days. To configure the weighting differently, just pass in an argument when you instantiate your Baseline object:
```python
my_baseline = Baseline(load_data, weighting_days=30)
```

Goodness of Fit Statistics
----
Once your baseline has been generated, some goodness of fit statistics will be available in the form of a dictionary:
```python
>>>my_baseline.generate()
>>>my_baseline.error_stats
{'MAPE_INTERVAL': 12.858, 'CORR_INTERVAL_DAYTIME': 0.88, 'RMSE_INTERVAL_DAYTIME': 2.421, 'MAPE_HOUR': 11.343, 'RMSE_INTERVAL': 1.723, 'RMSE_HOUR': 1.553, 'MAPE_INTERVAL_DAYTIME': 19.576, 'CORR_INTERVAL': 0.908, 'CORR_HOUR': 0.92}
```

Contribution
----
Contributions are welcome and encouraged. If you find a bug, please file it. If you would like to see a feature added, please request it. If you would like to contribute code, please fork and submit a pull request.
