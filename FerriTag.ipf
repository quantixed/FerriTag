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
Function DoItAll(small,big)
	Variable small
	Variable big
	
	Make/O/N=((big-small)+1) sizeWave,medianWave
	String wName
	
	Variable i
	
	for(i = small; i < big+1; i += 1)
		FerriTag(i,6.5,70,100)
		sizeWave[i-small] = i
		wName = "dist_" + num2str(i)
		WAVE w0 = $wName
		medianWave[i-small] = statsmedian(w0)
	endfor
	display medianWave vs sizeWave
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
	
	Variable i
	
	for(i = small; i < big+1; i += 1)
		FerriTag(i,6.5,70,100)
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
End