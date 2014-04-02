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
	make_option(c("-s","--timeStampFile"),
		help="Name of file that contains timestamps of baseline predictions (Required)"),			
	make_option(c("-t","--temperatureFile"), 
		help="Name of temperature data file (Optional, but required if model is to use temperature)"),
	make_option(c("-f","--fahrenheit"),
		default = T,
		help="use Fahrenheit temperatures? [default %default]"),	
	make_option(c("-p","--predictTemperatureFile"),
		help="Name of forecast or prediction temperature file (Optional)"),
	make_option(c("-o","--outputBaselineFile"),
		default="baseline.csv",
		help="Name of output file for the baseline [default %default]"),
	make_option(c("-e","--errorStatisticsFile"),
		default="errorStatisticsFile.csv",
		help="Name of output file for goodness-of-fit statistics [default %default]"),
	make_option(c("-d","--timescaleDays"),
		default=14,
		help="timescale for weighting function [default %default]"),
	make_option(c("-i","--intervalMinutes"),
		default=15,
		help="length of a Time Of Week interval [default %default]"),			
	make_option(c("-v","--verbosity"),
		default=1,
		help="determine what progress and error reports to print (non-neg integer) [default %default]")	
	)
	
opt = parse_args(OptionParser(option_list=option_list))	
	
#
##   First define functions (immediately below), then use them (bottom)
#
#
######

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



