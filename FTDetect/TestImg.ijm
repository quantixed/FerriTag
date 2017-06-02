/*
 * Make a test image and a ground truth image to compare.
 * Ten spots on a grey noisy background
 */
setBatchMode(true);
imageDim=512;     //-- Set image dimension in pixels
pixelSize=0.005;     //-- What is the pixel size in um/pixel

newImage("TestImg", "8-bit random", imageDim, imageDim, 1);
run("Mean...", "radius=2");
Tid = getImageID();
newImage("GTImg", "8-bit grayscale-mode black", imageDim, imageDim, 1,1,1);
GTid = getImageID()
for (i=0;i<10;i++){
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
setBatchMode("exit and display");