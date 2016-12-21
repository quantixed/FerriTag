#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Before starting. Load in some waves
// FileName and PixelSize to show what the pixel size for each file
// Note: you can generate these from the TIFFs themselves using LoadTIFFFilesGetScales(nm)
// TiffName and coords of FT particle and for a bg area

Function LoadTIFFFilesForAnalysis()
	// Check and scale waves
	WaveChecker()
	Wave/T/Z FileName = root:FileName
	Wave/Z PixelSize = root:PixelSize
	Wave/T/Z TiffName = root:TiffName
	Wave/Z Scaledx = root:Scaledx
	Wave/Z Scaledy = root:Scaledy
	Wave/Z ScaledBGx = root:ScaledBGx
	Wave/Z ScaledBGy = root:ScaledBGy	
	
	NewDataFolder/O/S root:data
	
	String expDiskFolderName, expDataFolderName
	String FileList, ThisFile
	Variable FileLoop, nWaves, i,j,k
	
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName=S_path
	FileList=IndexedFile(expDiskFolder,-1,".tif")
	Variable nFiles=ItemsInList(FileList)
	Variable nFT = numpnts(TiffName)
	Variable xpos,ypos,pxSize
	String mList, mName, newName
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		expDataFolderName = ReplaceString(".tif",ThisFile,"")
		NewDataFolder/O/S $expDataFolderName
		ImageLoad/O/T=tiff/Q/P=expDiskFolder/N=lImage ThisFile
		Wave/Z lImage
		i = 0
		j = 0
		do
			FindValue/TEXT=expDataFolderName/S=(i) TiffName
			i = V_Value
			if (i < 0)
				break
			endif
			xpos = round(Scaledx[i])
			ypos = round(Scaledy[i])
			mName = "clip_" + num2str(j)
			Duplicate/O/R=[xpos-10,xpos+10][ypos-10,ypos+10] lImage, $mName
			xpos = round(ScaledBGx[i])
			ypos = round(ScaledBGy[i])
			mName = "clipBG_" + num2str(j)
			// Source of error here if xpos or ypos are near the edge of image (not the case for our data)
			Duplicate/O/R=[xpos-25,xpos+24][ypos-25,ypos+24] lImage, $mName
			//
			pxSize = PixelSize[i]
			i += 1
			j += 1
		while (i < nFT)
		
		mList = WaveList("clip_*",";","")
		nWaves = ItemsInList(mList)
		
		for (k = 0; k < nWaves; k += 1)
			mName = StringFromList(k,mList)
			Wave m0 = $mName
			CurveFit/Q Gauss2D m0 /D
			newName = "root:'" + expDataFolderName + mName + "_coef'"
			WAVE/Z W_coef
			Duplicate/O W_coef, $newName
			Wave w0 = $newName
			// scale the x and y width of 2D gauss fit to nm
			w0[3] /= pxsize
			w0[5] /= pxsize
			// SNR calc.
			// now get mean pixel density of 3 x 3 ROI centred on peak
			xpos = round(W_coef[2])
			ypos = round(W_coef[4])
			newName = ReplaceString("clip",mName,"ROI")
			Duplicate/O/R=(xpos-1,xpos+1)(ypos-1,ypos+1) m0, $newName
			Wave m1 = $newName
			newName = ReplaceString("clip_",mName,"clipBG_")
			Wave m2 = $newName
			// invert - images use a weird 8-247 LUT
			m1 *= -1
			m2 *= -1
			newName = "root:'" + expDataFolderName + mName + "_SNR'"
			Make/O/N=(2) $newName
			Wave w1 = $newName
			ImageStats m1
			w1[0] = V_avg
			ImageStats m2
			w1[1] = V_sdev
		endfor
		KillWaves lImage
		SetDataFolder root:data:
	endfor
	SetDataFolder root:
	mList = WaveList("*_coef",";","")
	Concatenate/O/KILL mList, allCoefs
	MatrixTranspose allCoefs
	mList = WaveList("*_SNR",";","")
	Concatenate/O/KILL mList, allSNRs
	MatrixTranspose allSNRs
	CleanOutputs()
	PlotCoefs()
	PlotSNRs()
