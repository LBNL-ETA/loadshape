#!/usr/bin/env Rscript
#

library("optparse")
option_list = list(
	make_option(c("-l","--loadFile"),
    	help="Name of load data file (Required)"),
    make_option(c("-t","--tariffFile"),
    	help="Name of tariff file (Required)"),
    make_option(c("-s","--outputTimestampFile"),
    	help="Name of output times file (Required)"),
    make_option(c("-d","--demandResponseFile"),
    	help="File of Demand Response dates and times (optional)"),	
    make_option(c("-o","--outputFile"),
    	help="Name of output file for differences (Required)"), 	
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
	if(grepl("-",timeInfo[1])[1]) {
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



AggregateLoad = function(timestamp,load, outIntervalMinutes=15,
	thresholdPct = 50, verbose=1 ) {
	if (verbose > 1) { print("starting AggregateLoad()") }
	# Given load data collected at specified times, calculate the
	# average load at different time intervals.
	# If some data are missing from an output interval, adjust for them if the percent 
	#   missing is under a specified threshold; otherwise return NA for the interval
	

	time = getTime(timestamp)	
	timeNum = as.numeric(time)
	nT = length(timeNum)
	timeDiff = diff(timeNum)
	loadMeasurementIntervalSec = median(timeDiff,na.rm=T) # time interval in seconds

	# If load is reported as NA, interpolate
	okNA = is.na(load)
	load[okNA] = approx(timeNum[!okNA],load[!okNA],timeNum[okNA])$y
		
	# calculate the cumulative energy as of the end of each measured interval; convert
	# to kWh instead of kWs:
	cumEnergy = cumsum(loadMeasurementIntervalSec * load)/3600 
	cumEnergy = c(0,cumEnergy)
	
	# find start of first load time interval
	time0 = time[1] - loadMeasurementIntervalSec	
	timeEnergyNum = c(as.numeric(time0),timeNum)
	
	
	# Find the first output interval for which the load is completely known
	# Choose possible interval end times by starting the possibilities on an hour.
	# (We expect outIntervalMinutes to divide into 60, although we don't require it)
	# The first "pretty" output time that is after the start of the first load
	# interval will not necessarily work, since the load interval may be too
	# short. For instance, if the first load interval is 20s long and runs 
	# from 8:59:45 to 9:00:05, 9:00 will not work for the first output interval if we
	# want intervals to be 15 minutes long. Step through output interval start times
	# until we find one that works.
	endTime = time[1] - (time[1]$min*60 + time[1]$sec)
	startTime = endTime - outIntervalMinutes*60 
	goodInterval = F
	while (!goodInterval) {
		if (startTime >= time0) {
			timeOutNum = seq(from=as.numeric(endTime),to=timeNum[nT],
				by=outIntervalMinutes*60)
			goodInterval = T	
		} else {
			startTime = endTime
			endTime = endTime + outIntervalMinutes*60
		}			
	}		
	  	
	outIntervalSec = outIntervalMinutes*60
	cumEnergyAtOutIntervalEnd = approx(timeEnergyNum,cumEnergy,timeOutNum)$y
	cumEnergyAtOutIntervalStart = approx(timeEnergyNum,cumEnergy,timeOutNum-outIntervalSec)$y
	energyOut = cumEnergyAtOutIntervalEnd - cumEnergyAtOutIntervalStart
	powerOut = energyOut/(outIntervalMinutes/60)  # Energy is in kWh, so use time in hours
	#powerOutInterp = approx(timeEnergyNum,powerOut,timeOutNum)$y

	# #
	# Determine what fraction of seconds in each interval have reported meter data
	cumSecWithKnownLoad = c(0,cumsum(rep(loadMeasurementIntervalSec,nT)))
	cumSecKnownAtIntervalEnd = approx(timeEnergyNum,cumSecWithKnownLoad,timeOutNum)$y
	cumSecKnownAtIntervalStart = approx(timeEnergyNum,cumSecWithKnownLoad,timeOutNum-outIntervalSec)$y	
	secKnownInInterval = cumSecKnownAtIntervalEnd - cumSecKnownAtIntervalStart
	fracMissingInInterval = 1-secKnownInInterval/(outIntervalMinutes*60)

	okCorrectMissing = fracMissingInInterval < 
		(thresholdPct)/100
	powerOut[okCorrectMissing] = 
		powerOut[okCorrectMissing]/(1-fracMissingInInterval[okCorrectMissing])
	powerOut[!okCorrectMissing] = NA

	nP = length(powerOut)
	if (is.na(powerOut[nP])) {
		# Not enough data to complete the final interval so discard it
		powerOut = powerOut[-nP]
		timeOutNum = timeOutNum[-nP]
		fracMissingInInterval = fracMissingInInterval[-nP] 
	}
	
	# Interpolate to get missing power
	okPower = !is.na(powerOut)
	powerOutInterp = approx(timeOutNum[okPower],powerOut[okPower],timeOutNum)$y
	
	Out = NULL
	Out$timeNum = timeOutNum
	Out$load = powerOut
	Out$loadInterp = powerOutInterp
	Out$intervalMinutes = outIntervalMinutes
	Out$loadMeasurementIntervalMinutes = loadMeasurementIntervalSec/60
	Out$pctMissing = round(100*fracMissingInInterval,3)
	
	if(verbose > 1) {print("leaving AggregateLoad()") }
	return(Out)
}


getTariffInfo = function(tariffFile,verbose=1) {
	aScan = scan(tariffFile,sep="\n",what="character")
	
	nLines = length(aScan)
	
	# Get price info for each tariff identifier.
	# Tariffs are intended to be in a block at the start or end of the file, but 
	# It doesn't matter, any line with two commas will be interpreted as a tariff. 
	tariffDat = NULL
	for (iLine in 1:nLines) {
		aLine = aScan[iLine]
		# trim leading whitespace	
		gsub("^\\s+","",aLine)
		if(substr(aLine,1,1) != "#") {
			# not a comment line
			if (grepl(",",aLine)) {
				# Any line with a comma in it will be interpreted (or attempted to be 
				# interpreted) as: tariff ID number, buy rate, sell rate. 
				# This is true no matter where the line appears in the file.
				# 
				if (verbose > 4) { print(aLine) }
				tariffLine = unlist(strsplit(aLine,","))
				if (length(tariffLine) != 3) {
					stop("A line with a comma in it does not have three fields.")
				}
				tariffDat = rbind(tariffDat,as.numeric(tariffLine))
			}
		}
	}
	
	
	# Run through the lines again, and use all of the lines that have 24 digits in a block
	# after discarding leading and trailing whitespace.
	iCount=0
	tariffSchedule = NULL
	for (iLine in 1:nLines) {
		aLine = aScan[iLine]
		gsub("^\\s+|\\s+$","",aLine) # remove leading and trailing whitespace
		if (grepl("^[0-9]{24}$",aLine)) {
			# aLine contains exactly 24 digits and nothing else.
			if (verbose > 4) {print(aLine)}
			iCount = iCount+1
			tariffSchedLine = as.numeric(unlist(strsplit(aLine,"")))
			tariffSchedule = rbind(tariffSchedule,tariffSchedLine)
			# 
		}
	}
	
	if (!is.integer(nrow(tariffSchedule/12))) {
		stop("Tariff schedule does not have the right number of months.")
	}
	
	# First set of tariff schedule info is for weekdays (dayType = 1)
	# Second (if provided) is for weekends (dayType = 2)
	# Third (if provided) is for DR days (dayType = 3)
	if (nrow(tariffSchedule) == 12) {
		# Only one 12-month tariff was provided; use it for both weekdays and weekends
		tariffSchedule = rbind(tariffSchedule, tariffSchedule)
	} 
	month = rep(1:12,length=nrow(tariffSchedule))
	dayType = rep(1:(nrow(tariffSchedule)/12),each=12)

	tariffSchedule = cbind(dayType,month,tariffSchedule)
	tariffSchedule = as.data.frame(tariffSchedule,
		row.names=1:nrow(tariffSchedule))
	names(tariffSchedule)=c("dayType","month",
			paste("hour",0:23,sep=""))

	tariffScheduleUnpacked = NULL
	for (irow in 1:nrow(tariffSchedule)) {
		dayType = tariffSchedule$dayType[irow]
		month = tariffSchedule$month[irow]
		for (ihour in 0:23) {
			hourChar = paste("hour",ihour,sep="")
			rate = tariffSchedule[irow,hourChar]
			tariffScheduleUnpacked = rbind(
				tariffScheduleUnpacked,c(dayType,month,ihour,rate))
		}
	}
	tariffScheduleUnpacked = data.frame(tariffScheduleUnpacked)
	names(tariffScheduleUnpacked) = c("dayType","month","hour","Tariff")
			
	Out = NULL
	Out$tariffDat = tariffDat
	Out$tariffSchedule = tariffSchedule
	Out$tariffScheduleUnpacked = tariffScheduleUnpacked
	return(Out)
}	


calcCost = function(loadFile,tariffFile,DRdayFile = NULL, verbose=1) {
	if (verbose > 1) { print("Starting calcCost") }
	tariffInfo = getTariffInfo(tariffFile)
	tariffDat = tariffInfo$tariffDat
	tariffSchedule = tariffInfo$tariffSchedule
	tariffScheduleUnpacked = tariffInfo$tariffScheduleUnpacked
	
	loadDatRaw = read.table(loadFile,sep=",",as.is=T,header=F)
	tLoadRaw = getTime(loadDatRaw[,1])
	
	# If data are provided at a short time interval, like 20 seconds,
	# aggregate them to 15 minutes.   
	aggLoad = AggregateLoad(tLoadRaw,loadDatRaw[,2],
		outIntervalMinutes=15,
		thresholdPct=50)
	
	# If the timestamp is at the top of the hour, the energy associated with
	# that timestamp was from the end of the _previous_ hour, so when we 
	# look up what tariff to use, use the rate that was in effect one minute 
	# (60 seconds) ago. 
	tLoad = getTime(aggLoad$timeNum-60)	
	 
	loadVec = aggLoad$loadInterp
	
	loadMonth = tLoad$mon	
	loadDay = tLoad$wday
	loadHour = tLoad$hour
	loadDate = as.Date(tLoad)
	
	loadDayType = rep(1,length(loadVec))
	loadDayType[loadDay==0 | loadDay==6] = 2 # weekends
	
	if (!is.null(DRdayFile)) {
		DRlist = read.table(DRdayFile,sep=",",as.is=T,header=F)
		tDRstart = getTime(DRlist[,1])
		tDRend = getTime(DRlist[,2])
		DRdate = as.Date(tDRstart)
		
		loadDayType[loadDate %in% DRdate] = 3 # DR days	
	}
	
	tariffIDMatch = match(interaction(loadDayType,loadMonth,loadHour),
		interaction(tariffScheduleUnpacked$dayType,tariffScheduleUnpacked$month,
			tariffScheduleUnpacked$hour))

	tariffID = tariffScheduleUnpacked$Tariff[tariffIDMatch]
	
	tariffPriceMatch = match(tariffID,tariffDat[,1])
	
	energyPrice = tariffDat[tariffPriceMatch,2]  # price per kWh
	
	energyCost = energyPrice * loadVec * aggLoad$intervalMinutes/60
	
	Out = NULL
	Out$timeNum = aggLoad$timeNum
	Out$load15 = aggLoad$load
	Out$load15Interp = aggLoad$loadInterp
	Out$energyPrice = energyPrice
	Out$energyCost = energyCost
	Out$pctMissing = aggLoad$pctMissing
	return(Out)
	
}

main = function(loadFile,tariffFile,outputTimestampFile,
	outFilename,drFile=NULL,verbose=1) {
	aa = calcCost(loadFile,tariffFile,DRdayFile=drFile,verbose=verbose)
	
	outDat = read.table(outputTimestampFile,as.is=T,sep=",",header=F) 
	tOutput = getTime(outDat[,1])
	tOutNum = as.numeric(tOutput)
	
	cumCost = cumsum(aa$energyCost) # total cost accrued at END of each interval
	cumCostEndOfInterval = approx(aa$timeNum,cumCost,tOutNum)$y
	costDuringInterval = c(0,diff(cumCostEndOfInterval))
	cumCost = cumsum(costDuringInterval)
	
	OutMat = cbind(as.character(tOutput),round(costDuringInterval,2),
		round(cumCost,2))
	write(t(OutMat),outFilename,ncol=3,sep=",")	
	
	return(OutMat)
}


if (is.null(opt$loadFile)) {
	stop("Error: no input Load File is specified")
} else {
	loadFile = opt$loadFile
}
if (is.null(opt$tariffFile)) {
	stop("Error: no tariff file is specified")
} else {
	tariffFile = opt$tariffFile
}
if (is.null(opt$outputTimestampFile)) {
	stop("Error: no output times file is specified")
} else {
	outputTimestampFile=opt$outputTimestampFile
}
if (is.null(opt$outputFile)) {
	stop("Error: no output filename is specified")
} else {
	outFilename = opt$outputFile
}
if (is.null(opt$demandResponseFile)) {
	drFile=NULL
} else {
	drFile = opt$demandResponseFile
}
verbose = opt$verbosity


aa = main(loadFile,tariffFile,outputTimestampFile,outFilename,
	drFile=drFile,verbose=verbose)
