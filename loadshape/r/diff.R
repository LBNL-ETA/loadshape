#!/usr/bin/env Rscript
#
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

library("optparse")
option_list = list(
	make_option(c("-l","--loadFile"),
    	help="Name of load data file (Required)"),
    make_option(c("-b","--baselineFile"),
    	help="Name of predicted baseline file (Required)"),
    make_option(c("-t","--outputTimesFile"),
    	help="Name of output times file (Required)"),
    make_option(c("-o","--outputFile"),
    	help="Name of output file for differences (Required)"),
    make_option(c("-p","--predictedBaselineOutputFile"),
    	help="name of output file for predicted baseline power and energy (Optional)"), 	
	make_option(c("-v","--verbosity"),
		default=1,
		help="determine what progress and error reports to print (non-neg integer) [default %default]")    		
)    	

opt = parse_args(OptionParser(option_list=option_list))	


getTime = function(timeInfo) {
	# given a vector of timestamps using one of the following timestamp types, return
	# a vector of POSIXlt times:
	# 1. Year-month-day Hours:Minutes:Seconds
	# 2. Seconds since 1970-01-01 00:00:00
	# 3. Milliseconds since 1970-01-01 00:00:00
	# 
	if(grepl(":",timeInfo[1])[1]) {
		time = strptime(timeInfo,format="%Y-%m-%d %H:%M:%S")
	} else {
		if (!is.numeric(timeInfo[1])) {
			stop("Time is not in a recognized format")
		}
		if (timeInfo[1] > 3e9) {
			# If time is in seconds, then this would represent sometime after 2066 
			# so assume time is in milliseconds	
			timeNum = timeInfo/1000
		} else {
			timeNum = timeInfo
		}		
		time = as.POSIXlt(timeNum,origin="1970-01-01")
	}
	return(time)	
}

makeIntervalLengths = function(timeNum) {
	# given a vector of numeric times (seconds), find the median interval between
	# them, and make a vector of this value the same length as the input vector 
	nIntervals = length(timeNum)
	givenIntervals = timeNum[2:nIntervals] - timeNum[1:(nIntervals-1)]
	intervalLengths = rep(median(givenIntervals,na.rm=T),nIntervals)
	return(intervalLengths)
}

