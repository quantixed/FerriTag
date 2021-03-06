#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "Macros"
	"Stereological methods...", StereologyWorkflow()
End

// In this version, location of particles are picked manually and stored in a csv
// 3 columns - blind filename, xpos, ypos.
Function StereologyWorkflow()
	CoastClear()
	LoadManualPointLocs()
	Unblind()
	GetPixelData()
	LoadTIFFsAndCalc()
End

///	@param	nFiles	total number of TIFFs
///	@param	plotNum	number of plots per page
Function MakeSummaryLayout(nFiles,plotNum)
	Variable nFiles,plotNum
	Variable pgMax = floor((nFiles -1) / plotNum) + 1
	
	Variable i
	
	DoWindow/K SummaryLayout
	NewLayout /N=summaryLayout
	for(i = 1; i < pgMax; i += 1)
		LayoutPageAction/W=summaryLayout appendPage
	endfor
	
	LayoutPageAction size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
	ModifyLayout units=0
	ModifyLayout frame=0,trans=1
End

///	@param	maskMat	mask image for processing
Function ProcessMask(maskMat)
	Wave maskMat
	maskMat[][] = (maskMat[p][q] < 20) ? 0 : maskMat[p][q]
	maskMat[][] = (maskMat[p][q] == 125) ? 1 : maskMat[p][q]
	maskMat[][] = (maskMat[p][q] == 200) ? 4 : maskMat[p][q]
	maskMat[][] = (maskMat[p][q] > 240) ? 2 : maskMat[p][q]
	maskMat[][] = (maskMat[p][q] > 19) ? 3 : maskMat[p][q]
	maskMat[1038,*][1002,*] = 3
End

///	@param	volumeWave	matrix to store volume data
///	@param	maskMat	processed mask image
///	@param	i	iteration number (row number)
Function GetVolumes(volumeWave,maskMat,i)
	Wave volumeWave,maskMat
	Variable i
	
	Duplicate/O/FREE maskMat,tempwave
	Variable nCol = DimSize(volumeWave,1)
	Variable j
	
	for(j = 0; j < nCol; j += 1)
		tempwave[][] = (maskMat[p][q] == j) ? 1 : 0
		volumeWave[i][j] = sum(tempwave)
	endfor
End

///	@param	txtName	accepts the string ThisFile
Function CheckScale(txtName)
	String txtName
	
	Wave/T/Z FileName
	Wave/Z PixelSize
	Wave/Z matA
	Variable pxSize
	
	if (!WaveExists(FileName) || !WaveExists(PixelSize))
		Abort "I need two waves: FileName and PixelSize"
	endif
	FindValue/TEXT=txtName FileName
	if (V_Value == -1)
		Print txtName, "didn't scale"
	endif
	
	// PixelSize is in nm per pixel so convert to um
	pxSize = PixelSize[V_Value] / 1000
	return pxSize
End

///	@param	nFiles	total number of TIFFs
///	@param	plotNum	number of plots per page
Function TileLayout(nFiles,plotNum)
	Variable nFiles,plotNum
	Variable pgMax = floor((nFiles -1) / plotNum) + 1
	String exString = "Tile/A=(" + num2str(ceil(plotNum/2) + 1) + ",2)"
	
	Variable i
	
	DoWindow /F summaryLayout
	for(i = 1; i < pgMax + 1; i += 1)
		LayoutPageAction/W=summaryLayout page=(i)
		Execute /Q exString
	endfor
	SavePICT/PGR=(1,-1)/E=-2/W=(0,0,0,0) as "summary.pdf"
End

// Kill CMap wave if it has been loaded
Function KillCMaps()
	String wList = WaveList("CMap*",";","")
	Variable nWaves = ItemsInList(wList)
	String wName
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i,wList)
		KillWaves/Z $wName
	endfor
End

