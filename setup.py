# --------------------------------------------------
# loadshape - a set of tools for analyzing electric load shapes
#
# Dave Riess
# eetd.lbl.gov
# driess@lbl.gov
#
# License: MIT
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
      license='MIT',
      description='A set of tools for analyzing electric load shapes.',
      install_requires=['tzlocal>=1.0', 'pytz'],
      include_package_data=True,
      test_suite='tests',
      tests_require=[],
)
