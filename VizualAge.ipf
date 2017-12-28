//########################################################
//   VisualAge add-on for Iolite 2/3
//   Written by Joe Petrus      
//########################################################
#pragma rtGlobals=1
StrConstant VA_Version_No = "2015.06"

//------------------------------------------------------------------------
// Initialize settings for VisualAge
//------------------------------------------------------------------------
Function VAInit()
	NewDataFolder/O/S root:Packages:VisualAge

	Variable/G RecrunchAndersen = 0
	String/G VAVersion = VA_Version_No
	Variable/G Was204Measured = 0
	
	// If first initialization, set counters to 0:
	If (!exists("HistogramCount"))
		Variable/G HistogramCount = 0
	EndIf
	
	If (!exists("ConcordiaCount"))
		Variable/G ConcordiaCount = 0
	EndIf
		
	// Constants
	NewDataFolder/O/S root:Packages:VisualAge:Constants
	Variable/G l235 = 9.8485e-10
	Variable/G l238 = 1.55125e-10
	Variable/G l232 = 0.49475e-10
	Variable/G k = 137.88
	
	// Set some defaults for the options:
	NewDataFolder/O/S root:Packages:VisualAge:Options
			
	Variable/G HoldDHC = 0		
			
	// 207/206 options
	String/G PbPbOption_WavesForGuess = "FinalAge207_235;FinalAge206_238;"
	Variable/G PbPbOption_MaxIters = 1e6
	Variable/G PbPbOption_Epsilon = 1e-08
	Variable/G PbPbOption_Calculate = 0
	
	// Andersen options
	String/G AndersenOption_WavesForGuess = "FinalAge207_235;FinalAge207_206;FinalAge206_238;"
	Variable/G AndersenOption_t2 = 0
	Variable/G AndersenOption_MaxIters = 1e6
	Variable/G AndersenOption_Epsilon = 1e-08
	Variable/G AndersenOption_OnlyGTDisc = 5
	Variable/G AndersenOption_MaxRecalc = 3
	Variable/G AndersenOption_Calculate = 0

	// 204Pb options
	String/G PbCOption_WavesForGuess = "FinalAge207_235;FinalAge207_206;FinalAge206_238;"
	Variable/G PbCOption_Calculate = 0

	// General DRS options
	Variable/G Option_UsePbComp = 0 
	Variable/G Option_Common64 = NaN
	Variable/G Option_Common74 = NaN
	Variable/G Option_Common84 = NaN
	
	// Histogram options
	Variable/G HistogramOption_StartAge = 0
	Variable/G HistogramOption_StopAge = 4500
	Variable/G HistogramOption_BinSize = 50
	Variable/G HistogramOption_ShowStats = 0
	Variable/G HistogramOption_ShowPDP = 1
	Variable/G HistogramOption_ShowKDe = 1
	Variable/G HistogramOption_ShowTicks = 1
	Variable/G HistogramOption_KDEbw = 30
	
	// Concordia options
	Variable/G ConcordiaOption_OmitLTDisc = -inf
	Variable/G ConcordiaOption_OmitGTDisc = inf
	Variable/G ConcordiaOption_MarkerSep = 200
	Variable/G ConcordiaOption_FitLine = 0
	Variable/G ConcordiaOption_ThroughZero = 0
	Variable/G ConcordiaOption_PPE = 180
	Variable/G ConcordiaOption_OmitErrorsOver = Inf
	Variable/G ConcordiaOption_ShowInfo = 0
	Variable/G ConcordiaOption_ShowConcAge = 0
	Variable/G ConcordiaOption_RemoveIntegs = 1
	
	// Live concordia options
	Variable/G LiveOption_AutoResize = 1
	Variable/G LiveOption_MarkerSep = 100
	Variable/G LiveOption_UpdateInterval = 5
	Variable/G LiveOption_PPE = 180
	Variable/G LiveOption_ShowCorrectionsWhen = 0
	Variable/G LiveOption_Show204Correction = 0
	Variable/G LiveOption_ShowAndCorrection = 0
	Variable/G LiveOption_ShowInfo = 1
	Variable/G LiveOption_ShowAllIntegrations = 1
	Variable/G LiveOption_TW = 0
	Variable/G LiveOption_ShowConcAge = 0
End

//------------------------------------------------------------------------
// Function to check initialization
//------------------------------------------------------------------------
Function VAInitialized()
	// Check that main data folder exists:
	If ( DataFolderExists("root:Packages:VisualAge") )
		SVAR StoredVersion = root:Packages:VisualAge:VAVersion
		// Check version:
		If ( cmpstr(StoredVersion,VA_Version_No) != 0 )
			DoAlert/T="VisualAge" 1, "VisualAge version has changed.  Would you like to reinitialize?"
			If (V_flag == 1)
				VAInit()
			EndIf
		EndIf
		Return 1
	Else
		// Check if DRS is Chad's U-Pb DRS since it should mostly work...
		SVar S_currentDRS = $ioliteDFpath("output", "S_currentDRS")
		If (GrepString(S_currentDRS, "(?i)Geochron"))
			Print "Note: Using VizualAge with Iolite's U-Pb DRS is not supported. Proceed with caution!"
			If ( !DataFolderExists("root:Packages:VisualAge") )
				VAInit()
			EndIf
			Return 1
		Else
			DoAlert/T="VisualAge Error" 0,"Either the VisualAge DRS is not loaded or something is very wrong."
			Abort
		EndIf
	EndIf
End

