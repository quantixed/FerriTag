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
		// set quality to be 1 or zero depending on the acceptance criteria
		cQ[] = (cQ[p] > zMin && cQ[p] <= zMax) ? 1 : 0
		// now get rid of points that are not in zones 0, 1 or 2
		cX[] = (cZ[p] < 3) ? cX[p] : NaN
		cY[] = (cZ[p] < 3) ? cY[p] : NaN
		cZ[] = (cZ[p] < 3) ? cZ[p] : NaN
		cQ[] = (cZ[p] < 3) ? cQ[p] : NaN
		WaveTransform zapNans cX
		WaveTransform zapNans cY
		WaveTransform zapNans cZ
		WaveTransform zapNans cQ
		Concatenate/O {cX,cY,cZ,cQ}, $newName
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
	// make a matrix to take results
	// A, B, C, A&C, B&C
	Make/O/N=(nMat,5) compMat
	
	Variable i
	
	for(i = 0; i < nMat; i += 1)
		Wave manMat = $(dfrMan + "cdR" + num2str(IntegerManFromAuto[i]))
		Wave autoMat = $(dfrAuto + "cdR" + num2str(i))
		MatrixOp/O/FREE toSum = col(autoMat,3)
		// store the number of particles in compMat
		compMat[i][0] = DimSize(AutoMat,0) // how many auto total
		compMat[i][1] = sum(toSum) // how many auto thru filter?
		compMat[i][2] = DimSize(manMat,0) // how many manual
		if(compMat[i][2] == 0)
			continue
		endif
		// now find each manual particle counterpart in auto with Q=0 or 1
		FindMinima(autoMat,manMat)
		Wave distW = $(dfrAuto + "dist" + num2str(i))
		// find corresponding points (<10 px)
		Duplicate/O/FREE distW,tempW
		tempW[] = (distW[p] < 10) ? 1 : 0
		compMat[i][3] = sum(tempW)
		// in case number of manual particles is exceeded
		if(compMat[i][3] > compMat[i][2])
			compMat[i][3] = compMat[i][2]
		endif
		tempW[] = (autoMat[p][3] == 1) ? tempW[p] : 0
		compMat[i][4] = sum(tempW)
		if(compMat[i][4] > compMat[i][3])
			compMat[i][4] = compMat[i][3]
		endif
	endfor
End

STATIC Function/WAVE FindMinima(autoMat,manMat)
	Wave autoMat,manMat
	
	Variable nRowsA = DimSize(autoMat,0)
	Variable nRowsB = DimSize(manMat,0)
	
	// from http://www.igorexchange.com/node/8207
	MatrixOp/O/FREE ax = col(autoMat,0)
	MatrixOp/O/FREE ay = col(autoMat,1)
	MatrixOp/O/FREE bx = col(manMat,0)
	MatrixOp/O/FREE by = col(manMat,1)
	MatrixOp/O/FREE matAx = colRepeat(ax,nRowsB)
	MatrixOp/O/FREE matAy = colRepeat(ay,nRowsB)
	MatrixOp/O/FREE matBx = rowRepeat(bx,nRowsA)
	MatrixOp/O/FREE matBy = rowRepeat(by,nRowsA)
	MatrixOp/O/FREE distanceX = matAx - matBx
	MatrixOp/O/FREE distanceY = matAy - matBy
	MatrixOp/O/FREE matDist = sqrt(distanceX * distanceX + distanceY * distanceY)
	String mName = "root:dataAuto:" + ReplaceString("cdR",NameOfWave(autoMat),"dist")
	MatrixOp/O $mName = minRows(matDist)^t
End