Function CountValidParticles()
	String wList = WaveList("cdQ*",";","")
	Variable nWaves = ItemsInList(wList)
	String cdQName
	Variable nFT,zMin,zMax
	Make/O/N=(nWaves,4) countWave
	WAVE/Z LimitWave
	
	// Print results to Notebook
	NewNotebook/F=0/N=tallyNotes
	String text0
	
	Variable i,j
	
	for(i = 0; i < nWaves; i += 1)
		cdQName = StringFromList(i,wList)
			Notebook tallyNotes, text=cdQName, text=": "
		Wave cdQWave = $cdQName
		nFT = dimsize(cdQwave,0)
		Make/O/N=(nFT)/FREE w1 // using col3 of cdQ
		// find the max value of particles outside the cell, i.e. in area 0
		w1[] = (cdQWave[p][4] == 0) ? cdQWave[p][3] : NaN
			WaveStats/Q w1
			text0 = num2str(V_npnts)
			Notebook tallyNotes, text=text0, text=" in z0. zMin="
		zMin = LimitWave[i][0]
			text0 = num2str(zMin)
			Notebook tallyNotes, text=text0, text=". "
		// find the max value of particles at the membrane
		w1[] = (cdQWave[p][4] == 2) ? cdQWave[p][3] : NaN
			WaveStats/Q w1
			text0 = num2str(V_npnts)
			Notebook tallyNotes, text=text0, text=" in z2. zMax="
		zMax = LimitWave[i][1]
			text0 = num2str(LimitWave[i][1])
			Notebook tallyNotes, text=text0, text=".\r"
		for(j = 0; j < 4; j += 1)
			w1[] = (cdQWave[p][3] > zMin && cdQWave[p][3] <= zMax) ? 1 : 0
			// filter for each zone
			w1[] = (cdQWave[p][4] == j) ? w1[p] : 0
			countWave[i][j] = sum(w1)
		endfor
		// test for two things, add 1 to col 2 of limitWave or 0 if OK
		Variable nDetects = countWave[i][1] + countWave[i][2]
		// is zMin > zMax?
		if(zMin > zMax)
			limitWave[i][2] = 1
		// or is the number of particles ridiculous
		elseif(nDetects > 40)
			limitWave[i][2] = 1
		else
			limitWave[i][2] = 0
		endif
	endfor
End

Function CalculateDensities()
	WAVE/Z countWave
	WAVE/Z volumeWave
	WAVE/Z limitWave
	String text0,text1
	
	Duplicate/O volumeWave, volCorrWave
	volCorrWave = (limitWave[p][2] == 1) ? 0 : volCorrWave[p][q]
	MatrixOp/O countTotal = sumcols(countWave)
	MatrixOp/O volumeTotal = sumcols(volCorrWave)
	MatrixOp/O densityWave = sumcols(countWave) / sumcols(volCorrWave)
	// Print results to Notebook
	KillWindow/Z summaryNotes
	NewNotebook/F=0/N=summaryNotes
	text0 = num2str(countTotal[0][1])
	text1 = num2str(volumeTotal[0][1])
	Notebook summaryNotes, text=text0, text=" particles were detected in ", text=text1, text=" �m^3 of cytoplasm.\r"
	text0 = num2str(countTotal[0][2])
	text1 = num2str(volumeTotal[0][2])
	Notebook summaryNotes, text=text0, text=" particles were detected in ", text=text1, text=" �m^3 of membrane zone.\r"
	text0 = num2str(countTotal[0][0])
	Notebook summaryNotes, text=text0, text=" particles were detected outside the cell.\r\r"
	text0 = num2str(densityWave[0][1])
	text1 = num2str(densityWave[0][2])
	Notebook summaryNotes, text="The cytoplasmic density was ", text=text0
	Notebook summaryNotes, text=" and the membrane density was ", text=text1, text=" particles per �m^3.\r"
	text0 = num2str(densityWave[0][2] / densityWave[0][1])
	Notebook summaryNotes, text="An enrichment of ", text=text0, text="-fold.\r"
End

// Destructive function that will get rid of everything
Function CoastClear()
	String fullList = WinList("*", ";","WIN:3")
	Variable allItems = ItemsInList(fullList)
	String name
	Variable i
 
	for(i = 0; i < allItems; i += 1)
		name = StringFromList(i, fullList)
		DoWindow/K $name		
	endfor
	
	// Look for data folders
	DFREF dfr = GetDataFolderDFR()
	allItems = CountObjectsDFR(dfr, 4)
	for(i = 0; i < allItems; i += 1)
		name = GetIndexedObjNameDFR(dfr, 4, i)
		KillDataFolder $name		
	endfor
	
	KillWaves/A/Z
	KillStrings/A/Z
	KillVariables/A/Z
End

