# IPSpatStats
Spatial Statistics in Igor Pro

## FerriTag.ipf

Igor procedure file (ipf) featuring:

- Main program
	- `FerriTag()` performs the simulation
	- `LookAtPDFs()` visualise probability density functions
	- `MakeFTPlot()` compares real data with the model
- Version of the main program to label a point in 3D space
	- `FerriTagSphere()` performs the simulation
	- `LookAtPDFsSphere()` visualise probability density functions
	- `MakeFTPPlotSphere()` plots the model data only	
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

To run the simulation, type `LookAtPDFs(7,18)` or `LookAtPDFsSphere(7,18)`, for example.

To generate a 3D figure to show the pose of FerriTag and the measurements taken, run `FerriTag(16,6.5,70,100)` (or `FerriTagSphere(16,70,100)`) and append `posSect` and `posWave` as scatter in a gizmo. Plasma membrane can be generated using `PMMaker()`.

Note, that the main program requires a wave of observations called `FTMeasWave`. The alternative version of the program does not need this.

To run the simulation many times (settings are hardcoded), type `RunMultiple(n)` where n is the number of times you'd like to run the program.

To estimate the number of measurements are required, type `PowerTest(8,22)`.