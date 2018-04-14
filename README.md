# FerriTag

Code in this repo is for:

1. [Computer simulations and spatial analysis of FerriTag in Igor Pro](#computer-simulations)
2. [Nanoscale mapping FerriTag distributions using IMOD outputs](#imod-model-analysis)
3. [Signal-to-noise ratio calculation and 2D Gauss fitting of FerriTag particles](#2d-gaussian-fitting-and-snr-calculation)
4. [Stereological analysis of particles in EM images](#stereology)


## Computer simulations

Igor procedure file [Ferritag.ipf](https://github.com/quantixed/FerriTag/blob/master/FerriTag.ipf) featuring:

- Main program
	- `FerriTag()` performs the simulation
	- `LookAtPDFs()` visualise probability density functions
	- `MakeFTPlot()` compares real data with the model	
- Estimation of the number of observations required to determine the spatial resolution of the method
	- `PowerTest()`
- Run the main program many times to test robustness of simulation
	- `MedCalc()`
	- `RunMultiple()`

- Utility functions (called from other functions only)
	- `TidyUpPlots()`
	- `PMMaker()`
	- `ColorTraces()`
	- `FlushAllDist()`

--

To run the simulation, type `LookAtPDFs(7,18)`, for example.

To generate a 3D figure to show the pose of FerriTag and the measurements taken, run `FerriTag(16,6.5,70,100)` and append `posSect` and `posWave` as scatter in a gizmo. Plasma membrane can be generated using `PMMaker()`.

Note, that the main program requires a wave of observations called `FTMeasWave`.

To run the simulation many times (settings are hardcoded), type `RunMultiple(n)` where n is the number of times you'd like to run the program.

To estimate the number of measurements are required, type `PowerTest(8,22)`.

## IMOD model analysis

These functions (in [IMODModelAnalysis.ipf](https://github.com/quantixed/FerriTag/blob/master/IMODModelAnalysis.ipf)) will load and analyse FerriTagged particles near clathrin-coated pits visualised by EM.


1. To start you need to segment your images in IMOD.
2. Output models as text files using `model2point`. Use the command
`model2point -fl -ob -z example_Model_IMOD example.txt`
for each IMOD model.
3. These txt files should be in a directory with no other txt files (other filetypes are OK).
4. Load `IMODModelAnalysis.ipf` into Igor.
5. Igor needs scaling information for each image/model to do the analysis. You need to provide this as two waves called:
	1. FileName (textwave) containing the names of each txt file.
	2. PixelSize (numeric) size in nm of a pixel.
	
	This is important and the analysis will not run without it. We make a csv and load it in using Igor's *Load > Data > Load Delimited Text...* function.
	 
6. To run the analysis, select *Macros > FerriTag Analysis* or run `IMODModelAnalysis()` from the command line.
7. Igor will load each model and display it to you with a graphical interface.
8. Use Cursors A and Cursor B to mark out what you judge to be the start and end of the pit. Drag the Cursors from the little box below the graph.
9. Click continue and the next one will display until you have loaded all models from your directory.
10. Igor will then display several graphs of the analysis.

There are two layouts which can be saved in a variety of formats.


## 2D Gaussian fitting and SNR calculation

In the file [FTAnalysisSNR.ipf](https://github.com/quantixed/FerriTag/blob/master/FTAnalysisSNR.ipf), you will find tools to fit 2D Gaussian functions to FerriTag particles. The location of the peaks is then used to calculate the SNR. The function `LoadTIFFFilesForAnalysis()` works on a directory of TIFFs, but it requires several waves loaded into the experiment to do this properly. See comments for details.


## Stereology

The locations of particles in images are recorded in ImageJ and saved as a csv. To do this a images are stripped of metadata and the filenames encoded (using `blind_analysis.
ijm`) so that the person locating particles is blind to the conditions of the experiment.

A segmented version of each EM image is also required (in a directory called `Masks`). See comments for further details.

To run `Stereology Workflow` the following files are needed:

1. Images and a sub directory of Masks
2. csv with locations of particle xy coords
3. log file from `blind_analysis` for unblinding the images
4. csv with pixelsize information
5. csv with a list of conditions in each image (encoded with an integer).