//------------------------------------------------------------------------
// Hook function to add settings button to Iolite DRS settings window
//------------------------------------------------------------------------
Function AfterWindowCreatedHook(windowNameStr, wT)
	String windowNameStr
	Variable wT
	
	SVAR CurrentDRS = root:Packages:iolite:output:S_currentDRS
	
	If (CmpStr(windowNameStr, "EditSettingsWindow") == 0  && cmpstr(CurrentDRS, "VisualAgeDRS") == 0)
		Button VAExtendedDRSOptionsButton, title="Extended DRS Options", win=$windowNameStr, proc=VAShowDRSOptionsProc, size={150,20}
	EndIf
End

//------------------------------------------------------------------------
// Show the VA DRS options if button is pressed in Iolite DRS settings
//------------------------------------------------------------------------
Function VAShowDRSOptionsProc(ctrlName) : ButtonControl
	String ctrlName
	VAShowDRSOptions()
End

//------------------------------------------------------------------------
// Create VisualAge menu
//------------------------------------------------------------------------
Menu "VizualAge", dynamic
	"Histogram/7",/Q, AgeHistogram()
	SubMenu "Concordia"
		"Live/8",/Q, LiveConcordia()
		"-"			
		"U-Pb/9", /Q,Concordia(0)
		"Tera Wasserburg",/Q, Concordia(1)
		"U-Th-Pb", /Q,Do3dConc()
		"Total U-Pb",/Q, Do3dTera()
	End
	SubMenu "Windows"
		SubMenu "Histograms"
			GetDiagramList("Histogram"),/Q, ShowDiagram()
		End
		SubMenu "Concordia"
			GetDiagramList("Concordia"),/Q,ShowDiagram()
		End
	End
	"-"
	"Filter",/Q, VAFilter()
	SubMenu "Options"
		"DRS/S0", /Q,VAShowDRSOptions()
		"Plotting/S9",/Q, VAShowPlotOptions()
		"-"
		"Reset to Defaults",/Q, VAInit()
	End
	SubMenu "Edit"
		"DRS", DisplayProcedure/W=$"VisualAgeDRS.ipf"
		"Plotting", DisplayProcedure/W=$"VisualAgePlotting.ipf"
		"Calculations", DisplayProcedure/W=$"VisualAgeCalc.ipf"
		"Misc", DisplayProcedure/W=$"VisualAge.ipf"
	End
	"-"
	"About", VAShowAbout()
End

//------------------------------------------------------------------------
// Generate a list of diagrams matching the type specified
//------------------------------------------------------------------------
Function/S GetDiagramList(inType)
	String inType

	String completeList = WinList("*", ";", "WIN:1")
	String gizmoList = WinList("*", ";", "WIN:4096")
	String retList = ""
			
	Variable i
	For (i = 0; i < ItemsInList(completeList); i = i + 1)
		String curItem = StringFromList(i, completeList)
		String curType = GetUserData(curItem, "", "Type")
		If (cmpstr(curType, inType) == 0 )
			retList += curItem + ";"
		EndIf
	EndFor
	
	If (cmpstr(inType, "Concordia") == 0)
		For (i =0; i < ItemsInList(gizmoList); i = i + 1)
			If (cmpstr(StringFromList(i, gizmoList), "Conc3dGizmo") == 0)
				retList += "Conc3dGizmo;"
			Elseif (cmpstr(StringFromList(i, gizmoList), "Tera3dGizmo") == 0)
				retList += "Tera3dGizmo;"
			EndIf
		EndFor
	EndIf

	Return retList
End

//------------------------------------------------------------------------
// Show the diagram that is selected in the menu
//------------------------------------------------------------------------
Function ShowDiagram()
	GetLastUserMenuInfo
	DoWindow/F $S_value
End

//########################################################
//   Panel functions                        
//########################################################