readInputFiles = function(inLoadFile,inTemperatureFile=NULL,
	inPredTemperatureFile=NULL,
	timeStampFile=NULL,
	verbose=1,intervalMinutes=15) {
	if (verbose > 2) { print("starting readInputFiles()") }
	if (verbose > 3) { 
		print(inLoadFile)
	}
	loadDat = read.table(inLoadFile,as.is=T,sep=",",header=F)
	loadTime = getTime(loadDat[,1])	
	dataLoad = loadDat[,2]
	
	if (is.null(timeStampFile)) {
	   timeStampFile=inLoadFile
	}	
	# Read prediction times (required)
	predTimeStamp = read.table(timeStampFile,as.is=T,sep=",",header=F)
	predTime = getTime(predTimeStamp[,1])
	predTimeNum = as.numeric(predTime)

	# Aggregate load data to a reasonable interval length. intervalMinutes controls
	# the timescale at which the baseline is being fit (typically will be something
	# like 15 minutes or an hour). We start by aggregating to a timescale finer than
	# intervalMinutes but not by a lot. 
	# If for example intervalMinutes=15, we aggregate to 5-minute chunks. 
	# If the original data are at, say, 20s, then this way we avoid carrying 
	# around tens or hundreds of times more data than needed.
	aggregateMinutes = intervalMinutes/3
	t0 = min(loadTime,na.rm=T)
	tLoadMinutesSinceStart = difftime(loadTime,t0,units="mins") 
	
	# If the time period between measurements is less than intervalMinutes/3, then
	# we want to accumulate multiple measurements into our time intervals: two or more
	# measurements get the same value of intervalLoadSinceStart. But if the
	# time period between measurements is already longer than intervalMinutes/3, then just
	# use the measurements as they are; each measurement gets its own intervalLoadSinceStart. 
	intervalLoadSinceStart = 1+floor(tLoadMinutesSinceStart/aggregateMinutes)
	dataLoadAggregated = aggregate(dataLoad,by=list(intervalLoadSinceStart),mean,
		na.action=na.omit)[,2]
	
	# the timestamp for the interval is the time at the _end_ of the interval
	loadTimeNum = as.numeric(loadTime)		
	timeLoadAggregatedNum = aggregate(loadTimeNum,by=list(intervalLoadSinceStart),max,
		na.rm=T)[,2]
	timeLoadAggregated = as.POSIXlt(timeLoadAggregatedNum,origin="1970-01-01")	

	doTemperatureModel = F
	temperatureVec = NULL
	if (!is.null(inTemperatureFile)) {
		# inTemperatureFile has the temperature data to use for training	
		doTemperatureModel = T 
		if (verbose > 3) {
			print(inTemperatureFile)
		}
		temperatureDat = read.table(inTemperatureFile,as.is=T,sep=",",header=F)
		dataTemp = temperatureDat[,2]
		# discard NAs
		iokTemp = which(!is.na(dataTemp))
		
		temperatureDat = temperatureDat[iokTemp,]
		dataTemp = temperatureDat[,2]
						
		# Interpolate temperature data to desired timestamps. 
		# (In principle, the temperature we want should be the mean temperature in the time 
		# interval BEFORE the load timestamp, just as the load is the mean load in the 
		# time interval BEFORE the load timestamp. In practice, temperatures don't 
		# change much in 15 minutes or an hour, so we'll just interpolate. 
		tempTime = getTime(temperatureDat[,1])		
		tempTimeNum = as.numeric(tempTime)	
	
		if (verbose > 3) { print("interpolating temperatures")}
		temperatureVec = approx(tempTimeNum,dataTemp,timeLoadAggregatedNum,
			rule=1)$y	
	}
	# Now we have time, historic load, and historic temperature, all at the same times
	dataTime = timeLoadAggregated  
	
	predTempVec = NULL
	# Read temperature data for prediction periods (if provided)
	if (doTemperatureModel) {
		if (is.null(inPredTemperatureFile)) {
			# Training temperatures were provided, but there's no 
			# prediction temperature file...need to get prediction temperatures
			# from the training file. 
			predTempVec = approx(tempTimeNum,dataTemp,predTimeNum,rule=1)$y
		} else  {
			# There's a prediction temperature file, so use it
			temperaturePredDat = read.table(inPredTemperatureFile,as.is=T,sep=",",header=F)
			# discard times when temperature prediction is NA
			iok = which(!is.na(temperaturePredDat[,2]))
			temperaturePredDat=temperaturePredDat[iok,]
			predTempVec = temperaturePredDat[,2]	
			predTempTime = getTime(temperaturePredDat[,1])	
			predTempTimeNum = as.numeric(predTempTime)
		
			predTempVec = approx(predTempTimeNum,predTempVec,predTimeNum,rule=1)$y
		}	
		if (sum(is.na(predTempVec)) > 0 ) {
			if (verbose > 1) {
				doTemperatureModel=F
				stop("Error: prediction temperature data don't span prediction time range.")
			}
		}			
	}
			
	if (verbose > 3) { print("done reading input files; defining variables")}	
	loadVec = dataLoadAggregated
	tempVec = temperatureVec
	
	# Remove time and temperature data for times with NA temperatures
	if (!is.null(tempVec)) {
		if (sum(is.na(tempVec)) > 0) {
			if (verbose > 1) {print("Removed some NA temperatures")}
			abad = which(is.na(tempVec))
			dataTime = dataTime[-abad]
			loadVec = loadVec[-abad]
			tempVec = tempVec[-abad]
		}
	}

	
	Out = NULL
	Out$dataTime = dataTime
	Out$loadVec = loadVec
	Out$tempVec = tempVec
	Out$predTime = predTime
	Out$predTempVec = predTempVec
	Out$doTemperatureModel = doTemperatureModel
	if (verbose > 2) { print("leaving readInputFiles") }
	return(Out)
}	


piecewiseVariables = function(Tvec,Tknot) {
	nT = length(Tvec)
	nbins = length(Tknot) + 1 # lower than lowest; in between; and higher than highest	
	Tknot = c(-1000000,Tknot,1000000)  # Add a knot to make the loop below work out right
	
	Tmat = matrix(0,nrow=nT,ncol=nbins)
	for (ibin in 1:nbins) {
		ok = (Tvec > Tknot[ibin]) & (Tvec <= Tknot[ibin+1])
		ok[is.na(ok)] = F
		if (ibin ==1) {
			Tmat[ok,ibin] = Tvec[ok]
			Tmat[!ok,ibin] = Tknot[ibin+1]
		} else {
			Tmat[ok,ibin] = Tvec[ok] - Tknot[ibin]
			Tmat[Tvec > Tknot[ibin+1],ibin] = Tknot[ibin+1]-Tknot[ibin]			
		}	
	}	
	return(Tmat)
}