Function GetPixelData()
	Print "Locate csv containing pixelsize information"
	LoadWave/A/W/J/D/O/K=1/L={0,1,0,1,1}
	LoadWave/A/W/J/D/O/K=2/L={0,1,0,0,1} S_Path + S_fileName
End

// This function will save out a csv for import into R
// It is written to pull out coords and corresponding zones for
// "real particles".
/// @param	fileName	string of tiffname (without extension)
Function ExportRealParticles(fileName)
	String fileName
	WAVE/Z ImageNameWave
	if(!WaveExists(ImageNameWave))
		Abort "I need ImageNameWave"
	endif
	FindValue/TEXT=fileName ImageNameWave
	if (V_Value == -1)
		Print "Couldn't find", fileName 
	endif
	
	String mName = "cdW" + num2str(V_Value)
	Wave m0 = $mName
	MatrixOp/O cX = col(m0,1) // x coord in pixels
	MatrixOp/O cY = col(m0,2) // y coord in pixels
	mName = ReplaceString("cdW",mName,"cdQ")
	Wave m1 = $mName
	MatrixOp/O cZ = col(m1,4) // zone for each particle
	MatrixOp/O cQ = col(m1,3) // quality
	// get the limits for acceptance
	WAVE/Z LimitWave
	Variable zMin = limitWave[V_Value][0]
	Variable zMax = limitWave[V_Value][1]
	cX = (cQ[p] > zMin && cQ[p] <= zMax) ? cX[p] : NaN
	cY = (cQ[p] > zMin && cQ[p] <= zMax) ? cY[p] : NaN
	cZ = (cQ[p] > zMin && cQ[p] <= zMax) ? cZ[p] : NaN
	WaveTransform zapNans cX
	WaveTransform zapNans cY
	WaveTransform zapNans cZ
	Concatenate/O {cX,cY,cZ}, expWave
	KillWaves/Z cQ
	fileName = fileName + ".txt"
	Save/J/M="\n" expWave as fileName
End

Function LoadManualPointLocs()
	// load 2 numeric waves xw, yw
	Print "Locate csv with x and y locations of manual points"
	LoadWave/A/W/J/D/O/K=1/L={0,1,0,1,2}
	// load filename textwave (file)
	LoadWave/A/W/J/D/O/K=2/L={0,1,0,0,1} S_Path + S_fileName
	WAVE/T/Z file
	Rename file blindFileNameWave
	WAVE/Z xw,yw
	// resolution of images is 1 unit to 200 pixels
	xw *= 200
	yw *= 200
	Concatenate/O/NP=1/KILL {xw,yw}, pointLocWave
End

Function Unblind()
	// load log file that was saved by blind.ijm
	Print "Locate log file from blind.ijm"
	LoadWave/A/W/J/D/O/K=2/L={0,1,0,0,2}
	WAVE/Z/T Blinded_Name, Original_Name
	
	WAVE/Z/T blindFileNameWave
	Variable nRows = numpnts(blindFileNameWave)
	Make/O/T/N=(nRows) unblindFileNameWave
	String fileName
	
	Variable i
	
	for(i = 0 ; i < nRows; i += 1)
		fileName = blindFileNameWave[i]
		FindValue/TEXT=fileName Blinded_Name
		if (V_Value == -1)
			Print fileName, "not present"
		endif
		unblindFileNameWave[i] = Original_Name[V_Value]
	endfor
End