//------------------------------------------------------------------------
// VisualAge options panel
//------------------------------------------------------------------------
Window VADRSOptions() : Panel
	VAInitialized()
	
	String IgorInfoStr=IgorInfo(0)
	Variable scr0 = strsearch(IgorInfoStr,"RECT",0)
	Variable scr1 = strsearch(IgorInfoStr,",",scr0+9)
	Variable scr2 = strlen(IgorInfoStr)-2
	Variable screenWidth = str2num(IgorInfoStr[scr0+9,scr1-1])
	Variable screenHeight = str2num(IgorInfoStr[scr1+1,scr2])
	
	Variable panelWidth = 403
	Variable panelHeight = 380	
	
	NewPanel/W=(screenWidth/2-panelWidth/2,screenHeight/2-panelHeight/2,screenWidth/2+panelWidth/2,screenHeight/2+panelHeight/2)/K=1/N=VADRSOptions as "VisualAge Options"

	GroupBox groupDRS fSize=14,title="Data Reduction Scheme", size={400,370}, pos={2,1}

	DrawText 17, 45, "207Pb/206Pb Age"
	
	CheckBox PbPbCalculateBox title ="Do? (lookup table otherwise)", pos={300,30}, size={75,15}, side=1
	CheckBox PbPbCalculateBox variable=root:Packages:VisualAge:Options:PbPbOption_Calculate
	
	SetVariable PbPbWavesForGuessSetVar,pos={17, 50},size={375,15},title="Waves to use for guess age: " 
	SetVariable PbPbWavesForGuessSetVar,value=root:Packages:VisualAge:Options:PbPbOption_WavesForGuess	

	SetVariable PbPbMaxItersSetVar,pos={17, 70},size={375,15},title="Maximum number of iterations: " 
	SetVariable PbPbMaxItersSetVar,value=root:Packages:VisualAge:Options:PbPbOption_MaxIters	

	SetVariable PbPbEpsilonSetVar,pos={17, 90},size={375,15},title="Newton's method exit criteria: " 
	SetVariable PbPbEpsilonSetVar,value=root:Packages:VisualAge:Options:PbPbOption_Epsilon	

	DrawText 17, 130, "Andersen Routine"

	CheckBox AndersenCalculateBox title ="Do?", pos={300,115}, size={75,15}, side=1
	CheckBox AndersenCalculateBox variable=root:Packages:VisualAge:Options:AndersenOption_Calculate

	SetVariable AndersenWavesForGuessSetVar,pos={17, 135},size={375,15},title="Waves to use for guess age: " 
	SetVariable AndersenWavesForGuessSetVar,value=root:Packages:VisualAge:Options:AndersenOption_WavesForGuess		
	
	SetVariable AndersenMaxItersSetVar,pos={17, 155},size={375,15},title="Maximum number of iterations: " 
	SetVariable AndersenMaxItersSetVar,value=root:Packages:VisualAge:Options:AndersenOption_MaxIters	

	SetVariable AndersenEpsilonSetVar,pos={17, 175},size={375,15},title="Newton's method exit criteria: " 
	SetVariable AndersenEpsilonSetVar,value=root:Packages:VisualAge:Options:AndersenOption_Epsilon
	
	SetVariable Andersent2SetVar,pos={17, 195},size={375,15},title="Age of lead loss (t2) [Ma]: " 
	SetVariable Andersent2SetVar,value=root:Packages:VisualAge:Options:AndersenOption_t2	
	
	SetVariable AndersenOnlyGTSetVar,pos={17, 215},size={375,15},title="Only correct points with discordance greater than [%]: " 
	SetVariable AndersenOnlyGTSetVar,value=root:Packages:VisualAge:Options:AndersenOption_OnlyGTDisc	

	SetVariable AndersenMaxRecalcSetVar,pos={17, 235},size={375,15},title="Maximum number of recalculations using new Pb composition: " 
	SetVariable AndersenMaxRecalcSetVar,value=root:Packages:VisualAge:Options:AndersenOption_MaxRecalc
	
	DrawText 17, 275, "204Pb Correction"
	
	CheckBox PbCalculateBox title ="Do?", pos={300,260}, size={75,15}, side=1
	CheckBox PbCalculateBox variable=root:Packages:VisualAge:Options:PbCOption_Calculate

	SetVariable PbWavesForGuessSetVar,pos={17, 280},size={375,15},title="Waves to use for guess age: " 
	SetVariable PbWavesForGuessSetVar,value=root:Packages:VisualAge:Options:PbCOption_WavesForGuess	

	DrawText 17, 320, "General"
	
	CheckBox UsePbComp title="Specify common Pb composition?", pos={17, 325}, size={167,15}, side=1;
	CheckBox UsePbComp variable=root:Packages:VisualAge:Options:Option_UsePbComp
	
	SetVariable C64, pos={17, 345}, size={120,15}, title="206/204: "
	SetVariable C64, value=root:Packages:VisualAge:Options:Option_Common64

	SetVariable C74, pos={145, 345}, size={120,15}, title="207/204: "
	SetVariable C74, value=root:Packages:VisualAge:Options:Option_Common74
	
	SetVariable C84, pos={275, 345}, size={120,15}, title="208/204: "
	SetVariable C84, value=root:Packages:VisualAge:Options:Option_Common84
	
	PauseForUser VADRSOptions
End

//------------------------------------------------------------------------
// Function to setup and call drs options panel
//------------------------------------------------------------------------
Function VAShowDRSOptions()
	DoWindow/F VADRSOptions
	If ( V_flag != 1 )
		Execute "VADRSOptions()"
	EndIf
End
 
//------------------------------------------------------------------------
// VisualAge plot options panel
//------------------------------------------------------------------------
Window VAPlotOptions() : Panel
	VAInitialized()
	
	String IgorInfoStr=IgorInfo(0)
	Variable scr0 = strsearch(IgorInfoStr,"RECT",0)
	Variable scr1 = strsearch(IgorInfoStr,",",scr0+9)
	Variable scr2 = strlen(IgorInfoStr)-2
	Variable screenWidth = str2num(IgorInfoStr[scr0+9,scr1-1])
	Variable screenHeight = str2num(IgorInfoStr[scr1+1,scr2])
	
	Variable panelWidth = 403
	Variable panelHeight = 465	
	
	NewPanel/W=(screenWidth/2-panelWidth/2,screenHeight/2-panelHeight/2,screenWidth/2+panelWidth/2,screenHeight/2+panelHeight/2)/K=1/N=VAPlotOptions as "VisualAge Options"

	GroupBox groupPlotting fSize=14,title="Plotting", size={400,460}, pos ={ 2, 1}
	
	DrawText 17, 45, "Histogram"
	
	SetVariable HistogramStartAgeSetVar,pos={17, 50},size={375,15},title="Start age [Ma]: " 
	SetVariable HistogramStartAgeSetVar,value=root:Packages:VisualAge:Options:HistogramOption_StartAge		
	
	SetVariable HistogramStopAgeSetVar,pos={17, 70},size={375,15},title="Stop age [Ma]: " 
	SetVariable HistogramStopAgeSetVar,value=root:Packages:VisualAge:Options:HistogramOption_StopAge		
		
	SetVariable HistogramBinSizeSetVar,pos={17, 90},size={375,15},title="Bin size [Ma]: " 
	SetVariable HistogramBinSizeSetVar,value=root:Packages:VisualAge:Options:HistogramOption_BinSize	
	
