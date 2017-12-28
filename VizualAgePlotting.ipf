//########################################################
//   VisualAge add-on for Iolite                    
//   Written by Joe Petrus      
//   Version 2015.06
//########################################################
#pragma rtGlobals=1

//########################################################
// Histogram related functions
//########################################################

//------------------------------------------------------------------------
// Histogram creation -- called when histogram is selected from the menu
//------------------------------------------------------------------------
Function AgeHistogram()

	// Make sure VisualAge has been initialized:
	VAInitialized()
		
	// Get some variables from Iolite:
	String MatrixName = GetMatrixName()
	SVAR ListOfOutputChannels = $ioliteDFpath("Output", "ListOfOutputChannels")
	Variable NoOfChannels = ItemsInList(ListOfOutputChannels)

	// Get the default histogram plotting parameters:
	NVAR DefaultStartAge = root:Packages:VisualAge:Options:HistogramOption_StartAge
	NVAR DefaultStopAge = root:Packages:VisualAge:Options:HistogramOption_StopAge
	NVAR DefaultBinSize = root:Packages:VisualAge:Options:HistogramOption_BinSize
	NVAR hcount = root:Packages:VisualAge:HistogramCount

	// Get a list of ages available to plot:
	String ListOfHistogramOptions= ""
	Variable i
	For ( i = 0; i < NoOfChannels; i = i + 1)
		String CurrentChannel = StringFromList(i, ListOfOutputChannels)

		If ( StrSearch(CurrentChannel, "Age", 0) != -1 )
			ListOfHistogramOptions = ListOfHistogramOptions + CurrentChannel + ";"
		EndIf
	EndFor
		
	// Ask the user which age they'd like to plot and how to plot it:
	String HistAge = ""
	String HistInt = MatrixName
	String HistName = "Hist" + num2str(hcount)
	Variable HistStartAge = DefaultStartAge
	Variable HistStopAge = DefaultStopAge
	Variable HistBinSize = DefaultBinSize
	
	Prompt HistName, "Name of histogram: "
	Prompt HistAge, "Which age? ", popup, ListOfHistogramOptions
	Prompt HistInt, "Which integration type? ", popup, GetListOfUsefulIntegrations()
	Prompt HistStartAge, "Start age [Ma]: "
	Prompt HistStopAge, "Stop age [Ma]: "
	Prompt HistBinSize, "Bin size [Ma]: "
	
	// Ensure that the name given doesn't conflict with a built in Igor Pro name:
	Do
		DoPrompt/HELP="" "VisualAge Histogram", HistName, HistStartAge,HistInt, HistStopAge, HistAge, HistBinSize
		If ( V_Flag )
			Return -1
		EndIf
		
		If ( CheckName(HistName, 1) != 0 )
			DoAlert/T="VisualAge" 0, "The name you have entered is reserved in Igor Pro.  Please try a different name."
		Elseif ( !AlphaNumeric(HistName) )
			DoAlert/T="VisualAge" 0, "The name you enter must be alphanumeric (no symbols, except \"_\")" 
		EndIf

	While ( CheckName(HistName, 1) != 0 || !AlphaNumeric(HistName))
	
	// Ensure name starts with a letter:
	If (char2num(HistName[0]) < 57 && char2num(HistName[0]) > 48 )
		HistName = "h" + HistName
	EndIf	
	
	// Check if histogram exists:
	String HistPathAndName = "root:Packages:VisualAge:Histograms:" + HistInt + ":" + HistAge + ":" + HistName + "Counts"
	If (WaveExists($HistPathAndName))
		DoAlert/T="VisualAge" 1, "A histogram named " + HistName + " for " + HistInt + " already exists.  Would you like to replace it?"
		If (V_flag != 1)
			Return -1
		EndIf
		
		String actualWinName = Note($HistPathAndName)
		KillWindow $actualWinName
		KillWaves/Z root:Packages:VisualAge:Histograms:$(HistInt):$(HistAge):$(HistName + "Counts")
		KillWaves/Z root:Packages:VisualAge:Histograms:$(HistInt):$(HistAge):$(HistName + "Bins")
		KillWaves/Z root:Packages:VisualAge:Histograms:$(HistInt):$(HistAge):$(HistName + "KDE")
		KillWaves/Z root:Packages:VisualAge:Histograms:$(HistInt):$(HistAge):$(HistName + "PDP")
		KillWaves/Z root:Packages:VisualAge:Histograms:$(HistInt):$(HistAge):$(HistName + "TicksY")
		KillWaves/Z root:Packages:VisualAge:Histograms:$(HistInt):$(HistAge):$(HistName + "TicksX")		
	EndIf			
		
	// Create a folder for the histogram data:
	NewDataFolder/O/S root:Packages:VisualAge:Histograms
	NewDataFolder/O/S $HistInt
	NewDataFolder/O/S $HistAge

	// Get matrix for the selected integration:
	Wave aim = $ioliteDFpath("integration", "m_" + HistInt)
	Variable NoOfIntegrations = DimSize(aim,0) - 1
	
	// Get ages from Iolite + store in a wave:
	Make/O/N=(NoOfIntegrations) InputDataNumbers
	Make/O/N=(NoOfIntegrations) InputData2SE
	Wave ResultWave = $MakeioliteWave("CurrentDRS", "ResultWave", n=2)
	For ( i = 1; i <= NoOfIntegrations; i = i + 1 )
		GetIntegrationFromIolite(HistAge, HistInt, i, "ResultWave")
		InputDataNumbers[i-1] = ResultWave[0]
		InputData2SE[i-1][0] = ResultWave[1]
	EndFor
	
	Variable MaxAgeInData = WaveMax(InputDataNumbers)
	Variable MinAgeInData = WaveMin(InputDataNumbers)
	Variable AgeSpread = MaxAgeInData - MinAgeInData	
	
//	Variable bw = sqrt(0.28*numpnts(InputDataNumbers)^(-2/5))*(AgeSpread)
	NVAR bw = root:Packages:VisualAge:Options:HistogramOption_KDEbw
	Variable nx = min(round(1000*(AgeSpread+8*bw)/bw),1000)
		
	Variable xmin=MinAgeInData-4*bw
	Variable xmax=MaxAgeInData+4*bw
	
	// If the start and stop ages were specified as -1, try to guess at reasonable values (currently pretty bad):
	If ( (HistStartAge == -1 || numtype(HistStartAge) == 2) && (HistStopAge == -1 || numtype(HistStopAge) == 2) )	
		HistStartAge = FloorToSig(MinAgeInData, ceil(log(AgeSpread)))
		HistStopAge = CeilToSig(MaxAgeInData, ceil(log(AgeSpread)))
	EndIf
		
	// If the bin size is set to -1 split up the range into about 40 bins:
	If ( HistBinSize == -1 || numtype(HistBinSize) == 2)
		HistBinSize = FloorToSig((HistStopAge-HistStartAge)/40, 1)
	EndIf
	
	Variable NoOfBins = round((HistStopAge-HistStartAge)/HistBinSize)
	
	// Create histogram + display:
	Make/N=(NoOfBins)/O $(HistName + "Counts"), $(HistName + "Bins")
	Histogram/B={HistStartAge, HistBinSize, NoOfBins} InputDataNumbers,$(HistName + "Counts")
	Display/K=1/N=$HistName $(HistName + "Counts") as HistInt + " " + HistAge

	// Set some user data for the graph to be accessed by the hook function and others:
	SetWindow $S_name, userdata(Name)=HistName
	SetWindow $S_name, userdata(IntType)=HistInt
	SetWindow $S_name, userdata(AgeType)=HistAge
	SetWindow $S_name, userdata(Type)="Histogram"
	Note/K $(HistName + "Counts"), S_name
	
	// Make the bin wave:
	Wave Bins = $(HistName + "Bins")
	For (i = 0; i < NoOfBins; i = i + 1)
		Bins[i] = HistStartAge + HistBinSize*i
	EndFor
	
	// Calculate a probability distribution if desired (this could use some work!!):
	NVAR DoPDF = root:Packages:VisualAge:Options:HistogramOption_ShowPDP
	If (DoPDF)		
		Make/O/N=(nx) $(HistName+"PDP")
		Wave pdp = $(HistName+"PDP")
	
		For(i = 0; i < numpnts(InputDataNumbers); i = i + 1)
			Variable j
			For(j = 0; j < nx; j = j + 1)
				pdp[j] += StatsNormalPDF(xmin+j*(xmax-xmin)/nx, InputDataNumbers[i], InputData2SE[i]/2)
			EndFor
		EndFor
		
		SetScale /P x, xmin, (xmax-xmin)/nx, pdp	

		Variable pdp_norm = sum(pdp)*deltax(pdp)
		pdp = pdp/pdp_norm
		
		AppendToGraph/R pdp	
		
		ModifyGraph mode($(HistName+"PDP"))=0
		ModifyGraph rgb($(HistName+"PDP"))=(65535,0,0)	
	EndIf
	
	// Calculate KDE and plot if desired:
	NVAR DoKDE = root:Packages:VisualAge:Options:HistogramOption_ShowKDE
	If (DoKDE)
		Variable kde_norm
		Make /d/free/n=(numpnts(InputDataNumbers)) wweights=1
		FastGaussTransform /TET=500/WDTH=(bw) /RX=(bw/100)/OUT1={xmin,nx,xmax} InputDataNumbers,wweights 	// you may need to tweak /RX flag value /RX=(8*bw)/TET=200
		Wave M_FGT;  kde_norm=sum(M_FGT)*deltax(M_FGT);		M_FGT /= kde_norm; 
		String wn=HistName+"KDE";	duplicate /d/o M_FGT $wn 
		KillWaves M_FGT
		AppendToGraph/R $wn		
	EndIf
	
	NVAR DoTicks = root:Packages:VisualAge:Options:HistogramOption_ShowTicks
	If (DoTicks)
		
		Make/O/N=(numpnts(InputDataNumbers)) $(HistName+"TicksY")=0, $(HistName+"TicksX")=0
		Wave TickXData = $(HistName+"TicksX")
		TickXData = InputDataNumbers
		
		AppendToGraph $(HistName+"TicksY") vs $(HistName+"TicksX")
	EndIf

	// Adjust graph properties:
	Label bottom HistAge + " [Ma]"
	if (DoPDF || DoKDE)
		Label right "Probability"
	endif
	Label left "Counts"

	ModifyGraph mirror(bottom)=2, standoff=0, gFont="Helvetica", gfSize=16, axisOnTop(bottom)=1
	
	If (!DoPDF && !DoKDE)
		ModifyGraph mirror(left)=1
	EndIf	

	ModifyGraph width=600,height=400
	
	// Histogram:
	ModifyGraph rgb($(HistName + "Counts"))=(0,0,0)
	ModifyGraph lsize($(HistName + "Counts"))=1.5
	ModifyGraph mode($(HistName + "Counts"))=6
	
	// PDP:
	If (DoPDF)
		ModifyGraph rgb($(HistName + "PDP")) = (65535,0,0)
	EndIf
	
	// KDE:;
	If (DoKDE)
		ModifyGraph rgb($(HistName + "KDE")) = (0,0,65535)
	EndIf

	// Ticks:
	If (DoTicks)
		ModifyGraph mode($(HistName+"TicksY"))=3
		ModifyGraph marker($(HistName+"TicksY"))=10
		ModifyGraph rgb($(HistName+"TicksY"))=(0,0,0)
	EndIf
	
	// Legend:
	String LegendString = "\\s(" + HistName + "Counts) Histogram\r"
	If (DoPDF)
		LegendString += "\\s(" + HistName + "PDP) Probability distribution\r"
	EndIf
	If (DoKDE)
		LegendString += "\\s(" + HistName + "KDE) Kernel density estimate\r"
	EndIf
	If (DoTicks)
		LegendString += "\\s(" + HistName + "TicksY) Individual ages\r"
	EndIf
	
	LegendString += "N = " + num2str(numpnts(InputDataNumbers))
	
	Legend/C/N=HistLegend/J/A=MC LegendString
	Legend/C/N=HistLegend/J/A=LT/X=0.5/Y=0.5
		
	// Round up y-axis max to nearest 10:
	Variable CountMax = 10*ceil(WaveMax($(HistName + "Counts"))/10)
	SetAxis left 0, CountMax
	
	// Determine some stats and add them as an annotation:
	//NVAR ShowStats = root:Packages:VisualAge:Options:HistogramOption_ShowStats
	//If (ShowStats)
	//	WaveStats/Q/Z InputDataNumbers
	//	String InfoStr =  "Mean = " + num2str(V_avg) + " Ma \rStdev = " + num2str(V_sdev) + "\rN = " + num2str(V_npnts)
	//	TextBox/C/N=HistText/A=RT InfoStr
	//EndIf

	// Set the histogram hook function:
	SetWindow kwTopWin, hook(histHook) = AgeHistogramHook

	// Histogram counter increment
	hcount = hcount + 1

	KillWaves InputDataNumbers, InputData2SE
End

//------------------------------------------------------------------------
// Hook function for histogram window - shows the age corresponding to the mouse position
//------------------------------------------------------------------------
Function AgeHistogramHook(s)
	STRUCT WMWinHookStruct &s

	// Main hook switch:
	Switch(s.eventCode)
		// Mouse button down event:
		Case 3: 
			// If shift isn't down break:
			If (s.eventmod != 3)
				Break
			EndIf
			
			// Determine age corresponding to x-coord:
			GetWindow kwTopWin, psize
			Variable pmin = V_left
			Variable pmax = V_right
			Variable pvmin = V_top
			Variable pvmax = V_bottom
			GetAxis/Q bottom
			Variable amin = V_min
			Variable amax = V_max
				
			Variable xval = (amax-amin)*(s.mouseLoc.h-pmin)/(pmax-pmin) + amin
			Variable xa = 100*(s.mouseLoc.h-pmin)/(pmax-pmin)
			Variable ya = 100*(s.mouseLoc.v-pvmin)/(pvmax-pvmin)

			// Add/move tag:
			TextBox/C/N=HistMouseInfo/F=0/A=LT/X=(xa+2)/Y=(ya+2) num2str(xval) + " Ma"

			Break
			
		// Window killed:			
		Case 2: 
			// Delete data for this window:
			String HistName = GetUserData(s.winName,"", "Name")
			String IntType = GetUserData(s.winName,"","IntType")
			String AgeType = GetUserData(s.winName,"","AgeType")
			
			RemoveFromGraph/Z $(Histname + "Counts")
			RemoveFromGraph/Z $(HistName + "PDP")
			RemoveFromGraph/Z $(HistName + "KDE")
			RemoveFromGraph/Z $(HistName + "TicksY")						
			KillWaves/Z root:Packages:VisualAge:Histograms:$(IntType):$(AgeType):$(HistName + "Counts")
			KillWaves/Z root:Packages:VisualAge:Histograms:$(IntType):$(AgeType):$(HistName + "Bins")
			KillWaves/Z root:Packages:VisualAge:Histograms:$(IntType):$(AgeType):$(HistName + "PDP")
			KillWaves/Z root:Packages:VisualAge:Histograms:$(IntType):$(AgeType):$(HistName + "KDE")
			KillWaves/Z root:Packages:VisualAge:Histograms:$(IntType):$(AgeType):$(HistName + "PDF")			
			KillWaves/Z root:Packages:VisualAge:Histograms:$(IntType):$(AgeType):$(HistName + "TicksX")
			KillWaves/Z root:Packages:VisualAge:Histograms:$(IntType):$(AgeType):$(HistName + "TicksY")							
			KillWaves/Z root:Packages:VisualAge:Histograms:$(IntType):$(AgeType):$(HistName + "PDFBins")
			KillWaves/Z root:Packages:VisualAge:Histograms:$(IntType):$(AgeType):$(HistName + "BinSigma")	
			Break
	EndSwitch
		
	Return 0
End

//########################################################
// Concordia related functions
//########################################################