Function LoadTIFFsAndCalc()
	
	String expDiskFolderName, BrotherExpDiskFolderName
	String ThisFile, tifName
	String cdWName, cdIName, cdJName, cdMName
	Variable FileLoop, voxelSize, nWaves, i
	
	Print "Locate file containing TIFFs and the Masks directory"
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName = S_path
	// make path to brother directory containing mask images
	BrotherExpDiskFolderName = ExpDiskFolderName + "masks:"
	NewPath/O/Q BrotherExpDiskFolder, BrotherExpDiskFolderName
	// determine how many files we will process
	WAVE/Z/T Original_Name, unblindFileNameWave
	Variable nFiles = numpnts(Original_Name)
	Variable nRows = numpnts(unblindFileNameWave)
	
	Make/O/N=(nFiles,5) volumeWave
	Make/O/N=(nFiles,5) particleWave,gridWave
	Make/O/N=(nFiles) voxelWave
	Make/O/N=(nRows) zoneWave=NaN
	
	MakeSummaryLayout(nFiles,6)
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = Original_Name[fileloop]
		// load the mask image
		cdMName = "cdM" + num2str(fileLoop)
		ImageLoad/T=tiff/N=$cdMName/O/P=BrotherExpDiskFolder ThisFile
		Wave maskMat = $cdMName
		// now process the mask image to get discrete values for each zone
		ProcessMask(maskMat)
		// get area sizes of each zone (in pixels)
		GetVolumes(volumeWave,maskMat,FileLoop)
		
		// determine zones for each particle
		DetermineManualParticleZones(ThisFile,maskMat,FileLoop)
		
		// make a grid and find coincidence with each zone (stereology method)
		DetermineGridZones(ThisFile,maskMat,FileLoop)
		
		// load the parent image
		cdJName = "cdJ" + num2str(fileLoop)
		ImageLoad/T=tiff/N=$cdJName/O/P=ExpDiskFolder ThisFile
		Wave ParentImgMat = $cdJName
		voxelSize = 0.07 * (CheckScale(RemoveEnding(ThisFile,".tif")))^2
		voxelWave[FileLoop] = voxelSize // in um3
		//scale volumeWave result for this row
		volumeWave[fileLoop][] *= voxelSize
		
		// make the images for the summary layout showing where the spots are
		ImagePlusSpotsManual(ParentImgMat, FileLoop)
		
		KillWaves/Z ParentImgMat,maskMat
	endfor
	// Get rid of CMap waves. These are a colorscale that get loaded with 8-bit color TIFFs
	KillCMaps()
	
	// This is a comparison so we need to find out which file belongs to which condition
	ConditionsForManual()
	TileLayout(nFiles,6)
	ConditionsForManualAlt()
End

/// @param	ThisFile	name of original tif file
/// @param	maskMat	brother image with the mask of zones
/// @param	FileLoop	iteration number from calling function
Function DetermineManualParticleZones(ThisFile,maskMat,FileLoop)
	String ThisFile
	WAVE maskMat
	Variable FileLoop
	
	WAVE/Z/T unblindFileNameWave
	WAVE/Z pointLocWave
	WAVE/Z zoneWave
	Variable nRows = numpnts(unblindFileNameWave)
	
	Make/O/N=(nRows) w0=NaN,w1=NaN,w2=NaN
	Variable j = 0
	Variable xLoc,yLoc
	
	Variable i
	
	for(i = 0; i < nRows; i += 1)
		if(StringMatch(unblindFileNameWave[i], ThisFile) == 1)
			xLoc = round(pointLocWave[i][0])
			yLoc = round(pointLocWave[i][1])
			if(numtype(xLoc) == 0 && numtype(yLoc) == 0)
				zoneWave[i] = maskMat[xLoc][yLoc]
				if(zoneWave[i] == 0)
					zoneWave[i] = checkVicinity(maskMat,xLoc,yLoc)
				endif
				w0[j] = xLoc
				w1[j] = yLoc
				w2[j] = ZoneWave[i]
				j += 1
			endif
		endif
	endfor
	
	// make cdW and cdQ waves for display
	WaveTransform zapnans w0
	WaveTransform zapnans w1
	WaveTransform zapnans w2
	String wName = "cdW" + num2str(FileLoop)
	Concatenate/O/KILL {w0,w1}, $wName
	Wave cdWWave = $wName
	wName = "cdQ" + num2str(FileLoop)
	Rename w2, $wName
	Wave cdQWave = $wName
	
	// now store counts in ParticleWave
	WAVE/Z particleWave
	Variable totalP = dimsize(cdWWave,0)
	if(totalP == 0)
		particleWave[fileLoop][] = totalP
	else
		particleWave[fileLoop][0] = CountIf(cdQWave,0)	// zone 0 = outside
		particleWave[fileLoop][1] = CountIf(cdQWave,1)	// zone 1 = cyto
		particleWave[fileLoop][2] = CountIf(cdQWave,2)	//	zone 2 = membrane
		particleWave[fileLoop][3] = CountIf(cdQWave,4)	//	zone 4 = coat
		particleWave[fileLoop][4] = totalP	// total
	endif
End

