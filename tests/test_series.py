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

import unittest

from os import path
from loadshape import Series

class TestSeries(unittest.TestCase):
    
    def dummy_data(self):
        return [(1379487600, 1.0), (1379488500, 2.0), (1379489400, 3.0), (1379490300, 4.0), (1379491200, 5.0)]
        
    def get_kw_data_filepath(self):
        test_dir = path.dirname(path.abspath(__file__))
        return path.join(test_dir, 'data', 'test_kw.csv')

    def get_temp_data_filepath(self):
        test_dir = path.dirname(path.abspath(__file__))
        return path.join(test_dir, 'data', 'test_temp.csv')

    def test_validity(self):
        series = Series(self.get_kw_data_filepath())
        assert series.valid()
    
    def test_exclusion(self):
        series = Series(self.dummy_data())
        series.add_exclusion(1379488500, 1379490300)
        assert len(series.data()) == 2
        
    def test_data_slice(self):
        series = Series(self.dummy_data())
        assert len(series.data(1379488500, 1379490300)) == 3
        
    def test_temp_flag_default_is_f(self):
        series = Series(self.get_kw_data_filepath())
        assert series.is_farenheit()
        
    def test_temp_flag_is_f(self):
        series = Series(self.get_temp_data_filepath(), temp_units='F')
        assert series.is_farenheit()

    def test_temp_flag_is_not_f(self):
        series = Series(self.get_temp_data_filepath(), temp_units='C')
        assert series.is_farenheit() == False

    def test_named_exculsions(self):
        series = Series(self.get_temp_data_filepath(), temp_units='C')
        series.add_named_exclusion("US_HOLIDAYS")
        assert len(series.data()) < len(series.series)

    def test_interpolate(self):
        data = [(1379487600, 2.0), (1379488500, 4.0), (1379489400, 6.0), (1379490300, 8.0)]
        expected = [(1379488050, 3.0), (1379488950, 5.0), (1379489850, 7.0)]

        series = Series(data)
        out = series.data(start_at=1379488050, end_at=1379489850, step_size=900)

        assert out == expected

def main():
    unittest.main()

if __name__ == '__main__':
    main()
