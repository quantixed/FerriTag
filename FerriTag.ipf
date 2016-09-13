#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// This function is the engine of the model
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
	Variable section, front, back
	
	String wName = "nPart_" + num2str(rr)
	Make/O/N=(iter) $wName
	WAVE w0 = $wName
	Variable nTag
	Make/O/N=0 w1
	
	Variable i, j
	
	for(j = 0; j < iter; j += 1)
	
		for(i = 0; i < nPos; i += 1)
			alpha = asin(ss / rr) // restriction for FerriTag size
			theta = abs(enoise(pi/2)) - alpha
			phi = abs(enoise(2*pi))
			posWave[i][0] = rr * sin(theta) * cos(phi)
			posWave[i][1] = rr * sin(theta) * sin(phi)
			posWave[i][2] = rr * cos(theta)
		endfor
		
		section = enoise(thick + (rr/2))	// midpoint
		front = section - (thick/2)
		back = section + (thick/2)
			
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

// This generates probability density functions (not normalised)
// for the model run at various states (sizes)
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

// Gets rid of waves generated in previous analyses
Function FlushAllDist()
	String fulllist = WaveList("*dist*",";","") + WaveList("nPart*",";","")
	String wName
	Variable i
 
	for(i = 0; i < ItemsInList(fullList); i += 1)
		wName= StringFromList(i, fullList)
		KillWaves/Z $wName		
	endfor
End

// This makes a plot of the observed values versus experimental values
Function MakeFTPlot()
	Wave/Z FTMeasWave
	Wave/Z FTMeasWave_Hist
	DoWindow/K ftPlot
	if (!waveexists(FTMeasWave))
		return -1
	endif
	if (!waveexists(FTMeasWave_Hist))
		Make/N=111/O FTMeasWave_Hist
		Histogram/P/B={0,0.2,111} FTMeasWave,FTMeasWave_Hist
	endif
	Display/N=ftPlot FTMeasWave_Hist
	KillWaves/Z bigWave,bigWave_Hist
	String wList = WaveList("dist_*",";","")
	wList = RemoveFromList(WaveList("*_hist",";",""), wList,";")
	Concatenate/O/NP wList, bigWave
	Make/N=111/O bigWave_Hist
	Histogram/P/B={0,0.2,111} bigWave,bigWave_Hist
	AppendToGraph/W=ftPlot/R bigWave_Hist
	ModifyGraph/W=ftPlot rgb(bigWave_Hist)=(0,0,65535)
End

// This function will calculate the median real state of FT
// Although an equal number of states from small to big are generated
// not all are analysed due to section sampling.
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

// This function runs the model multiple times
// Generates a wave containing the median real state
// and the median observation of the model
//// @param	nTrials	Number of times to run LookAtPDFs
Function RunMultiple(nTrials)
	Variable nTrials
	
	Make/O/N=(nTrials,2) MedianOutput
	Variable i
	
	for (i = 0; i < nTrials; i += 1)
		LookAtPDFs(7,18)	// 7 nm to 18 nm is hardcoded
		Wave/Z bigWave
		MedianOutput[i][0] = StatsMedian(bigWave)
		MedianOutput[i][1] = MedCalc()
	endfor
End

//------------------
// This is the Sphere version (i.e. not restricted on a plane)
////	@param	rr	 		define the distance e.g. 22 nm
////	@param	ss	 		define the radius of particle e.g. 6.5 nm
////	@param	thick	 	thickness of section in nm
////	@oaram	iter		number of iterations
Function FerriTagSphere(rr,thick,iter)
	Variable rr
	Variable thick
	Variable iter
	
	Make/O/D/N=(1000,3) posWave
	Variable nPos=dimsize(posWave,0)
	Variable theta, phi
	Variable section, front, back
	
	String wName = "nPart_" + num2str(rr)
	Make/O/N=(iter) $wName
	WAVE w0 = $wName
	Variable nTag
	Make/O/N=0 w1
	
	Variable i, j
	
	for(j = 0; j < iter; j += 1)
	
		for(i = 0; i < nPos; i += 1)
			theta = abs(enoise(pi))
			phi = abs(enoise(2*pi))
			posWave[i][0] = rr * sin(theta) * cos(phi)
			posWave[i][1] = rr * sin(theta) * sin(phi)
			posWave[i][2] = rr * cos(theta)
		endfor
		
		section = enoise(thick + (rr/2))	// midpoint
		front = section - (thick/2)
		back = section + (thick/2)
			
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

// This generates probability density functions (not normalised)
// for the model run at various states (sizes)
////	@param	small		smallest size of tag
////	@param	big		biggest size of tag
Function LookAtPDFsSphere(small,big)
	Variable small
	Variable big
	
	Make/O/N=((big-small)+1) sizeWave,medianWave
	String wName,histName
	DoWindow/K pdfPlot
	Display/N=pdfPlot
	FlushAllDist()
	
	Variable i
	
	for(i = small; i < big+1; i += 1)
		FerriTagSphere(i,70,5)
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
	MakeFTPlotSphere()
	Execute/Q "TileWindows/A=(2,2)/W=(50,50,848,518) compPlot,ftPlot,pdfPlot"
