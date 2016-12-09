#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Menu item for easy execution
Menu "Macros"
	"FerriTag Analysis...",  IMODModelAnalysis()
End

Function IMODModelAnalysis()
	LoadIMODModels()
	ProcessAllModels()
	CollectAllMeasurements()
	MakeSummaryLayout()
	RotatePits()
	OverlayAllPits()
End

Function LoadIMODModels()
	// Check we have FileName wave and PixelSize
	Wave/T/Z FileName = root:FileName
	Wave/Z PixelSize = root:PixelSize
	if (!waveexists(FileName))
		Abort "Missing FileName textwave"
	endif
	if(!WaveExists(PixelSize))
		Abort "Missing PixelWave numeric wave"
	endif
	
	NewDataFolder/O/S root:data
	
	String expDiskFolderName, expDataFolderName
	String FileList, ThisFile, pdfName
	Variable FileLoop, nWaves, i
	
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName=S_path
	FileList=IndexedFile(expDiskFolder,-1,".txt")
	Variable nFiles=ItemsInList(FileList)
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		expDataFolderName = ReplaceString(".txt",ThisFile,"")
		NewDataFolder/O/S $expDataFolderName
		LoadWave/A/J/D/O/K=1/V={" "," $",0,0}/L={0,0,0,1,0}/P=expDiskFolder ThisFile
		MakeObjectContourWaves()
		SetDataFolder root:data:
	endfor
End

Function MakeObjectContourWaves()
	Concatenate/O/KILL wavelist("wave*",";",""), matA
	WaveStats/Q/RMD=[][0] matA
	// Scale the coordinates to real values
	ScaleCoords(matA)
	Variable nObjects = V_max + 1
	Variable nRows = dimsize(MatA,0)
	Variable nContours, rowStart, rowEnd
	String wName
	
	Variable i,j
	
	for (i = 0; i < nObjects; i += 1)
		MatrixOP/O filtObj = col(matA,0)
		filtObj = (filtObj == i) ? matA[p][1] : NaN
		nContours = wavemax(filtObj) + 1
		for (j = 0; j < nContours; j += 1)
			FindValue/V=(j)/Z filtObj
			rowStart = V_Value
			FindValue/V=(j+1)/Z filtObj
			if(V_Value == -1)
				FindValue/FNAN filtObj
				if(V_Value < rowStart)
					rowEnd = nRows - 1
				else
					rowEnd = V_Value - 1
				endif
			else
				rowEnd = V_Value - 1
			endif
			// Now make ObjectContour waves
			// Can edit this to generalise
			// Object 0 is FT, Object 1 is PM, can be 2
			if (i == 0)
				wName = "FT"
			else
				wName = "PM"
			endif
			wName += "_" + num2str(j)
			Make/O/N=((rowEnd-rowStart)+1,3) $wName
			Wave w0 = $wName
			w0[][] = matA[p+rowStart][q+2]
		endfor
	endfor
	KillWaves matA,filtObj
	
	String wList = WaveList("FT_*",";","")
	Variable nWaves = ItemsInList(wList)
	Variable nCol = 3 // x y and z
	Make/O/N=(nWaves,nCol) FTWave
	
	for (i = 0; i < nWaves; i += 1)
		wName = StringFromList(i, wList)
		Wave w0 = $wName
		nCol = dimsize(w0,1)
		for (j = 0; j < nCol; j += 1)
			WaveStats/Q/RMD=[][j] w0
			FTWave[i][j] = V_avg
		endfor
		KillWaves w0
	endfor
End

///	@param	matA	wave reference to matrix
Function ScaleCoords(matA)
	Wave matA
	
	String txtName = ReplAceString("'",GetDataFolder(0),"")
	Wave/T/Z FileName = root:FileName
	Wave/Z PixelSize = root:PixelSize
	Wave/Z matA
	Variable pxSize
	
	if (!WaveExists(FileName) || !WaveExists(PixelSize))
		DoAlert 0, "Cannot scale"
		Return -1
	endif
	FindValue/TEXT=txtName FileName
	if (V_Value == -1)
		Print txtName, "didn't scale"
	endif
	
	pxSize = PixelSize[V_Value]
	matA[][2,4] *= pxSize
	// Print txtName, pxSize
End

