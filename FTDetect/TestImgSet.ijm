/*
 * Make a set of test images with ground truth images to compare.
 * Ten spots on a grey noisy background
 */

macro "Make Test Images" {
	DIR_PATH=getDirectory("Select a directory");

	// Create the output folders
	TESTIMG_OUTPUT_DIR=DIR_PATH+"testImgs"+File.separator;
	File.makeDirectory(TESTIMG_OUTPUT_DIR);
	GTIMG_OUTPUT_DIR=TESTIMG_OUTPUT_DIR+"masks"+File.separator;
	File.makeDirectory(GTIMG_OUTPUT_DIR);
	
	setBatchMode(true);
	imageDim=1024;     //-- Set image dimension in pixels
	pixelSize=0.005;     //-- What is the pixel size in um/pixel

	for (i=0;i<12;i++){
		imgName = "img_"+IJ.pad(i,3);
		TESTIMG_OUTPUT=TESTIMG_OUTPUT_DIR + imgName;
		GTIMG_OUTPUT=GTIMG_OUTPUT_DIR + imgName;
		newImage("TestImg", "8-bit random", imageDim, imageDim, 1);
		run("Mean...", "radius=2");
		Tid = getImageID();
		newImage("GTImg", "8-bit grayscale-mode black", imageDim, imageDim, 1,1,1);
		GTid = getImageID();
		
		for (j=0;j<60;j++){
			posX=floor(random*imageDim);
			posY=floor(random*imageDim);
			selectImage(Tid);
			makeOval(posX, posY, 3, 3);     //-- Make a selection in the starting position using a 5 pixel circle
			run("Fill", "slice");     //-- Fill the point into the image (using foreground colour)
			run("Select None");     //-- Deselect everything
			selectImage(GTid);
			makeOval(posX, posY, 3, 3);     //-- Make a selection in the starting position using a 5 pixel circle
			run("Fill", "slice");     //-- Fill the point into the image (using foreground colour)
			run("Select None");     //-- Deselect everything
		}
		selectImage(Tid);
		run("Gaussian Blur...", "sigma=2 stack");
		save(TESTIMG_OUTPUT);
		close();
		selectImage(GTid);
		save(GTIMG_OUTPUT);
	}
	setBatchMode(false);
}