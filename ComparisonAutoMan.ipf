#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function RealParticles2cdR()
	String wList = WaveList("cdW*",";","")
	Variable nWaves = ItemsInList(wList)
	String mName, newName
	WAVE/Z LimitWave
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		mName = "cdW" + num2str(i)
		Wave m0 = $mName
		newName = "cdR" + num2str(i)
		MatrixOp/O/FREE cX = col(m0,1) // x coord in pixels
		MatrixOp/O/FREE cY = col(m0,2) // y coord in pixels
		mName = ReplaceString("cdW",mName,"cdQ")
		Wave m1 = $mName
		MatrixOp/O/FREE cZ = col(m1,4) // zone for each particle
		MatrixOp/O/FREE cQ = col(m1,3) // quality
		// get the limits for acceptance
		Variable zMin = limitWave[i][0]
		Variable zMax = limitWave[i][1]
		cX[] = (cQ[p] > zMin && cQ[p] <= zMax && cZ[p] < 3) ? cX[p] : NaN
		cY[] = (cQ[p] > zMin && cQ[p] <= zMax && cZ[p] < 3) ? cY[p] : NaN
		cZ[] = (cQ[p] > zMin && cQ[p] <= zMax && cZ[p] < 3) ? cZ[p] : NaN
//		cQ[] = (cQ[p] > zMin && cQ[p] <= zMax && cZ[p] < 3) ? cQ[p] : NaN
		WaveTransform zapNans cX
		WaveTransform zapNans cY
		WaveTransform zapNans cZ
//		WaveTransform zapNans cQ
		Concatenate/O {cX,cY,cZ}, $newName
	endfor
End

Function ManualParticles2cdR()
	String wList = WaveList("cdW*",";","")
	Variable nWaves = ItemsInList(wList)
	String mName, newName
	WAVE/Z LimitWave
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		mName = "cdW" + num2str(i)
		Wave m0 = $mName
		mName = ReplaceString("cdW",mName,"cdQ")
		Wave m1 = $mName
		newName = "cdR" + num2str(i)
		Concatenate/O/NP=1 {m0,m1}, $newName
	endfor
End

Function CompareAutoMan()
	SetDataFolder root:
	String dfrAuto = "root:DataAuto:"
	String dfrMan = "root:DataMan:"
	
	WAVE/Z IntegerManFromAuto
	Variable nMat = numpnts(IntegerManFromAuto)
	Make/O/N=(nMat,2) compMat
	
	Variable i
	
	for(i = 0; i < nMat; i += 1)
		Wave manMat = $(dfrMan + "cdR" + num2str(IntegerManFromAuto[i]))
		Wave autoMat = $(dfrAuto + "cdR" + num2str(i))
		compMat[i][0] = DimSize(manMat,0)
		compMat[i][1] = DimSize(autoMat,0)
	endfor
End