//------------------------------------------------------------------------
// Concordia creation -- called when the menu item is selected
//------------------------------------------------------------------------
Function Concordia(doTW)
	Variable doTW
	
	// Make sure VisualAge is initialized:
	VAInitialized()
	
	// Get some info from Iolite:
	String MatrixName = GetMatrixName()
	SVAR ListOfOutputChannels = $ioliteDFpath("Output", "ListOfOutputChannels")
	Variable NoOfChannels = ItemsInList(ListOfOutputChannels)
	
	// Get a list of options... kind of a complicated way to find Final, FinalAnd, or FinalPbC:
	String ListOfConcordiaOptions = ""
	Variable i
	For ( i = 0; i < NoOfChannels; i = i + 1)
		String currentChannel = StringFromList(i, ListOfOutputChannels)
		
		If ( StrSearch(currentChannel, "207_235", 0) != -1 && StrSearch(currentChannel, "Age",0) == -1 )
			ListOfConcordiaOptions = ListOfConcordiaOptions +  RemoveEnding(currentChannel, "207_235") + ";"
		EndIf
	EndFor
	
	// Ask the user which version and integration they'd like to plot:
	NVAR ccount = root:Packages:VisualAge:ConcordiaCount
	String ConcVersion = "Final"
	String ConcInteg = MatrixName
	String ConcName = "Conc" + num2str(ccount) // Defaults to "Conc" + the conc counter value
	Prompt ConcName, "Name of diagram: " 
	Prompt ConcVersion, "Which Version? ", popup, ListOfConcordiaOptions
	Prompt ConcInteg, "Which Integration? ", popup, GetListOfUsefulIntegrations()
	
	// Ensure that the name given doesn't conflict with a built in Igor Pro name:
	Do
		DoPrompt "VisualAge Concordia", ConcName, ConcVersion, ConcInteg
		If (V_Flag)
			Return -1
		EndIf
		
		If ( CheckName(ConcName, 1) != 0 )
			DoAlert/T="VisualAge" 0, "The name you have entered is reserved in Igor Pro.  Please try a different name."
		Elseif( !AlphaNumeric(ConcName) )
			DoAlert/T="VisualAge" 0, "The name you enter must be alphanumeric (no symbols, except \"_\")" 
		EndIf
	While ( CheckName(ConcName, 1) != 0 || !AlphaNumeric(ConcName))
	
	// Ensure name starts with a letter:
	If (char2num(ConcName[0]) < 57 && char2num(ConcName[0]) > 48 )
		ConcName = "c" + ConcName
	EndIf	
	
	// Check if concordia exists:
	If (DataFolderExists("root:Packages:VisualAge:ConcordiaDiagrams:" + ConcInteg + ":" + ConcName) )
		DoAlert/T="VisualAge" 1, "A concordia diagram named " + ConcName + " for " + ConcInteg + " already exists.  Would you like to replace it?"
		If (V_flag != 1)
			Return -1
		EndIf
		
		KillWindow $ConcName
		KillDataFolder/Z root:Packages:VisualAge:ConcordiaDiagrams:$(ConcInteg):$(ConcName)
	EndIf	
	
	// Set the data folder for this concordia diagram:
	NewDataFolder/O/S root:Packages:VisualAge:ConcordiaDiagrams
	NewDataFolder/O/S $ConcInteg
	NewDataFolder/O/S $ConcName
	
	// Determine the number of integrations:
	Wave aim = $ioliteDFpath("integration", "m_" + ConcInteg)
	Variable NoOfIntegrations = DimSize(aim,0)	-1

	// Plot the concordia:
	NVAR MarkerSep = root:Packages:VisualAge:Options:ConcordiaOption_MarkerSep
	GenerateConcordia(ConcName, 0, 5e9, NoOfPoints=100000, NoOfMarkers=5e9/(MarkerSep*1e6), doTW=doTW,ConcFolder=GetDataFolder(1))
	
	Wave conX = $(ConcName + "X"), conY = $(ConcName + "Y")
	Wave conMX = $(ConcName + "MarkerX"), conMY = $(ConcName + "MarkerY")

	DoWindow/K $ConcName
	Display/N=$ConcName/K=1

	AppendToGraph conY vs conX
	AppendToGraph conMY vs conMX

	// Create tags:
	For (i = 1; i < 5e9/(markerSep*1e6); i = i +1)
		String tagStr = "tag" + num2str(i)
		String tagValue = num2str(markerSep*(i)) + " Ma"
		String traceStr = ConcName + "MarkerY"
		Tag/N=$tagStr/A=RC/F=0/Z=1/I=1/B=1/X=-0.5/Y=0.5/L=0/AO=0 $traceStr, i, tagValue
	EndFor		
		
	// Set properties of concordia wave:
	ModifyGraph lStyle($(ConcName + "Y")) = 0
	ModifyGraph lSize($(ConcName + "Y")) = 1.5
	ModifyGraph rgb($(ConcName + "Y"))=(0,0,0)
	
	// Set properties for time symbols:
	ModifyGraph marker($(ConcName + "MarkerY"))=19
	ModifyGraph msize($(ConcName + "MarkerY"))=5
	ModifyGraph mode($(ConcName + "MarkerY"))=3
	ModifyGraph rgb($(ConcName + "MarkerY"))=(65000,0,0)	

	// Set general graph properties:
	ModifyGraph standoff(bottom)=0
	ModifyGraph standoff(left)=0
	ModifyGraph gFont="Helvetica",gfSize=14
	ModifyGraph width=600,height=475
	ModifyGraph mirror=2	
	
	// Set labels according to which plotting style was used:
	If (!doTW)
		Label bottom "\\S207\\MPb \\Z20/\\M \\S235\\MU"
		Label left "\\S206\\MPb \\Z20/\\M\\S238\\MU"	
	Else
		Label bottom "\\S238\\MU \\Z20/\\M \\S206\\MPb"
		Label left "\\S207\\MPb \\Z20/\\M\\S206\\MPb"	
	EndIf	

	// Add integrations to the diagram; hide if ellipse size or discordance is outside specified values:
	For (i = 1; i <= NoOfIntegrations; i = i + 1)
		String EllipseInfo = AddToConcordiaByIntegration(i, concVersion, concInteg, ConcName, doTW=doTW)
		If ( str2num(StringByKey("ErrorIsBig", EllipseInfo)) == 1 || str2num(StringByKey("DiscPercentGreaterThanCutoff", EllipseInfo)) == 1 || str2num(StringByKey("DiscPercentLessThanCutoff", EllipseInfo)) == 1)
			ModifyGraph hideTrace($StringByKey("Handle", EllipseInfo))=1		
		EndIf
	EndFor
	
	// Calculate the ConcAge:
	NVAR DoConcAge = root:Packages:VisualAge:Options:ConcordiaOption_ShowConcAge
	If (DoConcAge)
		CalculateConcAge(ConcVersion, ConcInteg, ConcFolder=GetDataFolder(1), AddToPlot=1, AddAnnotation=1, doTW=doTW)
	EndIf
	
	// Fit a line:
	NVAR FitLine = root:Packages:VisualAge:Options:ConcordiaOption_FitLine
	If (FitLine)
		ConcordiaFitLine(ConcVersion, ConcInteg, doTW)
	EndIf
	
	// Set some window data variables 
	SetDataFolder root:Packages:VisualAge:ConcordiaDiagrams:$(ConcInteg):$(ConcName)
	
	SetWindow $ConcName, userdata(CurrentTraces) = TraceNameList(ConcName, ";", 1)
	SetWindow $ConcName, userdata(PreviouslyActiveTrace) = ""
	SetWindow $ConcName, userdata(ConcName) = ConcName
	SetWindow $ConcName, userdata(ConcVersion) = ConcVersion
	SetWindow $ConcName, userdata(ConcInteg) = ConcInteg
	SetWindow $ConcName, userdata(doTW) = num2str(doTW)
	SetWindow $ConcName, userdata(ConcFolder) = "root:Packages:VisualAge:ConcordiaDiagrams:" + ConcInteg + ":" + ConcName
	SetWindow $ConcName, userdata(NameFolder)= ConcName
	SetWindow $ConcName, userdata(IntegFolder) = ConcInteg
	SetWindow $ConcName, userdata(Type) = "Concordia"
	
	// Auto scale:
	Variable DataMinX, DataMaxX, DataMinY, DataMaxY
	
	If (!doTW)
		DataMinX = GetMin(concInteg, concVersion + "207_235")
		DataMaxX = GetMax(concInteg, concVersion + "207_235")
		DataMinY = GetMin(concInteg, concVersion + "206_238")
		DataMaxY = GetMax(concInteg, concVersion + "206_238")
	Else
		DataMinX = GetMin(concInteg, concVersion + "238_206")
		DataMaxX = GetMax(concInteg, concVersion + "238_206")
		DataMinY = GetMin(concInteg, concVersion + "207_206")
		DataMaxY = GetMax(concInteg, concVersion + "207_206")
	EndIf
	
	Variable NewMinX = FloorToSig((DataMinX+DataMaxX)/2 - 2*(DataMaxX-DataMinX), 2)
	Variable NewMaxX = CeilToSig((DataMinX+DataMaxX)/2 + 2*(DataMaxX-DataMinX), 2)
	Variable NewMinY = FloorToSig((DataMinY+DataMaxY)/2 - 2*(DataMaxY-DataMinY), 2)
	Variable NewMaxY = CeilToSig((DataMinY+DataMaxY)/2 + 2*(DataMaxY-DataMinY), 2)
	
	SetAxis bottom, NewMinX, NewMaxX
	SetAxis left, NewMinY, NewMaxY
	
	// Increment concordia counter:
	ccount = ccount + 1
	
	// Set the concordia window hook function:
	SetWindow kwTopWin, hook(concHook) = ConcordiaHook
End

// The below code is useful for filled in ellipses... not currently activated.

//Menu "TracePopup", dynamic
//	"-"
//	SubMenu "Ellipse"
//		"None", ModifyEllipse()
//		"Solid", ModifyEllipse()
//		SubMenu "Color"
//			"*COLORPOP*", ModifyEllipse()
//		End
//		SubMenu "Pattern"
//			"*PATTERNPOP*", ModifyEllipse()
//		End
//	End
//End
//
//Function ModifyEllipse()
//	GetLastUserMenuInfo
//	
//	String GraphType = GetUserData(WinName(0,1), "", "Type")
//	If (cmpstr(GraphType, "Concordia") != 0)
//		Return 0
//	EndIf
//
//	If (cmpstr(S_traceName[strlen(S_traceName)-1],"b")==0)
//		S_traceName = S_traceName[0,strlen(S_traceName)-2]
//	EndIf
//	
//	Print V_flag
//	print V_value
//	print s_value
//	print S_traceName
//	
//	
//	Switch(V_flag)
//		// None selected:
//		Case 0:
//			// Remove fill:
//			If (V_value == 1)
//				ModifyGraph mode($S_traceName)=0,lsize($S_traceName)=1
//				ModifyGraph mode($(S_traceName + "b"))=0, lsize($(S_traceName + "b"))=1
//			Elseif (V_value == 2)
//				ModifyGraph rgb($S_traceName)=(0,0,0), lstyle($S_traceName)=0, lsize($S_traceName)=0
//				ModifyGraph rgb($(S_traceName +"b"))=(0,0,0), lstyle($(S_traceName + "b"))=0, lsize($(S_traceName + "b"))=0
//				ModifyGraph mode($S_traceName)=7,hbFill($S_traceName)=2,useNegPat($S_traceName)=1,toMode($S_traceName)=1					
//			EndIf
//			Break
//			
//		Case 7:
//			ModifyGraph hbFill($S_traceName)=V_value+5
//			Break
//			
//		Case 10:
//			ModifyGraph rgb($S_traceName)=(V_red,V_green,V_blue)
//			Break
//	
//	EndSwitch
//End