/// @param	ThisFile	name of original tif file
/// @param	maskMat	brother image with the mask of zones
/// @param	FileLoop	iteration number from calling function
Function DetermineGridZones(ThisFile,maskMat,FileLoop)
	String ThisFile
	WAVE maskMat
	Variable FileLoop
	
	// In DetermineManualParticleZones, the location of particles was found
	// each particle was on a different row for all images that are being loaded
	// So for two images with 4 and 6 particles, there would be ten rows to unblindFileNameWave
//	WAVE/Z/T unblindFileNameWave
//	WAVE/Z zoneWave
//	Variable nRows = numpnts(unblindFileNameWave)
	// instead of pointLocWave, we make our own gridLocWave
	Make/O/N=(24,2) gridLocWave
	// 8 x 6 grid just taking the inner 6 x 4 intersections
	gridLocWave[][0] = floor((floor(p/4)+1) * (dimsize(maskMat,0) / 8))
	gridLocWave[][1] = floor((floor(p/6)+1) * (dimsize(maskMat,1) / 6))
	String wName = "cdS" + num2str(FileLoop)
	Make/O/N=(24) $wName
	Wave cdSWave = $wName
	cdSWave[] = maskMat[gridLocWave[p][0]][gridLocWave[p][1]]
		
	// now store counts in gridWave
	WAVE/Z gridWave
	Variable totalP = dimsize(cdSWave,0)
	if(totalP == 0)
		gridWave[fileLoop][] = totalP
	else
		gridWave[fileLoop][0] = CountIf(cdSWave,0)	// zone 0 = outside
		gridWave[fileLoop][1] = CountIf(cdSWave,1)	// zone 1 = cyto
		gridWave[fileLoop][2] = CountIf(cdSWave,2)	//	zone 2 = membrane
		gridWave[fileLoop][3] = CountIf(cdSWave,4)	//	zone 4 = coat
		gridWave[fileLoop][4] = totalP	// total
	endif
End

///	@param	ParentImgMat	Image for addition of spots
///	@param	imgNum	variable containing image sequence suffix (easier than parsing it out)
Function ImagePlusSpotsManual(ParentImgMat, imgNum)
	WAVE ParentImgMat
	Variable imgNum
	
	String imgName = NameOfWave(ParentImgMat)
	String cdWName = ReplaceString("cdJ",imgName,"cdW")
	Wave cdW = $cdWName
	String spotName = ReplaceString("cdJ",imgName,"spot")
	String cdQName = ReplaceString("cdJ",imgName,"cdQ")
	Wave cdQWave = $cdQName
	WAVE/Z/T Original_Name
	String origName = Original_Name[imgNum]
	
	DoWindow/K imgPlot
	NewImage/N=imgPlot/HIDE=1 ParentImgMat
	if(dimsize(cdW,0) > 0)
		AppendToGraph/W=imgPlot/L/T cdW[][1] vs cdW[][0]
		ModifyGraph/W=imgPlot mode=3,marker=8
		ModifyGraph/W=imgPlot zColor={cdQWave,0,2,YellowHot,0}, zColorMin=NaN, zColorMax=NaN
	endif
	TextBox/W=imgPlot/C/N=text0/F=0/A=RB/X=1.00/Y=1.00 origName
	
	Variable pgNum = floor(imgNum / 6) + 1 // 1st page is pg 1
	SavePICT/WIN=imgPlot/E=-5/RES=300/W=(0,0,354,248) as "Clipboard"
	LoadPICT/O/Q "Clipboard", $spotName
	AppendLayoutObject/W=summaryLayout/PAGE=(pgnum) picture $spotName
	DoWindow/K imgPlot
End

STATIC Function CountIf(cdQWave,zoneVar)
	WAVE cdQWave
	Variable zoneVar
	
	Make/O/N=(Dimsize(cdQWave,0))/FREE w0
	w0 = (cdQWave[p] == zoneVar) ? 1 : 0
	
	return sum(w0)
End

// For edge cases, need to check that the particle really is outside the cell.
STATIC Function checkVicinity(maskMat,xLoc,yLoc)
	WAVE maskMat
	Variable xLoc,yLoc
	
	Duplicate/O/FREE/RMD=[xloc-20,xloc+20][yloc-20,yLoc+20] maskMat, m0
	
	Variable aveZone = round(sum(m0) / numpnts(m0))
	// if this isn't 0 it must be 2. Because 1 is highly unlikely.
	if(aveZone > 0)
		aveZone = 2
	endif
	
	return aveZone