##

findOccUnocc = function(intervalOfWeek,loadVec,TempF,intervalMinutes=15,verbose=1) {
	if (verbose > 4) { print("starting findOccUnocc()") }
	# Figure out which times of week a building is in one of two modes
	#  (called 'occupied' or 'unoccupied')

	uTOW = unique(intervalOfWeek)
	nTOW = length(uTOW)
	
	# Define 'occupied' and 'unoccupied' based on a regression
	# of load on outdoor temperature: times of week that the regression usually
	# underpredicts the load will be called 'occupied', the rest are 'unoccupied'
	# This is not foolproof but usually works well.
	#	
	TempF50 = TempF-50
	TempF50[TempF > 50] = 0
	TempF65 = TempF-65
	TempF65[TempF < 65] = 0
	
	if (verbose > 4) {
		print("fitting temperature regression")
	}
	amod = lm(loadVec ~ TempF50+TempF65,na.action=na.exclude)
	
	okocc = rep(0,nTOW)
	for (itow in 1:nTOW) {
		okTOW = intervalOfWeek==uTOW[itow]
		# if the regression underpredicts the load more than 65% of the time
		# then assume it's an occupied period
		if ( sum(residuals(amod)[okTOW]>0,na.rm=T) > 0.65*sum(okTOW) ) {
			okocc[itow]=1
		}
	}
	if (verbose > 4) { print("leaving findOccUnocc()") }
	return(cbind(uTOW,okocc))
}