//	CheckBox HistogramStatsSetVar title="Show simple statistics?", pos={67, 110}, size={75,15}, side=1
//	CheckBox HistogramStatsSetVar variable=root:Packages:VisualAge:Options:HistogramOption_ShowStats	

	CheckBox HistogramKDESetVar title="KDE?", pos={0, 110}, size={75,15}, side=1
	CheckBox HistogramKDESetVar variable=root:Packages:VisualAge:Options:HistogramOption_ShowKDE

	SetVariable HistogramBW, pos = {100, 110}, size={100,15}, title="Bandwidth: "
	SetVariable HistogramBW, value=root:Packages:VisualAge:Options:HistogramOption_KDEbw

	CheckBox HistogramPDPSetVar title="PDP?", pos={200, 110}, size={75,15}, side=1
	CheckBox HistogramPDPSetVar variable=root:Packages:VisualAge:Options:HistogramOption_ShowPDP
	
	CheckBox HistogramTicksSetVar title="Ticks?", pos={300, 110}, size={75,15}, side=1
	CheckBox HistogramTicksSetVar variable=root:Packages:VisualAge:Options:HistogramOption_ShowTicks
	
	DrawText 17, 150, "Concordia"
	
	SetVariable ConcordiaOnlyLTSetVar,pos={17, 155},size={375,15},title="Omit integrations with discordance less than [%]: " 
	SetVariable ConcordiaOnlyLTSetVar,value=root:Packages:VisualAge:Options:ConcordiaOption_OmitLTDisc

	SetVariable ConcordiaOnlyGTSetVar,pos={17, 175},size={375,15},title="Omit integrations with discordance greater than [%]: " 
	SetVariable ConcordiaOnlyGTSetVar,value=root:Packages:VisualAge:Options:ConcordiaOption_OmitGTDisc	
	
	SetVariable ConcordiaOnlyErrorsOverSetVar, pos={17,195},size={375,15},title="Omit integrations with ellipse larger than [%]: "
	SetVariable ConcordiaOnlyErrorsOverSetVar,value=root:Packages:VisualAge:Options:ConcordiaOption_OmitErrorsOver
	
	SetVariable ConcordiaMarkerSepSetVar,pos={17, 215},size={375,15},title="Concordia marker separation [Ma]: " 
	SetVariable ConcordiaMarkerSepSetVar,value=root:Packages:VisualAge:Options:ConcordiaOption_MarkerSep

	SetVariable ConcordiaPPESetVar,pos={17, 235},size={375,15},title="Points per ellipse: " 
	SetVariable ConcordiaPPESetVar,value=root:Packages:VisualAge:Options:ConcordiaOption_PPE
	
	CheckBox ConcordiaFitLineCheck title="Fit line?",pos={17,255},size={60,15},side=1;
	CheckBox ConcordiaFitLineCheck variable=root:Packages:VisualAge:Options:ConcordiaOption_FitLine

	CheckBox ConcordiaZeroCheck title="Through zero?",pos={110,255},size={60,15},side=1;
	CheckBox ConcordiaZeroCheck variable=root:Packages:VisualAge:Options:ConcordiaOption_ThroughZero

	CheckBox ConcordiaConcAgeCheck title="Calculate ConcAge?", pos={185,255}, size={100,15}, side=1
	CheckBox ConcordiaConcAgeCheck variable=root:Packages:VisualAge:Options:ConcordiaOption_ShowConcAge
	
	CheckBox ConcordiaShowInfoCheck title="Show info?", pos={270,255}, size={100,15}, side=1
	CheckBox ConcordiaShowInfoCheck variable=root:Packages:VisualAge:Options:ConcordiaOption_ShowInfo
	
	CheckBox ConcordiaRemIntCheck title="Delete integrations when removed from diagram?", pos={115,275},size={150,15}, side=1
	CheckBox ConcordiaRemIntCheck variable=root:Packages:VisualAge:Options:ConcordiaOption_RemoveIntegs
	
	DrawText 17, 315, "Live Concordia"
	
	CheckBox LiveTWCheck title="Tera-Wasserburg?", pos={260,320}, size={125,15}, side=1
	CheckBox LiveTWCheck variable=root:Packages:VisualAge:Options:LiveOption_TW	
	
	CheckBox LiveAutoResizeCheck title="Resize plot when new integration is selected?",pos={17,320},size={225,15},side=1;
	CheckBox LiveAutoResizeCheck variable=root:Packages:VisualAge:Options:LiveOption_AutoResize
	
	SetVariable LiveMarkerSepSetVar,pos={17, 340},size={375,15},title="Concordia marker separation [Ma]: " 
	SetVariable LiveMarkerSepSetVar,value=root:Packages:VisualAge:Options:LiveOption_MarkerSep

	SetVariable LivePPESetVar,pos={17, 360},size={375,15},title="Points per ellipse: " 
	SetVariable LivePPESetVar,value=root:Packages:VisualAge:Options:LiveOption_PPE	
		
	SetVariable LiveUpdateIntervalSetVar,pos={17, 380},size={375,15},title="Integration update interval [ticks]: " 
	SetVariable LiveUpdateIntervalSetVar,value=root:Packages:VisualAge:Options:LiveOption_UpdateInterval
	
	SetVariable LiveShowWhenConc, pos={17,400}, size={375,15},title="Show common-Pb correction when discordance is greater than [%]: "
	SetVariable LiveShowWhenConc, value=root:Packages:VisualAge:Options:LiveOption_ShowCorrectionsWhen
	
	CheckBox Live204Correction, pos={17,420}, size={110,15}, title="Show 204Pb corr.? ", side=1
	CheckBox Live204Correction, variable=root:Packages:VisualAge:Options:LiveOption_Show204Correction

	CheckBox LiveAndCorrection, pos={150,420}, size={110,15}, title="Show Andersen corr.? ", side=1
	CheckBox LiveAndCorrection, variable=root:Packages:VisualAge:Options:LiveOption_ShowAndCorrection
	
	CheckBox LiveConcAge, pos={300,420}, size={75,15}, title="Show ConcAge? ", side=1
	CheckBox LiveConcAge, variable=root:Packages:VisualAge:Options:LiveOption_ShowConcAge	
	
	CheckBox LiveShowInfoCheck title="Show info for active integration?", pos={17,440}, size={169,15}, side=1
	CheckBox LiveShowInfoCheck, variable=root:Packages:VisualAge:Options:LiveOption_ShowInfo
	
	CheckBox LiveShowAllCheck, pos={200,440}, size={123,15}, title="Show all integrations? ", side=1
	CheckBox LiveShowAllCheck, variable=root:Packages:VisualAge:Options:LiveOption_ShowAllIntegrations
	
	PauseForUser VAPlotOptions