End

Function ConditionsForManual()
	// load 1 numeric wave with name condWave
	Print "Locate csv with filenames and conditions"
	LoadWave/A/W/J/D/O/K=1/L={0,1,0,1,2}
	// load 1 textwave with name condFileName
	LoadWave/A/W/J/D/O/K=2/L={0,1,0,0,1} S_Path + S_fileName
	WAVE/T/Z condFileName
	WAVE/Z condWave
	
	// Make a wave to hold the conditions corresponding to files in Original_Name
	WAVE/Z/T Original_Name
	Variable nFiles = numpnts(Original_Name)
	Make/O/N=(nFiles) Original_Condition
	String fileName
	
	Variable i
	
	for(i = 0; i < nFiles; i += 1)
		fileName = Original_Name[i]
		FindValue/TEXT=fileName condFileName
		if (V_Value == -1)
			Print "Couldn't find", fileName 
		endif
		Original_Condition[i] = condWave[V_Value]
	endfor
	
	KillWaves/Z condFileName,condWave
	
	// make volume waves per condition (coded for 2 conditions right now)
	WAVE/Z VolumeWave
	Duplicate/O VolumeWave, VolumeWave0,VolumeWave1
	VolumeWave0[][] = (Original_Condition[p] == 0) ? VolumeWave[p][q] : 0
	VolumeWave1[][] = (Original_Condition[p] == 1) ? VolumeWave[p][q] : 0
	MatrixOp/O sumV0 = sumcols(volumeWave0)
	MatrixOp/O sumV1 = sumcols(volumeWave1)
	Redimension/N=(dimSize(sumV0,1)) sumV0
	Redimension/N=(dimSize(sumV1,1)) sumV1
	// make particle waves per condition ()
	WAVE/Z ParticleWave
	Duplicate/O ParticleWave, ParticleWave0,ParticleWave1
	ParticleWave0[][] = (Original_Condition[p] == 0) ? ParticleWave[p][q] : 0
	ParticleWave1[][] = (Original_Condition[p] == 1) ? ParticleWave[p][q] : 0
	MatrixOp/O sumP0 = sumcols(particleWave0)
	MatrixOp/O sumP1 = sumcols(particleWave1)
	Redimension/N=(dimSize(sumP0,1)) sumP0
	Redimension/N=(dimSize(sumP1,1)) sumP1
	// find densities
	MatrixOp/O density0 = sumP0 / sumV0
	MatrixOp/O density1 = sumP1 / sumV1
	// row 3 is garbage (total particles divided by zone 3)
End

// ParticleWave has Out, Cyto, Mem, Coat, Total
// ParticleWave has Out, Cyto, Mem, Junk, Coat
Function ConditionsForManualAlt()
	WAVE/Z Original_Condition
	if(!WaveExists(Original_Condition))
		return -1
	endif
	WAVE/Z particleWave,VolumeWave
	MatrixOp/O/FREE tempMat = particleWave / VolumeWave
	MatrixOp/O/FREE tempW0 = col(tempMat,1)
	MatrixOp/O/FREE tempW1 = col(tempMat,2)
	MatrixOp/O/FREE tempW2 = col(particleWave,3) / col(volumeWave,4)
	Concatenate/O/NP=1 {tempW0,tempW1,tempW2}, densityWave
	
	// Original_condition holds integers corresponding to different cells/conditions
	Variable nCond = WaveMax(Original_Condition) + 1
	Variable nRows = dimsize(densityWave,0)
	String w0Name,w1Name,w2Name
	
	Variable i
	
	for(i = 0; i < nCond; i += 1)
		w0Name = "cyto_" + num2str(i)
		w1Name = "memb_" + num2str(i)
		w2Name = "coat_" + num2str(i)
		Make/O/N=(nRows) $w0Name, $w1Name, $w2Name
		Wave w0 = $w0Name
		Wave w1 = $w1Name
		Wave w2 = $w2Name
		w0[] = (Original_Condition[p] == i) ? densityWave[p][0] : NaN
		w1[] = (Original_Condition[p] == i) ? densityWave[p][1] : NaN
		w2[] = (Original_Condition[p] == i) ? densityWave[p][2] : NaN
		WaveTransform zapNans w0
		WaveTransform zapNans w1
		WaveTransform zapNans w2
	endfor
End