//------------------------------------------------------------------------
// Hook function for the concordia window that shows some age info for the nearest ellipse
//------------------------------------------------------------------------
Function ConcordiaHook(s)
	STRUCT WMWinHookStruct &s
	
	// Make sure VisualAge is initialized:
	VAInitialized()
	
	// If the concordia diagram isn't the top window, exit:
	If (CmpStr(WinName(0,1), s.winName) != 0)
		Return 0
	EndIf

	// Get required data from the graph:
	String PreviouslyActiveTrace = GetUserData(s.winName, "", "PreviouslyActiveTrace")
	String CurrentTraces = GetUserData(s.winName, "", "CurrentTraces")
	String ConcFolder = GetUserData(s.winName, "", "ConcFolder")
	String ConcVersion = GetUserData(s.winName, "", "ConcVersion")
	String ConcInteg = GetUserData(s.winName, "", "ConcInteg")
	String ConcName = GetUserData(s.winName, "", "ConcName")
	Variable doTW = str2num(GetUserData(s.winName, "", "doTW"))
	
	Wave aim = $ioliteDFpath("integration", "m_" + ConcInteg)
	Variable NoOfIntegrations = DimSize(aim,0)	 	
	
	// Main switch control:
	Switch(s.eventCode)
		// Mouse scroll event:
		Case 22:
			GetAxis/W=$s.winname/Q Bottom
			Variable cMinx = V_min
			Variable cMaxx = V_max
			GetAxis/W=$s.winname/Q Left
			Variable cMiny = V_min
			Variable cMaxy = V_max
			
			Variable cMeanx = (cMinx+cMaxx)/2
			Variable cMeany = (cMiny+cMaxy)/2
			
			Variable axisScaler =s.wheelDy/50
			
			Variable nMinx = cMinx + (cMeanx-cMinx)*axisScaler
			Variable nMaxx = cMaxx - (cMaxx-cMeanx)*axisScaler
			Variable nMiny = cMiny + (cMeany-cMiny)*axisScaler
			Variable nMaxy = cMaxy - (cMaxy-cMeany)*axisScaler
			
			If ( (s.eventMod & 8) == 8 || s.eventMod == 0)
				SetAxis/W=$s.winname Bottom, nMinx, nMaxx
			EndIf
			
			If ( (s.eventMod & 4) == 4 || s.eventMod == 0)
				SetAxis/W=$s.winname Left, nMiny, nMaxy
			EndIf
			Break
			
		// Key pressed event:
		Case 11:  
			// Switch depending on which key was pressed:
			Switch (s.keycode)
				// r pressed:
				Case 114:
					// Auto scale the diagram:
					Variable DataMinX, DataMaxX, DataMinY, DataMaxY
					
					If (!doTW)
						DataMinX = GetMin(concInteg, concVersion + "207_235")
						DataMaxX = GetMax(concInteg, concVersion + "207_235")
						DataMinY = GetMin(concInteg, concVersion + "206_238")
						DataMaxY = GetMax(concInteg, concVersion + "206_238")
					Else
						DataMinX = GetMin(concInteg, concVersion + "238_206")
						DataMaxX = GetMax(concInteg, concVersion + "238_206")
						DataMinY = GetMin(concInteg, concVersion + "207_206")
						DataMaxY = GetMax(concInteg, concVersion + "207_206")
					EndIf
					
					Variable NewMinX = FloorToSig((DataMinX+DataMaxX)/2 - 2*(DataMaxX-DataMinX), 2)
					Variable NewMaxX = CeilToSig((DataMinX+DataMaxX)/2 + 2*(DataMaxX-DataMinX), 2)
					Variable NewMinY = FloorToSig((DataMinY+DataMaxY)/2 - 2*(DataMaxY-DataMinY), 2)
					Variable NewMaxY = CeilToSig((DataMinY+DataMaxY)/2 + 2*(DataMaxY-DataMinY), 2)
					
					SetAxis bottom, NewMinX, NewMaxX
					SetAxis left, NewMinY, NewMaxY				
					Break
					
				// z pressed:
				Case 122:
					// Draw a contour on the diagram:
					If ( FindListItem("ContourData", ContourNameList(s.winname, ";")) == -1)
						// Add contour if it isn't already there:
						KillWaves/Z ContourData, ContourX, ContourY
						
						If (!doTW)
							Wave xwave = $ioliteDFpath("CurrentDRS", ConcVersion + "207_235")
							Wave ywave = $ioliteDFpath("CurrentDRS", ConcVersion + "206_238")
						Else
							Wave xwave = $ioliteDFpath("CurrentDRS", ConcVersion + "238_206")
							Wave ywave = $ioliteDFpath("CurrentDRS", ConcVersion + "207_206")
						EndIf
						Wave Index_Time = $ioliteDFpath("CurrentDRS", "Index_Time")
					
						Variable startTime, stopTime
						Variable startIndex, stopIndex
						Variable Nbins = 100
						
						GetAxis/W=$s.winname/Q Bottom
						Variable MinX = V_min
						Variable MaxX = V_max
						GetAxis/W=$s.winname/Q Left
						Variable MinY = V_min
						Variable MaxY = V_max
						
						Make/O/N=(Nbins,Nbins) ContourData
						Make/O/N=(Nbins) ContourX, ContourY
						Variable StartX = MinX,  StopX = MaxX, BinX = (StopX-StartX)/Nbins
						Variable StartY = MinY,  StopY = MaxY, BinY = (StopY-StartY)/Nbins
					
						Variable i
						For ( i = 0; i < Nbins; i = i + 1)
							ContourX[i] = (i )*BinX + StartX
							ContourY[i] = (i )*BinY + StartY
						EndFor
					
						// Fill data matrix:
						For ( i = 1; i <= NoOfIntegrations; i = i + 1)
						
							startTime = aim[i][0][%$"Median Time"]-aim[i][0][%$"Time Range"]
							stopTime = aim[i][0][%$"Median Time"]+aim[i][0][%$"Time Range"]
						
							startIndex = ForBinarySearch(Index_Time, startTime) + 1
							If (numtype(Index_Time[startIndex]) == 2)
								startIndex += 1
							EndIf
						
							stopIndex = ForBinarySearch(Index_Time, stopTime)
							If (stopIndex == -2)
								stopIndex = numpnts(Index_Time) - 1
							EndIf
					
							Variable j
							For ( j = startIndex; j < stopIndex; j = j + 1)
								Variable cx = xwave[j]
								Variable cy = ywave[j]
					
								Variable ix = (cx-StartX)/BinX
								Variable iy = (cy-StartY)/BinY
								
								if (numtype(ix) == 2 || numtype(iy) == 2 || ix < 0 || iy < 0 || ix > Nbins || iy > Nbins)
									continue
								endif
					
								ContourData[ix][iy] = ContourData[ix][iy] + 1
							EndFor
						EndFor
						
						// Append + modify contour:
						AppendMatrixContour ContourData vs {ContourX, ContourY}	
						ModifyContour ContourData update=1,labels=0,autoLevels={*,*,100}, ctabLines={*,*,Rainbow,1}
					Else
						// Remove the contour if it is already there:
						RemoveContour/W=$s.winname ContourData	
					EndIf		
					Break
					
				// a pressed:
				Case 97:
					// Add the individual data points to the graph:
					If (FindListItem("ywave", TraceNameList(s.winname, ";", 1)) == -1)
						// Add points to graph if they aren't already there:
						KillWaves/Z $(ConcFolder + ":ywave"), $(ConcFolder + ":xwave")					
						If (!doTW)
							Duplicate root:Packages:iolite:output:VisualAgeDRS:$(ConcVersion + "206_238"), $(ConcFolder + ":ywave")
							Duplicate root:Packages:iolite:output:VisualAgeDRS:$(ConcVersion + "207_235"), $(ConcFolder + ":xwave")
						Else						
							Duplicate root:Packages:iolite:output:VisualAgeDRS:$(ConcVersion + "207_206"), $(ConcFolder + ":ywave")
							Duplicate root:Packages:iolite:output:VisualAgeDRS:$(ConcVersion + "238_206"), $(ConcFolder + ":xwave")
						EndIf
						
						Wave xwave = $(ConcFolder + ":xwave")
						Wave ywave = $(ConcFolder + ":ywave")
						
						GenerateIntegrationIndex(ConcFolder)
						Wave IntInd = $(ConcFolder + ":IntInd")
						Variable Cind = GetIntInd(ConcInteg)
						
						Variable xi
						For (xi = 0; xi < numpnts(xwave); xi = xi + 1)
							If ( numtype(xwave[xi]) == 2 )
								Continue
							EndIf
							
							// Note: doing bitwise comparison here...
							If ((IntInd[xi] & Cind) != CInd)
								xwave[xi] = Nan
								ywave[xi] = Nan
							EndIf
						EndFor
						
						AppendToGraph $(ConcFolder + ":ywave") vs $(ConcFolder + ":xwave")
						ModifyGraph mode(ywave)=2
						ModifyGraph rgb(ywave)=(0,0,0)
					Else
						// Remove points from graph if already there:
						RemoveFromGraph/W=$s.winname/Z ywave
						KillWaves $(ConcFolder + ":ywave"), $(ConcFolder + ":xwave")
					EndIf
					Break
			
				// d or D pressed:
				Case 100:
				Case 68:
					NVAR FitLine = root:Packages:VisualAge:Options:ConcordiaOption_FitLine			
					NVAR ThroughZero = root:Packages:VisualAge:Options:ConcordiaOption_ThroughZero
									
					// Check if fit is already on the graph:
					If (FindListItem("fit_yWave", TraceNameList(s.winname, ";", 1)) == -1)
						// If not on the graph, add a fit:
						FitLine = 1
						If (s.eventMod == 2)
							// If shift is down, force through zero:
							ThroughZero = 1
							ConcordiaFitLine(ConcVersion, ConcInteg, doTW, anchor=1)
						Else
							// Otherwise, do a free fit:
							ThroughZero = 0
							ConcordiaFitLine(ConcVersion, ConcInteg, doTW)
						EndIf
					Else
						// If a fit is already on the graph, remove it:	
						FitLine = 0
						RemoveFromGraph/W=$s.winname/Z fit_yWave
						TextBox/K/N=InterceptAgeText
					EndIf					
					Break
					
				// c pressed:
				Case 99: 			
					NVAR DoConcAge = root:Packages:VisualAge:Options:ConcordiaOption_ShowConcAge				

					// Check if ConcAge is already on the graph:
					If (FindListItem("WtdMeany", TraceNameList(s.winname, ";", 1)) == -1)
						// If not, calculate + add:
						DoConcAge = 1
						CalculateConcAge(ConcVersion, ConcInteg, ConcFolder=ConcFolder, AddToPlot=1, AddAnnotation=1, doTW=doTW)
					Else
						// If yes, remove it:
						DoConcAge = 0
						RemoveFromGraph/W=$s.winname/Z WtdMeany
						TextBox/K/N=ConcAgeText
					EndIf
					Break
			EndSwitch
			
			// Tell Igor we've handled the keypress event:
			Return 1
			
		// Graph modified event:
		Case 8: 
			// Check if we want to delete integrations when they're removed from a diagram:
			NVAR RemoveIntegrations = root:Packages:VisualAge:Options:ConcordiaOption_RemoveIntegs
			If (!RemoveIntegrations)
				Return 0
			EndIf
			
			// Determine if any waves have been removed:
			String NewTraces = TraceNameList(s.winName,";",1)
			String RemovedTraces = CurrentTraces

			For (i = 0; i < ItemsInList(NewTraces); i = i + 1)
				RemovedTraces=RemoveFromList(StringFromList(i, NewTraces), RemovedTraces)
			EndFor
			
			CurrentTraces = NewTraces
			SetWindow $ConcName, userdata(CurrentTraces) = CurrentTraces			

			// Remove integrations:
			For (i = 0; i < ItemsInList(RemovedTraces); i = i + 1)
				// Integration traces are of the form "Int#y" where # is the integration number
				String CurrentInt = StringFromList(i, RemovedTraces)
				
				// Make sure it was an ellipse:
				If (StrSearch(CurrentInt, "Int", 0) == -1)
					Return 0
				EndIf
				
				// Extra the number from the string
				Variable IntegNum = str2num(CurrentInt[3, strlen(CurrentInt)-2])
				
				RemoveIntegrationByIndex(ConcInteg, IntegNum)
			EndFor
			
			// Replot integrations:
			If ( ItemsInList(RemovedTraces) > 0)
				// Remove all integration ellipses:
				For (i=0; i < ItemsInList(NewTraces); i = i + 1)
					String TraceToRemove = StringFromList(i, NewTraces)
					If ( StrSearch(TraceToRemove, "Int", 0) != -1 )
						RemoveFromGraph/Z $TraceToRemove
					EndIf
				EndFor
				
				// Replot integrations:				
				For (i = 1; i <= NoOfIntegrations; i = i + 1)
					String EllipseInfo = AddToConcordiaByIntegration(i, ConcVersion, ConcInteg, s.winName, doTW=doTW)
					If ( str2num(StringByKey("ErrorIsBig", EllipseInfo)) == 1 || str2num(StringByKey("DiscPercentGreaterThanCutoff", EllipseInfo)) == 1 || str2num(StringByKey("DiscPercentLessThanCutoff", EllipseInfo)) == 1)
						ModifyGraph hideTrace($StringByKey("Handle", EllipseInfo))=1		
					EndIf
					
					CurrentTraces = TraceNameList(s.winName, ";", 1)
					SetWindow $ConcName, userdata(CurrentTraces) = CurrentTraces
				EndFor	
				
				
				// Recalculate ConcAge if desired:
				NVAR DoConcAge = root:Packages:VisualAge:Options:ConcordiaOption_ShowConcAge
				If ( DoConcAge )
					CalculateConcAge(ConcVersion, ConcInteg, ConcFolder=ConcFolder, AddToPlot=1, AddAnnotation=1, doTW=doTW)
				EndIf
				
				// Recalculate the fit if desired:
				NVAR FitLine = root:Packages:VisualAge:Options:ConcordiaOption_FitLine
				If ( FitLine )
					ConcordiaFitLine(ConcVersion, ConcInteg, doTW)
				EndIf
			EndIf
			
			// Tell Igor we've handled the event:
			Return 1
		// Mouse moved event:
		Case 4: 
			// Update the info annotation if desired:
			NVAR ShowInfoOption = root:Packages:VisualAge:Options:ConcordiaOption_ShowInfo
			If (ShowInfoOption)
				
				// Determine which trace is closest to the mouse:
				String ActiveTraceInfo = TraceFromPixel(s.mouseLoc.h, s.mouseLoc.v,"")
				String ActiveTrace = StringByKey("TRACE", activeTraceInfo)
				
				// If the trace isn't an ellipse then return:
				If (StrSearch(ActiveTrace, "Int", 0) == -1)
					Return 1
				EndIf
			
				// Determine the integration number of the trace:
				Variable IntegrationNo = str2num(ActiveTrace[3, strlen(ActiveTrace)-2])
				
				// Change ellipse color to indicate which is active:
				ModifyGraph/Z rgb($PreviouslyActiveTrace)=(0,0,0)
				ModifyGraph/Z rgb($ActiveTrace)=(65535,0,0)
				
				PreviouslyActiveTrace = ActiveTrace
				SetWindow $ConcName, userdata(PreviouslyActiveTrace) = PreviouslyActiveTrace
			
				// Contruct annotation:
				Wave/T IntLabels = $ioliteDFpath("integration", "IntegNoLabels")
		
				String AgeStr = ConcVersion[0,4] + "Age" + ConcVersion[5,inf]
			
				Variable a68, s68, a75, s75, a82, s82, a76, s76
				Variable aavg, savg, asd2, asd3, asd4
				Variable gval = 60000
				String info = ""

				Wave ResultWave = $MakeioliteWave("CurrentDRS", "ResultWave", n = 2)

				// Get age and uncert for all uncorrected ages:
				GetIntegrationFromIolite(AgeStr + "206_238", ConcInteg, IntegrationNo, "ResultWave")
				a68 = ResultWave[0]
				s68 = ResultWave[1]
		
				GetIntegrationFromIolite(AgeStr + "207_235", ConcInteg, IntegrationNo, "ResultWave")
				a75 = ResultWave[0]
				s75 = ResultWave[1]			

				GetIntegrationFromIolite(AgeStr + "208_232", ConcInteg, IntegrationNo, "ResultWave")
				a82 = ResultWave[0]
				s82 = ResultWave[1]

				GetIntegrationFromIolite(AgeStr + "207_206", ConcInteg, IntegrationNo, "ResultWave")
				a76 = ResultWave[0]
				s76 = ResultWave[1]

				// Do some tests on ages + uncerts to color the ages according to how well they agree:
				aavg = (a68+a75)/2
				savg = sqrt(s68^2 + s75^2)
				asd4 = sqrt( ( (a68-aavg)^2 + (a75-aavg)^2 + (a82-aavg)^2 + (a76-aavg)^2 )/4 )
				asd3 = sqrt( ( (a68-aavg)^2 + (a75-aavg)^2 + (a82-aavg)^2 )/3 )
				asd2 = sqrt( ( (a68-aavg)^2 + (a75-aavg)^2)/2)

				If ( abs(a68-aavg) < (s68+savg) )
					gval = 60000*(2/asd2)
					If (gval > 60000)
						gval = 60000
					EndIf
					Info += "\K(0," + num2str(gval) +",0)"
				EndIf
				info += "\f00\M\S206\MPb/\S238\MU Age = " + num2str(a68) + " ± " + num2str(s68)+ "\r\K(0,0,0)"			
				If ( abs(a75-aavg) < (s75+savg) )
					gval = 60000*(2/asd2)
					If (gval > 60000)
						gval = 60000
					EndIf			
					Info += "\K(0," + num2str(gval) +",0)"
				EndIf
				info += "\f00\M\S207\MPb/\S235\MU Age = " + num2str(a75) + " ± " + num2str(s75)+ "\r\K(0,0,0)"
				If ( abs(a82-aavg) < (s82+savg))
					gval = 60000*(2/asd3)
					If (gval > 60000)
						gval = 60000
					EndIf			
					Info += "\K(0," + num2str(gval) +",0)"
					aavg = (a68+a75+a82)/3
					savg = sqrt(s68^2 + s75^2 + s82^2)
				EndIf
				info += "\f00\M\S208\MPb/\S232\MTh Age = " + num2str(a82) + " ± " + num2str(s82)+ "\r\K(0,0,0)"
				If ( abs(a76-aavg) < (s76+savg) )
					gval = 60000*(2/asd4)
					If (gval > 60000)
						gval = 60000
					EndIf			
					Info += "\K(0," + num2str(gval) +",0)"
				EndIf
				info += "\f00\M\S207\MPb/\S206\MPb Age = " + num2str(a76) + " ± " + num2str(s76)+ "\K(0,0,0)"
			
				Wave/T IntLabels = $ioliteDFpath("integration", "IntegNoLabels")
				info[0] = "\f04\Z18Integration: " + IntLabels[IntegrationNo] + "\r"					
						
				TextBox/C/N=ActiveIntBox/B=1/A=RB info
			EndIf
			Return 1
		// Window killed event:
		Case 2: 
			// Remove traces from graph:
			If ( FindListItem("ContourData", ContourNameList(s.winname, ";")) != -1)
				RemoveContour ContourData
			EndIf
			String ConcordiaTraces = TraceNameList(s.winName, ";", 3)
			For (i = 0; i < ItemsInList(ConcordiaTraces); i = i + 1)
				RemoveFromGraph $StringFromList(i, ConcordiaTraces)
			EndFor
			
			// Delete data for this window:
			KillDataFolder $ConcFolder
			Break			
	EndSwitch
	
	Return 0
End

