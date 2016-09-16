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

- Utility functions
	- `TidyUpPlots()`
	- `PMMaker()`
	- `ColorTraces()`
	- `FlushAllDist()`

ghdsjkagfhjkd