End
 
//------------------------------------------------------------------------
// Function to setup and call plotting options panel
//------------------------------------------------------------------------
Function VAShowPlotOptions()
	DoWindow/F VAPlotOptions
	If ( V_flag != 1 )
		Execute "VAPlotOptions()"
	EndIf
End

//------------------------------------------------------------------------
// VisualAge about panel
//------------------------------------------------------------------------
Window VAAbout() : Panel
	String IgorInfoStr=IgorInfo(0)
	Variable scr0 = strsearch(IgorInfoStr,"RECT",0)
	Variable scr1 = strsearch(IgorInfoStr,",",scr0+9)
	Variable scr2 = strlen(IgorInfoStr)-2
	Variable screenWidth = str2num(IgorInfoStr[scr0+9,scr1-1])
	Variable screenHeight = str2num(IgorInfoStr[scr1+1,scr2])
	
	Variable panelWidth = 300
	Variable panelHeight = 80
	
	NewPanel/W=(screenWidth/2-panelWidth/2,screenHeight/2-panelHeight/2,screenWidth/2+panelWidth/2,screenHeight/2+panelHeight/2)/K=1/N=AboutPanel as "About"
	
	SetDrawEnv fsize= 18;DelayUpdate
	DrawText 30,30,"VizualAge"
	DrawText 30,50,"Version: " + VA_Version_No
	DrawText 30,70,"Created by: Joe Petrus and Balz Kamber"
End

//------------------------------------------------------------------------
// Function to setup and call about panel
//------------------------------------------------------------------------
Function VAShowAbout()
	DoWindow/F AboutPanel
	If ( V_flag != 1 )
		Execute "VAAbout()"
	EndIf
End

//########################################
//   Utility Functions
//########################################

//------------------------------------------------------------------------
// Get the value of an integration + its 2se from Iolite
//------------------------------------------------------------------------
Function GetIntegrationFromIolite(ChannelStr, IntStr, IntNum, ResultStr)
	String ChannelStr, IntStr, ResultStr
	Variable IntNum
	
	Wave aim= $ioliteDFpath("Integration", "m_" + IntStr)
	Wave ResultWave = $MakeioliteWave("CurrentDRS", ResultStr, n=2)	
	
	RecalculateIntegrations("m_" + IntStr, ChannelStr, RowNumber=IntNum)
	
	ResultWave[0] = aim[IntNum][%$ChannelStr][2]
	ResultWave[1] = aim[IntNum][%$ChannelStr][3]
	
	Return ResultWave[0]
End

//------------------------------------------------------------------------
// Calculates the correlation between two channels for a given integration number
//------------------------------------------------------------------------
Function ChannelCorrelation(ch1Str, ch2Str, IntNum, [ActiveIntegration])
	String ch1Str, ch2Str, ActiveIntegration
	Variable IntNum
	
	If ( ParamIsDefault(ActiveIntegration) )
		String MatrixName = GetMatrixName()	
		ActiveIntegration = MatrixName
	EndIf
	
	Wave aim = $ioliteDFpath("integration", "m_" + ActiveIntegration)
	Wave Index_Time = $ioliteDFpath("CurrentDRS", "Index_Time")
	
	Wave ch1 = $ioliteDFpath("CurrentDRS", ch1Str)
	Wave ch2 = $ioliteDFpath("CurrentDRS", ch2Str)
	
	Variable startTime, stopTime
	Variable startIndex, stopIndex
	
	startTime = aim[IntNum][0][%$"Median Time"]-aim[IntNum][0][%$"Time Range"]
	stopTime = aim[IntNum][0][%$"Median Time"]+aim[IntNum][0][%$"Time Range"]
	
	startIndex = ForBinarySearch(Index_Time, startTime) + 1
	If (numtype(Index_Time[startIndex]) == 2)
		startIndex += 1
	EndIf
	
	stopIndex = ForBinarySearch(Index_Time, stopTime)
	If (stopIndex == -2)
		stopIndex = numpnts(Index_Time) - 1
	EndIf
	If ( startIndex == stopIndex )
		Return -1
	EndIf		

	Duplicate/O/R=(startIndex,stopIndex) ch1, ch1sub
	Duplicate/O/R=(startIndex,stopIndex) ch2, ch2sub
	
	// Get rid of NaNs:
	If (stopIndex-startIndex > 5)
		Smooth/M=(NaN) 5, ch1sub
		Smooth/M=(Nan) 5, ch2sub
	EndIf
	
	Variable corr = StatsCorrelation(ch1sub, ch2sub)
	
	KillWaves ch1sub, ch2sub
	
	Return corr
End