//------------------------------------------------------------------------
// Fit a line through the data and find where it intersects the concordia
//------------------------------------------------------------------------
Function ConcordiaFitLine(ConcVersion, ConcInteg, doTW, [anchor, plotwindow])
	Variable doTW, anchor
	String ConcVersion, ConcInteg, plotwindow
	
	// Make sure VisualAge is initialized:
	VAInitialized()

	// Get options:
	NVAR doFitLine = root:Packages:VisualAge:Options:ConcordiaOption_FitLine
	NVAR forceZero = root:Packages:VisualAge:Options:ConcordiaOption_ThroughZero
	
	If (ParamIsDefault(anchor))
		anchor = forceZero
	EndIf
	
	String WorkingDF = ""
	
	If (ParamIsDefault(plotwindow))
		plotwindow=""
		WorkingDF = GetUserData(WinName(0,1), "", "ConcFolder")
	Else
		WorkingDF = GetUserData(plotwindow, "", "ConcFolder")
	EndIf
	
	SetDataFolder WorkingDF

	// Get some stuff from Iolite:
	String MatrixName = GetMatrixName()
	Wave aim = $ioliteDFpath("integration", "m_" + ConcInteg)
	Variable NoOfIntegrations = DimSize(aim,0) - 1

	Make/O/D/N=(NoOfIntegrations) yfWave, xfWave, yfeWave, xfeWave
	Wave ResultWave = $MakeioliteWave("CurrentDRS", "ResultWave", n = NoOfIntegrations)
	
	Variable i
	For ( i = 1; i <= NoOfIntegrations; i = i + 1 )
		If (!doTW)
			xfWave[i-1] = GetIntegrationFromIolite(ConcVersion+"207_235", ConcInteg, i, "ResultWave")
			xfeWave[i-1] = ResultWave[1]/2
			yfWave[i-1] = GetIntegrationFromIolite(ConcVersion+"206_238", ConcInteg, i, "ResultWave")
			yfeWave[i-1] = ResultWave[1]/2
		Else
			xfWave[i-1] = GetIntegrationFromIolite(ConcVersion+"238_206", ConcInteg, i, "ResultWave")
			xfeWave[i-1] = ResultWave[1]/2
			yfWave[i-1] = GetIntegrationFromIolite(ConcVersion+"207_206", ConcInteg, i, "ResultWave")
			yfeWave[i-1] = ResultWave[1]/2
		EndIf
	EndFor

	// Fit the data to a line:
	Make/O/D/N=2 fit_yWave, fit_xWave, fit_coefs	, W_sigma
	
	If (anchor)
		// To force through zero:
		fit_coefs[0] = 0
		CurveFit/ODR=2/H="10"/X=1/NTHR=0 line kwCWave=fit_coefs yfWave /X=xfWave /D/W=yfeWave /XW=xfeWave/I=1
	Else
		// To fit without constraints:
		CurveFit/ODR=2/X=1/NTHR=0 line kwCWave=fit_coefs yfWave /X=xfWave /D/W=yfeWave /XW=xfeWave/I=1
		//CurveFit/ODR=2 line, yfWave/X=xfWave/D/W=yfeWave/XW=xfeWave/I=1
	EndIf
	
	// Fill the waves to plot: 
	If (!doTW)
		fit_xWave[0] = 0
		fit_xWave[1] = 40
		fit_yWave[0] = fit_coefs[0] + fit_coefs[1]*0
		fit_yWave[1] = fit_coefs[0] + fit_coefs[1]*40			
	Else
		fit_xWave[0] = 0
		fit_xWave[1] = 7000
		fit_yWave[0] = fit_coefs[0] + fit_coefs[1]*0
		fit_yWave[1] = fit_coefs[0] + fit_coefs[1]*7000		
	EndIf
		
	RemoveFromGraph/W=$plotwindow/Z fit_yWave
	AppendToGraph/W=$plotwindow fit_yWave vs fit_xWave
			
	// Solve for intercepts:
	Variable UpperInterceptAge, LowerInterceptAge, UpperPlusError, UpperMinusError, LowerPlusError, LowerMinusError
	If (doTW)
		UpperInterceptAge = SolveTWConcordiaLine(fit_coefs[1], fit_coefs[0], 0.1)
		UpperPlusError = UpperInterceptAge - SolveTWConcordiaLine(fit_coefs[1] + W_sigma[1], fit_coefs[0] - W_sigma[0], 0.1)
		UpperMinusError = SolveTWConcordiaLine(fit_coefs[1] - W_sigma[1], fit_coefs[0] + W_sigma[0], 0.1) - UpperInterceptAge		
		
		LowerInterceptAge = SolveTWConcordiaLine(fit_coefs[1], fit_coefs[0], 50)
		LowerPlusError = LowerInterceptAge - SolveTWConcordiaLine(fit_coefs[1] + W_sigma[1], fit_coefs[0] - W_sigma[0], 50)
		LowerMinusError = SolveTWConcordiaLine(fit_coefs[1] - W_sigma[1], fit_coefs[0] + W_sigma[0], 50) - LowerInterceptAge		
	Else
		UpperInterceptAge = SolveConcordiaLine(fit_coefs[1], fit_coefs[0], 4.5e9)
		UpperPlusError = UpperInterceptAge - SolveConcordiaLine(fit_coefs[1] + W_sigma[1], fit_coefs[0] - W_sigma[0], 4.5e9)
		UpperMinusError = SolveConcordiaLine(fit_coefs[1] - W_sigma[1], fit_coefs[0] + W_sigma[0], 4.5e9) - UpperInterceptAge
		
		LowerInterceptAge = SolveConcordiaLine(fit_coefs[1], fit_coefs[0], 0)
		LowerPlusError = LowerInterceptAge - SolveConcordiaLine(fit_coefs[1] + W_sigma[1], fit_coefs[0] - W_sigma[0], 0)
		LowerMinusError = SolveConcordiaLine(fit_coefs[1] - W_sigma[1], fit_coefs[0] + W_sigma[0], 0) - LowerInterceptAge
				
	EndIf
	
	// Add annotation:
	String InterceptStr = ""
	If (numtype(UpperInterceptAge) !=2)
		// Note: not dividing by 2 because I want 2s.e.
		InterceptStr += "Upper Intercept = " + num2str(UpperInterceptAge) + " ± " + num2str((UpperPlusError+UpperMinusError)) + " Ma"
	EndIf
	If (numtype(LowerInterceptAge) !=2)
		If (numtype(UpperInterceptAge) !=2)
			InterceptStr += "\r"
		EndIf
		// Note: not dividing by 2 because I want 2s.e.		
		InterceptStr += "Lower Intercept = " + num2str(LowerInterceptAge) + " ± " + num2str((LowerPlusError+LowerMinusError)) +  " Ma"
	EndIf
	If ( numtype(UpperInterceptAge) == 2 && numtype(LowerInterceptAge) == 2)
		InterceptStr += "Couldn't find intercepts"
	EndIf

	TextBox/W=$plotwindow/C/N=interceptAgeText InterceptStr
		
	// Kill unneeded data:
	//KillWaves xfWave, yfWave, xfeWave, yfeWave
End

//########################################################
// Live concordia related functions
//########################################################

//------------------------------------------------------------------------
// Starts the live concordia window and updating process
//------------------------------------------------------------------------
Function LiveConcordia()

	// Make sure VisualAge is initialized:
	VAInitialized()
	
	String PreviousDF = GetDataFolder(1)
		
	// Check if a live concordia window is already open somewhere:
	DoWindow/F LiveConcordiaPanel
	If (V_flag == 1)
		DoAlert/T="VisualAge" 1, "A live concordia diagram already seems to be running.  Would you like to kill it and restart?"
		If (V_flag == 2)
			Return -1
		EndIf
		
		KillWindow LiveConcordiaPanel
	EndIf
	
	// Kill all previous live conc data and start fresh:
	KillDataFolder/Z root:Packages:VisualAge:LiveConcordia
	NewDataFolder/O/S root:Packages:VisualAge:LiveConcordia
	Variable/G PreviousLiveIntNum = 0
	Variable/G PreviousLiveStartIndex = 0
	Variable/G PreviousLiveStopIndex = 0		

	// Use the currently selected active integration:
	String MatrixName = GetMatrixName()
	Wave aim = $ioliteDFpath("integration", "m_" + MatrixName)
	Variable NoOfIntegrations = DimSize(aim,0)	 - 1
	
	// Kill any previous live concordia data:
	KillWaves/Z ccUX, ccUY, ccAX, ccAY, cc204X, cc204Y,ccEUX, ccEUY, ccEAX, ccEAY, ccE204X, ccE204Y
	
	// Generate concordia and add to diagram:
	NVAR markerSep = root:Packages:VisualAge:Options:LiveOption_MarkerSep
	NVAR doTW = root:Packages:VisualAge:Options:LiveOption_TW
	GenerateConcordia("LiveConc", 0, 5e9, NoOfPoints=10000, NoOfMarkers=5e9/(markerSep*1e6), doTW=doTW, ConcFolder="root:Packages:VisualAge:LiveConcordia")
	
	Wave conX = $("LiveConcX"), conY = $("LiveConcY")
	Wave conMX = $("LiveConcMarkerX"), conMY = $("LiveConcMarkerY")
	
	// Get some info about the screen geom. so that the window can be centered:
	String IgorInfoStr=IgorInfo(0)
	Variable scr0 = strsearch(IgorInfoStr,"RECT",0)
	Variable scr1 = strsearch(IgorInfoStr,",",scr0+9)
	Variable scr2 = strlen(IgorInfoStr)-2
	Variable screenWidth = str2num(IgorInfoStr[scr0+9,scr1-1])
	Variable screenHeight = str2num(IgorInfoStr[scr1+1,scr2])
	
	Variable panelWidth = 735
	Variable panelHeight = 543

	// Create the panel so it floats on top of other windows:
	NewPanel/FLT/N=LiveConcordiaPanel/K=1/W=(screenWidth/2-panelWidth/2,screenHeight/2-panelHeight/2,screenWidth/2+panelWidth/2,screenHeight/2+panelHeight/2)
	SetActiveSubwindow _endfloat_
	ModifyPanel/W=LiveConcordiaPanel fixedSize=0
	
	// Add graph to panel:
	Display/N=Live_Concordia/HOST=LiveConcordiaPanel/FG=(FL,FT,FR,FB) conY vs conX
//	Display/N=Live_Concordia conY vs conX
	AppendToGraph conMY vs conMX

	// Create tags:
	Variable i
	For (i = 1; i < 5e9/(markerSep*1e6); i = i +1)
		String tagStr = "tag" + num2str(i)
		String tagValue = num2str(markerSep*i) + " Ma"
		Tag/N=$tagStr/A=RC/F=0/Z=1/I=1/B=1/X=-0.5/Y=0.5/L=0/AO=0 liveConcMarkerY, i, tagValue
	EndFor
	
	// Generate waves for live concordia data:
	NVAR nPPE = root:Packages:VisualAge:Options:LiveOption_PPE
	Make/O/N=1 ccUX, ccUY, ccAX, ccAY, cc204X, cc204Y
	Make/O/N=(nPPE) ccEUX, ccEUY, ccEAX, ccEAY, ccE204X, ccE204Y
	
	// Add to diagram:
	AppendToGraph ccEUY vs ccEUX
	AppendToGraph ccEAY vs ccEAX
	AppendToGraph ccE204Y vs ccE204X

	// Set appearance of traces:	
	ModifyGraph lsize[0]=1.5,rgb[0]=(0,0,0) 
	ModifyGraph mode[1]=3, marker[1]=19, msize[1]=5
	ModifyGraph mode(ccEUY)=3,marker(ccEUY)=5,rgb(ccEUY)=(0,0,65535), mode(ccEUY) =0, lsize(ccEUY)=2
	ModifyGraph mode(ccEAY)=3,marker(ccEAY)=5,rgb(ccEAY)=(0,65535,0), mode(ccEAY) = 0, lsize(ccEAY)=2
	ModifyGraph mode(ccE204Y)=3,marker(ccE204Y)=5,rgb(ccE204Y)=(65535,0,0), mode(ccE204Y) = 0, lsize(ccE204Y)=2
	
	// Set graph properties:
	ModifyGraph width=595.276,height=453.543
	SetAxis left 0,0.8
	SetAxis bottom 0,20
	ModifyGraph standoff=0
	ModifyGraph gFont="Helvetica",gfSize=18
	ModifyGraph mirror=2
	
	// Label axes according to which plot we're making:
	NVAR doTW = root:Packages:VisualAge:Options:LiveOption_TW
	If (!doTW)
		Label left "\\S206\\MPb \\Z28/\\M \\S238\\MU"
		Label bottom "\\S207\\MPb \\Z28/\\M \\S235\\MU"	
	Else
		Label left "\\S207\\MPb \\Z28/\\M \\S206\\MPb"
		Label bottom "\\S238\\MU \\Z28/\\M \\S206\\MPb"
	EndIf
	
	// Add all integrations if desired:
	NVAR ShowAllInts = root:Packages:VisualAge:Options:LiveOption_ShowAllIntegrations
	If (ShowAllInts)
		For (i = 1; i <= NoOfIntegrations; i = i + 1)
			String EllipseInfo = AddToConcordiaByIntegration(i, "Final", MatrixName, "LiveConcordiaPanel#Live_Concordia", doTW=doTW, ConcFolder="root:Packages:VisualAge:LiveConcordia")
			String EllipseHandle = StringByKey("Handle", EllipseInfo)
			ModifyGraph/W=LiveConcordiaPanel#Live_Concordia lstyle($EllipseHandle)=1
		EndFor
	EndIf
	
	// Add a legend:
	Legend/C/N=lcLegend/J/F=0/A=LT "\\s(ccEUY) No correction\r\\s(ccE204Y) 204Pb correction\r\\s(ccEAY) Andersen correction"	
	
	// Set the background process and start it:
	NVAR numTicks = root:Packages:VisualAge:Options:LiveOption_UpdateInterval
	CtrlNamedBackground LiveTask, dialogsOK=1, period=(numTicks), proc=LiveConcordiaUpdate
	CtrlNamedBackground LiveTask, start
	
	// Set the window hook function:
	SetWindow LiveConcordiaPanel, hook(ConcordiaUpdateHook)=LiveConcordiaHook
	
	NVAR PrevIntNum = root:Packages:VisualAge:LiveConcordia:PreviousLiveIntNum
	PrevIntNum = -1
	SetActiveSubwindow _endfloat_
End

//------------------------------------------------------------------------
// Window hook function to stop the concordia updating background routine and stuff
//------------------------------------------------------------------------
Function LiveConcordiaHook(s)
	STRUCT WMWinHookStruct &s
	
	// Make sure VisualAge is initialized:
	VAInitialized()
	
	// Main hook switch:
	Switch (s.eventCode)
		// Mouse scroll event:
		Case 22:
			GetAxis/W=$s.winname/Q Bottom
			Variable cMinx = V_min
			Variable cMaxx = V_max
			GetAxis/W=$s.winname/Q Left
			Variable cMiny = V_min
			Variable cMaxy = V_max
			
			Variable cMeanx = (cMinx+cMaxx)/2
			Variable cMeany = (cMiny+cMaxy)/2
			
			Variable axisScaler =s.wheelDy/50
			
			Variable nMinx = cMinx + (cMeanx-cMinx)*axisScaler
			Variable nMaxx = cMaxx - (cMaxx-cMeanx)*axisScaler
			Variable nMiny = cMiny + (cMeany-cMiny)*axisScaler
			Variable nMaxy = cMaxy - (cMaxy-cMeany)*axisScaler
			
			If ( (s.eventMod & 8) == 8 || s.eventMod == 0)
				SetAxis/W=$s.winname Bottom, nMinx, nMaxx
			EndIf
			
			If ( (s.eventMod & 4) == 4 || s.eventMod == 0)
				SetAxis/W=$s.winname Left, nMiny, nMaxy
			EndIf
			
			Break
				
		// Window killed event:
		Case 2:
			// Stop the background process when the window is closed:
			CtrlNamedBackground LiveTask, stop
			Break
	EndSwitch

	// Do not maintain focus on the live conc window:
	SetActiveSubwindow _endfloat_
	Return 0
End

//------------------------------------------------------------------------
// Fits the live concordia window to the current set of data
//------------------------------------------------------------------------
Function FitLiveConcordiaWindow()

	// Make sure VisualAge is initialized:
	VAInitialized()

	// Get wave references:
	Wave ccEUX = $"ccEUX", ccEUY=$"ccEUY", ccEAX=$"ccEAX", ccEAY=$"ccEAY", ccE204X=$"ccE204X",ccE204Y=$"ccE204Y"
	
	// Determine the extent of the concordia data:
	Variable uxmax = WaveMax(ccEUX)
	Variable uxmin = WaveMin(ccEUX)
	Variable uymax = WaveMax(ccEUY)
	Variable uymin = WaveMin(ccEUY)

	Variable axmax = WaveMax(ccEAX)
	Variable axmin = WaveMin(ccEAX)
	Variable aymax = WaveMax(ccEAY)
	Variable aymin = WaveMin(ccEAY)
	
	// Try to avoid NaNs:
	If (numtype(axmax) == 2)
		axmax = uxmax
	EndIf
	
	If (numtype(aymax) == 2)
		aymax = uymax
	EndIf
	
	If (numtype(axmin) == 2)
		axmin = uxmin
	EndIf
	
	If(numtype(aymin)==2)
		aymin = uymin
	EndIf
		
	Variable xmax = max(uxmax, axmax)
	Variable ymax = max(uymax, aymax)
	Variable xmin = min(uxmin, axmin)
	Variable ymin = min(uymin, aymin)

	// Calculate a reasonable range:
	Variable xmax2 = 0.5*(xmin+xmax) + 3*(xmax-xmin)
	Variable xmin2 = 0.5*(xmin+xmax) - 3*(xmax-xmin)
	Variable ymax2 = 0.5*(ymin+ymax) + 3*(ymax-ymin)
	Variable ymin2 = 0.5*(ymin+ymax) - 3*(ymax-ymin)
	
	// Set some lower limits for the axes:
	if ( xmin < 0 )
		xmin = 0
	EndIf
	
	If (ymin < 0 )
		ymin = 0
	EndIf

	// Apply the new ranges:
	SetAxis/W=LiveConcordiaPanel#Live_Concordia left ymin2, ymax2
	SetAxis/W=LiveConcordiaPanel#Live_Concordia bottom xmin2, xmax2
End

