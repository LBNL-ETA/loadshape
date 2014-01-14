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

import os
import subprocess
from setuptools import setup, find_packages

# ----- check R dependency ----- #
RHOME = os.popen("R RHOME").readlines()
if len(RHOME) == 0: raise RuntimeError("Please make sure R is installed.")

# ----- check R package dependencies ----- #
RPACKAGES = ['optparse']
for package in RPACKAGES:
    exit_code = subprocess.call(["Rscript", "-e", ("library('%s')" % package)])
    if exit_code != 0:
        raise RuntimeError("Please make sure the R package '%s' is installed." % package)

setup(name='loadshape',
      packages=find_packages(exclude=['tests']),
      version='0.1.0', # Keep synchronized with loadshape/__init__.py.
      author='Dave Riess',
      author_email='driess@lbl.gov',
      url='https://bitbucket.org/berkeleylab/eetd-loadshape',
      license='revised BSD',
      description='A set of tools for analyzing electric load shapes.',
      install_requires=['tzlocal>=1.0', 'pytz'],
      include_package_data=True,
      test_suite='tests',
      tests_require=[],
)