Function ProcessAllModels()
	SetDataFolder root:data:	// relies on earlier load
	DFREF dfr = GetDataFolderDFR()
	String folderName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	
	Variable i
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		SetDataFolder ":'" + folderName + "':"
		Distance2PM()
		MarkOutPit()
		ContourCalcs()
		SetDataFolder root:data:
	endfor
	SetDataFolder root:
End


Function MarkOutPit()
	
	DoWindow/K FTPlot
	Display/N=FTPlot
	
	String wList = WaveList("PM_*",";","")
	String wName = StringFromList(0,wList) // it is probably PM_0
	Wave PMw = $wName
	AppendToGraph/W=FTPlot PMw[][1] vs PMw[][0]
	ModifyGraph/W=FTPlot rgb=(0,0,0)
	Wave FTwave
	AppendToGraph/W=FTPlot FTwave[][1] vs FTwave[][0]
	ModifyGraph/W=FTplot rgb(FTwave)=(127*257,0,0)
	ModifyGraph/W=FTPlot mode(FTWave)=3,marker(FTWave)=8
	ModifyGraph/W=FTplot width={plan,1,bottom,left}
	ModifyGraph/W=FTplot noLabel=2,axThick=0
	
	Make/O/N=(2) pitStartStop = 0
	
	DoWindow/F FTPlot
	ShowInfo
	NewPanel/K=1 /W=(187,368,437,531) as "Pause for Cursor"
	DoWindow/C tmp_PauseforCursor
	AutoPositionWindow/E/M=1/R=FTPlot
	
	DrawText 21,20,"Adjust the cursores and then"
	DrawText 21,40,"Click Continue."
	Button button0,pos={80,58},size={92,20},title="Continue"
	Button button0,proc=UserCursorAdjust_ContButtonProc
	PauseForUser tmp_PauseForCursor,FTPlot
	if (Strlen(CsrWave(A))>0 && Strlen(CsrWave(B))>0) // check cursors are on trace
		pitStartStop[0] = pcsr(A)
		pitStartStop[1] = pcsr(B)
	endif
	DoWindow/K FTPlot
End

// This is for marquee control
Function UserCursorAdjust_ContButtonProc(ctrlName) : ButtonControl
	String ctrlName

	DoWindow/K tmp_PauseforCursor				// Kill self
End

Function Distance2PM()
	Wave/Z FTWave
	String wList = WaveList("PM_*",";","")
	String wName = StringFromList(0,wList) // it is probably PM_0
	Wave PMw = $wName
	
	Variable nFT = DimSize(FTWave,0)
	Make/O/N=(nFT) distWave,rowPM
	Variable i
	
	for (i = 0; i < nFT; i += 1)
		Duplicate/O PMw, m0
		m0[][] -= FTwave[i][q]
		MatrixOP/O result = m0 * m0
		MatrixOP/O result2 = sumrows(result)
		MatrixOP/O result3 = sqrt(result2)
		WaveStats/Q result3
		distWave[i] = V_min
		rowPM[i] = V_minLoc
	endfor
	KillWaves m0,result,result2,result3
End

Function ContourCalcs()
	String wList = WaveList("PM_*",";","")
	String wName = StringFromList(0,wList) // it is probably PM_0
	Wave PMw = $wName
	WAVE/Z distWave, rowPM, pitStartStop
	Variable rStart, rEnd, rFT // rows of PMw
	
	if (pitStartStop[0] < pitStartStop[1])
		rStart = pitStartStop[0]
		rEnd = pitStartStop[1]
	else
		rStart = pitStartStop[1]
		rEnd = pitStartStop[0]
	endif
	
	Make/O/N=1 cPit
	
	Duplicate/O/RMD=[rStart,rEnd][0,2] PMw, pitWave
	cPit[0] = ContourLength(pitWave) // find pit length
	
	Variable nFT = numpnts(rowPM)
	Make/O/N=(nFT) cFT
	
	Variable i
	
	for (i = 0; i < nFT; i += 1)
		rFT = rowPM[i]
		if (rFT < rStart)
			Duplicate/O/RMD=[rFT,rStart][0,2] PMw, FTlocWave
			cFT[i] = ContourLength(FTLocWave) * (-1)
		elseif (rFT == rStart)
			cFT[i] = 0
		else
			Duplicate/O/RMD=[rStart,rFT][0,2] PMw, FTlocWave
			cFT[i] = ContourLength(FTLocWave)
		endif
	endfor
	Duplicate/O cFT, ratioFT
	ratioFT /= cPit[0]
	KillWaves/Z pitWave,FTlocWave,result,result2,result3