DiffFromBaseline = function(baselineFile=NULL, loadDataFile=NULL, outputTimesFile=NULL,
	outFilename = NULL, outPredictedBaselineFile=NULL,verbose=1) {

	# This function finds difference in load between baseline predictions and actual data.
	# The baseline and actual load may be reported at different timestamps.
	# Output times are in the first column of outputTimesFile (which can
	# 	be the same as baselineFile or loadDataFile). 
	# Both baseline and actual load are in units of average power (kW) over a time
	#	interval prior to the timestamp. 
	# We cannot assume that the time interval is the entire period since the last
	#	timestamp, because this gives a wrong answer in the case of missing data. 
	# Default behavior: all time intervals in a given data set are assumed to be uniform,
	#	equal to the median time interval. However, time intervals may also be specified
	#	explicitly, in seconds, to handle the situation that (for instance) the 
	#   reporting period changes, e.g. load is reported every 5 minutes up to some time, 
	#   and then every 15 minutes.
	 
	if (verbose > 2) { print ("Reading baseline file and load data file") }
	loadDat = read.table(loadDataFile,as.is=T,sep=",",header=F)
	baseDat = read.table(baselineFile,as.is=T,sep=",",header=F) 
	outDat = read.table(outputTimesFile,as.is=T,sep=",",header=F) 
	
	if (verbose > 3) { print ("Interpreting timestamps") }
	tLoad = getTime(loadDat[,1])
	tLoadNum = as.numeric(tLoad)
	tBase = getTime(baseDat[,1])
	tBaseNum = as.numeric(tBase)
	tOutput = getTime(outDat[,1])
	tOutNum = as.numeric(tOutput)
	
	if (verbose > 3) { print("Reading or calculating interval lengths") }	
	if (ncol(loadDat) > 2) {
		intervalLengthLoad = loadDat[,3] # 3rd column (if it exists) is interval length
	} else { 
		intervalLengthLoad = makeIntervalLengths(tLoadNum)
	} 
	
	if (ncol(baseDat) > 2) { 
		intervalLengthBaseline = baseDat[,3] # 3rd column (if it exists) is interval length
	} else {
		intervalLengthBaseline = makeIntervalLengths(tBaseNum)	
	} 
	
	if (ncol(outDat) > 2) {
		intervalLengthOut = outDat[,3] # 3rd column (if it exists) is interval length
	} else {
		intervalLengthOut = makeIntervalLengths(tOutNum)		
	} 
	
	if (sum(is.na(loadDat[,2])) > 1) {
		# some load data are missing; interpolate to fill them interpolate
		okLoad = !is.na(loadDat[,2])
		loadVec = approx(tBaseNum[okLoad],loadDat[okLoad,2],tBaseNum)$y
	} else {
		loadVec = loadDat[,2]
	}
	
	
	# Calculate baseline energy used up to each baseline timestamp and actual energy
	# used up to each load timestamp; 
	# interval lengths are in units of seconds
	# so multiplying load * interval in seconds gives kWs, but we want kWh, so
	# multiply by seconds/hour = 1/3600.
	if (verbose > 2) { print("Calculating cumulative energy at each timestamp") }
	
	cumBaseEnergy = cumsum(intervalLengthBaseline*baseDat[,2])/3600 
	cumActualEnergy = cumsum(intervalLengthLoad*loadVec)/3600
	# These are the cumulative amount of energy used at the END of the interval 
	# specified by the timestamp, which means this is (correctly) 
	# non-zero at the first timestamp. 
	
	# Extend to the START of the first reported interval
	tBaseAll = c(tBaseNum[1]-intervalLengthBaseline[1],tBaseNum)
	cumBaseEnergy = c(0,cumBaseEnergy) 
	tLoadAll = c(tLoadNum[1]-intervalLengthLoad[1],tLoadNum)
	cumActualEnergy = c(0,cumActualEnergy)
	
	# Interpolate baseline to the desired times. This gives us the cumulative
	# energy used up to the end of each time interval (including the first). 
	# But we have to subtract off the energy used in the first time interval, 
	# because we want the cumulative energy to be 0 at the first specified timestamp.	
	cumBaseEnergyEndOfInterval = approx(tBaseAll,cumBaseEnergy,tOutNum)$y 
	cumBaseEnergyEndOfInterval = cumBaseEnergyEndOfInterval - cumBaseEnergyEndOfInterval[1]
	baseEnergyDuringInterval = c(NA,diff(cumBaseEnergyEndOfInterval))
	
	# Interpolate actual energy to the desired times
	cumActualEnergyEndOfInterval = approx(tLoadAll,cumActualEnergy,tOutNum)$y
	cumActualEnergyEndOfInterval = cumActualEnergyEndOfInterval - 
		cumActualEnergyEndOfInterval[1]
	actualEnergyDuringInterval = c(NA,diff(cumActualEnergyEndOfInterval))

	# Determine what fraction of seconds in each interval have  data
	cumSecWithKnownLoad = c(0,cumsum(intervalLengthLoad))
	cumSecKnownAtIntervalEnd = approx(tLoadAll,cumSecWithKnownLoad,tOutNum)$y
	cumSecKnownAtIntervalStart = approx(tLoadAll,
		cumSecWithKnownLoad,tOutNum-intervalLengthOut)$y	
	secKnownInInterval = cumSecKnownAtIntervalEnd - cumSecKnownAtIntervalStart
	fracMissingInInterval = 1-secKnownInInterval/intervalLengthOut

	# Energy is in kWh. Baseline load is desired in mean kW, which is baseline energy
	# divided by interval length in hours (so divide interval length in seconds by 3600).
	baseLoadDuringInterval = baseEnergyDuringInterval/(intervalLengthOut/3600) 
	actualLoadDuringInterval = actualEnergyDuringInterval/(intervalLengthOut/3600)
	
	diffLoadDuringInterval = actualLoadDuringInterval - baseLoadDuringInterval
	diffEnergyDuringInterval = actualEnergyDuringInterval - baseEnergyDuringInterval

	diffEDIforCum = diffEnergyDuringInterval
	diffEDIforCum[is.na(diffEDIforCum)] = 0
	cumEnergyDifference = cumsum(diffEDIforCum)
		
	OutmatDiff = cbind(as.character(tOutput),
		round(diffLoadDuringInterval,4),
		round(cumEnergyDifference,4))
	write(t(OutmatDiff),outFilename,ncol=3,sep=",")	
	
	if (!is.null(outPredictedBaselineFile)) {
		OutmatBase = cbind(as.character(tOutput),
			round(baseLoadDuringInterval,4),
			round(cumBaseEnergyEndOfInterval,4))
		write(t(OutmatBase),outPredictedBaselineFile,ncol=3,sep=",")
	}
		
}
	
######### Function definitions are above. Now parse input data and run the function.	
	
	
if (is.null(opt$loadFile)) {
	stop("Error: no input Load File is specified")
} else {
	loadDataFile = opt$loadFile
}
if (is.null(opt$baselineFile)) {
	stop("Error: no baseline file is specified")
} else {
	baselineFile = opt$baselineFile
}
if (is.null(opt$outputTimesFile)) {
	stop("Error: no output times file is specified")
} else {
	outputTimesFile=opt$outputTimesFile
}
if (is.null(opt$outputFile)) {
	stop("Error: no output filename is specified")
} else {
	outputFile = opt$outputFile
}
outPredictedBaselineFile = opt$predictedBaselineOutputFile
verbose = opt$verbosity

DiffFromBaseline(baselineFile,loadDataFile,outputTimesFile=outputTimesFile,outputFile,
	outPredictedBaselineFile = outPredictedBaselineFile,
	 verbose=verbose)