fitLBNLregress = function(timeVec,loadVec,tempVec,
	predTime,predTemp,tempKnots,weightvec=NULL,
	intervalMinutes=15, fahrenheit = F, 
	doTemperatureModel=doTemperatureModel,verbose=1) {
	
	if (verbose > 3) {print("starting fitLBNLregress()")}
	if (!is.null(weightvec)) {
		# if weights are specified then base occupied/unoccupied decision
		# just on the relatively higher weights
		okUseForOcc = weightvec > 0.2*max(weightvec,na.rm=T)
		okUseForOcc[is.na(okUseForOcc)]=F
	} else {
		okUseForOcc = rep(T,length(loadVec))
	}
	
	minuteOfWeek = 24*60*timeVec$wday+60*timeVec$hour + timeVec$min
	intervalOfWeek = 1+floor(minuteOfWeek/intervalMinutes)
	nLoadTime = as.numeric(timeVec)
		
	minuteOfWeekPred = 24*60*predTime$wday+60*predTime$hour + predTime$min
	intervalOfWeekPred = 1+floor(minuteOfWeekPred/intervalMinutes)
	nPredTime = as.numeric(predTime)
		
	# If there's no temperature data, just fit the time-of-week regression.
	# In this case there is no difference between occupied and unoccupied periods,
	# just do one prediction.
	
	if (is.null(tempVec) | !doTemperatureModel) {
		# If we don't have temperature data then just fit the time-of-week model
	
		# make data frame for explanatory variables in training period
		# We will use the variable name ftow first for the training period and
		#	then for the prediction period for notational convenience when using
		#	the predict() function. 		
		
		if (verbose > 3) {print("fitting TOW model for training period")}
		
		ftow = factor(intervalOfWeek)
		dframe = data.frame(ftow)
		amod = lm(loadVec ~ .+0,data=dframe, na.action=na.exclude,
				weights = weightvec)
		trainingLoadPred = predict(amod)

		if (verbose > 3) {print("predicting baseline for prediction period")}		
		ftow = factor(intervalOfWeekPred)
		dframePred = data.frame(ftow)		
		oktowpred = factor(ftow) %in% amod$xlevels$ftow
		predVec = rep(NA,length(predTime))
		predVec[oktowpred] = predict(amod,dframePred)	
		
	} else {
		# If we have temperature data then fit the time-of-week-and-temperature model
		
		if (fahrenheit) {
			# temperature vector is already in fahrenheit
			tempVecF = tempVec
			tempVec = (tempVec-32)*5/9
			tempVecPredF = predTemp
			tempVecPred = (predTemp-32)*5/9
		} else {
			tempVecF = (tempVec*9/5)+32
			tempVecPredF = (predTemp*9/5)+32
			tempVecPred = predTemp
		}	
		# findOccUnocc requires Fahrenheit temperatures; everywhere else we can use either
		#  Celsius or Fahrenheit, as long as temperature knots are set appropriately 
		#
		# base occupied/unoccupied decision only on cases where we have load data:
		okload = !is.na(loadVec)
		occInfo = findOccUnocc(intervalOfWeek[okload],loadVec[okload],tempVecF[okload])
		occIntervals = occInfo[occInfo[,2]==1,1]  # which time intervals are 'occupied'?
		#
	
		occVec = rep(0,length(loadVec))
		if (length(occIntervals) > 2) {
			for (i in 1:length(occIntervals)) {
				occVec[intervalOfWeek==occIntervals[i]] = 1
			}
		}
		
		if (verbose > 3) {print("done determining occupied hours")}
			
		# If there aren't enough temperature data above the highest temperature knot,
		# then remove the knot. Repeat until there are sufficient data above the highest
		# remaining knot, or until there's only one knot left.  	
		ntempknots = length(tempKnots)
		checkknots = T
		while (checkknots) {
			if (sum(tempVec[okload] > tempKnots[ntempknots],na.rm=T) < 20) {
				# not enough data above upper knot; throw away that upper knot
				tempKnots = tempKnots[-ntempknots]
				ntempknots = ntempknots - 1
				if (ntempknots == 1) {
					# We have to keep at least one knot, even if we have no data above it.
					# A real fix requires rewriting piecewiseVariables so it can handle 
					# a case with no knots (just a single linear temperature dependence); 
					# not doing this for now. 
					checkknots = F
				}
			} else {
				# We have enough data above the upper knot, so need to keep checking 
				checkknots = F 
				
			}
		} #endwhile
		# Same principle as above, for aomount of data below the lowest knot. 
		checkknots = T
		while (checkknots) {	
			if (sum(tempVec[okload] < tempKnots[1], na.rm=T) < 20) {
				# not enough data below lower knot; throw away that lower knot
				tempKnots = tempKnots[-1]
				ntempknots = ntempknots-1
				if (ntempknots == 1) {
					# We have to keep one knot, even though we have no data below it.
					checkknots = F
				}			
			} else {
				checkknots = F # we have sufficient data below the lowest knot
			}
		} #endwhile 
		tempMat = piecewiseVariables(tempVec,tempKnots)
		tempMatPred = piecewiseVariables(tempVecPred,tempKnots)
		tMname=rep(NA,ncol(tempMat))
		for(i in 1:ncol(tempMat)) {
			tMname[i]=paste("tempMat",i,sep="")
		}
		names(tempMat) = tMname
		names(tempMatPred) = tMname
		
		if (verbose > 3) { print("done setting up temperature matrix") }
		
		if (is.null(weightvec)) { 
			weightvec = rep(1,length(loadVec))
		}
		
		# make data frame for explanatory variables in training period
		# We will use the variable name ftow twice, first for the training period and
		#	then for the prediction period, for notational convenience when using
		#	the predict() function. 		
		ftow = factor(intervalOfWeek)
		dframe = data.frame(ftow,tempMat)
		trainingLoadPred = rep(NA,nrow(dframe))
		
		# make data frame for explanatory variables in prediction period
		ftow = factor(intervalOfWeekPred)
		dframePred = data.frame(ftow,tempMatPred)
		predVec = rep(NA,length(predTime))		
				
		okocc = occVec==1
		okocc[is.na(okocc)] = T
		
		
		if(sum(okocc > 0)) {
			if (verbose > 3) { print("fitting regression for occupied periods") }
			# fit model to training data
			amod = lm(loadVec ~ .+0,data=dframe, na.action=na.exclude,
				weights = weightvec,subset=okocc)
			tP = predict(amod,dframe[okocc,])	
			trainingLoadPred[okocc] = tP	
				
			# Now make predictions for prediction period	
			# filter out times of week that are not in occupied training period.
			oktowpred = dframePred$ftow %in% amod$xlevels$ftow
			predVec[oktowpred] = predict(amod,dframePred[oktowpred,])
			if (verbose > 3) { print("done with prediction for occupied periods") }
		}
		
		if (sum(!okocc) > 0) {		
			if (verbose > 3) { print("fitting regression for unoccupied periods") } 
			bmod = lm(loadVec ~ .+0,data=dframe,na.action=na.exclude,
				weights = weightvec,subset=!okocc)
			tP = predict(bmod,dframe[!okocc,])
			trainingLoadPred[!okocc] = tP
				
			# filter out times of week that are not in unoccupied training period.
			oktowpred = dframePred$ftow %in% bmod$xlevels$ftow
			predVec[oktowpred] = predict(bmod,dframePred[oktowpred,])		
			if (verbose > 3) { print("done with prediction for unoccupied periods") }
		}
		
	}

	predVec[predVec < 0] = 0
	
	# Out$training has baseline predictions for training period
	# Out$predictions has baseline predictions for prediction period
	Out = NULL
	Out$training = data.frame(timeVec,nLoadTime,trainingLoadPred)
	Out$predictions = data.frame(predTime,nPredTime,predVec)
	
	if (verbose > 3) {print("leaving fitLBNLregress()")}
	return(Out)
}


