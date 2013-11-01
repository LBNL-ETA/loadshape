import unittest

from os import path
from loadshape import Tariff

class TestTariff(unittest.TestCase):

    def get_test_tariff(self):
        test_dir = path.dirname(path.abspath(__file__))
        return path.join(test_dir, 'data', 'test_tariff.json')

    def test_read_tariff_file(self):
        t = Tariff()
        t.read_tariff_file(tariff_file=self.get_test_tariff())
        assert t.tariff_file != None
        assert t.tariff_json != None

    def test_parse_rate_structure(self):
        t = Tariff()
        t.read_tariff_file(tariff_file=self.get_test_tariff())
        t.parse_rate_structure()
        assert t.rate_structure != None
    
    def test_parse_rate_schedule(self):
        t = Tariff()
        t.read_tariff_file(tariff_file=self.get_test_tariff())
        t.parse_rate_schedule()
        assert t.rate_schedule != None

    def test_init(self):
        t = Tariff(tariff_file=self.get_test_tariff())
        assert t.tariff_file != None
        assert t.tariff_json != None
        assert t.rate_structure != None
        assert t.rate_schedule != None

def main():
    unittest.main()

if __name__ == '__main__':
    main()
