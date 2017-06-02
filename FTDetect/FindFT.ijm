/*
 * Use ComDet v 0.3.5
 */

macro "Run ComDet" {
	DIR_PATH=getDirectory("Select a directory");
	
print("\\Clear");
print("DIR_PATH :"+DIR_PATH);
	
	// Get all file names
	ALL_NAMES=getFileList(DIR_PATH);

	// Create the output folder
	OUTPUT_DIR=DIR_PATH+"cd"+File.separator;
	File.makeDirectory(OUTPUT_DIR);

	// How many TIFFs do we have? Directory could contain other directories.
	for (i=0; i<ALL_NAMES.length; i++) {		
 		if (indexOf(toLowerCase(ALL_NAMES[i]), ".tif")>0) {	
 			IM_NUMBER=IM_NUMBER+1;		
 		}
 	}
	IM_NAMES=newArray(IM_NUMBER);
	
	// Test all files for extension
	j=0;
	for (i=0; i<ALL_NAMES.length; i++) {
		if (indexOf(toLowerCase(ALL_NAMES[i]), ".tif")>0) {	
			IM_NAMES[j]=ALL_NAMES[i];
			j=j+1;
		}
	}

	// Open each image then do the inversion/subtraction/detection
	setBatchMode(true);
	for(j=0; j<IM_NUMBER; j++){
		INPUT_PATH=DIR_PATH+IM_NAMES[j];
		OUTPUT_PATH=OUTPUT_DIR+IM_NAMES[j];
		OUTPUT_RES_PATH=OUTPUT_DIR+replace(IM_NAMES[j],".tif",".txt");
		open(INPUT_PATH);
		id0 = getImageID();
		run("8-bit");
		run("Invert");
		run("Duplicate...", " ");
		id1 = getImageID();
		run("Mean...", "radius=20");
		imageCalculator("Subtract create 32-bit", id0, id1);
		id2 = getImageID();
		selectImage(id2);
		run("8-bit");
		run("Detect Particles", "approximate=5 sensitivity=[Very dim particles (SNR=3)]");
		//run("Detect Particles", "  ch1a=3 ch1s=[Very dim particles (SNR=3)]"); // to work with 0.3.6
		save(OUTPUT_PATH);
		close();
		selectImage(id0);
		close();
		selectImage(id1);
		close();
		selectWindow("Results"); // will crash if no particles found
		saveAs("Results", OUTPUT_RES_PATH);
	}
	setBatchMode(false);
	showStatus("finished");
}