//------------------------------------------------------------------------
// Computes new values for live concordia (this is run as a background process, and is run frequently!)
// Note: must return 0 to keep the process alive
//------------------------------------------------------------------------
Function LiveConcordiaUpdate(s)
	STRUCT WMBackgroundStruct &s

	String PreviousDF = GetDataFolder(1)
	SetDataFolder root:Packages:VisualAge:LiveConcordia
	
	// Get the required Iolite waves:
	Wave Final206_204 = $ioliteDFpath("CurrentDRS", "Final206_204")
	Wave Final207_204 = $ioliteDFpath("CurrentDRS", "Final207_204")
	Wave Final207_235 = $ioliteDFpath("CurrentDRS", "Final207_235")
	Wave Final206_238 = $ioliteDFpath("CurrentDRS", "Final206_238")
	Wave FinalAnd207_235 = $ioliteDFpath("CurrentDRS", "FinalAnd207_235")
	Wave FinalAnd206_238 = $ioliteDFpath("CurrentDRS", "FinalAnd206_238")
	Wave FinalAgeAnd207_206 = $ioliteDFpath("CurrentDRS", "FinalAgeAnd207_206")
	Wave index_time = $ioliteDFpath("CurrentDRS", "Index_Time")
	Wave discTest = $ioliteDFpath("CurrentDRS", "FinalDiscPercent")

	// Get some info from Iolite:
	String MatrixName = GetMatrixName()
	Wave aim = $ioliteDFpath("integration", "m_" + MatrixName)
	Variable NoOfIntegrations = DimSize(aim,0)	 - 1
		
	// Get the required global variables:
	NVAR PreviousIntegrationNum = root:Packages:VisualAge:LiveConcordia:PreviousLiveIntNum
	NVAR PrevStartIndex = root:Packages:VisualAge:LiveConcordia:PreviousLiveStartIndex
	NVAR PrevStopIndex = root:Packages:VisualAge:LiveConcordia:PreviousLiveStopIndex

	NVAR ShowConcAge = root:Packages:VisualAge:Options:LiveOption_ShowConcAge
	NVAR Show204 = root:Packages:VisualAge:Options:LiveOption_Show204Correction
	NVAR ShowAnd = root:Packages:VisualAge:Options:LiveOption_ShowAndCorrection
	
	Variable ActiveIntNum = GetActiveIntNum()
	
	// If no active integration, exit:
	If (numtype(ActiveIntNum) == 2 || ActiveIntNum == -1)
		PreviousIntegrationNum = ActiveIntNum
		Return 0
	EndIf
	
	// Determine the current integration's range:	
	Variable StartTime = (aim[ActiveIntNum][0][0] - aim[ActiveIntNum][0][1])
	Variable StopTime= (aim[ActiveIntNum][0][0] + aim[ActiveIntNum][0][1])
	Variable StartIndex = ForBinarySearch(index_time, startTime) + 1
	Variable StopIndex = ForBinarySearch(index_time, stopTime)

	// .. and check if it has changed:
	If (StartIndex == PrevStartIndex && StopIndex == PrevStopIndex)
		// If range hasn't changed - exit, but keep background process running
		Return 0
	Endif
	
	// If showing all integrations, hide the one that is active:
	NVAR ShowAllInts = root:Packages:VisualAge:Options:LiveOption_ShowAllIntegrations
	If (ShowAllInts)
		String TraceToHide = "Int" + num2str(ActiveIntNum) + "y"
		If (FindListItem(TraceToHide,TraceNameList("LiveConcordiaPanel#Live_Concordia",";",1)) != -1)
			ModifyGraph/W=LiveConcordiaPanel#Live_Concordia hideTrace($TraceToHide)=1
		EndIf
	EndIf

	// Update the start and stop indices:
	PrevStartIndex = StartIndex
	PrevStopIndex = StopIndex
	
	// Get ellipse waves:
	Wave ccUX = $"ccUX", ccUY = $"ccUY", ccEUX = $"ccEUX", ccEUY=$"ccEUY"
	Wave ccAX = $"ccAX", ccAY = $"ccAY", ccEAX=$"ccEAX", ccEAY=$"ccEAY"
	Wave cc204X = $"cc204X", cc204Y = $"cc204Y", ccE204X=$"ccE204X",ccE204Y=$"ccE204Y"
	
	Variable sUX, sUY, sUXY, sAX, sAY, sAXY, s204X, s204Y, s204XY

	Wave ResultWave = $MakeioliteWave("CurrentDRS", "resultWave", n = 2)

	NVAR doTW = root:Packages:VisualAge:Options:LiveOption_TW
	NVAR doAndersen = root:Packages:VisualAge:Options:AndersenOption_Calculate
	NVAR do204 = root:Packages:VisualAge:Options:PbCOption_Calculate
	NVAR Was204Measured = root:Packages:VisualAge:Was204Measured
	
	
	// If the active integration is the reference standard update all integrations:
	SVAR StdName = root:Packages:iolite:output:VisualAgeDRS_globals:ReferenceStandard
//	
//	If (cmpstr(StdName, MatrixName) == 0)
//	
//		//Execute "DriftCorrectRatios()"
//		String StdIntTraces = TraceNameList("LiveConcordiaPanel#Live_Concordia", ";", 1)
//
//		Variable i
//		For (i = 0; i < ItemsInList(StdIntTraces); i = i + 1)
//			String TempStr = StringFromList(i, StdIntTraces)
//			TempStr = TempStr[0,2]
//			If ( cmpstr(TempStr, "Int") == 0)
//				RemoveFromGraph/W=LiveConcordiaPanel#Live_Concordia $StringFromList(i, StdIntTraces)
//			EndIf
//		EndFor
//		
//		// Add all integrations if desired:
//		NVAR ShowAllInts = root:Packages:VisualAge:Options:LiveOption_ShowAllIntegrations
//		If (ShowAllInts)
//			For (i = 1; i <= NoOfIntegrations; i = i + 1)
//				String EllipseInfo1 = AddToConcordiaByIntegration(i, "Final", MatrixName, "LiveConcordiaPanel#Live_Concordia", doTW=doTW, ConcFolder="root:Packages:VisualAge:LiveConcordia")
//				String EllipseHandle1 = StringByKey("Handle", EllipseInfo1)
//				ModifyGraph/W=LiveConcordiaPanel#Live_Concordia lstyle($EllipseHandle1)=1
//			EndFor
//		EndIf
//	EndIf
//	
	// Get integrated data depending on whether we're doing normal or TW concordia:
	If (!doTW)
		// Update uncorrected data:
		ccUX[0] = GetIntegrationFromIolite("Final207_235", MatrixName, ActiveIntNum, "ResultWave")
		sUX = ResultWave[1]/2
		ccUY[0] = GetIntegrationFromIolite("Final206_238", MatrixName, ActiveIntNum, "ResultWave")
		sUY = ResultWave[1]/2
		sUXY = sUX*sUY*ChannelCorrelation("Final207_235", "Final206_238", ActiveIntNum)

		If (doAndersen)
			// Update Andersen corrected data:
			ccAX[0] = GetIntegrationFromIolite("FinalAnd207_235", MatrixName, ActiveIntNum, "ResultWave")
			sAX = ResultWave[1]/2
			ccAY[0] = GetIntegrationFromIolite("FinalAnd206_238", MatrixName, ActiveIntNum, "ResultWave")
			sAY = ResultWave[1]/2
			SAXY = sAX*sAY*ChannelCorrelation("FinalAnd207_235", "FinalAnd206_238", ActiveIntNum)
		EndIf
		
		If (do204 && Was204Measured)
			// Update 204 corrected data:
			cc204X[0] = GetIntegrationFromIolite("FinalPbC207_235", MatrixName, ActiveIntNum, "ResultWave")
			s204X = ResultWave[1]/2
			cc204Y[0] = GetIntegrationFromIolite("FinalPbC206_238", MatrixName, ActiveIntNum, "ResultWave")
			s204Y = ResultWave[1]/2
			S204XY = s204X*s204Y*ChannelCorrelation("FinalPbC207_235", "FinalPbC206_238", ActiveIntNum)
		EndIf
	Else
		// Update uncorrected data:
		ccUX[0] = GetIntegrationFromIolite("Final238_206", MatrixName, ActiveIntNum, "ResultWave")
		sUX = ResultWave[1]/2
		ccUY[0] = GetIntegrationFromIolite("Final207_206", MatrixName, ActiveIntNum, "ResultWave")
		sUY = ResultWave[1]/2
		sUXY = sUX*sUY*ChannelCorrelation("Final238_206", "Final207_206", ActiveIntNum)

		If (doAndersen)
			// Update Andersen corrected data:
			ccAX[0] = GetIntegrationFromIolite("FinalAnd238_206", MatrixName, ActiveIntNum, "ResultWave")
			sAX = ResultWave[1]/2
			ccAY[0] = GetIntegrationFromIolite("FinalAnd207_206", MatrixName, ActiveIntNum, "ResultWave")
			sAY = ResultWave[1]/2
			SAXY = sAX*sAY*ChannelCorrelation("FinalAnd238_206", "FinalAnd207_206", ActiveIntNum)
		EndIf
		
		If (do204 && Was204Measured)
			// Update 204 corrected data:
			cc204X[0] = GetIntegrationFromIolite("FinalPbC238_206", MatrixName, ActiveIntNum, "ResultWave")
			s204X = ResultWave[1]/2
			cc204Y[0] = GetIntegrationFromIolite("FinalPbC207_206", MatrixName, ActiveIntNum, "ResultWave")
			s204Y = ResultWave[1]/2
			S204XY = s204X*s204Y*ChannelCorrelation("FinalPbC238_206", "FinalPbC207_206", ActiveIntNum)		
		EndIf
	EndIf

	// Calculate eigenvalues of covariance matrix:
	Variable ul1 = 2*sqrt( (sUX^2 + sUY^2 + sqrt( (sUY^2 - sUX^2)^2 + 4*sUXY^2 ) )/2)
	Variable ul2 = 2*sqrt( (sUX^2 + sUY^2 - sqrt( (sUY^2 - sUX^2)^2 + 4*sUXY^2 ) )/2)

	Variable al1 = 2*sqrt( ( sAX^2 + sAY^2 + sqrt( (sAY^2-sAX^2)^2 + 4*sAXY^2 ) )/2)
	Variable al2 = 2*sqrt( ( sAX^2 + sAY^2 - sqrt( (sAY^2-sAX^2)^2 + 4*sAXY^2 ) )/2)

	Variable v204l1 = 2*sqrt( ( s204X^2 + s204Y^2 + sqrt( (s204Y^2-s204X^2)^2 + 4*s204XY^2 ) )/2)
	Variable v204l2 = 2*sqrt( ( s204X^2 + s204Y^2 - sqrt( (s204Y^2-s204X^2)^2 + 4*s204XY^2 ) )/2)

	// Calculate the ellipse rotation angle:
	Variable uTheta = 0.5*atan( 2*sUXY/(sUX^2 - sUY^2) )	
	Variable aTheta = 0.5*atan( 2*sAXY/(sAX^2 - sAY^2) )
	Variable v204Theta = 0.5*atan( 2*s204XY/(s204X^2 - s204Y^2) )

	// Determine eigenvalue corresponding to each axis:
	Variable uxLength = 0, uyLength = 0
	Variable axLength = 0, ayLength = 0	
	Variable v204xLength = 0, v204yLength = 0
	
	If (sUX >= sUY)
		uxLength = max(ul1, ul2)
		uyLength = min(ul1, ul2)
	Else
		uxLength = min(ul1, ul2)
		uyLength = max(ul1, ul2)
	EndIf 		

	If (sAX >= sAY)
		axLength = max(al1, al2)
		ayLength = min(al1, al2)
	Else
		axLength = min(al1, al2)
		ayLength = max(al1, al2)
	EndIf 
	
	If (s204X >= s204Y)
		v204xLength = max(v204l1, v204l2)
		v204yLength = min(v204l1, v204l2)
	Else
		v204xLength = min(v204l1, v204l2)
		v204yLength = max(v204l1, v204l2)
	EndIf 			
	
	// Calculate sines and cosines of ellipse angles:
	Variable cuTheta = cos(uTheta), suTheta = sin(uTheta)
	Variable caTheta = cos(aTheta), saTheta = sin(aTheta) 
	Variable c204Theta = cos(v204Theta), s204Theta = sin(v204Theta)

	// Update live concordia ellipses:
	NVAR nPPE = root:Packages:VisualAge:Options:LiveOption_PPE
	
	Variable j
	For ( j = 0; j <= nPPE; j = j + 1)
		Variable eux = 0, euy = 0
		Variable eax = 0, eay = 0
		Variable e204x = 0, e204y = 0
		
		Variable p = 360*j/nPPE
			
		eux = uxLength*cos(p*Pi/180) 
		euy = uyLength*sin(p*Pi/180)

		eax = axLength*cos(p*Pi/180) 
		eay = ayLength*sin(p*Pi/180)

		e204x = v204xLength*cos(p*Pi/180) 
		e204y = v204yLength*sin(p*Pi/180)
						
		// Update ellipse for Andersen corrected data:
		ccEAX[j] = ccAX[0] + eax*caTheta - eay*saTheta
		ccEAY[j] = ccAY[0] + eax*saTheta + eay*caTheta
		
		// Update ellipse for 204Pb corrected data:
		ccE204X[j] = cc204X[0] + e204x*c204Theta - e204y*s204Theta
		ccE204Y[j] = cc204Y[0] + e204x*s204Theta + e204y*c204Theta		
		
		// Update ellipse for uncorrected data:
		ccEUX[j] = ccUX[0] + eux*cuTheta - euy*suTheta
		ccEUY[j] = ccUY[0] + eux*suTheta + euy*cuTheta
	EndFor
	
	// Auto-resize if necessary:
	NVAR AutoResize = root:Packages:VisualAge:Options:LiveOption_AutoResize
	If (PreviousIntegrationNum != ActiveIntNum && AutoResize)
		FitLiveConcordiaWindow()
	EndIf
	
	// Hide common Pb corrections if uncorrected is concordant to within tolerance:
	NVAR PlotCorWhen = root:Packages:VisualAge:Options:LiveOption_ShowCorrectionsWhen
	Variable d = DiscPercent(ccUX[0], ccUY[0])

	ModifyGraph/W=LiveConcordiaPanel#Live_Concordia hideTrace(ccE204Y)=1
	ModifyGraph/W=LiveConcordiaPanel#Live_Concordia hideTrace(ccEAY)=1

	If (d > PlotCorWhen)
		If (ShowAnd)
			ModifyGraph/W=LiveConcordiaPanel#Live_Concordia hideTrace(ccEAY)=0
		EndIf
		
		If (Show204)
			ModifyGraph/W=LiveConcordiaPanel#Live_Concordia hideTrace(ccE204Y)=0
		EndIf
		
	Else
		If (ShowAnd)
			ModifyGraph/W=LiveConcordiaPanel#Live_Concordia hideTrace(ccEAY)=1
		EndIf
		
		If (Show204)
			ModifyGraph/W=LiveConcordiaPanel#Live_Concordia hideTrace(ccE204Y)=1
		EndIf
	EndIf

	// Check if 204 was even measured and hide the trace if not:
	If (!Was204Measured)
		ModifyGraph/W=LiveConcordiaPanel#Live_Concordia hideTrace(ccE204Y)=1
	EndIf
	
	// Add info annotation if desired:
	NVAR ShowLiveInfo = root:Packages:VisualAge:Options:LiveOption_ShowInfo
	If (ShowLiveInfo)
		String info = ""

		Variable a68, s68, a75, s75, a82, s82, a76, s76
		Variable aavg, savg, asd2, asd3, asd4
		Variable gval = 60000

		GetIntegrationFromIolite("FinalAge206_238", MatrixName, ActiveIntNum, "ResultWave")
		a68 = ResultWave[0]
		s68 = ResultWave[1]
		
		GetIntegrationFromIolite("FinalAge207_235", MatrixName, ActiveIntNum, "ResultWave")
		a75 = ResultWave[0]
		s75 = ResultWave[1]			

		GetIntegrationFromIolite("FinalAge208_232", MatrixName, ActiveIntNum, "ResultWave")
		a82 = ResultWave[0]
		s82 = ResultWave[1]

		GetIntegrationFromIolite("FinalAge207_206", MatrixName, ActiveIntNum, "ResultWave")
		a76 = ResultWave[0]
		s76 = ResultWave[1]

		aavg = (a68+a75)/2
		savg = sqrt(s68^2 + s75^2)
		asd4 = sqrt( ( (a68-aavg)^2 + (a75-aavg)^2 + (a82-aavg)^2 + (a76-aavg)^2 )/4 )
		asd3 = sqrt( ( (a68-aavg)^2 + (a75-aavg)^2 + (a82-aavg)^2 )/3 )
		asd2 = sqrt( ( (a68-aavg)^2 + (a75-aavg)^2)/2)

		If ( abs(a68-aavg) < (s68+savg) )
			gval = 60000*(2/asd2)
			If (gval > 60000)
				gval = 60000
			EndIf
			Info += "\K(0," + num2str(gval) +",0)"
		EndIf
		info += "\f00\M\S206\MPb/\S238\MU Age = " + num2str(a68) + " ± " + num2str(s68)+ "\r\K(0,0,0)"			
		If ( abs(a75-aavg) < (s75+savg) )
			gval = 60000*(2/asd2)
			If (gval > 60000)
				gval = 60000
			EndIf			
			Info += "\K(0," + num2str(gval) +",0)"
		EndIf
		info += "\f00\M\S207\MPb/\S235\MU Age = " + num2str(a75) + " ± " + num2str(s75)+ "\r\K(0,0,0)"
		If ( abs(a82-aavg) < (s82+savg))
			gval = 60000*(2/asd3)
			If (gval > 60000)
				gval = 60000
			EndIf			
			Info += "\K(0," + num2str(gval) +",0)"
			aavg = (a68+a75+a82)/3
			savg = sqrt(s68^2 + s75^2 + s82^2)
		EndIf
		info += "\f00\M\S208\MPb/\S232\MTh Age = " + num2str(a82) + " ± " + num2str(s82)+ "\r\K(0,0,0)"
		If ( abs(a76-aavg) < (s76+savg) )
			gval = 60000*(2/asd4)
			If (gval > 60000)
				gval = 60000
			EndIf			
			Info += "\K(0," + num2str(gval) +",0)"
		EndIf
		info += "\f00\M\S207\MPb/\S206\MPb Age = " + num2str(a76) + " ± " + num2str(s76)+ "\r\K(0,0,0)"
		
		String topWinName = WinName(0,1)
		If ( cmpstr(topWinName, "TracesWindow0") == 0 )
			Wave/T IntLabels = $ioliteDFpath("traces", "IntegNoLabels")
			info[0] = "\f04\Z18Integration: " + IntLabels[ActiveIntNum] + "\r"		
		Else // Otherwise it should be from the Main Window (called MainControlWindow)
			Wave/T IntLabels = $ioliteDFpath("integration", "IntegNoLabels")
			info[0] = "\f04\Z18Integration: " + IntLabels[ActiveIntNum] + "\r"		
		EndIf
						
		// Only allow live ConcAge if fewer than 30 integrations:
		If (NoOfIntegrations < 30 && ShowConcAge )
			CalculateConcAge("Final", MatrixName, ConcFolder="root:Packages:VisualAge:LiveConcordia", AddToPlot=1, TargetWin="LiveConcordiaPanel#Live_Concordia", AddAnnotation=0,doTW=doTW)
			NVAR ConcAge = root:Packages:VisualAge:LiveConcordia:ConcAge
			NVAR ConcAgeSigma = root:Packages:VisualAge:LiveConcordia:ConcAgeSigma
			NVAR ConcAgeProb = root:Packages:VisualAge:LiveConcordia:ConcAgeProb
			info += "\f00\MConcAge = " + num2str(ConcAge/1e6) + " ± " + num2str(CeilToSig(ConcAgeSigma/1e6,3)) + " (P = " + num2str(CeilToSig(ConcAgeProb,3)) + ")\K(0,0,0)"
		EndIf
		
		TextBox/C/N=LiveIntBox/W=LiveConcordiaPanel#Live_Concordia/B=1/A=RB info	
	Else
		TextBox/K/N=LiveIntBox
	EndIf

	// Uncomment following line to fit a discordia when updating the live concordia:
	//ConcordiaFitLine("Final", MatrixName, doTW, anchor =0, plotwindow="LiveConcordiaPanel#Live_Concordia")

	// Put the previous integration back on the diagram if showing all integrations:
	If (PreviousIntegrationNum != ActiveIntNum && ShowAllInts)
		String EllipseInfo = AddToConcordiaByIntegration(PreviousIntegrationNum, "Final", MatrixName, "LiveConcordiaPanel#Live_Concordia", doTW=doTW, ConcFolder="root:Packages:VisualAge:LiveConcordia")
		String EllipseHandle = StringByKey("Handle", EllipseInfo)
		ModifyGraph/W=LiveConcordiaPanel#Live_Concordia lstyle($EllipseHandle)=1
	EndIf
	
	// Make a legend + add to plot:
	String LegendStr = "\\s(ccEUY) No correction"
	If (ShowAnd)
		LegendStr += "\r\\s(ccEAY) Andersen correction"
	EndIf
	If (Show204 && Was204Measured)
		LegendStr += "\r\\s(ccE204Y) 204Pb correction"
	EndIf
	If (ShowConcAge && NoOfIntegrations < 30)
		LegendStr += "\r\\s(WtdMeanY) ConcAge"
	EndIf
	
	Legend/W=LiveConcordiaPanel#Live_Concordia/C/N=lcLegend/J/F=0/A=LT LegendStr

	// Set previous integration to the one just used:	
	PreviousIntegrationNum = ActiveIntNum
	
	// Restore data folder:
	SetDataFolder PreviousDF
	Return 0