//------------------------------------------------------------------------
// Returns an integration number given a time series index
//------------------------------------------------------------------------
Function GetIntegrationByIndex(IntInd, [ActiveIntegration])
	Variable IntInd
	String ActiveIntegration	
	
	If ( ParamIsDefault(ActiveIntegration) )
		String MatrixName = GetMatrixName()	
		ActiveIntegration = MatrixName
	EndIf
	
	Wave aim = $ioliteDFpath("integration", "m_" + ActiveIntegration)
	Wave Index_Time = $ioliteDFpath("CurrentDRS", "Index_Time")	
	
	Variable NoOfIntegrations = DimSize(aim,0)-1
	//print NoOfIntegrations
	
	Variable i, startTime, stopTime, startIndex, stopIndex
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
		If ( startIndex == stopIndex )
			Return -1
		EndIf
		
		If ((IntInd >=startIndex) && (IntInd <= stopIndex))
			//Print IntInd, startIndex, stopIndex
			Return i
		EndIf	
	EndFor
	
	
	Return Nan
End

//------------------------------------------------------------------------
// Calculate a rough measure of discordance
//------------------------------------------------------------------------
Function DiscPercent(ix, iy)
	Variable ix, iy
	
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	
	Variable tx = (1/l235)*ln(ix + 1)
	Variable ty = (1/l238)*ln(iy + 1)
	
	Variable t = (tx+ty)/2
	
	Variable cx = exp(t*l235) - 1
	Variable cy = exp(t*l238) - 1
	
	Variable d = 100*abs(1- (sqrt(ix^2 + iy^2)/sqrt(cx^2 + cy^2)))
	
	Return d
End

Function DiscPercent2(t6_38,t7_6)
	Variable t6_38, t7_6
	
	Return 100*( 1 - (t6_38/t7_6) )
End

//------------------------------------------------------------------------
// Calculate a rough measure of discordance for TW mode
//------------------------------------------------------------------------
Function DiscPercentTW(ix,iy)
	Variable ix, iy
	
	Variable tx = Age6_38(1/ix)
	Variable ty = Age7_6(iy, tx)
	
	Variable t = (tx+ty)/2
	
	Variable cx = Ratio7_6(t)
	Variable cy = 1/Ratio6_38(t)
	
	Variable d = 100*abs(1-(sqrt(ix^2 + iy^2)/sqrt(cx^2 + cy^2)))

	Return d
End

//------------------------------------------------------------------------
// Determine an average age from a list of waves at wIndex
//------------------------------------------------------------------------
Function AgeFromList(ageList, wIndex)
	String ageList
	Variable wIndex
	
	Variable listSize = ItemsInList(ageList)
	If (listSize == 0)
		Return NaN
	EndIf

	Variable i
	Variable age = 0
	
	For ( i = 0; i < listSize; i = i + 1)
		String currentAge = StringFromList(i, ageList)

		// Check if wave exists in output:
		Wave ageWave = $ioliteDFpath("CurrentDRS", currentAge)
		If ( !WaveExists(ageWave) )
			listSize = listSize - 1
		Else
			age = age + ageWave[wIndex]
		EndIf
	
	EndFor
	
	Return age/listSize
End

//------------------------------------------------------------------------
// Give the 8/32 age for a specified 8/32 ratio
//------------------------------------------------------------------------
Function Age8_32(ratio)
	Variable ratio
	NVAR l232 = root:Packages:VisualAge:Constants:l232
	Return (1/l232)*ln(ratio + 1)
End

//------------------------------------------------------------------------
// Give the 8/32 ratio for a specified 8/32 age
//------------------------------------------------------------------------
Function Ratio8_32(age)
	Variable age
	NVAR l232 = root:Packages:VisualAge:Constants:l232
	Return exp(l232*age)-1
End

//------------------------------------------------------------------------
// Give the 7/35 age for a specified 7/35 ratio
//------------------------------------------------------------------------
Function Age7_35(ratio)
	Variable ratio
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	Return (1/l235)*ln(ratio + 1)
End

//------------------------------------------------------------------------
// Give the 7/35 ratio for a specified 7/35 age
//------------------------------------------------------------------------
Function Ratio7_35(age)
	Variable age
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	Return exp(l235*age)-1
End

//------------------------------------------------------------------------
// Give the 6/38 age for a specified 6/33 ratio
//------------------------------------------------------------------------
Function Age6_38(ratio)
	Variable ratio
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	Return (1/l238)*ln(ratio + 1)
End

//------------------------------------------------------------------------
// Give the 6/38 ratio for a specified 6/38 age
//------------------------------------------------------------------------
Function Ratio6_38(age)
	Variable age
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	Return exp(l238*age)-1
End

//------------------------------------------------------------------------
// Give the 7/6 ratio for a specified 7/6 age
//------------------------------------------------------------------------
Function Ratio7_6(age)
	Variable age
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR k = root:Packages:VisualAge:Constants:k
	
	Return (1/k)*(exp(l235*age)-1)/(exp(l238*age)-1)
End

//------------------------------------------------------------------------
// Give the 7/6 age for a specified 7/6 ratio
//------------------------------------------------------------------------
Function Age7_6(ratio, guess)
	Variable ratio, guess
	
	Return 1e6*CalculatePbPbAge(ratio, guess)
End

//------------------------------------------------------------------------
// Notch filters noise (+ data!) at the specified frequency + bandwidth... not really recommended for use.
//------------------------------------------------------------------------
Function VAFilter()

	DoAlert/T="Warning" 1, "Filtering data is a bad idea.  Continue anyways?"
	If (V_flag != 1)
		Return -1
	EndIf

	SVAR ListOfInputChannels = $ioliteDFpath("input", "GlobalListOfInputChannels")
	Variable NoOfChannels = ItemsInList(ListOfInputChannels)
	
	Variable f0, fw
	
	Prompt f0, "Center frequency [Hz]: "
	Prompt fw, "Notch width [Hz]: "
	DoPrompt "Enter filter parameters", f0, fw
	If (V_Flag)
		Return -1
	EndIf
	
	f0 = f0/(2*pi)
	fw = fw/(2*pi)
	
	Make/O/D/N=0 coefs
	
	Variable i
	For (i = 0; i < NoOfChannels; i = i + 1)
		String curChannel = "root:Packages:iolite:input:" + StringFromList(i, ListOfInputChannels)
		FilterFIR/DIM=0/NMF={f0, fw, 9e-13, 3}/COEF coefs, $curChannel
	EndFor