End

// Works out the contour length along a line
Function ContourLength(m0)
	Wave m0
	
	Differentiate/METH=1/EP=1/DIM=0 m0
	MatrixOP/O result = m0 * m0
	MatrixOP/O result2 = sumrows(result)
	MatrixOP/O result3 = sqrt(result2)
	Return sum(result3)
End

Function CollectAllMeasurements()
	SetDataFolder root:data:	// relies on earlier load
	DFREF dfr = GetDataFolderDFR()
	String folderName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	String wList = ""
	
	Variable i
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		wList += "root:data:'" + folderName + "':ratioFT;"
	endfor
	
	SetDataFolder root:
	Concatenate/O/NP=0 wList, allRatioWave
	wList = ReplaceString("ratioFT",wList,"distWave")
	Concatenate/O/NP=0 wList, allDistWave
	Variable nFT = numpnts(allDistWave)
	Make/O/N=(nFT,3) allFTNormWave = 0
	Duplicate/O/FREE allDistWave, w0
	w0 +=50
	w0 /=50	// scaling the distance measurements to a pit that was 100 nm diam
	for(i = 0; i < nFT; i += 1)
		if (allRatioWave[i] >= 0 && allRatioWave[i] <= 1)
			allFTNormWave[i][0] = cos(allRatioWave[i] * PI) * w0[i]
			allFTNormWave[i][1] = sin(allRatioWave[i] * PI) * w0[i]
		elseif (allRatioWave[i] < 0)
			allFTNormWave[i][0] = 1 + (abs(allRatioWave[i]) * PI)
			allFTNormWave[i][1] = w0[i] - 1 // because the distance from membrane to x-axis is 0
		else
			allFTNormWave[i][0] = ((allRatioWave[i] - 1) * -PI) - 1
			allFTNormWave[i][1] = w0[i] - 1 // because the distance from membrane to x-axis is 0
		endif
	endfor
	// now make the mirror version
	Duplicate/O allFTNormWave, allFTNormRWave
	allFTNormRWave[][0] *= -1
	// split them into inside and outside versions
	Duplicate/O allFTNormWave, w1
	Duplicate/O allFTNormRWave, w2
	w1 = (allRatioWave[p] >= 0 && allRatioWave[p] <= 1) ? allFTNormWave[p][q] : NaN
	w2 = (allRatioWave[p] >= 0 && allRatioWave[p] <= 1) ? allFTNormRWave[p][q] : NaN
	Concatenate/O/KILL/NP=0 {w1,w2}, allFTNormIn
	Duplicate/O allFTNormWave, w1
	Duplicate/O allFTNormRWave, w2
	w1 = (allRatioWave[p] >= 0 && allRatioWave[p] <= 1) ? NaN : allFTNormWave[p][q]
	w2 = (allRatioWave[p] >= 0 && allRatioWave[p] <= 1) ? NaN : allFTNormRWave[p][q]
	Concatenate/O/KILL/NP=0 {w1,w2}, allFTNormOut
	// now make waves for scatter plot of distances
	Duplicate/O allDistWave, wIn,wOut
	Concatenate/O/NP=0 {wIn,wOut}, allDistInOut // make a copy of this for allFTNormIn/out plotting
	wIn = (allRatioWave[p] >= 0 && allRatioWave[p] <= 1) ? alldistWave[p] : NaN
	wOut = (allRatioWave[p] >= 0 && allRatioWave[p] <= 1) ? NaN : alldistWave[p]
	WaveTransform zapnans wIn
	WaveTransform zapnans wOut
	Make/O/N=(5,2) distMean = {{-0.1,0.1,NaN,0.9,1.1},{0,0,NaN,0,0}}
	Make/O/N=(5,2) distSD = {{0,0,NaN,1,1},{0,0,NaN,0,0}}
	WaveStats/Q wIn
	distMean[0,1][1] = V_avg
	distSD[0][1] = V_avg - V_sdev
	distSD[1][1] = V_avg + V_sdev
	WaveStats/Q wOut
	distMean[3,4][1] = V_avg
	distSD[3][1] = V_avg - V_sdev
	distSD[4][1] = V_avg + V_sdev
	// need x jitter
	Duplicate/O wIn, xJit
	xJit = 0 + gnoise(0.1)
	Concatenate/O/KILL {xJit,wIn}, distWaveIn
	Duplicate/O wOut, xJit
	xJit = 1 + gnoise(0.1)
	Concatenate/O/KILL {xJit,wOut}, distWaveOut
	MakeModelCCP()