End

//########################################################
// Shared concordia related functions
//########################################################

//------------------------------------------------------------------------
// Function to generate some concordia waves
//------------------------------------------------------------------------
Function GenerateConcordia(ConcName, ConcStartAge, ConcStopAge, [NoOfPoints, NoOfMarkers, doTW, ConcFolder])
	String ConcName, ConcFolder
	Variable ConcStartAge, ConcStopAge, NoOfMarkers, NoOfPoints, doTW
	
	// Make sure VisualAge is initialized:
	VAInitialized()
	
	// Store the current data folder:
	String PreviousDF = GetDataFolder(1)
	
	// Check all of the optional parameters:
	
	// If a folder is specified, switch to it:
	If ( !ParamIsDefault(ConcFolder) )
		SetDataFolder ConcFolder
	EndIf
	
	// Handle defaults for optional params:
	If ( ParamIsDefault(NoOfMarkers) )
		NoOfMarkers = 10
	EndIf
	
	If ( ParamIsDefault(NoOfPoints) )
		NoOfPoints = 10000
	EndIf
	
	If ( ParamIsDefault(doTW) )
		doTW = 0
	EndIf
	
	Make/O/N=(NoOfPoints) $(ConcName + "X"), $(ConcName + "Y")
	Make/O/N=(NoOfMarkers) $(ConcName + "MarkerX"), $(ConcName + "MarkerY")
	
	Wave cX = $(ConcName + "X")
	Wave cY = $(ConcName + "Y")
	Wave cMX = $(ConcName + "MarkerX")
	Wave cMY = $(ConcName + "MarkerY")

	NVAR l238 = root:Packages:VisualAge:Constants:l238
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR k = root:Packages:VisualAge:Constants:k
	
	Variable i=0, ti = 0
	
	// Compute ratios for main concordia trace:
	For ( i = 0; i < NoOfPoints; i = i + 1 )
		ti = ((ConcStopAge-ConcStartAge)/NoOfPoints)*i + ConcStartAge
		If (!doTW)
			cX[i] = exp(l235*ti) - 1
			cY[i] = exp(l238*ti) - 1
		Else
			cX[i] = 1/(exp(l238*ti) - 1)
			cY[i] = (1/k)*(exp(l235*ti)-1)/(exp(l238*ti)-1)		
		EndIf
	EndFor
	
	// Compute ratios for markers:
	For ( i = 0; i < NoOfMarkers; i = i + 1 )
		ti = ((ConcStopAge-ConcStartAge)/NoOfMarkers)*i + ConcStartAge
		If (!doTW)
			cMX[i] = exp(l235*ti) - 1
			cMY[i] = exp(l238*ti) - 1
		Else
			cMX[i] = 1/(exp(l238*ti) - 1)
			cMY[i] = (1/k)*(exp(l235*ti)-1)/(exp(l238*ti)-1)		
		EndIf
	EndFor
	
	// Restore previous data folder:
	SetDataFolder PreviousDF
End

//------------------------------------------------------------------------
// Add an integration to a concordia diagram based on values
//------------------------------------------------------------------------
Function/S AddToConcordiaByValues(xv, sxv, yv, syv, pv, GraphName, EllipseName, [doTW])
	Variable xv, sxv, yv, syv, pv, doTW
	String GraphName, EllipseName
	String EllipseInfo = ""	
	
	// Make sure VisualAge is initialized:
	VAInitialized()

	// Do some calculations to figure out error ellipse info:
	Variable sxyv = pv*sxv*syv	
	
	Variable l1 = 2*sqrt( (sxv^2 + syv^2 + sqrt( (sxv^2 - syv^2)^2 + 4*sxyv^2)  )/2)
	Variable l2 = 2*sqrt( (sxv^2 + syv^2 - sqrt( (sxv^2 - syv^2)^2 + 4*sxyv^2)  )/2)
	
	Variable theta = 0.5*atan( 2*sxyv/(sxv^2 - syv^2) )	
	
	// Make ellipse:
 	NVAR nPPE = root:Packages:VisualAge:Options:LiveOption_PPE

	String IntStrx = EllipseName + "x"
	String IntStry = EllipseName + "y"
	EllipseInfo += "Handle:" + IntStry + ";"
	
	RemoveFromGraph/Z/W=$GraphName $IntStry
	
	Make/O/N=(nPPE) $IntStrx, $IntStry
	Wave ellipsex = $IntStrx
	Wave ellipsey = $IntStry
	
//	Make/O/N=(nPPE/2) $IntStry, $(intStry + "b")
//	Wave ellipsey = $IntStry
//	Wave ellipsey2 = $(IntStry + "b")
	
	Variable j = 0

	Variable/D xLength = 0
	Variable/D yLength = 0	

	If (sxv >= syv)
		xLength = max(l1, l2)
		yLength = min(l1, l2)
	Else
		xLength = min(l1, l2)
		yLength = max(l1, l2)
	EndIf 

	Variable cTheta = cos(theta), sTheta = sin(theta)
 
	For ( j = 0; j <= nPPE; j = j + 1)
		Variable/D ex = 0
		Variable/D ey = 0
		Variable/D pj = 360*j/(nPPE-2)
			
		ex = xLength*cos(pj*Pi/180) 
		ey = yLength*sin(pj*Pi/180)
			
		ellipsex[j] = xv + ex*cTheta - ey*sTheta	
		ellipsey[j] = yv + ex*sTheta + ey*cTheta
		
//		if (j < nPPE/2)
//			ellipsey[j] = yv + ex*sTheta + ey*cTheta
//		else
//			ellipsey2[nPPE-j] = yv + ex*sTheta + ey*cTheta
//		endif
		
	EndFor
	
	// Add to graph:
//	AppendToGraph/W=$GraphName ellipsey, ellipsey2 vs ellipsex
	AppendToGraph/W=$GraphName ellipsey vs ellipsex
	
	// Set some default trace properties:
	ModifyGraph/W=$GraphName rgb($IntStry)=(0,0,0), lstyle($IntStry)=0, lsize($IntStry)=1
//	ModifyGraph/W=$GraphName rgb($(IntStry +"b"))=(0,0,0), lstyle($(IntStry + "b"))=0, lsize($(IntStry + "b"))=0
//	ModifyGraph mode($IntStry)=7,hbFill($IntStry)=2,useNegPat($IntStry)=1,toMode($IntStry)=1	

	// Set some ellipse info:	
	NVAR dlt = root:Packages:VisualAge:Options:ConcordiaOption_OmitLTDisc
	NVAR dgt = root:Packages:VisualAge:Options:COncordiaOption_OmitGTDisc
	NVAR maxEllipseErrorPercent = root:Packages:VisualAge:Options:ConcordiaOption_OmitErrorsOver
		
	If (100*sqrt(xLength^2 + yLength^2)/sqrt(xv^2 + yv^2) > maxEllipseErrorPercent)
		EllipseInfo += "ErrorIsBig:1;"
	Else
		EllipseInfo += "ErrorIsBig:0;"
	EndIf	

	If ( (DiscPercent(xv,yv) > dgt && !doTW) || (DiscPercentTW(xv,yv) > dgt && doTW) )
		EllipseInfo += "DiscPercentGreaterThanCutoff:1;"
	Else
		EllipseInfo += "DiscPercentGreaterThanCutoff:0;"
	EndIf
	
	If ( (DiscPercent(xv,yv) < dlt && !doTW) || (DiscPercentTW(xv,yv) < dlt && doTW) )
		EllipseInfo += "DiscPercentLessThanCutoff:1;"
	Else
		EllipseInfo += "DiscPercentLessThanCutoff:0;"
	EndIf
		
	Return EllipseInfo
End

//------------------------------------------------------------------------
// Add an integration to a concordia diagram based on integration number, and specified params
//------------------------------------------------------------------------
Function/S AddToConcordiaByIntegration(IntNum, ConcVersion, ConcInteg, GraphName, [doTW, ConcFolder])
	Variable IntNum, doTW
	String ConcVersion, ConcInteg, GraphName, ConcFolder
	
	// Make sure VisualAge is initialized:
	VAInitialized()
	
	// Store the current data folder:
	String PreviousDF = GetDataFolder(1)
	
	// Check optional parameters:
	If ( !ParamIsDefault(ConcFolder) )
		// If a folder is specified, switch to it:
		SetDataFolder ConcFolder
	Else
		// If not, make the required folder:
		NewDataFolder/O/S root:Packages:VisualAge:ConcordiaDiagrams:$ConcInteg
		NewDataFolder/O/S $GraphName
	EndIf
	
	If ( ParamIsDefault( doTW ) )
		doTW = 0
	EndIf
	
	String EllipseInfo = ""	
	
	Wave ResultWave = $MakeioliteWave("CurrentDRS", "ResultWave", n = 2)

	Variable xv, sxv, yv, syv, pv

	// Get the required data:
	If (!doTW)
		xv = GetIntegrationFromIolite(ConcVersion+"207_235", ConcInteg, IntNum, "ResultWave")
		sxv = ResultWave[1]/2
		yv = GetIntegrationFromIolite(ConcVersion+"206_238", ConcInteg, IntNum, "ResultWave")
		syv = ResultWave[1]/2
		pv = ChannelCorrelation(ConcVersion + "207_235", ConcVersion + "206_238", IntNum, ActiveIntegration=ConcInteg)
	Else
		xv = GetIntegrationFromIolite(ConcVersion+"238_206", ConcInteg, IntNum, "ResultWave")
		sxv = ResultWave[1]/2
		yv = GetIntegrationFromIolite(ConcVersion+"207_206", ConcInteg, IntNum, "ResultWave")
		syv = ResultWave[1]/2
		pv = ChannelCorrelation(ConcVersion + "238_206", ConcVersion + "207_206", IntNum, ActiveIntegration=ConcInteg)
	EndIf

	// Now add by values:	
	EllipseInfo = AddToConcordiaByValues(xv, sxv, yv, syv, pv, GraphName, "Int"+num2str(IntNum), doTW=doTW)

	// Restore previous data folder:
	SetDataFolder PreviousDF
	Return EllipseInfo
End

//########################################################
// 3d concordia related functions
//########################################################