makeBaseline = function(dataTime, dataLoad, dataTemp, predTime, predTemp,
	intervalMinutes=15, timescaleDays = 14,fahrenheit = F, 
	doTemperatureModel=F,verbose=1) {

	if (verbose > 2) { print("starting makeBaseline()") }
	npoints = length(dataLoad)

	t0 = min(dataTime,na.rm=T)
	t1 = max(dataTime,na.rm=T)

	deltaT = as.numeric(difftime(t1,t0,units="days"))
	nsegments = max(1,ceiling(deltaT/timescaleDays))
	segmentwidth = (npoints-1)/nsegments
	pointlist = floor(sort(npoints-segmentwidth*(0:nsegments))+0.001)
	
	nModelRuns = max(1,length(pointlist))
	
	TrainMatrix = matrix(NA,nrow=nModelRuns,ncol=length(dataTime))
	PredMatrix = matrix(NA,nrow=nModelRuns,ncol=length(predTime))
	
	TrainWeightMatrix = matrix(NA, nrow=nModelRuns,ncol=length(dataTime))
	WeightMatrix = matrix(NA,nrow=nModelRuns,ncol=length(predTime))
	
	if (verbose > 2) {print(paste("running regression at",nModelRuns,"steps"))}
	for (irun in 1:nModelRuns) {
		if (verbose > 4) { print(paste("starting model run number",irun)) }
		tcenter = dataTime[pointlist[irun]]
		tDiff = as.numeric(difftime(tcenter,dataTime,units="days"))
		tDiffPred = as.numeric(difftime(tcenter,predTime,units="days"))
		
		# Statistical weight for training period 
		weightvec = timescaleDays^2/(timescaleDays^2 + tDiff^2)
		
		# Statistical weight for prediction period
		weightvecPred = timescaleDays^2/(timescaleDays^2 + tDiffPred^2)

		tempKnots = (c(40, 55, 65, 80, 90)-32)*5/9
		
		regOut = fitLBNLregress(dataTime,dataLoad,dataTemp,
			predTime,predTemp,
			tempKnots = tempKnots, weightvec=weightvec,
			intervalMinutes=intervalMinutes,fahrenheit=fahrenheit,
			doTemperatureModel=doTemperatureModel,verbose=verbose)
		
		trainOut = regOut$training
		TrainMatrix[irun,] = trainOut$trainingLoadPred
		TrainWeightMatrix[irun,] = weightvec
		
		predOut = regOut$predictions			
		PredMatrix[irun,] = predOut$predVec
		WeightMatrix[irun,] = weightvecPred
	}
	finalBaseline = apply(PredMatrix*WeightMatrix,2,sum)/apply(WeightMatrix,2,sum)
	finalTrainBaseline = 
		apply(TrainMatrix*TrainWeightMatrix,2,sum)/apply(TrainWeightMatrix,2,sum)

	Out = NULL
	Out$timeVec = predTime
	Out$Baseline = finalBaseline
	Out$PredMatrix = PredMatrix
	Out$WeightMatrix = WeightMatrix
	Out$trainTime = dataTime
	Out$trainBaseline = finalTrainBaseline
	if (verbose > 2) { print("leaving makeBaseline()") }
	return(Out)
}	

