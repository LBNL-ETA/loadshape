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

Wiki
----
Please take a look a the [Wiki](https://bitbucket.org/berkeleylab/eetd-loadshape/wiki) for installation instructions and more detailed usage information.

Future Development
----

  + add proper R bindings instead of shelling out to the R scripts
  + more sophisticated named exclusion periods
  + more robust timezone handling
  + move series diff functionality from R to python

Contribution
----
Contributions are welcome and encouraged. If you find a bug, please file it. If you would like to see a feature added, please request it. If you would like to contribute code, please fork and submit a pull request.