End

Function CleanOutputs()
	SetDataFolder root:
	WAVE/Z allCoefs
	if (!WaveExists(allCoefs) || !WaveExists(allCoefs))
		DoAlert 0, "Missing wave"
		Return -1
	endif
	WAVE/Z allSNRs
	if (!WaveExists(allSNRs) || !WaveExists(allSNRs))
		DoAlert 0, "Missing wave"
		Return -1
	endif
	Variable nFT = dimsize(allCoefs,0)
	Make/O/FREE/N=(nFT) qualWave=0
	qualWave = (allCoefs[p][3] >= 0 && allCoefs[p][3] <= 20) ? qualWave[p] : 1
	qualWave = (allCoefs[p][5] >= 0 && allCoefs[p][5] <= 20) ? qualWave[p] : 1
	qualWave = (allCoefs[p][1] <= 0 && allCoefs[p][1] >= -1000) ? qualWave[p] : 1
	Duplicate/O allCoefs, allCoefsClean
	Duplicate/O allSNRs, allSNRsClean
	Variable i
	
	for(i = 0; i < nFT; i += 1)
		if(qualwave[i] == 1)
			allCoefsClean[i][0,*] = NaN
			allSNRsClean[i][0,*] = NaN
		endif
	endfor
End

Function PlotCoefs()
	SetDataFolder root:
	WAVE/Z allCoefsClean
	if (!WaveExists(allCoefsClean) || !WaveExists(allCoefsClean))
		DoAlert 0, "Missing wave"
		Return -1
	endif
	MatrixOp/O widthX = col(allCoefsClean,3)
	MatrixOp/O widthY = col(allCoefsClean,5)
	MatrixOp/O peakWave = col(allCoefsClean,1)
	// filter out ridiculous values (NaNs inserted by CleanOutputs()
	WaveTransform zapnans widthX
	WaveTransform zapnans widthY
	WaveTransform zapnans peakWave
	Make/O/N=(5,2) fitMean = {{-0.1,0.1,NaN,0.9,1.1},{0,0,NaN,0,0}}
	Make/O/N=(5,2) fitSD = {{0,0,NaN,1,1},{0,0,NaN,0,0}}
	WaveStats/Q widthX
	fitMean[0,1][1] = V_avg
	fitSD[0][1] = V_avg - V_sdev
	fitSD[1][1] = V_avg + V_sdev
	WaveStats/Q widthY
	fitMean[3,4][1] = V_avg
	fitSD[3][1] = V_avg - V_sdev
	fitSD[4][1] = V_avg + V_sdev
	Make/O/N=(2,2) peakMean = {{1.9,2.1},{0,0}}
	Make/O/N=(2,2) peakSD = {{2,2},{0,0}}
	WaveStats/Q peakWave
	peakMean[0,1][1] = V_avg
	peakSD[0][1] = V_avg - V_sdev
	peakSD[1][1] = V_avg + V_sdev
	// need x jitter
	Duplicate/O widthX, xJit
	xJit = 0 + gnoise(0.1)
	Concatenate/O/KILL {xJit,widthX}, fitWaveX
	Duplicate/O widthY, xJit
	xJit = 1 + gnoise(0.1)
	Concatenate/O/KILL {xJit,widthY}, fitWaveY
	Duplicate/O peakWave, xJit
	xJit = 2 + gnoise(0.1)
	Concatenate/O/KILL {xJit,peakWave}, fitWavePeak
	// now plot
	DoWindow/K fitPlot
	Display/N=fitPlot
	AppendToGraph fitWaveX[][1] vs fitWaveX[][0]
	AppendToGraph fitWaveY[][1] vs fitWaveY[][0]
	ModifyGraph/W=fitPlot rgb=(65535,0,0,32768)
	SetAxis/W=fitPlot/A/N=1/E=1 left
	Label/W=fitPlot left "Fit width (nm)"
	AppendToGraph/R fitWavePeak[][1] vs fitWavePeak[][0]
	ModifyGraph/W=fitPlot mode=3,marker=19,msize=2
	ModifyGraph/W=fitPlot rgb(fitWavePeak)=(32768,32768,32768,32768)
	ModifyGraph/W=fitPlot mrkThick=0
	SetAxis/W=fitPlot/A/N=1/E=1 right
	SetAxis/A/R right
	Label/W=fitPlot right "Peak (a.u.)"
	SetAxis/W=fitPlot bottom -0.5,2.5
	// Hard code the labels
	Make/O/N=3 posWave = p
	Make/O/N=3/T labelWave = {"X", "Y", "Peak"}
	ModifyGraph/W=fitPlot userticks(bottom)={posWave,labelWave}
	AppendToGraph/W=fitPlot fitMean[][1] vs fitMean[][0]
	ModifyGraph/W=fitPlot mode(fitMean)=0, lsize(fitMean)=2, rgb(fitMean)=(0,0,0,65535)
	AppendToGraph/W=fitPlot fitSD[][1] vs fitSD[][0]
	ModifyGraph/W=fitPlot mode(fitSD)=0, lsize(fitSD)=1, rgb(fitSD)=(0,0,0,65535)
	AppendToGraph/W=fitPlot/R peakMean[][1] vs peakMean[][0]
	ModifyGraph/W=fitPlot mode(peakMean)=0, lsize(peakMean)=2, rgb(peakMean)=(0,0,0,65535)
	AppendToGraph/W=fitPlot/R peakSD[][1] vs peakSD[][0]
	ModifyGraph/W=fitPlot mode(peakSD)=0, lsize(peakSD)=1, rgb(peakSD)=(0,0,0,65535)