End

Function MakeModelCCP()
	SetDataFolder root:
	Wave/Z allDistInOut, allFTNormIn, allFTNormOut
	if (!WaveExists(allDistInOut) || !WaveExists(allFTNormIn))
		DoAlert 0, "Missing waves"
		Return -1
	endif
	DoWindow/K pitPlot
	DoWindow/K pitInPlot
	Display/N=pitInPlot allFTNormIn[][1] vs allFTNormIn[][0]
	ModifyGraph/W=pitInPlot mode=3,zColor(allFTNormIn)={allDistInOut,0,80,YellowHot,0}
	ModifyGraph/W=pitInPlot width={plan,1,bottom,left}
	ModifyGraph/W=pitInPlot noLabel=2,axThick=0
	DoWindow/K pitOutPlot
	Display/N=pitOutPlot allFTNormOut[][1] vs allFTNormOut[][0]
	ModifyGraph/W=pitOutPlot mode=3,zColor(allFTNormOut)={allDistInOut,0,80,YellowHot,0}
	ModifyGraph/W=pitOutPlot width={plan,1,bottom,left}
	ModifyGraph/W=pitOutPlot noLabel=2,axThick=0
	
	Make/O/N=80 CCPWave=0,CCPColor=0
	SetScale/P x -4,0.1,"", CCPWave
	CCPWave[x2pnt(CCPwave,-1),x2pnt(CCPwave,1)] = sqrt(1 - (x^2))
	CCPColor[x2pnt(CCPwave,-1),x2pnt(CCPwave,1)] = 1
	AppendToGraph/W=pitInPlot CCPWave
	ModifyGraph/W=pitInPlot mode(CCPWave)=0,lstyle(CCPWave)=3
	ModifyGraph/W=pitInPlot zColor(CCPWave)={CCPColor,-4,1,PlanetEarth,0}
	ModifyGraph/W=pitInPlot lsize(CCPWave)=2	
	ModifyGraph/W=pitInPlot margin=10
	SetAxis/W=pitInPlot left 2,0
	SetAxis/W=pitInPlot bottom -4,4
	AppendToGraph/W=pitOutPlot CCPWave
	ModifyGraph/W=pitOutPlot mode(CCPWave)=0,lstyle(CCPWave)=3
	ModifyGraph zColor(CCPWave)={CCPColor,0,5,PlanetEarth,1}
	ModifyGraph/W=pitOutPlot lsize(CCPWave)=2	
	ModifyGraph/W=pitOutPlot margin=10
	SetAxis/W=pitOutPlot left 2,0
	SetAxis/W=pitOutPlot bottom -4,4
	MakeScatterPlots()
End

Function MakeScatterPlots()
	SetDataFolder root:
	Wave/Z distWaveIn, distWaveOut, distMean, distSD
	if (!WaveExists(distWaveIn) || !WaveExists(distWaveOut))
		DoAlert 0, "Missing waves"
		Return -1
	endif
	DoWindow/K distPlot
	Display/N=distPlot
	AppendToGraph distWaveIn[][1] vs distWaveIn[][0]
	AppendToGraph distWaveOut[][1] vs distWaveOut[][0]
	ModifyGraph/W=distPlot mode=3,marker=19,msize=2
	ModifyGraph/W=distPlot rgb=(65535,0,0,32768)
	ModifyGraph mrkThick=0
	SetAxis/W=distPlot/A/N=1/E=1 left
	Label/W=distPlot left "Membrane proximity (nm)"
	SetAxis/W=distPlot bottom -0.5,1.5
	// Hard code the labels
	Make/O/N=2 posWave = p
	Make/O/N=2/T labelWave = {"Inside", "Outside"}
	ModifyGraph/W=distPlot userticks(bottom)={posWave,labelWave}
	AppendToGraph/W=distPlot distMean[][1] vs distMean[][0]
	ModifyGraph/W=distPlot mode(distMean)=0, lsize(distMean)=2, rgb(distMean)=(0,0,0,65535)
	AppendToGraph/W=distPlot distSD[][1] vs distSD[][0]
	ModifyGraph/W=distPlot mode(distSD)=0, lsize(distSD)=1, rgb(distSD)=(0,0,0,65535)
