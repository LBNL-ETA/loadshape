#!/bin/bash
set -e

# Update system
sudo apt-get update

# Install pip / distribute
sudo apt-get -y install python-pip
which pip
#sudo pip install -U pip
sudo pip install -U distribute nose setuptools pytz

# Install Python dependancies
sudo apt-get -y install python-numpy

# Install R, dependencies, and packages
sudo apt-get -y install r-base-core
wget http://cran.r-project.org/src/contrib/optparse_1.3.0.tar.gz
wget http://cran.r-project.org/src/contrib/getopt_1.20.0.tar.gz
sudo R CMD INSTALL getopt_1.20.0.tar.gz
sudo R CMD INSTALL optparse_1.3.0.tar.gz
rm getopt_1.20.0.tar.gz optparse_1.3.0.tar.gz

# Install loadshapes library
echo "Working direcotry: $PWD"
if [ $# -eq 0 ]
then
    echo "No path argument specified, using working directory."
    sudo pip install -e .

else
    echo "Path $1 specified, installing"
    sudo pip install -e $1
fi