End

//------------------------------------------------------------------------
// Round up to a certain number of significant figures
//------------------------------------------------------------------------
Function CeilToSig(in, sf)
	Variable in, sf
	Return (10^ceil(log(in)-(sf)))*ceil(in/((10^ceil(log(in)-(sf)))))
End

//------------------------------------------------------------------------
// Round down to a certain number of significant figures
//------------------------------------------------------------------------
Function FloorToSig(in, sf)
	Variable in, sf
	Variable out = (10^floor(log(in)-(sf-1)))*floor(in/((10^floor(log(in)-(sf-1)))))
	If (numtype(out) == 2)
		out = 0
	EndIf
	Return out
End	

//------------------------------------------------------------------------
// Get the minimum value of a particular integration/channel
//------------------------------------------------------------------------
Function GetMin(IntString, ValueString)
	String IntString, ValueString
	Variable intmin = 0
	
	Wave aim = $ioliteDFpath("integration", "m_" + IntString)
	Variable NoOfIntegrations = DimSize(aim,0) - 1
	Make/O/N=(NoOfIntegrations) Values 
	
	Wave ResultWave = $MakeioliteWave("CurrentDRS", "ResultWave", n=2)
	
	Variable i
	For ( i = 1; i <= NoOfIntegrations; i = i + 1 )
		GetIntegrationFromIolite(ValueString, IntString, i, "ResultWave")
		Values[i-1] = ResultWave[0] - ResultWave[1]
		If (numtype(Values[i-1]) == 2)
			Values[i-1] = inf
		EndIf
	EndFor
	
	intmin = WaveMin(Values)
	KillWaves Values
	Return intmin
End

//------------------------------------------------------------------------
// Get the maximum value of a particular integration/channel
//------------------------------------------------------------------------
Function GetMax(IntString, ValueString)
	String IntString, ValueString
	Variable intmax = 0
	
	Wave aim = $ioliteDFpath("integration", "m_" + IntString)
	Variable NoOfIntegrations = DimSize(aim,0) - 1
	Make/O/N=(NoOfIntegrations) Values 
	
	// Get ages from Iolite + store in a wave:
	Wave ResultWave = $MakeioliteWave("CurrentDRS", "ResultWave", n=2)
	
	Variable i
	For ( i = 1; i <= NoOfIntegrations; i = i + 1 )
		GetIntegrationFromIolite(ValueString, IntString, i, "ResultWave")
		Values[i-1] = ResultWave[0] + ResultWave[1]
		If (numtype(Values[i-1]) == 2)
			Values[i-1] = 0
		EndIf
	EndFor
	
	intmax = WaveMax(Values)
	KillWaves Values
	Return intmax
End

//------------------------------------------------------------------------
// Get a list of integrations that actually have some integrations set
//------------------------------------------------------------------------
Function/S GetListOfUsefulIntegrations()
	SVAR ListOfAvailableIntegrations = root:Packages:iolite:integration:ListOfIntegrations	
	String UsefulIntegrations = ""
	
	Variable i
	For (i = 0; i < ItemsInList(ListOfAvailableIntegrations); i = i + 1)
		Wave aim = $ioliteDFpath("integration", "m_" + StringFromList(i, ListOfAvailableIntegrations))
		Variable NoOfIntegrations = DimSize(aim,0)-1
		
		If (NoOfIntegrations > 0 && CmpStr(StringFromList(i,ListOfAvailableIntegrations),"Baseline_1") != 0 )
			UsefulIntegrations = UsefulIntegrations + StringFromList(i, ListOfAvailableIntegrations) + ";"
		EndIf
	EndFor
	
	Return UsefulIntegrations
End

//------------------------------------------------------------------------
// Remove an integration by the specified name/number
//------------------------------------------------------------------------
Function RemoveIntegrationByIndex(IntName, IntNo)
	String IntName
	Variable IntNo
	
	If (IntNo > 0 && numtype(IntNo) != 2)
		Reduce_Integ_Matrices(IntName, "Rows", "UsePointIndex", OptionalPointIndex = IntNo)
		//UpdateIntegNoLabels("m_"+IntName, "TotalBeam", "MainControlWindow")	
	EndIf
End

//------------------------------------------------------------------------
// Create a progress dialog to indicate progress in DRS 
//------------------------------------------------------------------------
//Function ProgressDialog()
//	String CurrentDF = GetDataFolder(1)
//	SetDataFolder root:Packages:VisualAge
//	
//	Variable/G ProgressPercent = 0
//	String/G ProgressMessage = "Starting DRS"
//
//	NewPanel/K=1/FLT /N=DRSProgress/W=(285,111,665,175) 
//	TitleBox ProgMsg, variable=ProgressMessage, pos={18, 5}
//	ValDisplay ProgVal,pos={18,32},size={342,18},limits={0,100,0},barmisc={0,0},value=_NUM:0, mode=3
//		
//	DoUpdate/W=DRSProgress/E=1
//	SetWindow DRSProgress, hook(ProgressHook)=ProgressHook
//
//	SetActiveSubwindow _endfloat_ 
//End