End

Function RotatePits()
	SetDataFolder root:data:	// relies on earlier load
	DFREF dfr = GetDataFolderDFR()
	String folderName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	String wList,wName
	Variable vStart, vStop
	Variable cx,cy
	Variable wx,wy
	Variable theta
	
	DoWindow/K testLayout
	NewLayout/N=testLayout
	
	Variable i
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		SetDataFolder ":'" + folderName + "':"
		PlotRotatedPit(folderName)
		SetDataFolder root:data:
	endfor
	SetDataFolder root:
	LayoutPageAction/W=testLayout size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
	ModifyLayout/W=testLayout units=0
	ModifyLayout/W=testLayout frame=0,trans=1
	Execute /Q "Tile/A=(10,5)"
End

Function PlotRotatedPit(folderName)
	String folderName
	
	String wList,wName
	Variable vStart, vStop
	Variable cx,cy
	Variable wx,wy
	Variable theta
	// do translation then rotation
	wList = WaveList("PM_*",";","")
	wName = StringFromList(0,wList) // it is probably PM_0
	Wave/Z PMw = $wName
	WAVE/Z FTWave
	WAVE/Z pitStartStop
	// 2D only!
	// make axis between start and stop
	vStart = pitStartStop[0] 
	vStop = pitStartStop[1]
	Make/O/FREE/N=(2,2) m1 = {{PMw[vStart][0],PMw[vStop][0]},{PMw[vStart][1],PMw[vStop][1]}}
	// find midpoint, c
	cx = (PMw[vStart][0] + PMw[vStop][0]) / 2
	cy = (PMw[vStart][1] + PMw[vStop][1]) / 2
	// centre axis
	m1[][0] -= cx
	m1[][1] -= cy
	// find theta and phi for axis
	wx = m1[1][0]
	wy = m1[1][1]
	theta = atan2(wy,wx)
	// Print folderName, vStart, vStop, theta
	// rotate spindle axis
	Make/O/FREE RotationMatrix={{cos(theta),sin(theta)},{-sin(theta),cos(theta)}} // rotate back
	Duplicate/O/FREE/RMD=[][0,1] PMw, m0
	m0[][0] -= cx
	m0[][1] -= cy
	MatrixMultiply m0, RotationMatrix
	Wave M_Product
	Duplicate/O M_Product rPMWave
	Duplicate/O/FREE/RMD=[][0,1] FTwave, m0
	m0[][0] -= cx
	m0[][1] -= cy
	MatrixMultiply m0, RotationMatrix
	Duplicate/O M_Product rFTWave
	// check if they're upside down
	Variable pitMid = dimsize(rPMWave,0)/2
	Duplicate/O/FREE/RMD=[pitMid-50,pitMid+50][1] rPMWave ozWave
	if(mean(ozWave) > 0)
		Make/O/FREE RotationMatrix={{-1,0},{0,-1}}
		MatrixMultiply rPMWave, RotationMatrix
		Duplicate/O M_Product rPMWave
		MatrixMultiply rFTWave, RotationMatrix
		Duplicate/O M_Product rFTWave
	endif
	KillWaves M_Product
	// make colour wave for rPMwave
	Make/O/N=(dimsize(rPMWave,0)) rPMColor=0
	if (vStart > vStop)
		rPMColor[vStop,vStart] = 1
	else
		rPMColor[vStart,vStop] = 1
	endif
	// do plot
	String plotName = "pp_" + ReplaceString("-",folderName,"_")
	DoWindow/K $plotName
	Display/N=$plotName/HIDE=1
	
	AppendToGraph/W=$plotName rPMWave[][1] vs rPMWave[][0]
	ModifyGraph/W=$plotName zcolor(rPMWave)={rPMColor,-1,1,Grays256,1}
	AppendToGraph/W=$plotName rFTWave[][1] vs rFTWave[][0]
	ModifyGraph/W=$plotName rgb(rFTWave)=(65535,127*257,127*257)
	ModifyGraph/W=$plotName mode(rFTWave)=3,marker(rFTWave)=19
	ModifyGraph/W=$plotName msize(rFTWave)=1.5
	ModifyGraph/W=$plotName width={plan,1,bottom,left}
	SetAxis/W=$plotName left -200,100
	SetAxis/W=$plotName bottom -150,150
	ModifyGraph/W=$plotName margin=10
	ModifyGraph/W=$plotName noLabel=2,axThick=0
	// add to layout
	AppendLayoutObject/W=testLayout graph $plotName