End

// This makes a plot of the observed values versus experimental values
Function MakeFTPlotSphere()
	DoWindow/K ftPlot
	Display/N=ftPlot
	KillWaves/Z bigWave,bigWave_Hist
	String wList = WaveList("dist_*",";","")
	wList = RemoveFromList(WaveList("*_hist",";",""), wList,";")
	Concatenate/O/NP wList, bigWave
	Make/N=111/O bigWave_Hist
	Histogram/P/B={0,0.2,111} bigWave,bigWave_Hist
	AppendToGraph/W=ftPlot bigWave_Hist
	ModifyGraph/W=ftPlot rgb(bigWave_Hist)=(0,0,65535)
End

// This function makes a grid of dots to append as a scatter plot to Gizmo
// Indicates the position of the plasma membrane.
Function PMMaker()
	Make/O/N=(2025,3) PMwave=0
	
	Variable i,j,k
	
	for(i = 0; i < 45; i += 1)
		for(j = 0; j < 45; j += 1)
			PMwave[k][0] = i - 22
			PMwave[k][1] = j - 22
			k += 1
		endfor
	endfor
End

// Plot Gizmo?

// Power calculation
Function PowerTest(small, big)
	Variable small
	Variable big
	
	String mw1Name, nPw1Name, w1Name
	String dw0Name, nPw0Name
	Variable iter
	Variable i,j,k
	
	for(i = small; i < (big + 1); i += 1)
		mw1Name = "temp_med_" + num2str(i)
		nPw1Name = "temp_nP_" + num2str(i)
		w1Name = "temp_w_" + num2str(i)
		Make/O/N=(100) $mw1Name,$nPw1Name
		Wave mw1 = $mw1Name
		Wave nPw1 = $nPw1Name
		Make/O/N=(100) $w1Name = i
		Wave w1 = $w1Name
		
		dw0Name = "dist_" + num2str(i)
		nPw0Name = "nPart_" + num2str(i)
		
		Wave/Z dw0 = $dw0Name
		Wave/Z nPw0 = $nPw0Name
		
		for(j = 0; j < 100; j += 1)
			iter = ceil(21 + enoise(20))
			FerriTag(i,6.5,70,iter)
			mw1[j] = statsmedian(dw0)
			nPw1[j] = sum(npw0)
		endfor
		
		// alterations to waves for display
		Sort nPw1,nPw1,mw1
		InsertPoints /M=0 100, 1, nPw1,mw1,w1
		nPw1[100] = NaN
		mw1[100] = NaN
		w1[100] = NaN
	endfor
	
	String wList = WaveList("temp_med_*",";","")
	Concatenate/O/NP/KILL wList,yW
	wList = WaveList("temp_nP_*",";","")
	Concatenate/O/NP/KILL wList,xW
	wList = WaveList("temp_w_*",";","")
	Concatenate/O/NP/KILL wList,zW
	Concatenate/O/KILL {xW,yW,zW},ResultWave3D
	
	DoWindow/K plot3D
	Display/N=plot3D ResultWave3D[][1] vs ResultWave3D[][0]
	ModifyGraph/W=plot3D zColor(ResultWave3D)={ResultWave3D[*][2],6,24,YellowHot,0}
	Label/W=plot3D left "Median distance (nm)"
	Label/W=plot3D bottom "Measurements"
	SetAxis/W=plot3D/A/N=1/E=1 left
	SetAxis/W=plot3D/A/N=1 bottom
	ColorScale/W=plot3D/C/N=text0/F=0/A=MC vert=0,side=2,trace=ResultWave3D,minor=1
	ColorScale/W=plot3D/C/N=text0/A=RB/X=0.00/Y=0.00
	
	DoWindow/K plot3Dz
	Display/N=plot3Dz ResultWave3D[][1] vs ResultWave3D[][0]
	ModifyGraph/W=plot3Dz zColor(ResultWave3D)={ResultWave3D[*][2],6,24,YellowHot,0}
	Label/W=plot3Dz left "Median distance (nm)"
	Label/W=plot3Dz bottom "Measurements"
	SetAxis/W=plot3Dz/A/N=1 left
	SetAxis/W=plot3Dz bottom 0,1000
	
	DoWindow/K plot3DLayout
	NewLayout/N=plot3DLayout
	LayoutPageAction/W=plot3DLayout size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
	AppendLayoutObject/W=plot3DLayout graph plot3D
	AppendLayoutObject/W=plot3DLayout graph plot3Dz
	ModifyLayout/W=plot3DLayout units=0
	ModifyLayout/W=plot3DLayout frame=0,trans=1
	Execute /Q "Tile/A=(4,2) plot3D,plot3Dz"
	
End