//------------------------------------------------------------------------
// Set the progress of the DRS progress bar (p = percent complete, m = message)
//------------------------------------------------------------------------
//Function SetProgress(p, m)
//	Variable p
//	String m
//	NVAR ProgressPercent = root:Packages:VisualAge:ProgressPercent
//	SVAR ProgressMessage = root:Packages:VisualAge:ProgressMessage
//	
//	ProgressPercent = p
//	ProgressMessage = m
//	
//	If (ProgressPercent >= 100 || CheckName("ProgVal", 15, "DRSProgress") == 0)
//		KillVariables/Z ProgressPercent
//		KillStrings/Z ProgressMessage
//		KillWindow DRSProgress
//		Return 1		
//	Else
//		ValDisplay ProgVal,value= _NUM:ProgressPercent,win=DRSProgress
//		TitleBox ProgMSG, title=ProgressMessage, win=DRSProgress
//		DoUpdate/W=DRSProgress
//	EndIf	
//
//	Return 0
//End

//------------------------------------------------------------------------
// Hook function for progress dialog
//------------------------------------------------------------------------
//Function ProgressHook(s) 
//	STRUCT WMWinHookStruct &s
//	
//	NVAR ProgressPercent = root:Packages:VisualAge:ProgressPercent
//	SVAR ProgressMessage = root:Packages:VisualAge:ProgressMessage
//	
//	Switch (s.eventCode)
//		Case 2: // killed
//			KillVariables/Z ProgressPercent
//			KillStrings/Z ProgressMessage
//			KillWindow DRSProgress
//			Return 0
//			Break
//	EndSwitch
//	Return 0
//End

//------------------------------------------------------------------------
// Try to determine if a string is alpha numeric to the extent that it can be used as an Igor name
//------------------------------------------------------------------------
Function AlphaNumeric(inStr)
	String inStr
	
	Variable i
	For (i = 0; i < strlen(inStr); i = i + 1)
		Variable curChar = char2num(inStr[i])
		
		// Small leters:
		If (curChar >= 97 && curChar <=122)
			Continue
		// Capitol letters:
		Elseif (curChar >=65 && curChar <=90)
			Continue
		// Numbers:
		Elseif (curChar >=48 && curChar <=57)
			Continue
		// Underscore:
		Elseif (curChar == 95)
			Continue
		Else
			Return 0
		EndIf
	EndFor
	
	Return 1	
End

//------------------------------------------------------------------------
// Constructs a wave that for each time slice is 0 if no integration exists or > 0 otherwise
// The specific value depends on which integrations types exist at the given index, see below.
//------------------------------------------------------------------------
Function GenerateIntegrationIndex(IndexFolder)
	String IndexFolder
	
	String IntNames = GetListOfUsefulIntegrations()
	
	Variable startTime, stopTime, startIndex, stopIndex
	Wave Index_Time = $ioliteDFpath("CurrentDRS", "Index_Time")
	
	Make/N=(numpnts(Index_Time))/O $(IndexFolder + ":IntInd")
	Wave IntInd = $(IndexFolder + ":IntInd")
	IntInd = 0
	
	Variable c
	For (c = 0; c < ItemsInList(IntNames); c = c + 1)
	
		Wave aim = $ioliteDFpath("integration", "m_" + StringFromList(c, IntNames))
		Variable NoOfIntegrations = DimSize(aim,0)-1
		
		Variable j
		For (j = 1; j <= NoOfIntegrations; j = j + 1)
		
			startTime = aim[j][0][%$"Median Time"]-aim[j][0][%$"Time Range"]
			stopTime = aim[j][0][%$"Median Time"]+aim[j][0][%$"Time Range"]
	
			startIndex = ForBinarySearch(Index_Time, startTime) + 1
			If (numtype(Index_Time[startIndex]) == 2)
				startIndex += 1
			EndIf
	
			stopIndex = ForBinarySearch(Index_Time, stopTime)
			If (stopIndex == -2)
				stopIndex = numpnts(Index_Time) - 1
			EndIf
			

			Variable k
			For ( k = startIndex; k < stopIndex; k = k + 1)	
				IntInd[k] += 2^c
			EndFor
			
		EndFor
	EndFor
End

//------------------------------------------------------------------------
// Calculates an "index" for the given Integration name. This is done in binary so,
// If we have a list of integrations, e.g., Output_1;JoesIntegrations;Z_91500,
// Then Output_1 would be 1, JoesIntegrations would be 2, and Z_91500 would be 4
//------------------------------------------------------------------------
Function GetIntInd(IntName)
	String IntName
	
	String IntNames = GetListOfUsefulIntegrations()
	
	Variable c
	For (c = 0; c < ItemsInList(IntNames); c = c + 1)
		If ( cmpstr(IntName, StringFromList(c, IntNames)) == 0 )
			Return 2^c
		EndIf
	EndFor
	Return -1
End

Function/S GetMatrixName()

	SVAR MatrixName = root:Packages:iolite:traces:MatrixName

	If (GrepString(ks_VersionOfThisIcpmsPackage, "(?i)3."))
		String CurrentTab = GetUserData("IoliteMainWindow", "", "currentTab" )
		//Get current tab name
		Wave/T SettingsWave = $IoliteDFpath("IoliteGlobals", "TabSettings_" + CurrentTab) //Current settings wave
		Return SettingsWave[7]
	Else 
		Return MatrixName
	EndIf
End

Function GetActiveIntNum()

	If (GrepString(ks_VersionOfThisIcpmsPackage, "(?i)3."))
		NVAR ActiveIntNum = root:Packages:iolite:Globals:ActiveSelectionMatrixRow
	Else
		NVAR ActiveIntNum = root:Packages:iolite:traces:IntegNumber
	EndIf
	
	Return ActiveIntNum
End