End

// generate the figure
Function MakeSummaryLayout()
	DoWindow/K summaryLayout
	NewLayout/N=summaryLayout

	AppendLayoutObject/W=summaryLayout graph pitInPlot
	AppendLayoutObject/W=summaryLayout graph pitOutPlot
	AppendLayoutObject/W=summaryLayout graph distPlot

	LayoutPageAction size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
	ModifyLayout units=0
	ModifyLayout frame=0,trans=1
	ModifyLayout left(pitInPlot)=21,top(pitInPlot)=21,width(pitInPlot)=284,height(pitInPlot)=84
	ModifyLayout left(pitOutPlot)=21,top(pitOutPlot)=110,width(pitOutPlot)=284,height(pitOutPlot)=84
	ModifyLayout left(distPlot)=428,top(distPlot)=21,width(distPlot)=150,height(distPlot)=150
	ColorScale/C/N=text0/F=0/A=LT/X=50/Y=1 trace={pitInPlot,allFTNormIn}
	ColorScale/C/N=text0 "Membrane proximity (nm)"
End

// This will show you the pit contained in folderName
Function ShowMePlot(folderName)
	string folderName
	
	DoWindow/K FTPlot
	Display/N=FTPlot
	
	SetDataFolder "root:data:'" + folderName + "':"
	String wList = WaveList("PM_*",";","")
	String wName = StringFromList(0,wList) // it is probably PM_0
	Wave PMw = $wName
	AppendToGraph/W=FTPlot PMw[][1] vs PMw[][0]
	ModifyGraph/W=FTPlot rgb=(0,0,0)
	Wave FTwave,distWave
	AppendToGraph/W=FTPlot FTwave[][1] vs FTwave[][0]
	ModifyGraph/W=FTplot rgb(FTwave)=(127*257,0,0)
	ModifyGraph/W=FTplot zColor(FTWave)={distWave,0,150,YellowHot,1}
	ModifyGraph/W=FTPlot mode(FTWave)=3,marker(FTWave)=8
	ModifyGraph/W=FTplot width={plan,1,bottom,left}
	ModifyGraph/W=FTplot noLabel=2,axThick=0
	SetDataFolder root:
End

Function OverlayAllPits()
	SetDataFolder root:data:	// relies on earlier load
	DFREF dfr = GetDataFolderDFR()
	String folderName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	String wList,wName
	
	DoWindow/K allPitOverlay
	Display/N=allPitOverlay
	
	Variable i
	
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		SetDataFolder ":'" + folderName + "':"
		WAVE/Z rPMWave
		WAVE/Z rFTWave
		AppendToGraph/W=allPitOverlay rPMWave[][1] vs rPMWave[][0]
		AppendToGraph/W=allPitOverlay rFTWave[][1] vs rFTWave[][0]
		SetDataFolder root:data:
	endfor
	
	String tList = TraceNameList("allPitOverlay",";",1)
	String tName
	Variable nTraces = ItemsInlist(tList)
	
	for(i = 0; i < nTraces; i += 1)
		tName = StringFromList(i,tList)
		if(StringMatch(tName, "rPM*")==1)
			ModifyGraph/W=allPitOverlay rgb($tName)=(0,0,0,16384)
		elseif(StringMatch(tName, "rFT*")==1)
			ModifyGraph/W=allPitOverlay rgb($tName)=(655355,0,0,32768)
			ModifyGraph/W=allPitOverlay mode($tName)=3,marker($tName)=19
			ModifyGraph/W=allPitOverlay msize($tName)=1.5
		endif
	endfor
	
	ModifyGraph/W=allPitOverlay width={plan,1,bottom,left}
	SetAxis/W=allPitOverlay left -200,100
	SetAxis/W=allPitOverlay bottom -150,150
	ModifyGraph/W=allPitOverlay margin=10
	ModifyGraph/W=allPitOverlay noLabel=2,axThick=0
	// add to layout
	AppendLayoutObject/W=testLayout graph allPitOverlay
	ModifyLayout/W=testLayout units=0
	ModifyLayout/W=testLayout frame=0,trans=1
	DoWindow/F testLayout
	Execute /Q "Tile/A=(10,5)"
End