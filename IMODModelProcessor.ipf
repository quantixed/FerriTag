#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function ProcessIMODModels()
	
	String expDiskFolderName
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
		LoadWave/A/J/D/O/K=1/V={" "," $",0,0}/L={0,0,0,1,0}/P=expDiskFolder ThisFile
		PlotFTData()
		ScaleIt(ThisFile)
		pdfName = ReplaceString(".txt", ThisFile, ".pdf")
		SavePICT/O/WIN=FTPlot/E=-2/P=expDiskFolder as pdfName
	endfor
	DoWindow/K FTPlot
	// KillWaves/A/Z
End

Function PlotFTData()
	Concatenate/O/KILL wavelist("wave*",";",""), matA
	WaveStats/Q/RMD=[][0] matA
	Variable nObjects = V_max + 1
	Variable nRows = dimsize(MatA,0)
	Variable nContours, rowStart, rowEnd
	
	DoWindow/K FTPlot
	Display/N=FTPlot/W=(0,0,1000,1000)
	
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
			AppendToGraph/W=FTPlot MatA[rowStart,rowEnd][3] vs MatA[rowStart,rowEnd][2]
		endfor
	endfor
	ModifyGraph/W=FTPlot width={Plan,1,bottom,left}
	SetAxis/W=FTPlot left 0,1200
	SetAxis/W=FTPlot bottom 0,1200
	ModifyGraph/W=FTPlot rgb=(0,0,0)
	ModifyGraph/W=FTPlot noLabel=2,axThick=0
End

///	@param	txtName	accepts the string ThisFile
Function ScaleIt(txtName)
	String txtName
	
	txtName = ReplaceString(".txt",txtName,"")
	Wave/T/Z FileName
	Wave/Z PixelSize
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
	MatA[][2,4] *= pxSize
	// Print txtName, pxSize
End

Function ProcessTIFFs()
	
	String FileList, ThisFile
	Variable FileLoop
	
	NewPath/O/Q/M="Folder with TIFFs" ExpDiskFolder
	if (V_flag != 0)
		DoAlert 0, "User pressed cancel"
		Return -1
	endif
	FileList = IndexedFile(expDiskFolder,-1,".tif")
	Variable nFiles = ItemsInList(FileList)
	Make/O/N=(nFiles)/T TiffName
	Make/O/N=(nFiles) sbPxSize
	
	for(FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile=StringFromList(FileLoop, FileList)
		ImageLoad/O/T=tiff/Q/P=expDiskFolder/N=lImage ThisFile
		Wave/Z lImage
		TiffName[FileLoop] = ThisFile
		sbPxSize[FileLoop] = CheckScaleBar(lImage)
	endfor
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