//------------------------------------------------------------------------
// Start 3d classical U-Th-Pb concordia
//------------------------------------------------------------------------
Function Do3dConc()

	// Make sure VisualAge is initialized:
	VAInitialized()

	// Check if a Conc3d window is already open:
	If (CheckName("Conc3dGizmo",5) != 0)
		// Bring it to the front if so:
		DoWindow/F Conc3dGizmo
		If (CheckName("C3dPanel", 9) != 0)
			DoWindow/F C3dPanel
		Else
			execute "Conc3dController()"
		EndIf
				
		Return 0
	EndIf 

	SVAR ListOfOutputChannels = $ioliteDFpath("Output", "ListOfOutputChannels")
	Variable NoOfChannels = ItemsInList(ListOfOutputChannels)
	
	String ListOfConcordiaOptions = ""
	SVAR ListOfAvailableIntegrations = root:Packages:iolite:integration:ListOfIntegrations
	
	// Get a list of options... kind of a complicated way to find Final or FinalAnd...
	Variable i
	For ( i = 0; i < NoOfChannels; i = i + 1)
		String currentChannel = StringFromList(i, ListOfOutputChannels)
		
		If ( StrSearch(currentChannel, "207_235", 0) != -1 && StrSearch(currentChannel, "Age",0) == -1 )
			ListOfConcordiaOptions = ListOfConcordiaOptions +  RemoveEnding(currentChannel, "207_235") + ";"
		EndIf
	EndFor
	
	// Ask the user which version and integration they'd like to plot:
	String MatrixName = GetMatrixName()

	String ConcVersion = "Final"
	String ConcInteg = MatrixName
	
	Prompt ConcVersion, "Which Version? ", popup, ListOfConcordiaOptions
	Prompt ConcInteg, "Which Integration? ", popup, GetListOfUsefulIntegrations()
	
	DoPrompt "VisualAge U-Th-Pb Concordia",  ConcVersion, ConcInteg
	If (V_Flag)
		Return -1
	EndIf

	Wave aim = $ioliteDFpath("integration", "m_" + ConcInteg)
	Variable NoOfIntegrations = DimSize(aim,0)

	String CurrentDF = GetDataFolder(1)
	NewDataFolder/O/S root:Packages:VisualAge:Conc3d

	// Fill data matrix:
	Make/O/N=(NoOfIntegrations,3) ConcData3d
	For ( i = 1; i < NoOfIntegrations; i = i + 1 )
		ConcData3d[i][0] = GetIntegrationFromIolite(ConcVersion + "207_235", ConcInteg, i, "ResultWave")
		ConcData3d[i][1] = GetIntegrationFromIolite(ConcVersion + "206_238", ConcInteg, i, "ResultWave")
		ConcData3d[i][2] = GetIntegrationFromIolite(ConcVersion + "208_232", ConcInteg, i, "ResultWave")
	EndFor
	
	// Do 1000 points for the concordia line:
	Make/O/N=(1000,3) Conc3d
	For (i = 0; i < 1000; i = i + 1)
		Conc3d[i][0] = Ratio7_35(4.5e9*(i/1000))
		Conc3d[i][1] = Ratio6_38(4.5e9*(i/1000))
		Conc3d[i][2] = Ratio8_32(4.5e9*(i/1000))
	EndFor
	
	// Put markers every 100 Ma
	Make/O/N=(45,3) Conc3dMarkers
	For (i = 0; i < 45; i = i + 1)
		Conc3dMarkers[i][0] = Ratio7_35(4.5e9*(i/45))
		Conc3dMarkers[i][1] = Ratio6_38(4.5e9*(i/45))
		Conc3dMarkers[i][2] = Ratio8_32(4.5e9*(i/45))
	EndFor
		
	// Construct gizmo to display 3d data:
	execute "NewGizmo/N=Conc3dGizmo/K=1"
	
	// Set gizmo properties:
	execute "AppendToGizmo/N=Conc3dGizmo/D scatter=ConcData3d, name=Conc3dScatter"
	execute "AppendToGizmo/N=Conc3dGizmo/D path=Conc3d, name=Conc3dConcordia"
	execute "AppendToGizmo/N=Conc3dGizmo/D scatter=Conc3dMarkers, name=Conc3dConcordiaMarkers"
	execute "AppendToGizmo/N=Conc3dGizmo/D Axes=BoxAxes, name=Conc3dAxes"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dScatter, property={size,0.1}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dConcordiaMarkers, property={size,0.2}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dConcordiaMarkers, property={color,1,0,0}"
	
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={0, axisLabel, 1}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={0, axisLabelText, \"207Pb/235U\"}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={0, axisLabelCenter, -0.5}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={0, axisLabelScale, 0.5}"	
		
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={1, axisLabel, 1}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={1, axisLabelText, \"206Pb/238U\"}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={1, axisLabelCenter, -0.5}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={1, axisLabelScale, 0.5}"	
	
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={2, axisLabel, 1}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={2, axisLabelText, \"208Pb/232Th\"}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={2, axisLabelCenter, -0.5}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={2, axisLabelScale, 0.5}"
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={2, axisLabelScale, 0.5}"	
	execute "ModifyGizmo/N=Conc3dGizmo modifyObject=Conc3dAxes, property={2, axisLabelScale, 0.5}"	
	
	// Set gizmo hook:			
	execute "ModifyGizmo/N=Conc3dGizmo namedHook={Conc3dHook, Conc3dHookFunction}"

	// Start control panel:
	execute "Conc3dController()"
	
	// Restore previous data folder:
	SetDataFolder CurrentDF
End

//------------------------------------------------------------------------
// Hook for Conc3d -- currently just kills the control panel
//------------------------------------------------------------------------
Function Conc3dHookFunction(s)
	STRUCT WMGizmoHookStruct &s

	// Kill the control panel if it is still open:
	If (cmpstr(s.eventName, "kill") == 0)
		If (CheckName("C3dPanel", 9) != 0)
			KillWindow C3dPanel
			execute "RemoveFromGizmo/Z/N=Conc3dGizmo object=Conc3dScatter"
			execute "RemoveFromGizmo/Z/N=Conc3dGizmo object=Conc3dConcordia"
			execute "RemoveFromGizmo/Z/N=Conc3dGizmo object=Conc3dConcordiaMarkers"
			KillDataFolder/Z root:Packages:VisualAge:Conc3d
		EndIf
	EndIf
	Return 0
End

//------------------------------------------------------------------------
// Panel to help control 3d diagram
//------------------------------------------------------------------------
Window Conc3dController() : Panel

	// Determine location and size:
	execute	"GetGizmo/N=Conc3dGizmo winPixels"
	Variable wLeft = V_right
	Variable wTop = V_top
	Variable wBottom = V_top+150
	Variable wRight = V_right + 180

	NewPanel/K=1/N=C3dPanel/W=(wLeft, wTop, wRight, wBottom) as "Conc3d Controller"
	
	String CurrentDF = GetDataFolder(1)
	SetDataFolder root:Packages:VisualAge:Conc3d
	
	Variable/G Conc3dMinAge = 0
	Variable/G Conc3dMaxAge = 4500
	
	Button ViewButton1, proc=ViewButtonClick, pos={2,1}, size={175,25}, title="\\S206\\MPb/\\S238\\MU vs \\S207\\MPb/\\S235\\MU"
	Button ViewButton2, proc=ViewButtonClick, pos={2,32}, size={175,25}, title="\\S208\\MPb/\\S232\\MTh vs \\S207\\MPb/\\S235\\MU"
	Button ViewButton3, proc=ViewButtonClick, pos={2,64}, size={175,25}, title="\\S208\\MPb/\\S232\\MTh vs \\S206\\MPb/\\S238\\MU"
	SetVariable MinAgeCtrl, proc=Adjust3dConcAges, pos={2,96}, title="Minimum age [Ma]:", size={175,20}, value=Conc3dMinAge
	SetVariable MaxAgeCtrl, proc=Adjust3dConcAges, pos={2,120}, title="Maximum age [Ma]:", size={175,20}, value=Conc3dMaxAge
	
	SetDataFolder CurrentDF
End

//------------------------------------------------------------------------
// Adjust Conc3d axes according to the age range specified
//------------------------------------------------------------------------
Function Adjust3dConcAges(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	String CurrentDF = GetDataFolder(1)
	SetDataFolder root:Packages:VisualAge:Conc3d

	Variable minX, minY, minZ, maxX, maxY, maxZ
	
	NVAR maxAge = root:Packages:VisualAge:Conc3d:Conc3dMaxAge
	NVAR minAge = root:Packages:VisualAge:Conc3d:Conc3dMinAge
	
	If ( cmpstr(sva.ctrlName, "MinAgeCtrl") == 0)
		minAge = sva.dval
	Else
		maxAge = sva.dval
	EndIf
	
	If ( maxAge > minAge )
	
		// Calculate axis limits based on ages specified:
		minX = Ratio7_35(minAge*1e6)
		minY = Ratio6_38(minAge*1e6)
		minZ = Ratio8_32(minAge*1e6)
	
		maxX = Ratio7_35(maxAge*1e6)
		maxY = Ratio6_38(maxAge*1e6)
		maxZ = Ratio8_32(maxAge*1e6)	
	
		// Set limits:
		execute "ModifyGizmo/N=Conc3dGizmo setOuterBox={" + num2str(minX) + "," + num2str(maxX) + "," + num2str(minY) + "," + num2str(maxY) + "," + num2str(minZ) + "," + num2str(maxZ) +"}"	
	Else
		DoAlert/T="VisualAge" 0, "Maximum age must be greater than minimum age."
	EndIf

	SetDataFolder CurrentDF
End

//------------------------------------------------------------------------
// Adjust Conc3d view according to the button clicked
//------------------------------------------------------------------------
Function ViewButtonClick(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	Switch( ba.eventCode )
		Case 2: // mouse up
			If (cmpstr(ba.ctrlName, "ViewButton1" ) == 0 )
				execute "ModifyGizmo euler={0,0,0}"
			Elseif (cmpstr(ba.ctrlName, "ViewButton2") == 0 )
				execute "ModifyGizmo euler={-90,0,0}"
			Elseif (cmpstr(ba.ctrlName, "ViewButton3") == 0 )
				execute "ModifyGizmo euler={90,-90,180}"
			EndIf
			Break
	EndSwitch

	Return 0
End

//------------------------------------------------------------------------
// Start 3d Total Pb/U isochron diagram
//------------------------------------------------------------------------
Function Do3dTera()

	// Make sure VisualAge is initialized:
	VAInitialized()

	NVAR Was204Measured = root:Packages:VisualAge:Was204Measured
	
	If (!Was204Measured)
		DoAlert/T="VisualAge" 0, "Cannot construct a total U-Pb diagram: 204Pb data is not available"
		Return 0
	EndIf

	// Check if a Tera3d window is already open:
	If (CheckName("Tera3dGizmo",5) != 0)
		// Bring it to the front if so:
		DoWindow/F Tera3dGizmo
		If (CheckName("T3dPanel", 9) != 0)
			DoWindow/F T3dPanel
		Else
			execute "Tera3dController()"
		EndIf
		
		Return 0
	EndIf 

	SVAR ListOfOutputChannels = $ioliteDFpath("Output", "ListOfOutputChannels")
	Variable NoOfChannels = ItemsInList(ListOfOutputChannels)
	
	String ListOfConcordiaOptions = ""
	SVAR ListOfAvailableIntegrations = root:Packages:iolite:integration:ListOfIntegrations
	
	// Get a list of options... kind of a complicated way to find Final or FinalAnd...
	Variable i
	For ( i = 0; i < NoOfChannels; i = i + 1)
		String currentChannel = StringFromList(i, ListOfOutputChannels)
		
		If ( StrSearch(currentChannel, "207_235", 0) != -1 && StrSearch(currentChannel, "Age",0) == -1 )
			ListOfConcordiaOptions = ListOfConcordiaOptions +  RemoveEnding(currentChannel, "207_235") + ";"
		EndIf
	EndFor
	
	// Ask the user which version and integration they'd like to plot:
	String MatrixName = GetMatrixName()

	String ConcVersion = "Final"
	String ConcInteg = MatrixName
	
	Prompt ConcVersion, "Which Version? ", popup, ListOfConcordiaOptions
	Prompt ConcInteg, "Which Integration? ", popup, GetListOfUsefulIntegrations()
	
	DoPrompt "VisualAge U-Th-Pb Concordia",  ConcVersion, ConcInteg
	If (V_Flag)
		Return -1
	EndIf

	Wave aim = $ioliteDFpath("integration", "m_" + ConcInteg)
	Variable NoOfIntegrations = DimSize(aim,0)
	
	// Change the data folder:
	String CurrentDF = GetDataFolder(1)
	NewDataFolder/O/S root:Packages:VisualAge:Tera3d

	Make/O/N=(NoOfIntegrations,3) TeraData3d
	
	// Get the required data:
	For ( i = 1; i < NoOfIntegrations; i = i + 1 )
		TeraData3d[i][0] = GetIntegrationFromIolite("Final238_206", ConcInteg, i, "ResultWave")
		TeraData3d[i][1] = 	GetIntegrationFromIolite("Final207_206", ConcInteg, i, "ResultWave")
		TeraData3d[i][2] = 1/GetIntegrationFromIolite("Final206_204", ConcInteg, i, "ResultWave")
	EndFor
	
	Make/O/N=(1000,3) Tera3d, Pb3d
	Make/O/N=(20,3) Tera3dMarkers, Pb3dMarkers
		
	Variable cAge = 0, common64, common74, common84
	
	// Calculate concordia + lead growth curve:
	For (i = 0; i < 1000; i = i + 1)
		cAge = 4.5e9*(i/1000)
		
		Tera3d[i][0] = 1/Ratio6_38(cAge) 
		Tera3d[i][1] = Ratio7_6(cAge)
		Tera3d[i][2] = 0
		
		common64 = 0.023*(cAge/1e9)^3 - 0.359*(cAge/1e9)^2 - 1.008*(cAge/1e9) + 19.04
		common74 = -0.034*(cAge/1e9)^4 +0.181*(cAge/1e9)^3 - 0.448*(cAge/1e9)^2 + 0.334*(cAge/1e9) + 15.64
		common84 = -2.200*(cAge/1e9) + 39.47		
		
		Pb3d[i][0] = 0
		Pb3d[i][1] = common74/common64
		Pb3d[i][2] = 1/common64
	EndFor
	
	// Calculate concordia + lead growth markers:
	For (i = 0; i < 20; i = i + 1)
		cAge = 4.5e9*(i/20)
			
		Tera3dMarkers[i][0] = 1/Ratio6_38(cAge)
		Tera3dMarkers[i][1] = Ratio7_6(cAge)
		Tera3dMarkers[i][2] = 0
		
		common64 = 0.023*(cAge/1e9)^3 - 0.359*(cAge/1e9)^2 - 1.008*(cAge/1e9) + 19.04
		common74 = -0.034*(cAge/1e9)^4 +0.181*(cAge/1e9)^3 - 0.448*(cAge/1e9)^2 + 0.334*(cAge/1e9) + 15.64
		common84 = -2.200*(cAge/1e9) + 39.47		
		
		Pb3dMarkers[i][0] = 0
		Pb3dMarkers[i][1] = common74/common64
		Pb3dMarkers[i][2] = 1/common64
	
	EndFor
	
	// Make gizmo:
	execute "NewGizmo/N=Tera3dGizmo/K=1"
	
	// Set gizmo data + properties:
	execute "AppendToGizmo/N=Tera3dGizmo/D scatter=TeraData3d, name=Tera3dScatter"
	execute "AppendToGizmo/N=Tera3dGizmo/D path=Tera3d, name=Tera3dConcordia"
	execute "AppendToGizmo/N=Tera3dGizmo/D path=Pb3d, name=Tera3dPb"
	execute "AppendToGizmo/N=Tera3dGizmo/D scatter=Tera3dMarkers, name=Tera3dConcordiaMarkers"
	execute "AppendToGizmo/N=Tera3dGizmo/D scatter=Pb3dMarkers, name=Tera3dPbMarkers"	
	execute "AppendToGizmo/N=Tera3dGizmo/D Axes=BoxAxes, name=Tera3dAxes"
	execute "ModifyGizmo/N=Tera3dGizmo modifyObject=Tera3dScatter, property={size,0.1}"
	execute "ModifyGizmo/N=Tera3dGizmo modifyObject=Tera3dConcordiaMarkers, property={size,0.2}"
	execute "ModifyGizmo/N=Tera3dGizmo modifyObject=Tera3dConcordiaMarkers, property={color,1,0,0}"
	execute "ModifyGizmo/N=Tera3dGizmo modifyObject=Tera3dPbMarkers, property={size,0.2}"
	execute "ModifyGizmo/N=Tera3dGizmo modifyObject=Tera3dPbMarkers, property={color,1,0,0}"
	
	// Set gizmo hook function:
	execute "ModifyGizmo/N=Tera3dGizmo namedHook={Tera3dHook, Tera3dHookFunction}"	
	
	// Start control panel:
	execute "Tera3dController()"
	
	String/G T3dConcInteg
	T3dConcInteg = ConcInteg
	
	// Restore previous data folder:
	SetDataFolder CurrentDF
End

//------------------------------------------------------------------------
// Hook for Tera3d -- currently just kills the control panel
//------------------------------------------------------------------------
Function Tera3dHookFunction(s)
	STRUCT WMGizmoHookStruct &s

	If (cmpstr(s.eventName, "kill") == 0)
		If (CheckName("T3dPanel", 9) != 0)
			KillWindow T3dPanel
			execute "RemoveFromGizmo/Z/N=Tera3dGizmo object=Tera3dScatter"
			execute "RemoveFromGizmo/Z/N=Tera3dGizmo object=Tera3dConcordia"
			execute "RemoveFromGizmo/Z/N=Tera3dGizmo object=Tera3dConcordiaMarkers"
			execute "RemoveFromGizmo/Z/N=Tera3dGizmo object=Tera3dPb"
			execute "RemoveFromGizmo/Z/N=Tera3dGizmo object=Tera3dPbMarkers"			
			KillDataFolder/Z root:Packages:VisualAge:Tera3d
		EndIf
	EndIf
	Return 0
End

//------------------------------------------------------------------------
// Panel to help control 3d Tera diagram
//------------------------------------------------------------------------
Window Tera3dController() : Panel

	// Determine location and size:
	execute	"GetGizmo/N=Tera3dGizmo winPixels"
	Variable wLeft = V_right
	Variable wTop = V_top
	Variable wBottom = V_top+190
	Variable wRight = V_right + 190

	// Put panel to the upper right:
	NewPanel/K=1/N=T3dPanel/W=(wLeft, wTop, wRight, wBottom) as "Tera3d Controller"
	
	String CurrentDF = GetDataFolder(1)
	SetDataFolder root:Packages:VisualAge:Tera3d
	
	Variable/G Tera3dMinAge = 100
	Variable/G Tera3dMaxAge = 5500
	Variable/G Tera3dMinZ = 0
	Variable/G Tera3dMaxZ = 1/(0.023*(4.5)^3 - 0.359*(4.5)^2 - 1.008*(4.5) + 19.04)
	
	Button ViewButton1, proc=ViewButtonClick, pos={2,1}, size={175,25}, title="\\S207\\MPb/\\S206\\MPb vs \\S238\\MU/\\S206\\MPb"
	Button ViewButton2, proc=ViewButtonClick, pos={2,32}, size={175,25}, title="\\S204\\MPb/\\S206\\MPb vs \\S238\\MU/\\S206\\MPb"
	Button ViewButton3, proc=ViewButtonClick, pos={2,64}, size={175,25}, title="\\S204\\MPb/\\S206\\MPb vs \\S207\\MPb/\\S206\\MPb"
	SetVariable MinAgeCtrl, proc=Adjust3dTeraAges, pos={2,96}, title="Minimum age [Ma]:", size={175,20}, value=Tera3dMinAge
	SetVariable MaxAgeCtrl, proc=Adjust3dTeraAges, pos={2,120}, title="Maximum age [Ma]:", size={175,20}, value=Tera3dMaxAge
	SetVariable MinZCtrl, proc=Adjust3dTeraAges, pos={2,146}, title="Minimum 204/206:", size={175,20}, value=Tera3dMinZ
	SetVariable MaxZCtrl, proc=Adjust3dTeraAges, pos={2,170}, title="Maximum 204/206:", size={175,20}, value=Tera3dMaxZ

	SetDataFolder CurrentDF	
End

//------------------------------------------------------------------------
// Adjust Tera3d axes according to the age range specified
//------------------------------------------------------------------------
Function Adjust3dTeraAges(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	String CurrentDF = GetDataFolder(1)
	SetDataFolder root:Packages:VisualAge:Tera3d

	Variable minX, minY, minZ, maxX, maxY, maxZ
	
	NVAR maxAge = root:Packages:VisualAge:Tera3d:Tera3dMaxAge
	NVAR minAge = root:Packages:VisualAge:Tera3d:Tera3dMinAge
	NVAR T3dMaxZ = root:Packages:VisualAge:Tera3d:Tera3dMaxZ
	NVAR T3dMinZ = root:Packages:VisualAge:Tera3d:Tera3dMinZ
	
	If ( cmpstr(sva.ctrlName, "MinAgeCtrl") == 0)
		minAge = sva.dval
	Elseif ( cmpstr(sva.ctrlName, "MaxAgeCtrl") == 0)
		maxAge = sva.dval
	Elseif ( cmpstr(sva.ctrlName, "MaxZCtrl") == 0)
		T3dMaxZ = sva.dval
	Elseif ( cmpstr(sva.ctrlName, "MinZCtrl") == 0)
		T3dMinZ = sva.dval
	EndIf
	
	If ( maxAge > minAge )
	
		minX = 0//1/Ratio6_38(maxAge*1e6)
		minY = 0//Ratio7_6(minAge*1e6)
		minZ = T3dMinZ
	
		maxX = 1/Ratio6_38(minAge*1e6)
		maxY = Ratio7_6(maxAge*1e6)
		maxZ = T3dMaxZ
	
		execute "ModifyGizmo/N=Tera3dGizmo setOuterBox={" + num2str(minX) + "," + num2str(maxX) + "," + num2str(minY) + "," + num2str(maxY) + "," + num2str(minZ) + "," + num2str(maxZ) +"}"	
	Else
		DoAlert/T="VisualAge" 0, "Maximum age must be greater than minimum age."
	EndIf

	SetDataFolder CurrentDF
End

//------------------------------------------------------------------------
// Add contour to concordia
//------------------------------------------------------------------------
Function ConcordiaContour()

	// Make sure VisualAge has been initialized:
	VAInitialized()


	SVAR ListOfOutputChannels = $ioliteDFpath("Output", "ListOfOutputChannels")
	Variable NoOfChannels = ItemsInList(ListOfOutputChannels)
	
	String ListOfConcordiaOptions = ""
	SVAR ListOfAvailableIntegrations = root:Packages:iolite:integration:ListOfIntegrations
	
	// Get a list of options... kind of a complicated way to find Final or FinalAnd...
	Variable i
	For ( i = 0; i < NoOfChannels; i = i + 1)
		String currentChannel = StringFromList(i, ListOfOutputChannels)
		
		If ( StrSearch(currentChannel, "207_235", 0) != -1 && StrSearch(currentChannel, "Age",0) == -1 )
			ListOfConcordiaOptions = ListOfConcordiaOptions +  RemoveEnding(currentChannel, "207_235") + ";"
		EndIf
	EndFor
	
	// Ask the user which version and integration they'd like to plot:
	String MatrixName = GetMatrixName()

	String ConcVersion = "Final"
	String ConcInteg = MatrixName
	
	Prompt ConcVersion, "Which Version? ", popup, ListOfConcordiaOptions
	Prompt ConcInteg, "Which Integration? ", popup, GetListOfUsefulIntegrations()
	
	DoPrompt "VisualAge Concordia Contour",  ConcVersion, ConcInteg
	If (V_Flag)
		Return -1
	EndIf

	Wave aim = $ioliteDFpath("integration", "m_" + ConcInteg)
	Variable NoOfIntegrations = DimSize(aim,0)
	
	Wave Final207_235 = $ioliteDFpath("CurrentDRS", ConcVersion + "207_235")
	Wave Final206_238 = $ioliteDFpath("CurrentDRS", ConcVersion + "206_238")
	
	Wave Index_Time = $ioliteDFpath("CurrentDRS", "Index_Time")

	String CurrentDF = GetDataFolder(1)
	NewDataFolder/O/S root:Packages:VisualAge:ConcContour

	String ConcName = "CC"

	// Plot the concordia:
	NVAR MarkerSep = root:Packages:VisualAge:Options:ConcordiaOption_MarkerSep
	GenerateConcordia("CC", 0, 5e9, NoOfPoints=100000, NoOfMarkers=5e9/(MarkerSep*1e6), doTW=0,ConcFolder=GetDataFolder(1))
	
	Wave conX = $("CC" + "X"), conY = $("CC" + "Y")
	Wave conMX = $("CC" + "MarkerX"), conMY = $("CC" + "MarkerY")

	DoWindow/K $ConcName
	Display/N=$ConcName/K=1

	AppendToGraph conY vs conX
	AppendToGraph conMY vs conMX

	// Create tags:
	For (i = 1; i < 5e9/(markerSep*1e6); i = i +1)
		String tagStr = "tag" + num2str(i)
		String tagValue = num2str(markerSep*(i)) + " Ma"
		String traceStr = ConcName + "MarkerY"
		Tag/N=$tagStr/A=RC/F=0/Z=1/I=1/B=1/X=-0.5/Y=0.5/L=0/AO=0 $traceStr, i, tagValue
	EndFor		
		
	// Set properties of concordia wave:
	ModifyGraph lStyle($(ConcName + "Y")) = 0
	ModifyGraph lSize($(ConcName + "Y")) = 1.5
	ModifyGraph rgb($(ConcName + "Y"))=(0,0,0)
	
	// Set properties for time symbols:
	ModifyGraph marker($(ConcName + "MarkerY"))=19
	ModifyGraph msize($(ConcName + "MarkerY"))=5
	ModifyGraph mode($(ConcName + "MarkerY"))=3
	ModifyGraph rgb($(ConcName + "MarkerY"))=(65000,0,0)	

	KillWaves/Z ContourData, ContourX, ContourY

	Variable startTime, stopTime
	Variable startIndex, stopIndex
	Variable Nbins = 150

	Make/O/N=(Nbins,Nbins) ContourData
	Make/O/N=(Nbins) ContourX, ContourY
	Variable Start7_35 = 0,  Stop7_35 = 30, Bin7_35 = (Stop7_35-Start7_35)/Nbins
	Variable Start6_38 = 0,  Stop6_38 = 1.5, Bin6_38 = (Stop6_38-Start6_38)/Nbins

	For ( i = 0; i < Nbins; i = i + 1)
		ContourX[i] = i*Bin7_35
		ContourY[i] = i*Bin6_38
	EndFor

	// Fill data matrix:
	For ( i = 1; i < NoOfIntegrations; i = i + 1)
	
		startTime = aim[i][0][%$"Median Time"]-aim[i][0][%$"Time Range"]
		stopTime = aim[i][0][%$"Median Time"]+aim[i][0][%$"Time Range"]
	
		startIndex = ForBinarySearch(Index_Time, startTime) + 1
		If (numtype(Index_Time[startIndex]) == 2)
			startIndex += 1
		EndIf
	
		stopIndex = ForBinarySearch(Index_Time, stopTime)
		If (stopIndex == -2)
			stopIndex = numpnts(Index_Time) - 1
		EndIf

		Variable j
		For ( j = startIndex; j < stopIndex; j = j + 1)
			Variable cx = Final207_235[j]
			Variable cy = Final206_238[j]

			Variable ix = cx/Bin7_35
			Variable iy = cy/Bin6_38
			
			if (numtype(ix) == 2 || numtype(iy) == 2)
				continue
			endif

			ContourData[ix][iy] = ContourData[ix][iy] + 1
		EndFor
	EndFor
	
	AppendMatrixContour ContourData vs {ContourX, ContourY}
End

//------------------------------------------------------------------------
// Plot 207/206 vs 206/204, useful for common Pb assessment
//------------------------------------------------------------------------
Function DoCommonPbPlot1(ActiveInt)
	String ActiveInt
	
	NewDataFolder/O/S root:Packages:VisualAge:PbPlot1
	
	Display

	Wave aim = $ioliteDFpath("Integration", "m_" + ActiveInt)
	Wave ResultWave = $MakeioliteWave("CurrentDRS", "ResultWave", n = 2)
	
	Variable NumberOfIntegrations = Dimsize(aim,0)-1
	Make/N=(NumberOfIntegrations)/O PbPX, PbPY, PbPSX, PbPSY, PbPYc
	
	NVAR Pb64 = root:Packages:VisualAge:Options:Option_Common64
	NVAR Pb74 = root:Packages:VisualAge:Options:Option_Common74
		
	Variable i 
	
	Variable MysteryFactor = 1
	
	For(i = 1; i <= NumberOfIntegrations; i = i + 1)
	
		PbPY[i-1] = GetIntegrationFromIolite("Final207_206",  ActiveInt, i, "ResultWave")
		PbPSY[i-1] = ResultWave[1]
		
		Variable x = GetIntegrationFromIolite("Pb206_CPS", ActiveInt, i, "ResultWave")
		Variable sx = ResultWave[1]
		Variable x2 = GetIntegrationFromIolite("Pb204_CPS", ActiveInt, i, "ResultWave")
		if (x2 < 0) 
			x2 = abs(x2)
		EndIf
		
		Variable sx2 = ResultWave[1]
		Variable m64 = MysteryFactor*x/x2

		PbPYc[i-1] =  (PbPY[i-1]*m64 - Pb74)/( m64 - Pb64)
//		PbPYc[i-1] = GetIntegrationFromIolite("FinalAnd207_206", ActiveInt, i, "ResultWave")
		
		PbPX[i-1] = x/x2
		PbPSX[i-1] = (x/x2)*sqrt((sx/x)^2 + (sx2/x2)^2)
		
	EndFor
	
	AppendToGraph PbPY vs PbPX
	AppendToGraph PbPyc vs PbPx
	ModifyGraph rgb(PbPYc)=(0,0,65535)
	ModifyGraph mode=3;DelayUpdate
 //	ErrorBars PbPY XY,wave=(PbPSX,PbPSX),wave=(PbPSY,PbPSY)
//	 FuncFit/L=50000 /X=1/NTHR=0 HyperRect W_coef  PbPY /X=PbPX /D 
	 
	ModifyGraph mirror=2,standoff=0;DelayUpdate
	SetAxis left 0.1,0.5;DelayUpdate
	SetAxis bottom -1000,100000
	ModifyGraph width=566.929
	ModifyGraph height=396.85
	
	Label bottom "\\S206\\MPb/\\S204\\MPb"
	Label left "\\S207\\MPb/\\S206\\MPb"	
End


//------------------------------------------------------------------------
// Do 207/206 vs 204/206 plot
//------------------------------------------------------------------------
Function DoCommonPbPlot2(ActiveInt)
	String ActiveInt
	
	
	NewDataFolder/O/S root:Packages:VisualAge:PbPlot2
	
	
	Display

	Wave aim = $ioliteDFpath("Integration", "m_" + ActiveInt)
	Wave ResultWave = $MakeioliteWave("CurrentDRS", "ResultWave", n = 2)
	
	Variable NumberOfIntegrations = Dimsize(aim,0)-1
	KillWaves PbPx, PbPy, PbPSX, PbPSY, PbPYc, PbPSYc
	Make/N=(NumberOfIntegrations)/O PbPX, PbPY, PbPSX, PbPSY, PbPYc, PbPSYc
	
	NVAR Pb64 = root:Packages:VisualAge:Options:Option_Common64
	NVAR Pb74 = root:Packages:VisualAge:Options:Option_Common74
		
	Variable i 
	
	Variable MysteryFactor = 0.6
	print NumberOfIntegrations
	For(i = 1; i <= NumberOfIntegrations; i = i + 1)
	
		PbPY[i-1] = GetIntegrationFromIolite("Final207_206",  ActiveInt, i, "ResultWave")
		PbPSY[i-1] = ResultWave[1]
		
		Variable x = GetIntegrationFromIolite("Pb206_CPS", ActiveInt, i, "ResultWave")
		Variable sx = ResultWave[1]
		Variable x2 = GetIntegrationFromIolite("Pb204_CPS", ActiveInt, i, "ResultWave")
		if (x2 < 0) 
			x2 = abs(x2)
		EndIf
		

		Variable sx2 = ResultWave[1]
		Variable m64 = MysteryFactor*x/x2

		PbPYc[i-1] =  (PbPY[i-1]*m64 - Pb74)/( m64 - Pb64)
//		PbPYc[i-1] = GetIntegrationFromIolite("FinalAnd207_206", ActiveInt, i, "ResultWave")
		PbPSYc[i-1] = PbPSY[i-1]*PbPYc[i-1]/PbPY[i-1]
		
		PbPX[i-1] = 1/m64
		PbPSX[i-1] = (1/m64)*sqrt((sx/x)^2 + (sx2/x2)^2)
		
		if (PbPSX[i-1] > 0.01)
			//PbPX[i-1] = Nan
		Endif
		
	EndFor
	
	AppendToGraph PbPY vs PbPX
	AppendToGraph PbPyc vs PbPx
	ModifyGraph rgb(PbPYc)=(0,0,65535)
	ModifyGraph mode=3;DelayUpdate
 	ErrorBars PbPY XY,wave=(PbPSX,PbPSX),wave=(PbPSY,PbPSY)
//	 FuncFit/L=50000 /X=1/NTHR=0 HyperRect W_coef  PbPY /X=PbPX /D 
	 
	ModifyGraph mirror=2,standoff=0;DelayUpdate
	SetAxis left 0.15,0.5;DelayUpdate
	SetAxis bottom 0,0.025
	ModifyGraph width=566.929
	ModifyGraph height=396.85
	
	Label bottom "\\S204\\MPb/\\S206\\MPb"
	Label left "\\S207\\MPb/\\S206\\MPb"	
	
	ModifyGraph width=595.276,height=453.543,gFont="Helvetica",gfSize=18
	Label left "\\S207\\MPb\\Z28/\\M\\S206\\MPb";DelayUpdate
	Label bottom "\\S204\\MPb\\Z28/\\M\\S206\\MPb"
	ModifyGraph gmSize=5
	ModifyGraph msize(PbPY)=5
	ModifyGraph axOffset(left)=-2;DelayUpdate
	SetAxis left 0.15,0.45
	ModifyGraph rgb(PbPY)=(0,0,0)
	
End