End

Function PlotSNRs()
	SetDataFolder root:
	WAVE/Z allSNRsClean
	if (!WaveExists(allSNRsClean) || !WaveExists(allSNRsClean))
		DoAlert 0, "Missing wave"
		Return -1
	endif
	MatrixOp/O/FREE SNRnum = col(allSNRsClean,0)
	MatrixOp/O/FREE SNRden = col(allSNRsClean,1)
	MatrixOp/O SNRWave = SNRnum / SNRden
	// filter out ridiculous values
	WaveTransform zapnans SNRWave
	Make/O/N=(2,2) SNRMean = {{-0.1,0.1},{0,0}}
	Make/O/N=(2,2) SNRSD = {{0,0},{0,0}}
	WaveStats/Q SNRWave
	SNRMean[0,1][1] = V_avg
	SNRSD[0][1] = V_avg - V_sdev
	SNRSD[1][1] = V_avg + V_sdev
	// need x jitter
	Duplicate/O SNRWave, w0,xJit
	xJit = 0 + gnoise(0.1)
	Concatenate/O/KILL {xJit,w0}, SNRWave
	// now plot
	DoWindow/K SNRPlot
	Display/N=SNRPlot
	AppendToGraph SNRWave[][1] vs SNRWave[][0]
	ModifyGraph/W=SNRPlot mode=3,marker=19,msize=2
	ModifyGraph/W=SNRPlot mrkThick=0
	ModifyGraph/W=SNRPlot rgb=(65535,0,0,32768)
	SetAxis/W=SNRPlot/A/N=1/E=1 left
	Label/W=SNRPlot left "SNR"
	SetAxis/W=SNRPlot bottom -0.5,0.5
	// Hard code the labels
	Make/O/N=1 posSNRWave = p
	Make/O/N=1/T labelSNRWave = {"FerriTag"}
	ModifyGraph/W=SNRPlot userticks(bottom)={posSNRWave,labelSNRWave}
	AppendToGraph/W=SNRPlot SNRMean[][1] vs SNRMean[][0]
	ModifyGraph/W=SNRPlot mode(SNRMean)=0, lsize(SNRMean)=2, rgb(SNRMean)=(0,0,0,65535)
	AppendToGraph/W=SNRPlot SNRSD[][1] vs SNRSD[][0]
	ModifyGraph/W=SNRPlot mode(SNRSD)=0, lsize(SNRSD)=1, rgb(SNRSD)=(0,0,0,65535)
