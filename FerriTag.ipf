#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
////	@param	rVar	 define the distance e.g. 22 nm
////	@param	thick	 thickness of section in nm
////	@oaram	iter		number of iterations
Function FerriTag(rVar,thick,iter)
	Variable rVar
	Variable thick
	Variable iter
	
	Make/O/D/N=(1000,3) posWave
//	Make/O/N=1000 rWave
	Variable nPos=dimsize(posWave,0)
	Variable theta, phi
	
	String wName = "nPart_" + num2str(rVar)
	Make/O/N=(iter) $wName
	WAVE w0 = $wName
	Variable nTag
	Make/O/N=0 w1
	
	Variable i, j
	
	for(j = 0; j < iter; j += 1)
	
		for(i = 0; i < nPos; i += 1)
			theta = enoise(pi/2)
			phi = enoise(2*pi)
			if(theta < 0)
				theta *= -1
			endif
			if(phi < 0)
				phi *= -1
			endif
			posWave[i][0] = rVar * sin(theta) * cos(phi)
				posWave[i][1] = rVar * sin(theta) * sin(phi)
			posWave[i][2] = rVar * cos(theta)
		//	rWave[i] = sqrt( posWave[i][0]^2 + posWave[i][1]^2 + posWave[i][2]^2 )
		endfor
		
		Variable section = enoise(thick + (rVar/2))	// midpoint
		Variable front = section - (thick/2)
		Variable back = section + (thick/2)
			
		MatrixOp/O cX = col(posWave,0)
		MatrixOp/O cY = col(posWave,1)
		MatrixOp/O cZ = col(posWave,2)
			// XZ scetions so test for Y
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
	wName = "dist_" + num2str(rVar)
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
		FerriTag(i,70,100)
		sizeWave[i-small] = i
		wName = "dist_" + num2str(i)
		WAVE w0 = $wName
		medianWave[i-small] = statsmedian(w0)
	endfor
	display medianWave vs sizeWave
End


Function TestIt()
	Variable iter = 100
	Make/O/N=(iter) medianWave_22,nPartWave_22
	
	WAVE/Z dist_22
	WAVE/Z nPart_22
	
	Variable i,j
	
	for(i = 0; i < iter; i += 1)
		j = ceil(21 + enoise(20))
		FerriTag(22,70,j)
		medianWave_22[i] = statsmedian(dist_22)
		nPartWave_22[i] = sum(nPart_22)
	endfor
End

Function TestIt2()
	Variable iter = 100
	Make/O/N=(iter) medianWave_10,nPartWave_10
	
	WAVE/Z dist_10
	WAVE/Z nPart_10
	
	Variable i,j
	
	for(i = 0; i < iter; i += 1)
		j = ceil(21 + enoise(20))
		FerriTag(10,70,j)
		medianWave_10[i] = statsmedian(dist_10)
		nPartWave_10[i] = sum(nPart_10)
	endfor
End