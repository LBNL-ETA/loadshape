#Loadshape
Tools for analyzing electric load shapes.  

Generating baselines for electric loads can be tricky, this module makes it easy.

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

###Dependencies
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

##Quick Start
TODO: quickstart

Table of Contents:
----
+ **Introduction**
+ **Installation**
    + Dependencies
+ **Quick Start**
+ **Input Data:**
    + Timestamps
    + Timezones
    + Power Data
+ **Calculations:**
    + Baselines
    + Measurement and Verification
    + Economic Valuation
+ **Advanced Usage:**
    + Exclusion Periods
    + Outdoor Air Temperature
    + Modeling Interval
    + Weighting
    + Goodness of Fit
    + Tariffs
+ **Examples:**
    + Ex 1: Seven Day Baseline
    + Ex 2: Cumulative Sum
    + Ex 3: DR Event Performance
+ **Contribution**

##Input Data

###Timestamps

###Time Zones

###Power Data

##Calculations

###Baselines

###Measurement and Verification

###Economic Valuation

## Advanced usage

###Exclusion Periods

###Outdoor Air Temperature

###Modeling Interval

###Weighting

###Goodness of Fit

###Tariffs

##Examples

###Ex 1: Seven Day Baseline

###Ex 2: Cumulative Sum

###Ex 3: DR Event Performance

##Contribution
Contributions are welcome and encouraged. If you find a bug, please file it. If you would like to see a feature added, please request it. If you would like to contribute code, please fork and submit a pull request.
