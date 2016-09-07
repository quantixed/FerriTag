#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
////	@param	rr	 		define the distance e.g. 22 nm
////	@param	ss	 		define the radius of particle e.g. 6.5 nm
////	@param	thick	 	thickness of section in nm
////	@oaram	iter		number of iterations
Function FerriTag(rr,ss,thick,iter)
	Variable rr
	Variable ss
	Variable thick
	Variable iter
	// we observe/measure dd
	// rr = ll + ss
	// i.e. the length of r from plane to centre of sphere is
	// length from plane to edge of sphere plus sphere radius
	if (ss > rr)
		return -1
	endif
	
	Make/O/D/N=(1000,3) posWave
	Variable nPos=dimsize(posWave,0)
	Variable theta, phi, alpha
	
	String wName = "nPart_" + num2str(rr)
	Make/O/N=(iter) $wName
	WAVE w0 = $wName
	Variable nTag
	Make/O/N=0 w1
	
	Variable i, j
	
	for(j = 0; j < iter; j += 1)
	
		for(i = 0; i < nPos; i += 1)
			// add a restriction here for theta
			alpha = asin(ss / rr)
			theta = enoise((pi/2) - alpha)
			phi = enoise(2*pi)
			if(theta < 0)
				theta *= -1
			endif
			if(phi < 0)
				phi *= -1
			endif
			posWave[i][0] = rr * sin(theta) * cos(phi)
			posWave[i][1] = rr * sin(theta) * sin(phi)
			posWave[i][2] = rr * cos(theta)
		endfor
		
		Variable section = enoise(thick + (rr/2))	// midpoint
		Variable front = section - (thick/2)
		Variable back = section + (thick/2)
			
		MatrixOp/O cX = col(posWave,0)
		MatrixOp/O cY = col(posWave,1)
		MatrixOp/O cZ = col(posWave,2)
		// XZ sections so test for Y
		cX = ((cY[p] >= front) && (cY[p] < back)) ? cX : NaN
		cY = ((cY[p] >= front) && (cY[p] < back)) ? cY : NaN
		cZ = ((cY[p] >= front) && (cY[p] < back)) ? cZ : NaN
		WaveTransform zapnans cX
		WaveTransform zapnans cY
		WaveTransform zapnans cZ
		// add some noise
		cZ += gnoise(1.5)
		nTag=numpnts(cZ)
		w0[j] = nTag
		
		Concatenate/NP {cZ}, w1
		Concatenate/O/KILL {cX,cY,cZ}, posSect
	endfor
	wName = "dist_" + num2str(rr)
	Duplicate/O w1, $wName
	Killwaves w1
End

////	@param	small		smallest size of tag
////	@param	big		biggest size of tag
Function LookAtPDFs(small,big)
	Variable small
	Variable big
	
	Make/O/N=((big-small)+1) sizeWave,medianWave
	String wName,histName
	DoWindow/K pdfPlot
	Display/N=pdfPlot
	FlushAllDist()
	
	Variable i
	
	for(i = small; i < big+1; i += 1)
		FerriTag(i,6.5,70,5)
		sizeWave[i-small] = i
		wName = "dist_" + num2str(i)
		WAVE w0 = $wName
		medianWave[i-small] = statsmedian(w0)
		histName = wName + "_hist"
		Make/N=111/O $histName
		Histogram/P/B={0,0.2,111} w0,$histName
		AppendToGraph/W=pdfPlot $histName
	endfor
	DoWindow/K compPlot
	Display/N=compPlot medianWave vs sizeWave
	DoWindow/F pdfPlot
	MakeFTPlot()
	Execute/Q "TileWindows/A=(2,2)/W=(50,50,848,518) compPlot,ftPlot,pdfPlot"
End

Function FlushAllDist()
	String fulllist = WaveList("*dist*",";","") + WaveList("nPart*",";","")
	String wName
	Variable i
 
	for(i = 0; i < ItemsInList(fullList); i += 1)
		wName= StringFromList(i, fullList)
		KillWaves/Z $wName		
	endfor
End

Function MakeFTPlot()
	Wave/Z FTMeasWave
	Wave/Z FTMeasWave_Hist
	DoWindow/K ftPlot
	if (!waveexists(FTMeasWave))
		return -1
	endif
	if (!waveexists(FTMeasWave_Hist))
		Make/N=111/O FTMeasWave_Hist
		Histogram/B={0,0.2,111} FTMeasWave,FTMeasWave_Hist
	endif
	Display/N=ftPlot FTMeasWave_Hist
	KillWaves/Z bigWave,bigWave_Hist
	String wList = WaveList("dist_*",";","")
	wList = RemoveFromList(WaveList("*_hist",";",""), wList,";")
	Concatenate/O/NP wList, bigWave
	Make/N=111/O bigWave_Hist
	Histogram/B={0,0.2,111} bigWave,bigWave_Hist
	AppendToGraph/W=ftPlot/R bigWave_Hist
	ModifyGraph/W=ftPlot rgb(bigWave_Hist)=(0,0,65535)
End

Function MedCalc()
	String nList = WaveList("nPart*",";","")
	String wName
	Variable nWaves = ItemsInList(nList)
	Variable obs,nmVar
	Make/O/N=0 nWave
	
	Variable i
	
	for (i = 0; i < nWaves; i += 1)
		wName = StringFromList(i,nList)
		Duplicate/O $wName w0
		WaveTransform zapnans w0
		obs = sum(w0)
		nmVar = str2num(ReplaceString("nPart_",wName,""))
		Make/O/N=(obs) w1 = nmVar
		Concatenate/NP {w1}, nWave
	endfor
	Variable ans = StatsMedian(nWave)
	KillWaves nWave,w0
	Return ans
End

Function RunMultiple(nTrials)
	Variable nTrials
	
	Make/O/N=(nTrials,2) MedianOutput
	Variable i
	
	for (i = 0; i < nTrials; i += 1)
		LookAtPDFs(7,18)
		Wave/Z bigWave
		MedianOutput[i][0] = StatsMedian(bigWave)
		MedianOutput[i][1] = MedCalc()
	endfor
End