GoodnessOfFit = function(time1, loadVec, time2, baselinePred, verbose=1) {
	fail=F	
	if (verbose > 1) { print("starting GoodnessOfFit()") }
	if (length(loadVec) != length(baselinePred)) {
		if (verbose > 0) { 
			print("Warning: GoodnessOfFit: vector length mismatch")
			fail = T 
		}
	}
	if (sum(abs(as.numeric(time1) - as.numeric(time2))) > 0) {
		if (verbose > 0) {
			print("Warning: GoodnessOfFit: timestamps do not match") 
			fail = T
		}
	}
	
	if (fail) { 
		# something's wrong, return NAs
		resid = rep(NA,length(time1)) 
	} else { 
		resid = loadVec-baselinePred
	}	
	iHour = time1$year*366*24+time1$yday*24+time1$hour
	ok_8AM_6PM = 7 < time1$hour & time1$hour < 19
	
	loadVecHour = aggregate(loadVec,by=list(iHour),mean,na.action=na.omit)[,2]
	baselinePredHour = aggregate(baselinePred,by=list(iHour),mean,na.action=na.omit)[,2]
	residHour = loadVecHour - baselinePredHour
		
	RMSE_Interval = sqrt(mean(resid^2,na.rm=T))
	RMSE_Interval_Daytime = sqrt(mean(resid[ok_8AM_6PM]^2,na.rm=T))
	
	RMSE_Hour = sqrt(mean(residHour^2,na.rm=T))

	MAPE_Interval = mean(abs(resid/loadVec),na.rm=T)*100
	MAPE_Interval_Daytime = mean(abs(resid[ok_8AM_6PM]/loadVec[ok_8AM_6PM]),
		na.rm=T)*100
	
	MAPE_Hour = mean(abs(residHour/loadVecHour),na.rm=T)*100	
	
	corr_Interval = cor(loadVec,baselinePred,use="complete.obs")
	corr_Interval_Daytime = cor(loadVec[ok_8AM_6PM],baselinePred[ok_8AM_6PM],use="complete.obs")
	corr_Hour = cor(loadVecHour,baselinePredHour,use="complete.obs")

	if(verbose > 1) { print("leaving GoodnessOfFit()") }
	Out = NULL
	Out$RMSE_Interval = RMSE_Interval
	Out$MAPE_Interval = MAPE_Interval
	Out$corr_Interval = corr_Interval
	Out$RMSE_Hour = RMSE_Hour
	Out$MAPE_Hour = MAPE_Hour
	Out$corr_Hour = corr_Hour
	Out$RMSE_Interval_Daytime = RMSE_Interval_Daytime
	Out$MAPE_Interval_Daytime = MAPE_Interval_Daytime
	Out$corr_Interval_Daytime = corr_Interval_Daytime
	return(Out)
}