End


/// @param	nm		number of nanometres the scale bar corresponds to
Function LoadTIFFFilesGetScales(nm)
	Variable nm
	
	// gives error from trying to kill locked waves
	NewDataFolder/O/S root:data
	
	String expDiskFolderName, expDataFolderName
	String FileList, ThisFile
	Variable FileLoop, nWaves, i
	
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName=S_path
	FileList=IndexedFile(expDiskFolder,-1,".tif")
	Variable nFiles=ItemsInList(FileList)
	
	Make/O/T/N=(nFiles) root:FileName
	Make/O/N=(nFiles) root:PixelSize
	Wave/T/Z FileName = root:FileName
	Wave/Z PixelSize = root:PixelSize
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		expDataFolderName = ReplaceString(".tif",ThisFile,"")
		NewDataFolder/O/S $expDataFolderName
		ImageLoad/O/T=tiff/Q/P=expDiskFolder/N=lImage ThisFile
		Wave/Z lImage
		FileName[fileLoop] = expDataFolderName
		PixelSize[fileLoop] = CheckScaleBar(lImage)
		//KillWaves/Z lImage
		SetDataFolder root:data:
	endfor
	PixelSize /=nm
End

Function WaveChecker()
	SetDataFolder root:
	Wave/T/Z FileName = root:FileName
	Wave/Z PixelSize = root:PixelSize
	Wave/T/Z TiffName = root:TiffName
	Wave/Z coordx = root:coordx
	Wave/Z coordy = root:coordy
	Wave/Z coordBGx = root:coordBGx
	Wave/Z coordBGy = root:coordBGy
	if (!waveexists(FileName))
		Abort "Missing FileName textwave"
	endif
	if(!WaveExists(PixelSize))
		Abort "Missing PixelWave numeric wave"
	endif
	if (!waveexists(TiffName))
		Abort "Missing TiffName textwave"
	endif
	if(!WaveExists(coordx))
		Abort "Missing coordx numeric wave"
	endif
	if(!WaveExists(coordy))
		Abort "Missing coordy numeric wave"
	endif
	if(!WaveExists(coordBGx))
		Abort "Missing coordx numeric wave"
	endif
	if(!WaveExists(coordBGy))
		Abort "Missing coordy numeric wave"
	endif
	// TIFFs are at 200 px per unit
	Duplicate/O coordx, Scaledx
	Duplicate/O coordy, Scaledy
	Scaledx *=200
	Scaledy *=200
	Duplicate/O coordBGx, ScaledBGx
	Duplicate/O coordBGy, ScaledBGy
	ScaledBGx *=200
	ScaledBGy *=200
End

// Use this tool to check the scale bar on micrographs taken on a JEOL 1400 with iTEM software
// This software prints a scale bar which can be machine read.
/// @param	matB	TIFF image wave reference
Function CheckScaleBar(matB)
	Wave matB
	
	Make/O/I/N=(7) sbStartSeq={0,255,255,255,255,255,0}
	Make/O/I/N=(8) sbEndSeq={0,255,255,255,255,255,255,0}
	
	Variable vStart,vEnd, vLen
	
	MatrixOP/O sbWave = col(matB,1008)
	FindSequence/I=sbStartSeq sbWave
	vStart = V_Value + 6
	FindSequence/I=sbEndSeq sbWave
	vEnd = V_Value + 1
	vLen = vEnd - vStart
	KillWaves/Z sbStartSeq,sbEndSeq,matB
	Return vLen
End