main = function(inLoadFile=inLoadFile,
	timeStampFile=timeStampFile,
	inTemperatureFile=inTemperatureFile,
	inPredTemperatureFile=inPredTemperatureFile,outBaselineFile=outBaselineFile,
	outGoodnessOfFitFile=outGoodnessOfFitFile,
	intervalMinutes=intervalMinutes,timescaleDays=timescaleDays, 
	fahrenheit=F,verbose=verbosity,
	returnPreds=F) {
	if (verbose > 1) { print("starting main()") }

	aa = readInputFiles(inLoadFile=inLoadFile,inTemperatureFile=inTemperatureFile,
		inPredTemperatureFile=inPredTemperatureFile,timeStampFile=timeStampFile,
		intervalMinutes=intervalMinutes, verbose=verbose)
		
	if (verbose > 2) { print(paste("doTemperatureModel=",aa$doTemperatureModel)) }
	cc = makeBaseline(aa$dataTime,aa$loadVec,aa$tempVec,
		aa$predTime,aa$predTempVec,
	  intervalMinutes=intervalMinutes,timescaleDays=timescaleDays,
	  fahrenheit=fahrenheit,aa$doTemperatureModel,verbose=verbose)

	trainingGOF = GoodnessOfFit(aa$dataTime,aa$loadVec,cc$trainTime,cc$trainBaseline,
		verbose=verbose)

	write(t(cbind(names(trainingGOF),round(unlist(trainingGOF),3))),
		outGoodnessOfFitFile,ncol=2,sep=",")

	if (verbose > 2) {print("interpolating")}
	## We only want the baseline prediction at the times that we ask for it
	predTime = aa$predTime
	
	# interpolate baseline load to the actual times 
	# use "constant" rather than "linear" interpolation. Note that for
	# the interval that runs from t1 to t2, we want the value to be 
	# constant at y(t2) not y(t1). This is because the meter reports
	# the average power over the period that _ends_ at the reported time.
	# Create a new time vector and load vector that shift things to the
	# start of the interval rather than the end.
	# We'll make:
	# y(t1) = t1
	# y(t1+delta) = y(t2)
	# y(t2+delta) = y(t3)
	# and so on.
	tBaseNum = as.numeric(cc$timeVec)
	tBaseShiftedNum = tBaseNum+0.01 # .01 second into the start of the next interval
	tBaseShiftedNum = c(tBaseNum[1],tBaseShiftedNum)
	baseShifted =  c(cc$Baseline[1],cc$Baseline)
	predBaseline = approx(tBaseShiftedNum,baseShifted,as.numeric(predTime),
		method="constant")$y
		
	dd = cbind(as.character(predTime),round(predBaseline,2))
  	 write(t(dd),outBaselineFile,sep=",",ncol=2)

	if (returnPreds) {
		Out = NULL
		Out$dataTime = aa$dataTime
		Out$loadVec = aa$loadVec
		Out$predTime = predTime
		Out$predBaseline = predBaseline
		return(Out)
	}
	

	if(verbose > 1) { print("leaving main()") }
}
 
##################################

if (is.null(opt$loadFile)) {
	stop("Error: no input Load File is defined.")
} else {
	inLoadFile=opt$loadFile
}
if(is.null(opt$timeStampFile)) {
	stop("Error: no file of output timestamps is defined.")
} else {
	timeStampFile = opt$timeStampFile
}


inTemperatureFile = opt$temperatureFile
inPredTemperatureFile = opt$predictTemperatureFile
timescaleDays = opt$timescaleDays
outBaselineFile = opt$outputBaselineFile
timeStampFile = opt$timeStampFile
outGoodnessOfFitFile = opt$errorStatisticsFile
verbosity = opt$verbosity
intervalMinutes = opt$intervalMinutes
fahrenheit = opt$fahrenheit

if (!is.logical(fahrenheit)) {
	stop(
		paste("Error: fahrenheit must be logical (True or False); current value is",
			fahrenheit))
}


if (verbosity > 1) { 
	print(paste(
	"inLoadFile =",inLoadFile,
	"timeStampFile=",timeStampFile))
	print(paste(
	"inTemperatureFile =",inTemperatureFile,
	"inPredTemperatureFile =",inPredTemperatureFile
	))
	print(paste(
	"outBaselineFile = ", outBaselineFile,
	"intervalMinutes = ", intervalMinutes,
	"timescaleDays =",timescaleDays)) 
}


main(inLoadFile=inLoadFile,
	timeStampFile=timeStampFile,
	inTemperatureFile=inTemperatureFile,
	inPredTemperatureFile=inPredTemperatureFile,
	outBaselineFile=outBaselineFile,
	outGoodnessOfFitFile=outGoodnessOfFitFile,
	intervalMinutes=intervalMinutes,
	timescaleDays=timescaleDays, 
	fahrenheit = fahrenheit,
	verbose=verbosity)

if (verbosity > 1) { print("Done.") }	
	