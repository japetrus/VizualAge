#pragma rtGlobals=1		// Use modern global access method. - Leave this line as is, as 1st line!
#pragma ModuleName= Iolite_ActiveDRS  	//Leave this line as is, as 2nd line!
	StrConstant DRS_Version_No= "2015.06"  	//Leave this line as is, as 3rd line!
	//****End of Header Lines - do not disturb anything above this line!****


	//****The global strings (SVar) and variables (NVar) below must always be present. Do not alter their names, alter only text to the right of the "=" on each line.**** (It is important that this line is left unaltered)
	GlobalString				IndexChannel 						="U238"
	GlobalString				ReferenceStandard 					="Z_91500"
	GlobalString				DefaultIntensityUnits				="CPS"
	//**** Below are some optional global strings and variables with pre-determined behaviour. If you wish to include these simply remove the two "//" at the beginning of the line. Similarly, if you wish to omit them, simply comment them using "//"
	GlobalString				BeamSecondsMethod				= "Rate of Change"
	GlobalVariable			BeamSecondsSensitivity				=1
	GlobalString				CurveFitType						="Exponential"
	GlobalVariable			MaskThreshold 						=1000
	GlobalVariable			MaskEdgeDiscardSeconds 			=1
	//**** Any global strings or variables you wish to use in addition to those above can be placed here. You may name these how you wish, and have as many or as few as you like**** (It is important that this line is left unaltered)
	GlobalVariable			Sample238_235Ratio	 			=137.88
	GlobalVariable			DefaultStartMask			 		=0
	GlobalVariable			DefaultEndMask			 			=0
	GlobalVariable			MaxBeamDuration			 		=60
	GlobalVariable			FitOutlierTolerance		 			=1.5
	GlobalString				Ignore_235U			 			="Yes"
	//**** If you'd like to set up some preferred settings for the report window you can set these here too
	GlobalString				Report_DefaultChannel				="Final206_238"
	GlobalString				Report_AverageMethod				="weighted (2 S.E.)"
	GlobalString				Report_UncertaintyMethod			="2 S.E. (absolute)"
	GlobalString				Report_OutlierMethod				="None"
	//**** End of optional global strings and variables**** (It is important that this line is left unaltered)
	//certain optional globals are built in, and have pre-determined lists. these are currently: "StandardisationMethod", "OutputUnits"
	//Note that the above values will be the initial values every time the DRS is opened for the first time, but can then be overwritten for that experiment after that point via the button "Edit DRS Variables". This means that the settings for the above will effectively be stored within the experiment, and not this DRS (this is a good thing)
	//DO NOT EDIT THE ABOVE IF YOU WISH TO EDIT THESE VALUES WITHIN A PARTICULAR EXPERIMENT. THESE ARE THE STARTING VALUES ONLY. THEY WILL ONLY BE LOOKED AT ONCE WHEN THE DRS IS OPENED FOR THE FIRST TIME (FOR A GIVEN EXPERIMENT).


	//**** Initialisation routine for this DRS.  Will be called each time this DRS is selected in the "Select DRS" popup menu (i.e. usually only once).
Function InitialiseActiveDRS() //If init func is required, this line must be exactly as written.   If init function is not required it may be deleted completely and a default message will print instead at initialisation.
	SVAR nameofthisDRS=$ioliteDFpath("Output","S_currentDRS") //get name of this DRS (which should have been already stored by now)

	//###########################################################	
  	// JAP
	Print "DRS initialised:  VizualAge U(Th)Pb zircon laser ablation module for ICP-MS, \"" + nameofthisDRS + "\", Version " + DRS_Version_No + "\r"
  
  	// Initialize VisualAge
	If (strlen(FunctionInfo("VAInit")) == 0)
		printabort("VisualAge isn't loaded!")
	Else
		Execute "VAInit()" 
	EndIf
	// !JAP
	//###########################################################	
End //**end of initialisation routine


//###########################################################	
// JAP
// Function used to make a 204Hg wave if all we have is a 204Pb wave
Function MakeHgWave()
	Wave Pb204 = $ioliteDFPath("input", "Pb204")
	Wave Pb204_time = $ioliteDFPath("input", "Pb204_time")
	Variable NoOfPoints = numpnts(Pb204)
	Wave Hg204 = $makeioliteWave("input", "Hg204", n=NoOfPoints)//$IoliteDFPath("input", "Hg204")
	Wave Hg204_time = $makeioliteWave("input", "Hg204_time", n = NoOfPoints)
	Redimension/D Hg204
	Redimension/D Hg204_time
	Hg204_time = Pb204_time
	Hg204 = Pb204
	SVAR ListOfInputChannels=$ioliteDFpath("input","GlobalListOfInputChannels") //Get reference to "GlobalListOfInputChannels", in the Input folder, and is a list of the form "ChannelName1;ChannelName2;..."
	ListOfInputChannels = RemoveFromList("Hg204", ListOfInputChannels)
	ListOfInputChannels += "Hg204;"
End

Function CalculateDose()

	Wave Uppm = $ioliteDFpath("CurrentDRS", "Approx_U_PPM")
	Wave Thppm = $ioliteDFpath("CurrentDRS", "Approx_Th_PPM")
	
	Wave FinalAge206_238 = $iolitedfpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge207_206 = $iolitedfpath("CurrentDRS", "FinalAge207_206")
	
	Variable Npts = numpnts(Uppm)

	Wave Dose = $makeiolitewave("CurrentDRS", "Dose", n = Npts)
	
	// Loop through each time slice:
	Variable N238, N235, N232
	Variable l235 = 9.8485e-10
	Variable l238 = 1.55125e-10
	Variable l232 = 0.49475e-10
	Variable k = 137.88	
	Variable ct = 0
	Variable Navo = 6.0221413E+23
	
	Variable i
	For( i = 0; i < Npts; i = i + 1 )
		N238 = 0.001*Uppm[i]*1e-6*Navo/238
		N235 = 0.001*(Uppm[i]/k)*1e-6*Navo/235
		N232 = 0.001*Thppm[i]*1e-6*Navo/232
		
		ct = FinalAge206_238[i]
		If (ct > 2000)
			ct = FinalAge207_206[i]
		EndIf
		
		Dose[i] = 8*N238*(exp(l238*ct*1e6)-1) + 7*N235*(exp(l235*ct*1e6)-1) + 6*N232*(exp(l232*ct*1e6)-1)
		
	EndFor		
	SVAR ListOfOutputChannels=$ioliteDFpath("Output","ListOfOutputChannels") 
	ListOfOutputChannels = RemoveFromList("Dose", ListOfOutputChannels)
	ListOfOutputChannels += "Dose;"
End

// !JAP
//###########################################################	

//****Start of actual Data Reduction Scheme.  This is run every time raw data is added or the user presses the "crunch data" button.  Try to keep it to no more than a few seconds run-time!
Function RunActiveDRS() //The DRS function name must be exactly as written here.  Enter the function body code below.
	
	ProgressDialog()		//Start progress indicator
	
	//the next 5 lines reference all of the global strings and variables in the header of this file for use in the main code of the DRS that follows.
	string currentdatafolder = GetDataFolder(1)
	setdatafolder $ioliteDFpath("DRSGlobals","")
	SVar IndexChannel, ReferenceStandard, DefaultIntensityUnits, UseOutlierRejection, BeamSecondsMethod, CurveFitType, Ignore_235U
	NVar MaskThreshold, MaskEdgeDiscardSeconds, BeamSecondsSensitivity, MaxBeamDuration, DefaultStartMask, DefaultEndMask, FitOutlierTolerance, Sample238_235Ratio
	setdatafolder $currentdatafolder
	//convert the long names of CurveFitType in the user interface into short labels
	string ShortCurveFitType
	string UserInterfaceList = "Exponential plus optional linear;Linear;Exponential;Double exponential;Smoothed cubic spline;Running median"
	string ShortLabelsList = "LinExp;Lin;Exp;DblExp;Spline;RunMed"
	ShortCurveFitType = StringFromList(WhichListItem(CurveFitType, UserInterfaceList, ";", 0, 0), ShortLabelsList, ";")	//this line extracts the short label corresponding to the user interface label in the above string.
	if(cmpstr(ShortCurveFitType, "") == 0)	//if for some reason the above substitution didn't work, then need to throw an error, as that will have to be fixed
		printabort("Sorry, the DRS failed to recognise the down-hole fractionation model you chose")
	endif
	//Do we have a baseline_1 spline for the index channel, as require this to proceed further?
	DRSabortIfNotWave(ioliteDFpath("Splines", IndexChannel+"_Baseline_1"))	//Abort if [index]_Baseline_1 is not in the Splines folder, otherwise proceed with DRS code below..
	
	SetProgress(5, "Starting baseline subtraction...")
	
	//Next, create a reference to the Global list of Output channel names, which must contain the names of all outputs produced by this routine, and to the inputs 
	SVAR ListOfOutputChannels=$ioliteDFpath("Output","ListOfOutputChannels") //"ListOfOutputChannels" is already in the Output folder, and will be empty ("") prior to this function being called.
	SVAR ListOfIntermediateChannels=$ioliteDFpath("Output","ListOfIntermediateChannels")
	SVAR ListOfInputChannels=$ioliteDFpath("input","GlobalListOfInputChannels") //Get reference to "GlobalListOfInputChannels", in the Input folder, and is a list of the form "ChannelName1;ChannelName2;..."
	//Now create the global time wave for intermediate and output waves, based on the index isotope  time wave  ***This MUST be called "index_time" as some or all export routines require it, and main window will look for it
	wave Index_Time = $MakeIndexTimeWave()	//create the index time wave using the external function - it tries to use the index channel, and failing that, uses total beam
	variable NoOfPoints=numpnts(Index_Time) //Make a variable to store the total number of time slices for the output waves

	//THIS DRS IS A SPECIAL CASE, and has been built to allow a 'partial' data crunch, beginning after the downhole correction of ratios
	NVar OptionalPartialCrunch = $ioliteDFpath("CurrentDRS","OptionalPartialCrunch")
	if(NVar_Exists(OptionalPartialCrunch)!=1)	//if the OptionalPartialCrunch NVar doesn't exist yet then make it here. this will only happen once, the first time the DRS is crunched
		variable/g $ioliteDFpath("CurrentDRS","OptionalPartialCrunch") = 0	//so make the global variable and set it to 0
		NVar OptionalPartialCrunch = $ioliteDFpath("CurrentDRS","OptionalPartialCrunch")	//and reference it
	endif
	//The below Svar is used throughout the DRS, so place it outside the below if command
	String/g $ioliteDFpath("CurrentDRS","Measured_UPb_Inputs")
	SVar Measured_UPb_Inputs = $ioliteDFpath("CurrentDRS","Measured_UPb_Inputs")
	if(OptionalPartialCrunch!=1)	//if this is a normal crunch data then do all of this stuff, otherwise skip to the 'else' after DownHoleCurveFit()
		wave IndexOut = $InterpOntoIndexTimeAndBLSub(IndexChannel)	//Make an output wave for Index isotope (as baseline-subtracted intensity)
		//baseline subtract all input channels. will sieve out the U Pb ones specifically afterwards
		variable CurrentChannelNo
		CurrentChannelNo = 0
		variable NoOfChannels
		NoOfChannels = itemsinlist(ListOfInputChannels) //Create local variables to hold the current input channel number and the total number of input channels
		String NameOfCurrentChannel
		String CurrentElement //Create a local string to contain the name of the current channel, and its corresponding element
		Do //Start to loop through the available channels
			NameOfCurrentChannel=StringFromList(CurrentChannelNo,ListOfInputChannels) //Get the name of the nth channel from the input list
			//Can no longer use the below test, as some inputs from multicollectors are too complex and will not be recognised as elements
			//CurrentElement=GetElementFromIsotope(NameOfCurrentChannel) //get name of the element
			if(cmpstr(NameOfCurrentChannel, IndexChannel)!=0) //if this element is not "null" (i.e. is an element), and it is not the index isotope, then..
				wave ThisChannelBLsub = $InterpOntoIndexTimeAndBLSub(NameOfCurrentChannel)		//use this external function to interpolate the input onto index_time then subtract it's baseline
				ListOfIntermediateChannels+=NameOfCurrentChannel+"_" + DefaultIntensityUnits +";" //Add the name of this new output channel to the list of outputs
			endif //Have now created a (baseline-subtracted channel) output wave for the current input channel, unless it was TotalBeam or index
			
			SetProgress(5+((CurrentChannelNo+1)/NoOfChannels)*10,"Processing baselines")	//Update progress for each channel
			
			CurrentChannelNo+=1 //So move the counter on to the next channel..
		While(CurrentChannelNo<NoOfChannels) //..and continue to loop until the last channel has been processed.
		ListOfIntermediateChannels+=IndexChannel+"_"+DefaultIntensityUnits+";" //Add the name of this new output channel to the list of outputs
		//Now all baseline subtracted waves have been created.
		
		//###########################################################	
		// JAP
		// Do 204Pb = 204Total - F*202Hg
		// where F is the ratio of 204Hg/202Hg determined from the baseline
		Print "Checking if Hg correction should be applied..."
		If (FindListItem("Hg204", ListOfInputChannels) != -1 && FindListItem("Pb204", ListOfInputChannels) != -1)
			Print "Doing Hg correction..."
			Wave Hg204 = $IoliteDFPath("input", "Hg204")
			Wave Hg202 = $IoliteDFPath("input", "Hg202")
			Wave Pb204 = $ioliteDFPath("input", "Pb204")	
		
			Wave Hg204_Spline = $InterpSplineOntoIndexTime("Hg204", "Baseline_1")
			Wave Hg202_Spline = $InterpSplineOntoIndexTime("Hg202", "Baseline_1")
		
			Wave HgRatio = $MakeIoliteWave("CurrentDRS", "HgRatio", n=NoOfPoints)
			HgRatio = Hg204_Spline/Hg202_Spline
	
			// Use this line to use the determined HgRatio spline:
			Pb204 = Hg204 - HgRatio*Hg202
		
			// Use this line to use the expected Hg ratio:
			//Pb204 = Hg204 - 0.22987*Hg202
	
		EndIf
		// !JAP		
		//###########################################################	

		//make a mask for ratios, don't put it on baseline subtracted intermediates, as the full range is useful on these.	
		Wave MaskLowCPSBeam=$DRS_CreateMaskWave(IndexOut,MaskThreshold,MaskEdgeDiscardSeconds,"MaskLowCPSBeam","StaticAbsolute")  //This mask currently removes all datapoints below 1000 CPS on U238, with a sideways effect of 1 second.
		//The below function is called to detect which inputs are present - the format of the inputs can vary depending on the machine used to acquire the data.
		//the function returns a list of the inputs in ascending mass order, with 204 at the very end if present. The list can then be used below to reference the waves in this function
		//As part of the below function that detects a variety of input channel names (they vary depending on the mass spec used), make a global string to use as a reference of which Hg, Pb, Th, U isotopes have been measured (using a key=value; system)
		Measured_UPb_Inputs = "200=no;202=no;204=no;206=no;207=no;208=no;232=no;235=no;238=no;"
		//the "no" values in this string will be replaced by the name of the input channel for each isotope that was measured
		VAGenerateUPbInputsList(ListOfIntermediateChannels)
		//Now have a key=value string storing either "no" if a channel wasn't measured, or the name of the channel if it was, e.g. "200=no;202=no;204=no;206=Pb206;207=Pb207;208=Pb208;232=Th232;235=no;238=U238;"
		//can now use this string to reference the relevant baseline-subtracted waves
		//At its most basic level this DRS will expect at least Pb 206 and U238. The below lines check if these two are present, and report a failure if they're not
		if(cmpstr(StringByKey("206", Measured_UPb_Inputs, "=", ";", 0), "no") ==0 || cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") ==0)
			printabort("It appears that 206Pb or U238 were not measured. The DRS requires that as a minimum these two isotopes were measured.")
		endif
		//In addition to the key=value string used above, want to make flags for which ratios can be calculated - these can then be used throughout the rest of the DRS (note that 204 uses a separate flag)
		variable/G $ioliteDFpath("CurrentDRS","Calculate_206_238")
		variable/G $ioliteDFpath("CurrentDRS","Calculate_207_235")
		variable/G $ioliteDFpath("CurrentDRS","Calculate_208_232")
		variable/G $ioliteDFpath("CurrentDRS","Calculate_207_206")
		variable/G $ioliteDFpath("CurrentDRS","Calculate_206_208")
		NVar Calculate_206_238 = $ioliteDFpath("CurrentDRS","Calculate_206_238")
		NVar Calculate_207_235 = $ioliteDFpath("CurrentDRS","Calculate_207_235")
		NVar Calculate_208_232 = $ioliteDFpath("CurrentDRS","Calculate_208_232")
		NVar Calculate_207_206 = $ioliteDFpath("CurrentDRS","Calculate_207_206")
		NVar Calculate_206_208 = $ioliteDFpath("CurrentDRS","Calculate_206_208")
		//Now set each one, depending on whether the required waves are present (for both UPb ratios check using 238, with the assumption that it will always be available and ok to use, even if 235 wasn't measured)
		Calculate_206_238 = (cmpstr(StringByKey("206", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		Calculate_207_235 = (cmpstr(StringByKey("207", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		Calculate_208_232 = (cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		Calculate_207_206 = (cmpstr(StringByKey("207", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("206", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		Calculate_206_208 = (cmpstr(StringByKey("206", Measured_UPb_Inputs, "=", ";", 0), "no") !=0 && cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") !=0)? 1 : 0
		//Now start referencing the isotopes used in ratio calculation
		string ThisChannelName	//(re-use this string for each of the channels below)
		//Hg200
		ThisChannelName = StringByKey("200", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Hg200_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Hg202
		ThisChannelName = StringByKey("202", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Hg202_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Pb204
		ThisChannelName = StringByKey("204", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Pb204_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Pb206
		ThisChannelName = StringByKey("206", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Pb206_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Pb207
		ThisChannelName = StringByKey("207", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Pb207_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Pb208
		ThisChannelName = StringByKey("208", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Pb208_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//Th232
		ThisChannelName = StringByKey("232", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave Th232_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//U235
		ThisChannelName = StringByKey("235", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave U235_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//U238
		ThisChannelName = StringByKey("238", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)
			Wave U238_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		endif
		//have now referenced all relevant channels that have been measured
		//Now as a last check, just confirm that 206 and 238 do not have zero point waves
		if((numpnts(Pb206_Beam)==0)||(numpnts(U238_Beam)==0))
			abort "One of the Pb, Th, or U channels are empty or missing, things are going to end badly..."
		endif
		//now check if a 204 beam has been measured and set a flag appropriately so that it can be used elsewhere
		variable Was204Measured
		ThisChannelName = StringByKey("204", Measured_UPb_Inputs, "=", ";", 0)
		if(cmpstr(ThisChannelName, "no") != 0)	//if 204 was measured
			//set the flag to 1
			Was204Measured = 1
			//and reference the relevant wave
			wave Pb204_Beam = $ioliteDFpath("CurrentDRS", ThisChannelName)
		else	//otherwise set the flag to 0
			Was204Measured = 0
		endif
		//now, if 204 has been measured, the flag will be set to 1 and the wave has been referenced, otherwise it will be set to 0

		SetProgress(20,"Calculating raw ratios...")	//Update progress for each channel

		if(Calculate_206_238 == 1)
			Wave Raw_206_238=$MakeioliteWave("CurrentDRS","Raw_206_238",n=NoOfPoints)
			Raw_206_238 = Pb206_Beam/U238_Beam * MaskLowCPSBeam
			Wave Raw_Age_206_238=$MakeioliteWave("CurrentDRS","Raw_Age_206_238",n=NoOfPoints)
			Raw_Age_206_238 = Ln(Raw_206_238 + 1) / 0.000155125
			ListOfIntermediateChannels+="Raw_206_238;Raw_Age_206_238;"
		endif
		if(Calculate_207_235 == 1)
			Wave Raw_207_235=$MakeioliteWave("CurrentDRS","Raw_207_235",n=NoOfPoints)
			if(waveexists(U235_Beam) == 1 && cmpstr(Ignore_235U, "No") == 0)
				Raw_207_235 = Pb207_Beam/U235_Beam * MaskLowCPSBeam
			else
				Raw_207_235 = Pb207_Beam/U238_Beam * Sample238_235Ratio * MaskLowCPSBeam
			endif
			Wave Raw_Age_207_235=$MakeioliteWave("CurrentDRS","Raw_Age_207_235",n=NoOfPoints)
			Raw_Age_207_235 = Ln((Raw_207_235) + 1) / 0.00098485
			ListOfIntermediateChannels+="Raw_207_235;Raw_Age_207_235;"
		endif
		if(Calculate_208_232 == 1)
			Wave Raw_208_232=$MakeioliteWave("CurrentDRS","Raw_208_232",n=NoOfPoints)
			Raw_208_232 = Pb208_Beam/Th232_Beam * MaskLowCPSBeam
			Wave Raw_Age_208_232=$MakeioliteWave("CurrentDRS","Raw_Age_208_232",n=NoOfPoints)
			Raw_Age_208_232 = Ln(Raw_208_232 + 1) / 0.000049475
			ListOfIntermediateChannels+="Raw_208_232;Raw_Age_208_232;"
		endif
		if(Calculate_207_206 == 1)
			//Call the function that will generate a lookup table to be used in calculating 207/206 ages
			VAGenerate207206LookupTable()
			Wave Raw_207_206=$MakeioliteWave("CurrentDRS","Raw_207_206",n=NoOfPoints)
			Raw_207_206 = Pb207_Beam/Pb206_Beam * MaskLowCPSBeam
			Wave Raw_Age_207_206=$MakeioliteWave("CurrentDRS","Raw_Age_207_206",n=NoOfPoints)
			wave LookupTable_76 = $ioliteDFpath("CurrentDRS","LookupTable_76")
			wave LookupTable_age = $ioliteDFpath("CurrentDRS","LookupTable_age")
			Raw_Age_207_206 = interp(Raw_207_206, LookupTable_76, LookupTable_age)
			ListOfIntermediateChannels+="Raw_207_206;Raw_Age_207_206;"
		endif
		if(Calculate_206_208 == 1)
			Wave Raw_206_208=$MakeioliteWave("CurrentDRS","Raw_206_208",n=NoOfPoints)
			Raw_206_208 = Pb206_Beam/Pb208_Beam * MaskLowCPSBeam
			ListOfIntermediateChannels+="Raw_206_208;"
		endif
		//Now deal with 204 ratios if available
		if(Was204Measured == 1)
			Wave Raw_206_204=$MakeioliteWave("CurrentDRS","Raw_206_204",n=NoOfPoints)
			Raw_206_204 = Pb206_Beam/Pb204_Beam * MaskLowCPSBeam
			ListOfIntermediateChannels+="Raw_206_204;"
			if(waveexists(Pb207_Beam) == 1)
				Wave Raw_207_204=$MakeioliteWave("CurrentDRS","Raw_207_204",n=NoOfPoints)
				Raw_207_204 = Pb207_Beam/Pb204_Beam * MaskLowCPSBeam
				ListOfIntermediateChannels+="Raw_207_204;"
			endif
			if(waveexists(Pb208_Beam) == 1)
				Wave Raw_208_204=$MakeioliteWave("CurrentDRS","Raw_208_204",n=NoOfPoints)
				Raw_208_204 = Pb208_Beam/Pb204_Beam * MaskLowCPSBeam
				ListOfIntermediateChannels+="Raw_208_204;"
			endif
		endif
		//now want to add in a channel for U/Th ratio if both were measured (already know U238 was measured, so only need to check 232)
		if(waveexists(Th232_Beam) == 1)
			Wave Raw_U_Th_Ratio=$MakeioliteWave("CurrentDRS","Raw_U_Th_Ratio",n=NoOfPoints)
			Raw_U_Th_Ratio = (U238_Beam/1.0000)/(Th232_Beam/1.0000) * MaskLowCPSBeam		//currently using simple isotopic ratio here, can convert to elemental using 0.99275 (238U) and XXXXX (232Th)
			ListOfIntermediateChannels+="Raw_U_Th_Ratio;"
		endif
		//Now make the BeamSeconds wave (used as a proxy for hole depth during downhole fractionation correction)
		wave BeamSeconds=$DRS_MakeBeamSecondsWave(IndexOut,BeamSecondsSensitivity, BeamSecondsMethod) //This is determined by an external function which can be fine-tuned using the single sensitivity parameter.  Let me know if it fails!
		ListOfIntermediateChannels+="Beam_Seconds;"
		//up to this point no standard is required. Need to choose at least one standard integration at this point. (e.g. Z_91500)
		//Next, are we ready to proceed to producing the remaining outputs?
		DRSAbortIfNotSpline(StringFromList(0,ListOfIntermediateChannels), ReferenceStandard)
		//		//Have now checked that at least one Z_91500 has been selected, can proceed with the following, which is for down-hole fractionation correction
	
		SetProgress(30,"Starting down-hole curve fit...")	//Update progress for each channel

		//the following lines are for the down-hole correction of ratios
		// JAP
		NVAR HoldDHC = root:Packages:VisualAge:Options:HoldDHC
		
		if(Calculate_208_232 == 1 && HoldDHC == 0)
			VADownHoleCurveFit("Raw_208_232", OptionalWindowNumber = 0)	//the optional window number can be set, if it is it allows the function to stagger the windows so that they don't all overlap completely. if it's missing it defaults to 1
		endif
		if(Calculate_207_235 == 1 && HoldDHC == 0)
			VADownHoleCurveFit("Raw_207_235", OptionalWindowNumber = 1)	//the optional window number can be set, if it is it allows the function to stagger the windows so that they don't all overlap completely. if it's missing it defaults to 1
		endif
		if(Calculate_206_238 == 1 && HoldDHC == 0)
			VADownHoleCurveFit("Raw_206_238", OptionalWindowNumber = 2)	//the optional window number can be set, if it is it allows the function to stagger the windows so that they don't all overlap completely. if it's missing it defaults to 1
		endif
		// !JAP
		//Note that the reverse order of the ratios here just means that the topmost graph is the most commonly used (i.e. 6/38 ratio)
		//NOTE: Although it may be confusing and is not a particularly nice solution, it is necessary to add waves to the list of intermediates and outputs here so that they won't be duplicated unnecessarily during a partial data crunch
		//This is an unnecessarily long list, but is done this way in order to produce the desired order for the output channels
		if(Calculate_207_235 == 1)
			ListOfIntermediateChannels+="DC207_235;"
			ListOfOutputChannels+="Final207_235;"
		endif
		if(Calculate_206_238 == 1)
			ListOfIntermediateChannels+="DC206_238;"
			ListOfOutputChannels+="Final206_238;"
		endif
		if(Calculate_207_206 == 1)
			ListOfIntermediateChannels+="DC207_206;"
			ListOfOutputChannels+="Final207_206;"
		endif
		if(Calculate_208_232 == 1)
			ListOfIntermediateChannels+="DC208_232;"
			ListOfOutputChannels+="Final208_232;"
		endif
		if(Calculate_206_208 == 1)
			ListOfIntermediateChannels+="DC206_208;"
			ListOfOutputChannels+="Final206_208;"
		endif
		if(Calculate_207_235 == 1)
			ListOfIntermediateChannels+="DCAge207_235;"
			ListOfOutputChannels+="FinalAge207_235;"
		endif
		if(Calculate_206_238 == 1)
			ListOfIntermediateChannels+="DCAge206_238;"
			ListOfOutputChannels+="FinalAge206_238;"
		endif
		if(Calculate_208_232 == 1)
			ListOfIntermediateChannels+="DCAge208_232;"
			ListOfOutputChannels+="FinalAge208_232;"
		endif
		if(Calculate_207_206 == 1)
			ListOfIntermediateChannels+="DCAge207_206;"
			ListOfOutputChannels+="FinalAge207_206;"
		endif
		if(Was204Measured == 1)		//if 204 was measured
			ListOfIntermediateChannels+="DC206_204;"
			ListOfOutputChannels+="Final206_204;"
			if(waveexists(Pb207_Beam) == 1)
				ListOfIntermediateChannels+="DC207_204;"
				ListOfOutputChannels+="Final207_204;"
			endif
			if(waveexists(Pb208_Beam) == 1)
				ListOfIntermediateChannels+="DC208_204;"
				ListOfOutputChannels+="Final208_204;"
			endif
		endif
		//now want to add in channels for U, Th, Pb abundances
		if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
			ListOfOutputChannels+="Approx_U_PPM;"
		endif
		if(cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
			ListOfOutputChannels+="Approx_Th_PPM;"
		endif
		if(cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
			ListOfOutputChannels+="Approx_Pb_PPM;"
		endif
		if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0 && cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
			ListOfOutputChannels+="FInal_U_Th_Ratio;"
		endif
	//THIS IS A BIG ELSE. The following occurs if a 'partial' crunch data has been chosen. Any waves used below need to be referenced here
	else	
		//Allow all waves to be referenced, even if some don't exist
		Wave Raw_206_238=$ioliteDFpath("CurrentDRS","Raw_206_238")
		Wave Raw_207_235=$ioliteDFpath("CurrentDRS","Raw_207_235")
		Wave Raw_208_232=$ioliteDFpath("CurrentDRS","Raw_208_232")
		Wave Raw_207_206=$ioliteDFpath("CurrentDRS","Raw_207_206")
		Wave Raw_206_208=$ioliteDFpath("CurrentDRS","Raw_206_208")
		wave BeamSeconds=$ioliteDFpath("CurrentDRS", "Beam_Seconds")
	endif	//everything after here will be executed during both the 'partial' and normal data crunches
	OptionalPartialCrunch = 0	//Important: the first thing is to set the optional crunch back to the default of a full data crunch.
	if(Calculate_206_238 == 1)
		Wave DC206_238=$MakeioliteWave("CurrentDRS","DC206_238",n=NoOfPoints)
		Wave DCAge206_238=$MakeioliteWave("CurrentDRS","DCAge206_238",n=NoOfPoints)
	endif
	if(Calculate_207_235 == 1)
		Wave DC207_235=$MakeioliteWave("CurrentDRS","DC207_235",n=NoOfPoints)
		Wave DCAge207_235=$MakeioliteWave("CurrentDRS","DCAge207_235",n=NoOfPoints)
	endif
	if(Calculate_208_232 == 1)
		Wave DC208_232=$MakeioliteWave("CurrentDRS","DC208_232",n=NoOfPoints)
		Wave DCAge208_232=$MakeioliteWave("CurrentDRS","DCAge208_232",n=NoOfPoints)
	endif
	string CoefficientWaveName, ratio, SmoothWaveName, SplineWaveName, AverageBeamSecsName	//various strings required by the different fit types below
	strswitch(ShortCurveFitType)
		case "LinExp":
			if(Calculate_206_238 == 1)
				ratio = "Raw_206_238"
				CoefficientWaveName = "LECoeff_" + ratio
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				NVar Variable_b = $ioliteDFpath("CurrentDRS","LEVarB_"+ratio)	//variable b is the linear component of the equation
				DC206_238 = Raw_206_238 /  (1 + (Variable_b/Coefficients[0])*BeamSeconds + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			if(Calculate_207_235 == 1)
				ratio = "Raw_207_235"
				CoefficientWaveName = "LECoeff_" + ratio
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				NVar Variable_b = $ioliteDFpath("CurrentDRS","LEVarB_"+ratio)	//variable b is the linear component of the equation
				DC207_235 = Raw_207_235 /  (1 + (Variable_b/Coefficients[0])*BeamSeconds + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			if(Calculate_208_232 == 1)
				ratio = "Raw_208_232"
				CoefficientWaveName = "LECoeff_" + ratio
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				NVar Variable_b = $ioliteDFpath("CurrentDRS","LEVarB_"+ratio)	//variable b is the linear component of the equation
				DC208_232 = Raw_208_232 /  (1 + (Variable_b/Coefficients[0])*BeamSeconds + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			break
		case "Exp":
			if(Calculate_206_238 == 1)
				CoefficientWaveName = "ExpCoeff_" + "Raw_206_238"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC206_238 = Raw_206_238 /  (1+(Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))//this equation is trying to change the magnitude of the original std wave to equal 1 at beamseconds = infinity, otherwise it will alter the ratios depending on the value obtained for the standard (could exploit this by factoring in a simultaneous drift correction?)
			endif
			if(Calculate_207_235 == 1)
				CoefficientWaveName = "ExpCoeff_" + "Raw_207_235"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC207_235 = Raw_207_235 /  (1+(Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			if(Calculate_208_232 == 1)
				CoefficientWaveName = "ExpCoeff_" + "Raw_208_232"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC208_232 = Raw_208_232 /  (1+(Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds))
			endif
			break
		case "DblExp":
			if(Calculate_206_238 == 1)
				CoefficientWaveName = "DblExpCoeff_" + "Raw_206_238"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC206_238 = Raw_206_238 /  (1 + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds) + (Coefficients[3]/Coefficients[0])*Exp(-Coefficients[4]*BeamSeconds))//this equation (y = K0+K1*exp(-K2*x)+K3*exp(-K4*x)) is trying to change the magnitude of the original std wave to equal 1 at beamseconds = infinity
			endif
			if(Calculate_207_235 == 1)
				CoefficientWaveName = "DblExpCoeff_" + "Raw_207_235"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC207_235 = Raw_207_235 /  (1 + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds) + (Coefficients[3]/Coefficients[0])*Exp(-Coefficients[4]*BeamSeconds))//this equation (y = K0+K1*exp(-K2*x)+K3*exp(-K4*x)) is trying to change the magnitude of the original std wave to equal 1 at beamseconds = infinity
			endif
			if(Calculate_208_232 == 1)
				CoefficientWaveName = "DblExpCoeff_" + "Raw_208_232"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC208_232 = Raw_208_232 /  (1 + (Coefficients[1]/Coefficients[0])*Exp(-Coefficients[2]*BeamSeconds) + (Coefficients[3]/Coefficients[0])*Exp(-Coefficients[4]*BeamSeconds))//this equation (y = K0+K1*exp(-K2*x)+K3*exp(-K4*x)) is trying to change the magnitude of the original std wave to equal 1 at beamseconds = infinity
			endif
			break
		case "Lin":
			if(Calculate_206_238 == 1)
				CoefficientWaveName = "LinCoeff_" + "Raw_206_238"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC206_238 = Raw_206_238 /  (1+(Coefficients[1]/Coefficients[0])*BeamSeconds)//this equation is trying to change the magnitude of the original std wave to equal 1 at beamseconds = 0, otherwise it will alter the ratios depending on the value obtained for the standard (could exploit this by factoring in a simultaneous drift correction?)
			endif
			if(Calculate_207_235 == 1)
				CoefficientWaveName = "LinCoeff_" + "Raw_207_235"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC207_235 = Raw_207_235 /  (1+(Coefficients[1]/Coefficients[0])*BeamSeconds)
			endif
			if(Calculate_208_232 == 1)
				CoefficientWaveName = "LinCoeff_" + "Raw_208_232"
				wave Coefficients = $ioliteDFpath("CurrentDRS",CoefficientWaveName)
				DC208_232 = Raw_208_232 /  (1+(Coefficients[1]/Coefficients[0])*BeamSeconds)
			endif
			break
		case "RunMed":
			if(Calculate_206_238 == 1)
				ratio = "Raw_206_238"
				SmoothWaveName = "SmthFitCurve_"+Ratio
				wave SmoothedWave = $ioliteDFpath("CurrentDRS",SmoothWaveName)
				wave AverageBeamSeconds = $ioliteDFpath("CurrentDRS","AverageBeamSecs_"+ratio)
				DC206_238 = Raw_206_238 / ForInterp(Beamseconds, AverageBeamSeconds, SmoothedWave) * SmoothedWave[0]
			endif
			if(Calculate_207_235 == 1)
				ratio = "Raw_207_235"
				SmoothWaveName = "SmthFitCurve_"+Ratio
				wave SmoothedWave = $ioliteDFpath("CurrentDRS",SmoothWaveName)
				wave AverageBeamSeconds = $ioliteDFpath("CurrentDRS","AverageBeamSecs_"+ratio)
				DC207_235 = Raw_207_235 / ForInterp(Beamseconds, AverageBeamSeconds, SmoothedWave) * SmoothedWave[0]
			endif
			if(Calculate_208_232 == 1)
				ratio = "Raw_208_232"
				SmoothWaveName = "SmthFitCurve_"+Ratio
				wave SmoothedWave = $ioliteDFpath("CurrentDRS",SmoothWaveName)
				wave AverageBeamSeconds = $ioliteDFpath("CurrentDRS","AverageBeamSecs_"+ratio)
				DC208_232 = Raw_208_232 / ForInterp(Beamseconds, AverageBeamSeconds, SmoothedWave) * SmoothedWave[0]
			endif
			break
		case "Spline":
			if(Calculate_206_238 == 1)
				ratio = "Raw_206_238"
				SplineWaveName = "SplineCurve_"+Ratio
				wave SplineWave = $ioliteDFpath("CurrentDRS",SplineWaveName)
				wave SplineBeamSeconds = $ioliteDFpath("CurrentDRS","SplineBeamSecs_"+ratio)	//note that the spline method creates its own beamseconds wave that extends beyond averagebeamseconds
				DC206_238 = Raw_206_238 / ForInterp(Beamseconds, SplineBeamSeconds, SplineWave) * SplineWave[0]
			endif
			if(Calculate_207_235 == 1)
				ratio = "Raw_207_235"
				SplineWaveName = "SplineCurve_"+Ratio
				wave SplineWave = $ioliteDFpath("CurrentDRS",SplineWaveName)
				wave SplineBeamSeconds = $ioliteDFpath("CurrentDRS","SplineBeamSecs_"+ratio)
				DC207_235 = Raw_207_235 / ForInterp(Beamseconds, SplineBeamSeconds, SplineWave) * SplineWave[0]
			endif
			if(Calculate_208_232 == 1)
				ratio = "Raw_208_232"
				SplineWaveName = "SplineCurve_"+Ratio
				wave SplineWave = $ioliteDFpath("CurrentDRS",SplineWaveName)
				wave SplineBeamSeconds = $ioliteDFpath("CurrentDRS","SplineBeamSecs_"+ratio)
				DC208_232 = Raw_208_232 / ForInterp(Beamseconds, SplineBeamSeconds, SplineWave) * SplineWave[0]
			endif
			break
	endswitch
	if(Calculate_206_238 == 1)
		DCAge206_238 = Ln(DC206_238 + 1) / 0.000155125
		Wave Final206_238=$MakeioliteWave("CurrentDRS","Final206_238",n=NoOfPoints)
		Wave FinalAge206_238=$MakeioliteWave("CurrentDRS","FinalAge206_238",n=NoOfPoints)
	endif
	if(Calculate_207_235 == 1)
		DCAge207_235 = Ln((DC207_235) + 1) / 0.00098485
		Wave Final207_235=$MakeioliteWave("CurrentDRS","Final207_235",n=NoOfPoints)
		Wave FinalAge207_235=$MakeioliteWave("CurrentDRS","FinalAge207_235",n=NoOfPoints)
	endif
	if(Calculate_208_232 == 1)
		DCAge208_232 = Ln(DC208_232 + 1) / 0.000049475
		Wave Final208_232=$MakeioliteWave("CurrentDRS","Final208_232",n=NoOfPoints)
		Wave FinalAge208_232=$MakeioliteWave("CurrentDRS","FinalAge208_232",n=NoOfPoints)
	endif
	//at the moment I don't think Pb-Pb ratios need any treatment, so they are left as they were...
	if(Calculate_207_206 == 1)
		Wave DC207_206=$MakeioliteWave("CurrentDRS","DC207_206",n=NoOfPoints)
		Wave DCAge207_206=$MakeioliteWave("CurrentDRS","DCAge207_206",n=NoOfPoints)
		DC207_206 = Raw_207_206
		wave LookupTable_76 = $ioliteDFpath("CurrentDRS","LookupTable_76")
		wave LookupTable_age = $ioliteDFpath("CurrentDRS","LookupTable_age")
		DCAge207_206 = interp(DC207_206, LookupTable_76, LookupTable_age)
		Wave Final207_206=$MakeioliteWave("CurrentDRS","Final207_206",n=NoOfPoints)
		Wave FinalAge207_206=$MakeioliteWave("CurrentDRS","FinalAge207_206",n=NoOfPoints)
	endif
	if(Calculate_206_208 == 1)
		Wave DC206_208=$MakeioliteWave("CurrentDRS","DC206_208",n=NoOfPoints)
		DC206_208 = Raw_206_208
		Wave Final206_208=$MakeioliteWave("CurrentDRS","Final206_208",n=NoOfPoints)
	endif
	if(Was204Measured == 1)		//if 204 was measured
		Wave DC206_204=$MakeioliteWave("CurrentDRS","DC206_204",n=NoOfPoints)
		DC206_204 = Raw_206_204
		Wave Final206_204=$MakeioliteWave("CurrentDRS","Final206_204",n=NoOfPoints)
		if(waveexists(Pb207_Beam) == 1)
			Wave DC207_204=$MakeioliteWave("CurrentDRS","DC207_204",n=NoOfPoints)
			DC207_204 = Raw_207_204
			Wave Final207_204=$MakeioliteWave("CurrentDRS","Final207_204",n=NoOfPoints)
		endif
		if(waveexists(Pb208_Beam) == 1)
			Wave DC208_204=$MakeioliteWave("CurrentDRS","DC208_204",n=NoOfPoints)
			DC208_204 = Raw_208_204
			Wave Final208_204=$MakeioliteWave("CurrentDRS","Final208_204",n=NoOfPoints)
		endif
	endif
	
	SetProgress(40,"Calculating final ratios...")	//Update progress for each channel
	
	//so, have done down-hole correction, now need to do drift correction (note that there is often a substantial offset in raw and down hole corr. values from true values)		
	//(relevant waves were already made above in the if statements)
	//and make some waves for the approximated elemental concentrations
	//now want to add in a channel for U, Th, Pb abundances
	if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave Approx_U_PPM=$MakeioliteWave("CurrentDRS","Approx_U_PPM",n=NoOfPoints)
	endif
	if(cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave Approx_Th_PPM=$MakeioliteWave("CurrentDRS","Approx_Th_PPM",n=NoOfPoints)
	endif
	if(cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave Approx_Pb_PPM=$MakeioliteWave("CurrentDRS","Approx_Pb_PPM",n=NoOfPoints)
	endif
	if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0 && cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave FInal_U_Th_Ratio=$MakeioliteWave("CurrentDRS","FInal_U_Th_Ratio",n=NoOfPoints)
	endif
	//now call an external function to do the actual drift correction. The reason for using an external function is that it's also called during export for error propagation.
	VADriftCorrectRatios()		//this function has optional range parameters, but they can be left blank and the function will operate on the entire wave
	//replacing the original error propagation with the below generic version (no blossoming of errors with low N integrations)
	//propagate each ratio separately, using the relevant down-hole corrected ratio
	
	//############################################################
	// JAP	
	
	// Get rid of old waves:
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalDiscPercent")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd207_235")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd206_238")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd208_232")	
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgeAnd207_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalFracCommonPb")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalFracLostPb")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "AndersenDeltaAge")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "AndersenSolution")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgeAnd206_238")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgeAnd207_235")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgeAnd208_232")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "Final238_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd238_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAnd207_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC206_238")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC207_235")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC208_232")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC238_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalPbC207_206")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgePbC206_238")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgePbC207_235")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgePbC208_232")
	KillWaves/Z $ioliteDFpath("CurrentDRS", "FinalAgePbC207_206")

	// Remove everything from the output list (they'll be added back later):
	ListOfOutputChannels = RemoveFromList("Final238_206;FinalAnd238_206;FinalAnd207_206;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalAnd207_235;FinalAnd206_238;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalAnd208_232;FinalAgeAnd207_206;FinalAgeAnd206_238;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalAgeAnd207_235;FinalAgeAnd208_232;FinalFracCommonPb;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalFracLostPb;AndersenSolution;FinalDiscPercent;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalPbC206_238;FinalPbC207_235;FinalPbC208_232;FinalPbC207_206;FinalPbC238_206;", ListOfOutputChannels)
	ListOfOutputChannels = RemoveFromList("FinalAgePbC206_238;FinalAgePbC207_235;FinalAgePbC208_232;FinalAgePbC207_206;", ListOfOutputChannels)
	
	NVAR doPbPb = root:Packages:VisualAge:Options:PbPbOption_Calculate	
	NVAR doAndersen = root:Packages:VisualAge:Options:AndersenOption_Calculate	
	NVAR do204 = root:Packages:VisualAge:Options:PbCOption_Calculate
	NVAR Have204 = root:Packages:VisualAge:Was204Measured
	
	Have204 = Was204Measured

	// Make the required waves:
	Wave Final238_206=$MakeioliteWave("CurrentDRS", "Final238_206", n=NoOfPoints)
	Wave FinalDiscPercent=$MakeioliteWave("CurrentDRS", "FinalDiscPercent", n = NoOfPoints)	
	
	If (doPbPb)
		Killwaves/Z $ioliteDFpath("CurrentDRS", "FinalAge207_206")
		ListOfOutputChannels = RemoveFromList("FinalAge207_206;", ListOfOutputChannels)
		Wave FinalAge207_206=$MakeioliteWave("CurrentDRS", "FinalAge207_206", n = NoOfPoints)	
	EndIf
	
	If (doAndersen)
		Wave FinalAnd207_235=$MakeioliteWave("CurrentDRS", "FinalAnd207_235", n = NoOfPoints)
		Wave FinalAnd206_238=$MakeioliteWave("CurrentDRS", "FinalAnd206_238", n = NoOfPoints)
		Wave FinalAnd208_232=$MakeioliteWave("CurrentDRS", "FinalAnd208_232", n = NoOfPoints)
		Wave FinalAnd238_206=$MakeioliteWave("CurrentDRS", "FinalAnd238_206", n=NoOfPoints)
		Wave FinalAnd207_206=$MakeioliteWave("CurrentDRS", "FinalAnd207_206", n=NoOfPoints)

		Wave FinalAgeAnd207_206=$MakeioliteWave("CurrentDRS", "FinalAgeAnd207_206", n = NoOfPoints)
		Wave FinalAgeAnd206_238=$MakeioliteWave("CurrentDRS", "FinalAgeAnd206_238", n = NoOfPoints)
		Wave FinalAgeAnd207_235=$MakeioliteWave("CurrentDRS", "FinalAgeAnd207_235", n = NoOfPoints)
		Wave FinalAgeAnd208_232=$MakeioliteWave("CurrentDRS", "FinalAgeAnd208_232", n = NoOfPoints)

		Wave FinalFracCommonPb=$MakeioliteWave("CurrentDRS", "FinalFracCommonPb", n = NoOfPoints)
		Wave FinalFracLostPb=$MakeioliteWave("CurrentDRS", "FinalFracLostPb", n = NoOfPoints)
		Wave AndersenDeltaAge=$MakeioliteWave("CurrentDRS", "AndersenDeltaAge", n = NoOfPoints)
		Wave AndersenSolution=$MakeioliteWave("CurrentDRS", "AndersenSolution", n = NoOfPoints)
	EndIf
	
	If (do204 && Was204Measured)
		Wave FinalPbC206_238=$MakeioliteWave("CurrentDRS", "FinalPbC206_238", n = NoOfPoints)
		Wave FinalPbC207_235=$MakeioliteWave("CurrentDRS", "FinalPbC207_235", n = NoOfPoints)
		Wave FinalPbC208_232=$MakeioliteWave("CurrentDRS", "FinalPbC208_232", n = NoOfPoints)
		Wave FinalPbC238_206=$MakeioliteWave("CurrentDRS", "FinalPbC238_206", n = NoOfPoints)
		Wave FinalPbC207_206=$MakeioliteWave("CurrentDRS", "FinalPbC207_206", n = NoOfPoints)
		Wave FinalAgePbC206_238=$MakeioliteWave("CurrentDRS", "FinalAgePbC206_238", n = NoOfPoints)
		Wave FinalAgePbC207_235=$MakeioliteWave("CurrentDRS", "FinalAgePbC207_235", n = NoOfPoints)
		Wave FinalAgePbC208_232=$MakeioliteWave("CurrentDRS", "FinalAgePbC208_232", n = NoOfPoints)
		Wave FinalAgePbC207_206=$MakeioliteWave("CurrentDRS", "FinalAgePbC207_206", n = NoOfPoints)		
	EndIf
	
	// Calculate the 38/06 ratio:
	ListOfOutputChannels += "Final238_206;"
	Final238_206 = 1/Final206_238
	
	// Do 7/6 age calculation if desired:
	If (doPbPb)
		SetProgress(50, "Calculating 207Pb/206Pb ages")
	
		ListOfOutputChannels += "FinalAge207_206;"
		PbPbAges()
	EndIf
	
	// Calculate a rough measure of discordance:
	ListOfOutputChannels += "FinalDiscPercent;"
	SetProgress(60, "Calculating degree of discordance")
	CalculateDisc()
	CalculateDose()
	
	// Do Andersen correction if desired:
	If (doAndersen)
		ListOfOutputChannels += "FinalAnd207_235;FinalAnd206_238;FinalAnd208_232;FinalAnd238_206;FinalAnd207_206;"
		ListOfOutputChannels += "FinalAgeAnd207_206;FinalAgeAnd207_235;FinalAgeAnd206_238;FinalAgeAnd208_232;"
		ListOfOutputChannels += "FinalFracCommonPb;FinalFracLostPb;AndersenSolution;"
		
		// Then iterate Andersen routine until ages don't change:
		NVAR reAndersen = root:Packages:VisualAge:RecrunchAndersen
		NVAR maxAndersenItrs = root:Packages:VisualAge:Options:AndersenOption_MaxRecalc
	
		SetProgress(70, "Doing Andersen's common-Pb correction")
	
		Print "[VisualAge] Andersen routine will execute " + num2str(maxAndersenItrs) + " times or less."
	
		Variable numAndersenItrs = 0
	
		AndersenDeltaAge = -1
		AndersenSolution = 0
		Do
			Print "[VisualAge] Starting Andersen iteration " + num2str (numAndersenItrs + 1) + "."
			Andersen()
			numAndersenItrs = numAndersenItrs + 1
		While ( reAndersen && numAndersenItrs < maxAndersenItrs )
		
		FinalAnd238_206 = 1/FinalAnd206_238
		Variable j
		For (j = 0; j < NoOfPoints; j = j + 1)
			FinalAnd207_206[j] = Ratio7_6(FinalAgeAnd207_206[j]*1e6)
		EndFor
	EndIf
	
	// Do 204Pb common Pb correction if desired:
	If (do204 && Was204Measured)
		ListOfOutputChannels += "FinalPbC207_235;FinalPbC206_238;FinalPbC208_232;FinalPbC207_206;FinalPbC238_206;"
		ListOfOutputChannels += "FinalAgePbC207_206;FinalAgePbC207_235;FinalAgePbC206_238;FinalAgePbC208_232;"
		
		SetProgress(80, "Doing 204Pb common-Pb correction")
		
		Calculate204PbCorrection()
	EndIf
		
	// !JAP
	//############################################################
	
	
	SetProgress(90,"Propagating errors...")	//Update progress for each channel
	
	string ListOfOutputsToPropagate
	if(Calculate_206_238 == 1)
		ListOfOutputsToPropagate = "Final206_238;FinalAge206_238"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_238", ReferenceStandard)
	endif
	if(Calculate_207_235 == 1)
		ListOfOutputsToPropagate = "Final207_235;FinalAge207_235"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_235", ReferenceStandard)
	endif
	if(Calculate_208_232 == 1)
		ListOfOutputsToPropagate = "Final208_232;FinalAge208_232"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC208_232", ReferenceStandard)
	endif
	if(Calculate_207_206 == 1)
		ListOfOutputsToPropagate = "Final207_206;FinalAge207_206"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_206", ReferenceStandard)
	endif
	if(Calculate_206_208 == 1)
		ListOfOutputsToPropagate = "Final206_208"
		Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_208", ReferenceStandard)
	endif
	
	If (doAndersen)
		if (Calculate_206_238 == 1)
			ListOfOutputsToPropagate = "FinalAnd206_238;FinalAgeAnd206_238"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_238", ReferenceStandard)
		endif

		if (Calculate_207_235 == 1)		
			ListOfOutputsToPropagate = "FinalAnd207_235;FinalAgeAnd207_235"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_235", ReferenceStandard)
		endif
		
		if (Calculate_208_232 == 1)
			ListOfOutputsToPropagate = "FinalAnd208_232;FinalAgeAnd208_232"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC208_232", ReferenceStandard)		
		endif
		
		if (Calculate_207_206 == 1)
			ListOfOutputsToPropagate = "FinalAnd207_206;FinalAgeAnd207_206"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_206", ReferenceStandard)
		endif
	EndIf
	
	if (do204 && Was204Measured)
		if (Calculate_206_238 == 1)
			ListOfOutputsToPropagate = "FinalPbC206_238;FinalAgePbC206_238"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC206_238", ReferenceStandard)
		endif

		if (Calculate_207_235 == 1)		
			ListOfOutputsToPropagate = "FinalPbC207_235;FinalAgePbC207_235"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_235", ReferenceStandard)
		endif
		
		if (Calculate_208_232 == 1)
			ListOfOutputsToPropagate = "FinalPbC208_232;FinalAgePbC208_232"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC208_232", ReferenceStandard)		
		endif
		
		if (Calculate_207_206 == 1)
			ListOfOutputsToPropagate = "FinalPbC207_206;FinalAgePbC207_206"
			Propagate_Errors("All", ListOfOutputsToPropagate, "DC207_206", ReferenceStandard)
		endif	
	endif

	SetProgress(100,"Finished DRS.")	//Update progress for each channel

end   //****End of DRS function.  Write any required external sub-routines below this point****




//############################################################
// JAP

//------------------------------------------------------------------------
// Calculates discordance of each point
//------------------------------------------------------------------------
Function CalculateDisc()
	
	Wave FinalDiscPercent=$ioliteDFpath("CurrentDRS", "FinalDiscPercent")
	
	Wave Final207_235=$ioliteDFpath("CurrentDRS", "Final207_235")
	Wave Final206_238=$ioliteDFpath("CurrentDRS", "Final206_238")
	
	Wave FinalAge206_238=$ioliteDFpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge207_206=$ioliteDFpath("CurrentDRS", "FinalAge207_206")
		
	Variable Npts = numpnts(FinalDiscPercent)
	
	Variable i
	For( i = 0; i < Npts; i = i + 1 )
		//FinalDiscPercent[i] = DiscPercent(Final207_235[i], Final206_238[i])
		FinalDiscPercent[i] = DiscPercent2(FinalAge206_238[i], FinalAge207_206[i])
	EndFor		
End

//------------------------------------------------------------------------
// Calculates the 207/206 age of each point
//------------------------------------------------------------------------
Function PbPbAges()
	Print "[VisualAge] Starting calculation of 207Pb/206Pb ages."

	// Get time for calculation start:
	Variable calcStartTime = DateTime

	// Get required waves from iolite:
	Wave Final207_206=$ioliteDFpath("CurrentDRS", "Final207_206")
	Wave FinalAge207_235=$ioliteDFpath("CurrentDRS", "FinalAge207_235")
	Wave FinalAge206_238=$ioliteDFpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge207_206=$ioliteDFpath("CurrentDRS", "FinalAge207_206")
	
	// Get number of wave points:
	Variable Npts = numpnts(FinalAge207_206)

	SVAR wavesForGuess = root:Packages:VisualAge:Options:PbPbOption_WavesForGuess
	
	// Loop through each point, and call the PbPb routine for each:
	Variable i
	For ( i = 1; i < Npts; i = i + 1 )
		
		// Get current 7/6 ratio:
		Variable m = (Final207_206[i] + Final207_206[i-1] + Final207_206[i+1])/3
		
		// Calculate a reasonable guess at the age:
		Variable guess = 1e6*(AgeFromList(wavesForGuess, i))
		
		// If the ratio or age seem unreasonable set age to NaN and skip
		If (numtype(m) == 2 || guess <= 1 || guess > 5e9 || numtype(guess) == 2)
			FinalAge207_206[i] = NaN
			Continue
		EndIf
		
		// Call Newton's method PbPb function:
		FinalAge207_206[i] = CalculatePbPbAge(m, guess)
	
	EndFor

	// Get time of completion:
	Variable calcStopTime = DateTime

	// Spit out some info:
	Print "[VisualAge] ...Done. Calculation duration: " + num2str(calcStopTime - calcStartTime) + " s."
End

//------------------------------------------------------------------------
// Calculates 204Pb corrections for each point
//------------------------------------------------------------------------
Function Calculate204PbCorrection()

	Variable calcStartTime = DateTime
	Print "[VisualAge] Starting 204Pb correction."
	
	Wave Final207_204 = $ioliteDFpath("CurrentDRS", "Final207_204")
	Wave Final206_204 = $ioliteDFpath("CurrentDRS", "Final206_204")
	Wave Final208_204 = $ioliteDFpath("CurrentDRS", "Final208_204")
	Wave Final207_206 = $ioliteDFpath("CurrentDRS", "Final207_206")
	Wave FinalAge206_238 = $ioliteDFpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge207_206 = $ioliteDFpath("CurrentDRS", "FinalAge207_206")
	Wave FinalPbC206_238 = $ioliteDFpath("CurrentDRS", "FinalPbC206_238")
	Wave FinalPbC238_206 = $ioliteDFpath("CurrentDRS", "FinalPbC238_206")	
	Wave FinalPbC207_235 = $ioliteDFpath("CurrentDRS", "FinalPbC207_235")
	Wave FinalPbC208_232 = $ioliteDFpath("CurrentDRS", "FinalPbC208_232")
	Wave FinalPbC207_206 = $ioliteDFpath("CurrentDRS", "FinalPbC207_206")
	Wave Final207_235 = $ioliteDFpath("CurrentDRS", "Final207_235")
	Wave Final206_238 = $ioliteDFpath("CurrentDRS", "Final206_238")
	Wave Final208_232 = $ioliteDFpath("CurrentDRS", "Final208_232")
	Wave FinalAgePbC207_235 = $ioliteDFpath("CurrentDRS", "FinalAgePbC207_235")
	Wave FinalAgePbC206_238 = $ioliteDFpath("CurrentDRS", "FinalAgePbC206_238")
	Wave FinalAgePbC208_232 = $ioliteDFpath("CurrentDRS", "FinalAgePbC208_232")
	Wave FinalAgePbC207_206 = $ioliteDFpath("CurrentDRS", "FinalAgePbC207_206")
	
	SVAR WavesForGuess = root:Packages:VisualAge:Options:PbCOption_WavesForGuess
	NVAR UsePbComp = root:Packages:VisualAge:Options:Option_UsePbComp
	NVAR Pb64 = root:Packages:VisualAge:Options:Option_Common64
	NVAR Pb74 = root:Packages:VisualAge:Options:Option_Common74
	NVAR Pb84 = root:Packages:VisualAge:Options:Option_Common84		
	NVAR k = root:Packages:VisualAge:Constants:k
	
	Variable Npts = numpnts(FinalAge206_238)	
	Variable common64, common74, common84	
	
	Variable i
	For (i = 0; i < Npts; i = i + 1)
		Variable cAge = AgeFromList(WavesForGuess, i)
		If (numtype(cAge) == 2)
			FinalPbC207_235[i] = NaN
			FinalPbC206_238[i] = NaN
			FinalPbC208_232[i] = NaN
			FinalAgePbC207_235[i] = NaN
			FinalAgePbC206_238[i] = NaN
			FInalAgePbC208_232[i] = NaN
			FinalAgePbC207_206[i] = NaN
			Continue
		EndIf
		
		If (UsePbComp)
			common64 = Pb64
			common74 = Pb74
			common84 = Pb84
		Else
			common64 = 0.023*(cAge/1e3)^3 - 0.359*(cAge/1e3)^2 - 1.008*(cAge/1e3) + 19.04
			common74 = -0.034*(cAge/1e3)^4 +0.181*(cAge/1e3)^3 - 0.448*(cAge/1e3)^2 + 0.334*(cAge/1e3) + 15.64	
			common84 = -2.200*(cAge/1e3) + 39.47
		EndIf
		
		FinalPbC207_235[i] = Final207_235[i]*(Final207_204[i] - common74)/(Final207_204[i])
		FinalPbC206_238[i] = Final206_238[i]*(Final206_204[i] - common64)/(Final206_204[i])
		FinalPbC208_232[i] = Final208_232[i]*(Final208_204[i] - common84)/(Final208_204[i])
		FinalPbC207_206[i] = (Final206_204[i]*Final207_206[i] - common74)/(Final206_204[i] - common64)
	
		FinalAgePbC207_235[i] = 1e-6*Age7_35(FinalPbC207_235[i])
		FinalAgePbC206_238[i] = 1e-6*Age6_38(FinalPbC206_238[i])
		FinalAgePbC208_232[i] = 1e-6*Age8_32(FinalPbC208_232[i])
		
		Variable guess = 1e6*(AgeFromList(WavesForGuess, i))
		FinalAgePbC207_206[i] = CalculatePbPbAge( FinalPbC207_206[i], guess) 
		
		//Variable guess = 1e6*(AgeFromList(WavesForGuess, i))		
		//FinalAgePbC207_206[i] = CalculatePbPbAge( (1/k)*FinalPbC207_235[i]/FInalPbC206_238[i], guess)
		//FinalPbC207_206[i] = Ratio7_6(1e6*FinalAgePbC207_206[i])
	
	EndFor
	
	FinalPbC238_206 = 1/FinalPbC206_238
	
	// Get time of completion:
	Variable calcStopTime = DateTime

	// Spit out some info:
	Print "[VisualAge] ...Done. Calculation duration: " + num2str(calcStopTime - calcStartTime) + " s."	
End

//------------------------------------------------------------------------
// Calculates the Andersen corrections for each point
//------------------------------------------------------------------------
Function Andersen()

	// Get calculation start time:
	Variable calcStartTime = DateTime

	Wave FinalDiscPercent=$ioliteDFpath("CurrentDRS", "FinalDiscPercent")

	// Get ratios computed by iolite:
	Wave Final207_235=$ioliteDFpath("CurrentDRS", "Final207_235")
	Wave Final206_238=$ioliteDFpath("CurrentDRS", "Final206_238")
	Wave Final208_232=$ioliteDFpath("CurrentDRS", "Final208_232")
	Wave Final207_206=$ioliteDFpath("CurrentDRS", "Final207_206")
	Wave Final_U_Th_Ratio=$ioliteDFpath("CurrentDRS", "Final_U_Th_Ratio")

	// Get ages computed by iolite + PbPbAges:
	Wave FinalAge207_206=$ioliteDFpath("CurrentDRS", "FinalAge207_206")
	Wave FinalAge207_235=$ioliteDFpath("CurrentDRS", "FinalAge207_235")
	Wave FinalAge206_238=$ioliteDFpath("CurrentDRS", "FinalAge206_238")
	Wave FinalAge208_232=$ioliteDFpath("CurrentDRS", "FinalAge208_232")

	// Get waves for Andersen routine:
	Wave FinalAgeAnd207_206=$ioliteDFpath("CurrentDRS", "FinalAgeAnd207_206")
	Wave AndersenDeltaAge=$ioliteDFpath("CurrentDRS", "AndersenDeltaAge")
	Wave FinalFracCommonPb=$ioliteDFpath("CurrentDRS", "FinalFracCommonPb")
	Wave FinalFracLostPb=$ioliteDFpath("CurrentDRS", "FinalFracLostPb")
	Wave AndersenSolution=$ioliteDFpath("CurrentDRS", "AndersenSolution")
	Wave FinalAnd207_235=$ioliteDFpath("CurrentDRS", "FinalAnd207_235")
	Wave FinalAnd206_238=$ioliteDFpath("CurrentDRS", "FinalAnd206_238")
	Wave FinalAnd208_232=$ioliteDFpath("CurrentDRS", "FinalAnd208_232")
	Wave FinalAgeAnd206_238=$ioliteDFpath("CurrentDRS", "FinalAgeAnd206_238")
	Wave FinalAgeAnd207_235=$ioliteDFpath("CurrentDRS", "FinalAgeAnd207_235")
	Wave FinalAgeAnd208_232=$ioliteDFpath("CurrentDRS", "FinalAgeAnd208_232")
	
	Variable Npts = numpnts(FinalAgeAnd207_206)	
		
	// Make duplicates of the needed ratios:
	Duplicate/O Final207_235, xw
	Duplicate/O Final206_238, yw
	Duplicate/O Final208_232, zw
	Duplicate/O Final_U_Th_Ratio, uw
	
	Make/O/N=(Npts) StartingAges

	// Define iteration parameters:
	Variable itrNum = 0
	SVAR ageList = root:Packages:VisualAge:Options:AndersenOption_WavesForGuess
	NVAR numMaxItr = root:Packages:VisualAge:Options:AndersenOption_MaxIters
	NVAR eps = root:Packages:VisualAge:Options:AndersenOption_Epsilon
	NVAR reAndersen = root:Packages:VisualAge:RecrunchAndersen
	NVAR t2 = root:Packages:VisualAge:Options:AndersenOption_t2
	reAndersen = 0
	
	// Decay constants:
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	NVAR l232 = root:Packages:VisualAge:Constants:l232
	
	// Define present-day 238U/235U:
	NVAR k = root:Packages:VisualAge:Constants:k
	
	Variable c7, c8 // Common Pb composition
	Variable ct1, nt1 // Current and "new" value for t1
	Variable xt1, yt1, zt1 // U-Pb and Th-Pb ratios at t1
	Variable dxt1, dyt1, dzt1 // Derivative of ratios wrt t1
	Variable xt2, yt2, zt2 // U-Pb and Th-Pb ratios at t2 (age of Pb loss)
	
	Variable i
	For ( i=0; i<Npts; i=i+1) // Main loop
		itrNum = 0	
		
		// If age hasn't changed, skip:
		If (AndersenDeltaAge[i] == 0 || numtype(AndersenDeltaAge[i]) == 2)
			Continue
		EndIf
			
		If (AndersenDeltaAge[i] > 0 )  
			// If Andersen's t1 has already been calculated, use it as the guess:
			ct1 = FinalAgeAnd207_206[i]*1e6
		Else
			// Otherwise, use a guess at the age and if it is young, don't bother with the 7/35 or 7/6 age:
			If ( Final207_206[i] > 0.5 )
				ct1 = AgeFromList(ageList, i)*1e6	
			Else
				ct1 = AgeFromList(RemoveFromList("FinalAge207_235;FinalAge207_206;", ageList), i)*1e6
			EndIf
		EndIf
		
		// Set the starting ages:
		StartingAges[i] = ct1
		nt1 = ct1

		// Calculate starting values for ratios:
		xt1 = exp(l235*ct1) -1
		yt1 = exp(l238*ct1) -1
		zt1 = exp(l232*ct1) -1
			
		xt2 = exp(l235*t2) - 1
		yt2 = exp(l238*t2) - 1
		zt2 = exp(l232*t2) - 1
		
		// Initialize function + derivative:
		Variable ft = 0, dft = 0
		Variable A1, B1, C1, D1
		
		// Initialize common Pb stuff:
		Variable common64, common74, common84
		Variable Gct1 = ct1/1e9
		
		NVAR usePbComp = root:Packages:VisualAge:Option_UsePbComp
		
		If ( usePbComp )
			// Use common Pb composition specified in DRS options:
			NVAR c64 = root:Packages:VisualAge:Options:Option_Common64
			NVAR c74 = root:Packages:VisualAge:Options:Option_Common74
			NVAR c84 = root:Packages:VisualAge:Options:Option_Common84
			
			common64 = c64
			common74 = c74
			common84 = c84
		Else
			// Compute c7 and c8 using BSK's fits:
			common64 = 0.023*(Gct1)^3 - 0.359*(Gct1)^2 - 1.008*(Gct1) + 19.04
			common74 = -0.034*(Gct1)^4 +0.181*(Gct1)^3 - 0.448*(Gct1)^2 + 0.334*(Gct1) + 15.64
			common84 = -2.200*(Gct1) + 39.47
		EndIf

		c7 = common74/common64
		c8 = common84/common64
					
		// Determine if point is roughly concordant, if so: skip
		NVAR discCutOff = root:Packages:VisualAge:Options:AndersenOption_OnlyGTDisc

		If ( FinalDiscPercent[i] < discCutOff)
			AndersenSolution[i] = 0.5
			AndersenDeltaAge[i] = 0
			FinalAgeAnd207_206[i] = FinalAge207_206[i]
			FinalAnd206_238[i] = Final206_238[i]
			FinalAnd207_235[i] = Final207_235[i]
			FinalAnd208_232[i] = Final208_232[i]
			FinalFracCommonPb[i] = 0
			FinalFracLostPb[i] = 0
			Continue
		EndIf

		// Newton's method to find Andersen's t1:
		Do 			
			ct1 = nt1	
			
			xt1 = exp(l235*ct1) -1
			yt1 = exp(l238*ct1) -1
			zt1 = exp(l232*ct1) -1
		
			dxt1 = l235*exp(l235*ct1)
			dyt1 = l238*exp(l238*ct1)
			dzt1 = l232*exp(l232*ct1)			
			
			// Andersen's version:
			A1 = (yw[i]*(xt1-xt2) - yt2*xt1 + xw[i]*(yt2-yt1) + xt2*yt1)*yw[i]
			B1 = (zt1-zt2-c8*uw[i]*yt1+c8*uw[i]*yt2)
			C1 = (zw[i]*(yt2-yt1) + zt2*yt1 + yw[i]*(zt1-zt2) -yt2*zt1)*yw[i]
			D1 = (xt1-xt2 -c7*k*yt1 + c7*k*yt2)
			ft = A1*B1 - C1*D1
			dft = A1*(dzt1 - c8*uw[i]*dyt1) + B1*yw[i]*(yw[i]*dxt1 - yt2*dxt1 - xw[i]*dyt1 + xt2*dyt1) - C1*(dxt1-c7*k*dyt1) - D1*yw[i]*(-zw[i]*dyt1+zt2*dyt1 + yw[i]*dzt1 -yt2*dzt1)
			
			// Another version:
			//A1 = (yw[i]*(xt1-xt2) - yt2*xt1 + xw[i]*(yt2-yt1) + xt2*yt1)
			//B1 = (zt1-zt2-c8*uw[i]*yt1+c8*uw[i]*yt2)
			//C1 = (zw[i]*(yt2-yt1) + zt2*yt1 + yw[i]*(zt1-zt2) -yt2*zt1)
			//D1 = (xt1-xt2 -c7*k*yt1 + c7*k*yt2)
			//ft = (A1/D1) - (C1/B1)
			//dft = (1/D1)*(yw[i]*dxt1 - yt2*dxt1 - xw[i]*dyt1 + xt2*dyt1) - (A1/(D1*D1))*(dxt1-c7*k*dyt1) - (1/B1)*(-zw[i]*dyt1+zt2*dyt1 + yw[i]*dzt1 -yt2*dzt1) + (C1/(B1*B1))*(dzt1 - c8*uw[i]*dyt1)
			
			nt1 = ct1 - ft/dft
			itrNum = itrNum + 1
	
		While ( abs(ft) > eps && itrNum < numMaxItr )
		// End of Newton's method
		
		// Check if value makes sense:
		If (nt1 > 4.5e9 || nt1 < 1e6 || numtype(nt1) == 2 )
			// If no solution is found, set age to not a number or last known age (not sure which is better?)
			nt1 = StartingAges[i]//NaN
			
			// Keep track of whether or not a valid solution was found:
			AndersenSolution[i] = 0
		Else
			AndersenSolution[i] = 1
		EndIf
		
		// Store final age in Ma:
		FinalAgeAnd207_206[i] = nt1/1e6
		
		// Compute the delta age and set reAndersen if large enough delta:
		AndersenDeltaAge[i] = abs(StartingAges[i] - nt1)
		If (AndersenDeltaAge[i] > 0.1)
			reAndersen = 1
		EndIf
		
		// Compute a final set of ratios using Andersen's t1:
		xt1 = exp(l235*nt1) -1
		yt1 = exp(l238*nt1) -1
		zt1 = exp(l232*nt1) -1		
		
		// Compute fraction of common Pb (two different ways, probably best to use first as it doesn't depend on 208/232):
		FinalFracCommonPb[i] = (-yw[i]*xt1 + yw[i]*xt2 + yt2*xt1 + xw[i]*yt1 - xw[i]*yt2 - xt2*yt1)/(-yw[i]*xt1 + yw[i]*xt2 + yw[i]*c7*k*yt1 - yw[i]*c7*k*yt2)
		 //FinalFracCommonPb[i] = ((yt1-yt2)*(zt2-zw[i]) + (yw[i]-yt2)*(zt1-zt2))/(yw[i]*(zt1-zt2) + yw[i]*c8*uw[i]*(yt2-yt1))
		
		// Compute common Pb corrected ratios:
		FinalAnd207_235[i] = xw[i] - yw[i]*c7*k*FinalFracCommonPb[i]
		FinalAnd206_238[i] = yw[i]*(1-FinalFracCommonPb[i])
		FinalAnd208_232[i] = zw[i] - yw[i]*c8*uw[i]*FinalFracCommonPb[i]
		
		// Compute fraction of Pb lost:
		FinalFracLostPb[i] = (yt1 - FinalAnd206_238[i])/(yt1 - yt2)
	EndFor // End of main loop
	
	// Calculate common Pb corrected ages:
	FinalAgeAnd206_238 = (1/1e6)*(1/l238)*ln(FinalAnd206_238 + 1)
	FinalAgeAnd207_235 = (1/1e6)*(1/l235)*ln(FinalAnd207_235 + 1)
	FinalAgeAnd208_232 = (1/1e6)*(1/l232)*ln(FinalAnd208_232 + 1)
	
	Variable calcStopTime = DateTime
	KillWaves StartingAges, xw, yw, zw, uw
	Print "[VisualAge] ... Done. Calculation duration: " + num2str(calcStopTime-calcStartTime) + " s."
End

// !JAP
//###########################################################	

//This function uses grep to hunt through the list of inputs for possible matches to each required input channel
//In each case it checks whether more than one result was found, and if so refines the search
Function/T VAGenerateUPbInputsList(ListOfIntermediateChannels)
	string ListOfIntermediateChannels
	SVar Measured_UPb_Inputs = $ioliteDFpath("CurrentDRS","Measured_UPb_Inputs")
	string ThisGrepMatch	//temporary wave to store the finds
	//want to go through the search in the same order that the input will be referenced in at the top of the main DRS function - this is 206,207,208,232,238 (204 if present)
	//****Hg200***
	ThisGrepMatch = GrepList(ListOfIntermediateChannels, "200", 0, ";")
	//first check if there were multiple matches - then need to refine the search
	if(ItemsInList(ThisGrepMatch, ";") > 1)	//otherwise if more than one match was found need to refine the search
		ThisGrepMatch = GrepList(ThisGrepMatch, "Hg", 0, ";")	//this won't necessarily pick up everything, but a more thorough approach would probably get very cluttered and long winded
	endif
	if(ItemsInList(ThisGrepMatch, ";") == 1)		//if a single match was found
		Measured_UPb_Inputs = ReplaceStringByKey("200", Measured_UPb_Inputs, ThisGrepMatch[0, strlen(ThisGrepMatch)-2], "=", ";", 0)
	endif
	//****Hg202***
	ThisGrepMatch = GrepList(ListOfIntermediateChannels, "202", 0, ";")
	//first check if there were multiple matches - then need to refine the search
	if(ItemsInList(ThisGrepMatch, ";") > 1)	//otherwise if more than one match was found need to refine the search
		ThisGrepMatch = GrepList(ThisGrepMatch, "Hg", 0, ";")	//this won't necessarily pick up everything, but a more thorough approach would probably get very cluttered and long winded
	endif
	if(ItemsInList(ThisGrepMatch, ";") == 1)		//if a single match was found
		Measured_UPb_Inputs = ReplaceStringByKey("202", Measured_UPb_Inputs, ThisGrepMatch[0, strlen(ThisGrepMatch)-2], "=", ";", 0)
	endif
	//****Pb204***
	ThisGrepMatch = GrepList(ListOfIntermediateChannels, "204", 0, ";")
	//first check if there were multiple matches - then need to refine the search
	if(ItemsInList(ThisGrepMatch, ";") > 1)	//otherwise if more than one match was found need to refine the search
		ThisGrepMatch = GrepList(ThisGrepMatch, "Pb", 0, ";")	//this won't necessarily pick up everything, but a more thorough approach would probably get very cluttered and long winded
	endif
	if(ItemsInList(ThisGrepMatch, ";") == 1)		//if a single match was found
		Measured_UPb_Inputs = ReplaceStringByKey("204", Measured_UPb_Inputs, ThisGrepMatch[0, strlen(ThisGrepMatch)-2], "=", ";", 0)
	endif
	//****Pb206***
	ThisGrepMatch = GrepList(ListOfIntermediateChannels, "206", 0, ";")
	//first check if there were multiple matches - then need to refine the search
	if(ItemsInList(ThisGrepMatch, ";") > 1)	//otherwise if more than one match was found need to refine the search
		ThisGrepMatch = GrepList(ThisGrepMatch, "Pb", 0, ";")	//this won't necessarily pick up everything, but a more thorough approach would probably get very cluttered and long winded
	endif
	if(ItemsInList(ThisGrepMatch, ";") == 1)		//if a single match was found
		Measured_UPb_Inputs = ReplaceStringByKey("206", Measured_UPb_Inputs, ThisGrepMatch[0, strlen(ThisGrepMatch)-2], "=", ";", 0)
	endif
	//****Pb207***
	ThisGrepMatch = GrepList(ListOfIntermediateChannels, "207", 0, ";")
	//first check if there were multiple matches - then need to refine the search
	if(ItemsInList(ThisGrepMatch, ";") > 1)	//otherwise if more than one match was found need to refine the search
		ThisGrepMatch = GrepList(ThisGrepMatch, "Pb", 0, ";")	//this won't necessarily pick up everything, but a more thorough approach would probably get very cluttered and long winded
	endif
	if(ItemsInList(ThisGrepMatch, ";") == 1)		//if a single match was found
		Measured_UPb_Inputs = ReplaceStringByKey("207", Measured_UPb_Inputs, ThisGrepMatch[0, strlen(ThisGrepMatch)-2], "=", ";", 0)
	endif
	//****Pb208***
	ThisGrepMatch = GrepList(ListOfIntermediateChannels, "208", 0, ";")
	//first check if there were multiple matches - then need to refine the search
	if(ItemsInList(ThisGrepMatch, ";") > 1)	//otherwise if more than one match was found need to refine the search
		ThisGrepMatch = GrepList(ThisGrepMatch, "Pb", 0, ";")	//this won't necessarily pick up everything, but a more thorough approach would probably get very cluttered and long winded
	endif
	if(ItemsInList(ThisGrepMatch, ";") == 1)		//if a single match was found
		Measured_UPb_Inputs = ReplaceStringByKey("208", Measured_UPb_Inputs, ThisGrepMatch[0, strlen(ThisGrepMatch)-2], "=", ";", 0)
	endif
	//****Th232***
	ThisGrepMatch = GrepList(ListOfIntermediateChannels, "232", 0, ";")
	//first check if there were multiple matches - then need to refine the search
	if(ItemsInList(ThisGrepMatch, ";") > 1)	//otherwise if more than one match was found need to refine the search
		ThisGrepMatch = GrepList(ThisGrepMatch, "Th", 0, ";")	//this won't necessarily pick up everything, but a more thorough approach would probably get very cluttered and long winded
	endif
	if(ItemsInList(ThisGrepMatch, ";") == 1)		//if a single match was found
		Measured_UPb_Inputs = ReplaceStringByKey("232", Measured_UPb_Inputs, ThisGrepMatch[0, strlen(ThisGrepMatch)-2], "=", ";", 0)
	endif
	//****U235***
	ThisGrepMatch = GrepList(ListOfIntermediateChannels, "235", 0, ";")
	//first check if there were multiple matches - then need to refine the search
	if(ItemsInList(ThisGrepMatch, ";") > 1)	//otherwise if more than one match was found need to refine the search
		ThisGrepMatch = GrepList(ThisGrepMatch, "U", 0, ";")	//this won't necessarily pick up everything, but a more thorough approach would probably get very cluttered and long winded
	endif
	if(ItemsInList(ThisGrepMatch, ";") == 1)		//if a single match was found
		Measured_UPb_Inputs = ReplaceStringByKey("235", Measured_UPb_Inputs, ThisGrepMatch[0, strlen(ThisGrepMatch)-2], "=", ";", 0)
	endif
	//****U238***
	ThisGrepMatch = GrepList(ListOfIntermediateChannels, "238", 0, ";")
	//first check if there were multiple matches - then need to refine the search
	if(ItemsInList(ThisGrepMatch, ";") > 1)	//otherwise if more than one match was found need to refine the search
		ThisGrepMatch = GrepList(ThisGrepMatch, "U", 0, ";")	//this won't necessarily pick up everything, but a more thorough approach would probably get very cluttered and long winded
	endif
	if(ItemsInList(ThisGrepMatch, ";") == 1)		//if a single match was found
		Measured_UPb_Inputs = ReplaceStringByKey("238", Measured_UPb_Inputs, ThisGrepMatch[0, strlen(ThisGrepMatch)-2], "=", ";", 0)
	endif
end

//The below function performs drift correction on each of the final ratios. It references appropriate waves, looks up information from the Edit DRS Variables window, finds "true" values from the standard text file, then performs the correction
Function VADriftCorrectRatios([OptionalMinPoint, OptionalMaxPoint])
	variable OptionalMinPoint, OptionalMaxPoint
	If(ParamIsDefault(OptionalMinPoint))	//if this has not bee specified
		OptionalMinPoint = 0		//then set it to 0 to include all data
	endif
	If(ParamIsDefault(OptionalMaxPoint))	//if this has not bee specified
		OptionalMaxPoint = inf	//then set it to inf to include all data
	endif
	//the next 5 lines reference all of the global strings and variables in the header of this file for use in the main code of the DRS that follows.
	string currentdatafolder = GetDataFolder(1)
	setdatafolder $ioliteDFpath("DRSGlobals","")
	SVar IndexChannel, ReferenceStandard, DefaultIntensityUnits, UseOutlierRejection, BeamSecondsMethod, CurveFitType
	NVar MaskThreshold, MaskEdgeDiscardSeconds, BeamSecondsSensitivity, MaxBeamDuration, DefaultStartMask, DefaultEndMask, FitOutlierTolerance, Sample238_235Ratio
	setdatafolder $currentdatafolder
	SVar Measured_UPb_Inputs = $ioliteDFpath("CurrentDRS","Measured_UPb_Inputs")	
	//reference flags for each ratio
	NVar Calculate_206_238 = $ioliteDFpath("CurrentDRS","Calculate_206_238")
	NVar Calculate_207_235 = $ioliteDFpath("CurrentDRS","Calculate_207_235")
	NVar Calculate_208_232 = $ioliteDFpath("CurrentDRS","Calculate_208_232")
	NVar Calculate_207_206 = $ioliteDFpath("CurrentDRS","Calculate_207_206")
	NVar Calculate_206_208 = $ioliteDFpath("CurrentDRS","Calculate_206_208")
	//now need to reference all the waves that are used here (for simplicity just disregard whether or not they exist)
	Wave DC206_238=$ioliteDFpath("CurrentDRS","DC206_238")
	Wave DC207_235=$ioliteDFpath("CurrentDRS","DC207_235")
	Wave DC208_232=$ioliteDFpath("CurrentDRS","DC208_232")
	Wave DC207_206=$ioliteDFpath("CurrentDRS","DC207_206")
	Wave DC206_208=$ioliteDFpath("CurrentDRS","DC206_208")
	Wave Final206_238=$ioliteDFpath("CurrentDRS","Final206_238")
	Wave Final207_235=$ioliteDFpath("CurrentDRS","Final207_235")
	Wave Final208_232=$ioliteDFpath("CurrentDRS","Final208_232")
	Wave Final207_206=$ioliteDFpath("CurrentDRS","Final207_206")
	Wave Final206_208=$ioliteDFpath("CurrentDRS","Final206_208")
	Wave FinalAge206_238=$ioliteDFpath("CurrentDRS","FinalAge206_238")
	Wave FinalAge207_235=$ioliteDFpath("CurrentDRS","FinalAge207_235")
	Wave FinalAge208_232=$ioliteDFpath("CurrentDRS","FinalAge208_232")
	Wave FinalAge207_206=$ioliteDFpath("CurrentDRS","FinalAge207_206")
	//and waves for approx. elemental concentrations
	if(cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave Pb208_CPS=$ioliteDFpath("CurrentDRS",StringByKey("208", Measured_UPb_Inputs, "=", ";", 0))
	endif
	if(cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave Th232_CPS=$ioliteDFpath("CurrentDRS",StringByKey("232", Measured_UPb_Inputs, "=", ";", 0))
	endif
	if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		Wave U238_CPS=$ioliteDFpath("CurrentDRS",StringByKey("238", Measured_UPb_Inputs, "=", ";", 0))
	endif
	Wave Approx_U_PPM=$ioliteDFpath("CurrentDRS","Approx_U_PPM")
	Wave Approx_Th_PPM=$ioliteDFpath("CurrentDRS","Approx_Th_PPM")
	Wave Approx_Pb_PPM=$ioliteDFpath("CurrentDRS","Approx_Pb_PPM")
	//and for U_Th ratio	
	Wave Raw_U_Th_Ratio=$ioliteDFpath("CurrentDRS","Raw_U_Th_Ratio")
	Wave FInal_U_Th_Ratio=$ioliteDFpath("CurrentDRS","FInal_U_Th_Ratio")
	//now test if a 204 wave is present
	Wave Final206_204=$ioliteDFpath("CurrentDRS","Final206_204")
	variable Was204Measured = 0
	if(waveexists(Final206_204)==1)	
		Wave Final207_204=$ioliteDFpath("CurrentDRS","Final207_204")
		Wave Final208_204=$ioliteDFpath("CurrentDRS","Final208_204")
		Wave DC206_204=$ioliteDFpath("CurrentDRS","DC206_204")
		Wave DC207_204=$ioliteDFpath("CurrentDRS","DC207_204")
		Wave DC208_204=$ioliteDFpath("CurrentDRS","DC208_204")
		Was204Measured = 1		//set this as a flag so that it can be used in the rest of the function
	endif
	//make a string of the waves that will need splines
	string ListOfSplinesForRecalc = ""
	if(Calculate_206_238 == 1)
		ListOfSplinesForRecalc += "DC206_238;"
	endif
	if(Calculate_207_235 == 1)
		ListOfSplinesForRecalc += "DC207_235;"
	endif
	if(Calculate_208_232 == 1)
		ListOfSplinesForRecalc += "DC208_232;"
	endif
	if(Calculate_207_206 == 1)
		ListOfSplinesForRecalc += "DC207_206;"
	endif
	if(Calculate_206_208 == 1)
		ListOfSplinesForRecalc += "DC206_208;"
	endif
	if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		ListOfSplinesForRecalc += StringByKey("238", Measured_UPb_Inputs, "=", ";", 0) + ";"
	endif
	if(cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		ListOfSplinesForRecalc += StringByKey("232", Measured_UPb_Inputs, "=", ";", 0) + ";"
	endif
	if(cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		ListOfSplinesForRecalc += StringByKey("208", Measured_UPb_Inputs, "=", ";", 0) + ";"
	endif
	if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0 && cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		ListOfSplinesForRecalc += "Raw_U_Th_Ratio;"
	endif
	if(Was204Measured == 1)		//if 204 was measured
		ListOfSplinesForRecalc += "DC206_204;"
		if(waveexists(Pb207_Beam) == 1)
			ListOfSplinesForRecalc += "DC207_204;"
		endif
		if(waveexists(Pb208_Beam) == 1)
			ListOfSplinesForRecalc += "DC208_204;"
		endif
	endif
	//update their splines to make sure they're up to date
	RecalculateIntegrations("m_"+ReferenceStandard,ListOfSplinesForRecalc)
	//use this one-liner to make spline waves interpolated onto index_time. they can then be used directly in equations without needing to use "interp"
	if(Calculate_206_238 == 1)
		wave DC206_238_Spline = $InterpSplineOntoIndexTime("DC206_238", ReferenceStandard)
		//NOTE that by putting this value into a variable for the line below you will speed up the calculations immensely. If you instead put it in the below calculation line it will be called for every point of the wave...
		variable StdValue_206_238 = GetValueFromStandard("206Pb/238U",ReferenceStandard)
		//use a point range here so that there is the option of calculation for a subsection of the wave (this is used to calculate errors on the standards)
		Final206_238[OptionalMinPoint, OptionalMaxPoint]= DC206_238 * ( StdValue_206_238 / DC206_238_Spline)
		FinalAge206_238[OptionalMinPoint, OptionalMaxPoint] = Ln(Final206_238 + 1) / 0.000155125
	endif
	if(Calculate_207_235 == 1)
		wave DC207_235_Spline = $InterpSplineOntoIndexTime("DC207_235", ReferenceStandard)
		variable StdValue_207_235 = GetValueFromStandard("207Pb/235U",ReferenceStandard)
		Final207_235[OptionalMinPoint, OptionalMaxPoint]= DC207_235 * (StdValue_207_235 / DC207_235_Spline)
		FinalAge207_235[OptionalMinPoint, OptionalMaxPoint] = Ln((Final207_235) + 1) / 0.00098485
	endif
	if(Calculate_208_232 == 1)
		wave DC208_232_Spline = $InterpSplineOntoIndexTime("DC208_232", ReferenceStandard)
		variable StdValue_208_232 = GetValueFromStandard("208Pb/232Th",ReferenceStandard)
		Final208_232[OptionalMinPoint, OptionalMaxPoint]= DC208_232 * (StdValue_208_232 / DC208_232_Spline)
		FinalAge208_232[OptionalMinPoint, OptionalMaxPoint] = Ln(Final208_232 + 1) / 0.000049475
	endif
	if(Calculate_207_206 == 1)
		wave DC207_206_Spline = $InterpSplineOntoIndexTime("DC207_206", ReferenceStandard)
		variable StdValue_207_206 = GetValueFromStandard("207Pb/206Pb",ReferenceStandard)
		Final207_206[OptionalMinPoint, OptionalMaxPoint]= DC207_206 * (StdValue_207_206 / DC207_206_Spline)
		wave LookupTable_76 = $ioliteDFpath("CurrentDRS","LookupTable_76")
		wave LookupTable_age = $ioliteDFpath("CurrentDRS","LookupTable_age")
		FinalAge207_206[OptionalMinPoint, OptionalMaxPoint] = interp(Final207_206, LookupTable_76, LookupTable_age)
	endif
	if(Calculate_206_208 == 1)
		wave DC206_208_Spline = $InterpSplineOntoIndexTime("DC206_208", ReferenceStandard)
		variable StdValue_206_208 = GetValueFromStandard("206Pb/208Pb",ReferenceStandard)
		Final206_208[OptionalMinPoint, OptionalMaxPoint]= DC206_208 * (StdValue_206_208 / DC206_208_Spline)
	endif
	//and waves for concentrations and U/Th ratio
	//Note that the isotopic abundance isn't actually necessary in the below line - provided it's the same in the std and sample!
	if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		wave U238_CPS_Spline = $InterpSplineOntoIndexTime(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), ReferenceStandard)
		variable StdValue_UPPM = GetValueFromStandard("U",ReferenceStandard)
		Approx_U_PPM[OptionalMinPoint, OptionalMaxPoint] = StdValue_UPPM * U238_CPS / U238_CPS_Spline * 1000000
	endif
	if(cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		wave Th232_CPS_Spline = $InterpSplineOntoIndexTime(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), ReferenceStandard)
		variable StdValue_ThPPM = GetValueFromStandard("Th",ReferenceStandard)
		Approx_Th_PPM[OptionalMinPoint, OptionalMaxPoint] = StdValue_ThPPM * Th232_CPS / Th232_CPS_Spline	 * 1000000
	endif
	if(cmpstr(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		wave Pb208_CPS_Spline = $InterpSplineOntoIndexTime(StringByKey("208", Measured_UPb_Inputs, "=", ";", 0), ReferenceStandard)
		variable StdValue_PbPPM = GetValueFromStandard("Pb",ReferenceStandard)
		Approx_Pb_PPM[OptionalMinPoint, OptionalMaxPoint] = StdValue_PbPPM * Pb208_CPS / Pb208_CPS_Spline * 1000000			//abundance in std * sample intensity / std intensity * million / isotopic abundance
	endif
	if(cmpstr(StringByKey("238", Measured_UPb_Inputs, "=", ";", 0), "no") != 0 && cmpstr(StringByKey("232", Measured_UPb_Inputs, "=", ";", 0), "no") != 0)
		wave Raw_U_Th_Ratio_Spline = $InterpSplineOntoIndexTime("Raw_U_Th_Ratio", ReferenceStandard)
		FInal_U_Th_Ratio[OptionalMinPoint, OptionalMaxPoint] = Raw_U_Th_Ratio * (StdValue_UPPM / StdValue_ThPPM) / Raw_U_Th_Ratio_Spline	//raw sample ratio * true std ratio / observed std ratio
	endif
	if(Was204Measured == 1)		//if 204 was measured
		wave DC206_204_Spline = $InterpSplineOntoIndexTime("DC206_204", ReferenceStandard)
		variable StdValue_206_204 = GetValueFromStandard("206Pb/204Pb",ReferenceStandard)
		Final206_204[OptionalMinPoint, OptionalMaxPoint]= DC206_204// * (StdValue_206_204 / DC206_204_Spline)
		//if(waveexists(Pb207_Beam) == 1)
			wave DC207_204_Spline = $InterpSplineOntoIndexTime("DC207_204", ReferenceStandard)
			variable StdValue_207_204 = GetValueFromStandard("207Pb/204Pb",ReferenceStandard)
			Final207_204[OptionalMinPoint, OptionalMaxPoint]= DC207_204 //* (StdValue_207_204 / DC207_204_Spline)
		//endif
		//if(waveexists(Pb208_Beam) == 1)
			wave DC208_204_Spline = $InterpSplineOntoIndexTime("DC208_204", ReferenceStandard)
			variable StdValue_208_204 = GetValueFromStandard("208Pb/204Pb",ReferenceStandard)
			Final208_204[OptionalMinPoint, OptionalMaxPoint]= DC208_204 //* (StdValue_208_204 / DC208_204_Spline)
		//endif
	endif 
end

//the below function takes the ratio provided (e.g. "raw_206_238"), combines all std integs relative to shutter opening (i.e. against beamseconds), then makes an average wave of the integs. This average wave
//is then used to curve fit an exponential function. in the process this is all graphed in a new window. Measures of the quality of the fit are also calculated and added to the window
Function VADownHoleCurveFit(Ratio, [OptionalWindowNumber])
	string Ratio
	variable OptionalWindowNumber	//note that this variable is optional
	if(paramisdefault(OptionalWindowNumber))	//so, check if it has been set
		OptionalWindowNumber = 1	//and if it hasn't, set it to 1
	endif
	//the next 5 lines reference all of the global strings and variables in the header of this file for use in the main code of the DRS that follows.
	string currentdatafolder = GetDataFolder(1)
	setdatafolder $ioliteDFpath("DRSGlobals","")
	SVar IndexChannel, ReferenceStandard, DefaultIntensityUnits, UseOutlierRejection, BeamSecondsMethod, CurveFitType
	NVar MaskThreshold, MaskEdgeDiscardSeconds, BeamSecondsSensitivity, MaxBeamDuration, DefaultStartMask, DefaultEndMask, FitOutlierTolerance, Sample238_235Ratio
	setdatafolder $currentdatafolder
	//convert the long names of CurveFitType in the user interface into short labels
	string ShortCurveFitType
	string UserInterfaceList = "Exponential plus optional linear;Linear;Exponential;Double exponential;Smoothed cubic spline;Running median"	//VERY IMPORTANT that this line and the line below are in the same relative order
	string ShortLabelsList = "LinExp;Lin;Exp;DblExp;Spline;RunMed"		//i.e. the first item in the line above must correspond with the first item in this line, etc.
	ShortCurveFitType = StringFromList(WhichListItem(CurveFitType, UserInterfaceList, ";", 0, 0), ShortLabelsList, ";")	//this line extracts the short label corresponding to the user interface label in the above string.
	if(cmpstr(ShortCurveFitType, "") == 0)	//if for some reason the above substitution didn't work, then need to throw an error, as that will have to be fixed
		printabort("Sorry, the DRS failed to recognise the down-hole fractionation model you chose")
	endif
	String WindowName = "Win_"+Ratio+"1"
	DoWindow/F $WindowName 
	if(V_flag==1) //if the window did  already exist, kill it and start again
		killwindow $WindowName
	endif //otherwise, must build it..	
	Wave/z  Index_Time=$ioliteDFpath("CurrentDRS","Index_Time")
	if(!waveexists(Index_Time))
		abort "couldn't find the index_time wave when beginning the DownHoleCurveFit() function"
	endif
	Wave/z IndexOut=$ioliteDFpath("CurrentDRS",IndexChannel +"_"+ DefaultIntensityUnits)
	if(!waveexists(IndexOut))
		abort "Sorry, the IndexOut wave is missing, the DownHoleCurveFit() function has aborted."
	endif	
	variable NoOfPoints=numpnts(Index_Time)
	Wave BeamSeconds=$ioliteDFpath("CurrentDRS","Beam_Seconds")
	wave StandardMatrix = $iolitedfpath("integration","m_" + ReferenceStandard)
	if(!waveexists(StandardMatrix))
		abort "Unable to locate the standard matrix. the function DownHoleCurveFit for the "+ Ratio + " ratio has been abandoned."
	endif
	variable thisinteg=1		//Need to start at 1 here to avoid the first (default) row in the matrix
	variable NoOfIntegs=dimsize(StandardMatrix,0) 
	variable thisstartpoint,thisendpoint,thisstarttime,thisendtime // per-integration start and end points and times
	string ThisWaveName, ThisBeamSecondsName
	Do //loop through the integrations of output_1 and make a separate wave for each one
		if(thisinteg>NoOfIntegs-1) //if there are no integrations left
			break //then break the loop
		endif
		thisstarttime=StandardMatrix[thisinteg][0][%$"Median Time"]-StandardMatrix[thisinteg][0][%$"Time Range"]//get start, and
		thisendtime=StandardMatrix[thisinteg][0][%$"Median Time"]+StandardMatrix[thisinteg][0][%$"Time Range"]//end times for this integration
		//Note that when finding the below start point it's important to go to the point after the start time. do this by adding 1 to the result from binarysearch, then need to check if the result is a NaN. if it is, need to add 1 more.
		thisstartpoint=ForBinarySearch(index_time, thisstarttime) + 1	//NOTE that if binarysearch returned -1 then by adding 1 to the result we'll get 0, which is good.
		//then need to check if the result is a NaN. if it is, need to add 1 more.
		if(numtype(index_time[thisstartpoint]) == 2)	//if the resulting point was a NaN
			thisstartpoint += 1		//then add 1 to it
		endif
		thisendpoint=ForBinarySearch(index_time, thisendtime) //end point returned by binarysearch should be the point preceding the time, which is perfect.
		if(thisendpoint == -2)	//if the last selection goes over the end of the data
			thisendpoint = numpnts(index_time) - 1
		endif
		if(thisstartpoint==thisendpoint) //if start and end points the same, then both times precede or postdate entive wave, wave is only 0 points long, or start and end times do not bracket any point in the wave.
			thisinteg+=1 //set pointer to next sample
			continue //and return to start of loop
		endif //otherwise, have bracketed at least a single point
		if(BeamSeconds[thisstartpoint]> MaxBeamDuration) // this if section eliminates those cases where beamseconds resets after the beginning of the integration by moving the integ start point to beamseconds=0
			wavestats/q/r=[thisstartpoint,thisendpoint] BeamSeconds
			thisstartpoint = V_minloc
			print "The integration at row " + num2str(thisstartpoint) + "  of IndexTime had a beamseconds of greater than " +num2str(MaxBeamDuration) + ", you may have a problem with your detection of beamseconds"
		endif
		ThisWaveName = Ratio+"_StdInt_"+num2str(thisinteg)
		ThisBeamSecondsName = Ratio+"_BeamSec_"+num2str(thisinteg)
		duplicate/o/R=[thisstartpoint,thisendpoint ] $ioliteDFpath("CurrentDRS",Ratio) $ioliteDFpath("temp",ThisWaveName)
		duplicate/o/R=[thisstartpoint,thisendpoint ] $ioliteDFpath("CurrentDRS","Beam_Seconds") $ioliteDFpath("temp",ThisBeamSecondsName)
		wave ThisWave = $ioliteDFpath("temp",ThisWaveName)
		//NOTE the next line smooths all waves generated at this point. The aim of this is ONLY to remove outliers. averaging should take care of normal data noise. It seems to be currently screening large spikes well, may need to be reduced if it turns out it's not catching all spikes)
		//next smooth the wave to replace outlier values with NaN. Note this only replaces positive spikes!
		//Note that "abs()" is used to avoid rare cases containing negative ratios (low counts for an isotope, where some datapoints are 0, combined with a baseline spline above zero produces negative baseline-corrected values)
		Smooth/M=(abs(FitOutlierTolerance*(ThisWave[p]+ThisWave[p+1]+ThisWave[p-1])/3))/R=(NaN) 9, ThisWave //aiming at only removing spikes. set here at 1.5 times the average value for this portion of the wave (9 point range centered on this point)
		thisinteg+=1 //next integration  
	while(thisinteg<NoOfIntegs) //until all integrations added
	//special case of first waves (i.e. integ 0) used to make the window. A loop is then used to append additional integs.
	string FirstWaveName = Ratio+"_StdInt_1"
	string FirstBeamSecondsName = Ratio+"_BeamSec_1"
	wave FirstWave = $ioliteDFpath("temp",FirstWaveName)
	wave FirstBeamSeconds = $ioliteDFpath("temp",FirstBeamSecondsName)
	//searchforthis. need to test if the below coordinates will need to be adjusted for the PC. if they do need to be adjusted, the position of controls and drawn text will need to be checked (below in the strswitch)
	//Will tile the windows across the screen so that they don't directly overlap each other. 
	Variable WindowLeft, WindowRight, WindowTop, WindowBottom
	variable PointToPixelConvert = IfPC() == 1 ? 72/96 : 1	//now need to convert  the pixels used above to points for the below movewindow operation
	WindowLeft = 30*PointToPixelConvert + mod(OptionalWindowNumber, 15)*15*PointToPixelConvert
	WindowRight = WindowLeft + 1020*PointToPixelConvert
	WindowTop = 45*PointToPixelConvert + mod(OptionalWindowNumber, 3)*15*PointToPixelConvert
	WindowBottom = WindowTop + 645*PointToPixelConvert
	//now need to modify these to make them PC friendly	
	//	WindowLeft *= PointToPixelConvert
	//	WindowRight *= PointToPixelConvert
	//	WindowTop *= PointToPixelConvert
	//	WindowBottom *= PointToPixelConvert
	Display/W=(WindowLeft, WindowTop, WindowRight,WindowBottom)/k=1/N=$WindowName /B=Bottom /L=$ratio FirstWave vs FirstBeamSeconds as Ratio + " Down Hole"
	SetWindow $WindowName hook=DCFitWindowHook //set window hook to call the function "TracesWindowHook()" for user events
	ModifyGraph /w=$WindowName noLabel($Ratio)=0, freePos($Ratio)=0, tick($Ratio)=0, axThick($Ratio)=1
	ModifyGraph /W=$WindowName  lSize($FirstWaveName) = 0.5, rgb($FirstWaveName)=(65535,0,65000)
	variable red, blue
	variable LowestBeamSec, HighestBeamSec
	LowestBeamSec = FirstBeamSeconds[0]
	HighestBeamSec = FirstBeamSeconds[inf]	//putting inf here returns the value for the highest point
	thisinteg=2		//have already dealt with the first integ explicitly in the above lines, so start at 2 in the loop
	do
		if(thisinteg>=NoOfIntegs)
			break
		endif
		ThisWaveName = Ratio+"_StdInt_"+num2str(thisinteg)
		ThisBeamSecondsName = Ratio+"_BeamSec_"+num2str(thisinteg)
		wave ThisWave = $ioliteDFpath("temp",ThisWaveName)
		wave ThisBeamSeconds = $ioliteDFpath("temp",ThisBeamSecondsName)
		AppendToGraph /W=$WindowName /B/L=$Ratio ThisWave vs ThisBeamSeconds
		red = 65535 - thisinteg * (50000/NoOfIntegs)
		blue = 35000 + thisinteg * (30000/NoOfIntegs)
		ModifyGraph /W=$WindowName  lSize($ThisWaveName) = 0.5, rgb($ThisWaveName)=(red,32000,blue)
		LowestBeamSec = LowestBeamSec>ThisBeamSeconds[0] ? ThisBeamSeconds[0]:LowestBeamSec	//is the current LowestBeamSec greater than the minimum beamsecs for this integration? If yes, then make it equal the first point of thisbeamseconds, otherwise leave it as is.
		HighestBeamSec = HighestBeamSec<ThisBeamSeconds[numpnts(ThisBeamSeconds)] ? ThisBeamSeconds[numpnts(ThisBeamSeconds)]:HighestBeamSec	//is the current HighestBeamSec lower than the minimum beamsecs for this integration? If yes, then make it equal the last point of thisbeamseconds, otherwise leave it as is.
		thisinteg+=1 //next integration
	while (thisinteg<NoOfIntegs)
	variable TotalPointsInBeamSecs, TimeSpacingOfData
	TimeSpacingOfData = (FirstBeamSeconds[numpnts(FirstBeamSeconds)] - FirstBeamSeconds[0]) / numpnts(FirstBeamSeconds)	//use the first beamseconds to get an estimate of the time spacing of each data point
	TotalPointsInBeamSecs =ceil((HighestBeamSec - LowestBeamSec) / TimeSpacingOfData) //get the number of points that will span all data used in making the average wave and round to the nearest integer.
	string AverageName = "Average_"+ratio
	string AverageErrorName = "AverageError_"+ratio
	string AverageBeamSecsName = "AverageBeamSecs_"+ratio
	wave Average = $MakeioliteWave("CurrentDRS",AverageName,n=TotalPointsInBeamSecs)
	wave AverageError = $MakeioliteWave("CurrentDRS",AverageErrorName,n=TotalPointsInBeamSecs)
	wave TempWaveOfValues = $MakeioliteWave("temp","TempWaveOfValues",n=NoOfIntegs)
	wave AverageBeamSeconds = $MakeioliteWave("CurrentDRS",AverageBeamSecsName,n=TotalPointsInBeamSecs, type = "d")
	average = 0
	TempWaveOfValues = NaN
	AverageBeamSeconds = LowestBeamSec + (TimeSpacingOfData * p)
	variable PointNumber = 0, counter, ThisPointValue
	do	//this loop goes through the average wave one point at a time and collects all the relevant points from each individual standard integration and interpolates them onto the average wave, then generates an average for that point
		thisinteg = 1
		counter = 0
		do	//takes each integration of the standard and interpolates every point onto the nearest point of the average wave
			if(thisinteg>=NoOfIntegs)
				break
			endif
			ThisWaveName = Ratio+"_StdInt_"+num2str(thisinteg)
			ThisBeamSecondsName = Ratio+"_BeamSec_"+num2str(thisinteg)
			wave ThisWave = $ioliteDFpath("temp",ThisWaveName)
			wave ThisBeamSeconds = $ioliteDFpath("temp",ThisBeamSecondsName)
			ThisPointValue = ForInterp(AverageBeamSeconds[PointNumber], ThisBeamSeconds, ThisWave)
			if (Forbinarysearch(ThisBeamSeconds, AverageBeamSeconds[PointNumber])>=0)
				TempWaveOfValues[thisinteg] = ThisPointValue
				counter+=1
			endif
			thisinteg +=1
		while (thisinteg < NoOfIntegs)
		wavestats /q /m=2 TempWaveOfValues
		Average[PointNumber] = v_avg			//calculate the average for all combined points for this particular point of beamseconds
		//need to fix the error below. often it ends up filling the error wave with NaNs, which then later causes trouble for the curvefit
		v_sdev = numtype(v_sdev)==2 ? v_avg : v_sdev	//is v_sdev a NaN? if so, make the error equal to V_avg
		AverageError[PointNumber] = v_sdev	//similarly, calculate the std deviation on the points.
		TempWaveOfValues = NaN	//clear the temporary wave so that if it is filled with fewer values next time it won't have a memory effect.
		PointNumber +=1
	while (PointNumber < TotalPointsInBeamSecs)
	AppendToGraph /W=$WindowName /B/L=$Ratio Average vs AverageBeamSeconds
	ModifyGraph /W=$WindowName  lSize($AverageName) = 2, rgb($AverageName)=(0,0,0)
	setaxis /W=$WindowName /A=1 /E=1 bottom		//sets the axis so that it will autoscale to include all data, but will always keep the low end at zero.
	//all of the above code is to make the window, make separate waves of each std integ vs beamseconds, and make an average wave vs. beamseconds.
	//below is the code to do the actual curve fitting. This is done using the average wave, but incorporating the errors generated in calculating the average wave.
	//up to this point, everything is always the same, regardless of whether a manual or auto fit is used, and regardless of fit type.
	//now need to test for whether an auto or manual fit is required, and behave appropriately. may also need to initialise a lot of things if this is the first time a fit is performed.
	//make the histogram wave and gaussian curve fit wave here, as they will not change
	string HistogramWaveName = "HistoWv_"+ratio
	wave HistogramWave = $MakeioliteWave("CurrentDRS",HistogramWaveName,n=40)
	string GaussianFitName = "GaussFit_"+ratio
	wave GaussianFit = $MakeioliteWave("CurrentDRS",GaussianFitName,n=40)
	string HistoXWaveName = "histoX_"+ratio
	wave HistoXWave = $MakeioliteWave("CurrentDRS",HistoXWaveName,n=40)
	string GFitXWaveName = "GFitX_"+ratio
	wave GfitXWave = $MakeioliteWave("CurrentDRS",GFitXWaveName,n=40)
	//now begin by checking whether things need to be initialised
	string AutoOrManual
	string AutoSVarName = "Auto_"+Ratio+ShortCurveFitType
	AutoSVarName = AutoSVarName[0,30]		//limit the name to 31 characters
	AutoSVarName = CleanupName(AutoSVarName, 0)	//use this just in case a space of something else illegal ended up in the name of one of the fit types
	SVar AutoSetting = $ioliteDFpath("CurrentDRS",AutoSVarName)	// this global (specific to this ratio and fit type) is used to govern whether a fully automatic fit can be used, or it the user has customised settings for the fit. NOTE that these globals need to be in the current DRS folder. If they're in the temp folder they will be deleted during a save, which is bad
	if(SVar_exists(AutoSetting)&&cmpstr(AutoSetting, "Initialise")!=0)	//if this variable exists and is not set to initialise then just use the given setting
		AutoOrManual = AutoSetting	//then set the AutoOrManual string to the given setting
	else	//otherwise the variable doesn't exist or is set to initialise, so make all the generic globals from scratch
		string/g $ioliteDFpath("CurrentDRS",AutoSVarName)	//make the global string
		SVar AutoSetting = $ioliteDFpath("CurrentDRS",AutoSVarName)
		AutoSetting = "FullAuto"		//set this global to fullauto. unless changed by the user, this is how the fit will be performed next time
		AutoOrManual = "Initialise"	//then set the AutoOrManual string to initialise, as this is the first time the fit is being perfomed (on this ratio using this fit type). Once the initialisation is complete it will be set to FullAuto
		Variable/g $ioliteDFpath("CurrentDRS","SM_"+Ratio) = DefaultStartMask	//in addition to the above, declare some globals here that will be used by all of the below curve fit types
		Variable/g $ioliteDFpath("CurrentDRS","EM_"+ratio) = DefaultEndMask
		Variable/g $ioliteDFpath("CurrentDRS","StErr_"+ratio) = 0
		Variable/g $ioliteDFpath("CurrentDRS","Bias_"+ratio) = 0
		Variable/g $ioliteDFpath("CurrentDRS","Gauss_"+ratio) = 0
	endif
	NVar Start_MaskForFit = $ioliteDFpath("CurrentDRS","SM_"+Ratio)	//reference the above 'generic' global variables so that they can be used in all of the curve fit types below
	NVar End_MaskForFit = $ioliteDFpath("CurrentDRS","EM_"+ratio)
	NVar StdErrOfResids = $ioliteDFpath("CurrentDRS","StErr_"+ratio)
	NVar BiasOfResids = $ioliteDFpath("CurrentDRS","Bias_"+ratio)
	NVar GaussOfFit = $ioliteDFpath("CurrentDRS","Gauss_"+ratio)
	//set the main layout indexes for the right hand side of the fit window here. These should all be the same for every fit type. They can then be tweaked within the control code
	variable TopOfBlueHeaderText = 30*PointToPixelConvert
	variable LeftOfBlueHeaderText = 870*PointToPixelConvert
	variable TopOfFirstBox = 85
	variable LeftOfBoxes = 745
	variable TopOfMaskingBox = 323
	variable TopOfQualityBox = 396
	strswitch(ShortCurveFitType)	//ShortCurveFitType is the string set using the edit DRS variables window. 
		case "LinExp":
			if(cmpstr(AutoOrManual,"Initialise")==0)	//do we need to initialise stuff? i.e. is this the first time the fit has been performed (on this ratio using this fit type)?
				variable/g $ioliteDFpath("CurrentDRS","LEVarA_"+ratio) = 0	//make global variables that can be used to remember the values of each fit variable. No need to reference them here, that will be done below
				variable/g $ioliteDFpath("CurrentDRS","LEVarB_"+ratio) = 0
				variable/g $ioliteDFpath("CurrentDRS","LEVarC_"+ratio) = 0
				variable/g $ioliteDFpath("CurrentDRS","LEVarD_"+ratio) = 0
				AutoOrManual = "FullAuto"	//then set to FullAuto to get a normal auto fit in the next step
			endif	//now know that all the globals required exist, so can go ahead and reference them
			NVar Variable_a = $ioliteDFpath("CurrentDRS","LEVarA_"+ratio) 	//reference the globals so that they can be used below
			NVar Variable_b = $ioliteDFpath("CurrentDRS","LEVarB_"+ratio)
			NVar Variable_c = $ioliteDFpath("CurrentDRS","LEVarC_"+ratio)
			NVar Variable_d = $ioliteDFpath("CurrentDRS","LEVarD_"+ratio)
			VAFitToAverageWave(ratio, ShortCurveFitType, AutoOrManual)	//send the relevant strings to a separate function that does the curve fit. Note that variables a,c,d are sent, as b is for the linear component above
			string LEFittedCurveName = "LEFitCurve_"+Ratio
			wave FittedCurve = $ioliteDFpath("CurrentDRS",LEFittedCurveName)
			AppendToGraph /W=$WindowName /B/L=$Ratio FittedCurve vs AverageBeamSeconds
			ModifyGraph /W=$WindowName  lSize($LEFittedCurveName) = 2, rgb($LEFittedCurveName)=(65535,0,5000), axisEnab($Ratio)={0.25,1.0}
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1, fname = "Geneva"
			DrawText /W=$WindowName LeftOfBlueHeaderText, TopOfBlueHeaderText, "The equation for the fit is"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1, fname = "Geneva"
			DrawText /W=$WindowName LeftOfBlueHeaderText-12, TopOfBlueHeaderText+28*PointToPixelConvert, "y = a + bx + c.Exp"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 14*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1, fname = "Geneva"
			DrawText /W=$WindowName LeftOfBlueHeaderText+75*PointToPixelConvert*PointToPixelConvert, TopOfBlueHeaderText+25*PointToPixelConvert, "-dx"
			GroupBox 	LinearComponent 		title="user-defined linear component", win=$WindowName ,pos={LeftOfBoxes,TopOfFirstBox-5},size={250,63}, fsize = 14, frame = 1
			SetVariable BVariable Title = "b =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+30-5},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_b, limits={-10,10,(0.0001*average[0])}, format="%-12.4g", userdata = AutoSVarName
			GroupBox 	ExpComponent 		title="exponential function", win=$WindowName ,pos={LeftOfBoxes,TopOfFirstBox+65},size={250,165}, fsize = 14, frame = 1
			button		LinExpAuto			title="Auto"	, win=$WindowName ,fsize=15, font="Lucida Grande", pos={LeftOfBoxes+35,TopOfFirstBox+95}, fcolor=(25000,25000,64000),size={80,20},proc=VAAutoManButton, userdata = AutoSVarName		//the userdata is set to AutoSVarName for each control so that this info can be extracted later
			button		LinExpManual		title="Manual"	, win=$WindowName ,fsize=15, font="Lucida Grande", pos={LeftOfBoxes+130,TopOfFirstBox+95}, fcolor=(0,0,0),size={80,20},proc=VAAutoManButton, userdata = AutoSVarName
			//Need to define an increment here for the below variables for modifying the fit. Originally used the first point in the average wave, but this causes problems if it's a NaN.
			//Instead, do wavestats on the average wave and use the mean
			wavestats /q /m=1 average
			//can now use the variable V_avg
			SetVariable AVariable Title = "a =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+132},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_a, limits={-10,10,(0.001*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			SetVariable CVariable Title = "c =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+164},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_c, limits={-10,10,(0.002*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			SetVariable DVariable Title = "d =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+196},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_d, limits={-10,10,(0.005*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			if(cmpstr(AutoOrManual, "FullManual")==0)	//all of the above buttons are set up on the assumption that full auto is being used. if it is actually manual, need to change some things:
				modifycontrol LinExpAuto fcolor=(0,0,0), win=$WindowName
				modifycontrol LinExpManual fcolor=(25000,25000,64000), win=$WindowName
				modifycontrol AVariable, win=$WindowName, disable=0
				modifycontrol CVariable, win=$WindowName, disable=0
				modifycontrol DVariable, win=$WindowName, disable=0
			endif
			break
		case "Exp":
			if(cmpstr(AutoOrManual,"Initialise")==0)	//do we need to initialise stuff? i.e. is this the first time the fit has been performed (on this ratio using this fit type)?
				variable/g $ioliteDFpath("CurrentDRS","ExpVarA_"+ratio) = 0	//make global variables that can be used to remember the values of each fit variable. No need to reference them here, that will be done below
				variable/g $ioliteDFpath("CurrentDRS","ExpVarB_"+ratio) = 0
				variable/g $ioliteDFpath("CurrentDRS","ExpVarC_"+ratio) = 0
				AutoOrManual = "FullAuto"	//then set to FullAuto to get a normal auto fit in the next step
			endif	//now know that all the globals required exist, so can go ahead and reference them
			NVar Variable_a = $ioliteDFpath("CurrentDRS","ExpVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			NVar Variable_b = $ioliteDFpath("CurrentDRS","ExpVarB_"+ratio) 
			NVar Variable_c = $ioliteDFpath("CurrentDRS","ExpVarC_"+ratio) 
			VAFitToAverageWave(ratio, ShortCurveFitType, AutoOrManual)	//send the relevant strings to a separate function that does the curve fit. Note that variables a,c,d are sent, as b is for the linear component above
			string ExpFittedCurveName = "ExpFitCurve_"+Ratio
			wave FittedCurve = $ioliteDFpath("CurrentDRS",ExpFittedCurveName)
			AppendToGraph /W=$WindowName /B/L=$Ratio FittedCurve vs AverageBeamSeconds
			ModifyGraph /W=$WindowName  lSize($ExpFittedCurveName) = 2, rgb($ExpFittedCurveName)=(65535,0,5000), axisEnab($Ratio)={0.25,1.0}
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText, TopOfBlueHeaderText, "The equation for the fit is"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText-10*PointToPixelConvert*PointToPixelConvert, TopOfBlueHeaderText+28*PointToPixelConvert, "y = a + b.Exp"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 14*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText+75*PointToPixelConvert*PointToPixelConvert, TopOfBlueHeaderText+25*PointToPixelConvert*PointToPixelConvert, "-cx"
			GroupBox 	ExpComponent 		title="Exponential function", win=$WindowName ,pos={LeftOfBoxes,TopOfFirstBox+40},size={250,165}, fsize = 14, frame = 1
			button		ExpAuto			title="Auto"	, win=$WindowName ,fsize=15, font="Lucida Grande", pos={LeftOfBoxes+35,TopOfFirstBox+70}, fcolor=(25000,25000,64000),size={80,20},proc=VAAutoManButton, userdata = AutoSVarName		//the userdata is set to AutoSVarName for each control so that this info can be extracted later
			button		ExpManual			title="Manual"	, win=$WindowName ,fsize=15, font="Lucida Grande", pos={LeftOfBoxes+130,TopOfFirstBox+70}, fcolor=(0,0,0),size={80,20},proc=VAAutoManButton, userdata = AutoSVarName
			//Need to define an increment here for the below variables for modifying the fit. Originally used the first point in the average wave, but this causes problems if it's a NaN.
			//Instead, do wavestats on the average wave and use the mean
			wavestats /q /m=1 average
			//can now use the variable V_avg
			SetVariable AVariable Title = "a =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+107},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_a, limits={-10,10,(0.001*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			SetVariable BVariable Title = "b =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+139},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_b, limits={-10,10,(0.002*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			SetVariable CVariable Title = "c =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+171},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_c, limits={-10,10,(0.005*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			if(cmpstr(AutoOrManual, "FullManual")==0)	//all of the above buttons are set up on the assumption that full auto is being used. if it is actually manual, need to change some things:
				modifycontrol ExpAuto fcolor=(0,0,0), win=$WindowName
				modifycontrol ExpManual fcolor=(25000,25000,64000), win=$WindowName
				modifycontrol AVariable, win=$WindowName, disable=0
				modifycontrol BVariable, win=$WindowName, disable=0
				modifycontrol CVariable, win=$WindowName, disable=0
			endif
			break
		case "DblExp":
			if(cmpstr(AutoOrManual,"Initialise")==0)	//do we need to initialise stuff? i.e. is this the first time the fit has been performed (on this ratio using this fit type)?
				variable/g $ioliteDFpath("CurrentDRS","DblExpVarA_"+ratio) = 0	//make global variables that can be used to remember the values of each fit variable. No need to reference them here, that will be done below
				variable/g $ioliteDFpath("CurrentDRS","DblExpVarB_"+ratio) = 0
				variable/g $ioliteDFpath("CurrentDRS","DblExpVarC_"+ratio) = 0
				variable/g $ioliteDFpath("CurrentDRS","DblExpVarD_"+ratio) = 0
				variable/g $ioliteDFpath("CurrentDRS","DblExpVarE_"+ratio) = 0
				AutoOrManual = "FullAuto"	//then set to FullAuto to get a normal auto fit in the next step
			endif	//now know that all the globals required exist, so can go ahead and reference them
			NVar Variable_a = $ioliteDFpath("CurrentDRS","DblExpVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			NVar Variable_b = $ioliteDFpath("CurrentDRS","DblExpVarB_"+ratio) 
			NVar Variable_c = $ioliteDFpath("CurrentDRS","DblExpVarC_"+ratio) 
			NVar Variable_d = $ioliteDFpath("CurrentDRS","DblExpVarD_"+ratio) 
			NVar Variable_e = $ioliteDFpath("CurrentDRS","DblExpVarE_"+ratio) 
			VAFitToAverageWave(ratio, ShortCurveFitType, AutoOrManual)	//send the relevant strings to a separate function that does the curve fit. Note that variables a,c,d are sent, as b is for the linear component above
			string DblExpFittedCurveName = "DblExpFitCurve_"+Ratio
			wave FittedCurve = $ioliteDFpath("CurrentDRS",DblExpFittedCurveName)
			AppendToGraph /W=$WindowName /B/L=$Ratio FittedCurve vs AverageBeamSeconds
			ModifyGraph /W=$WindowName  lSize($DblExpFittedCurveName) = 2, rgb($DblExpFittedCurveName)=(65535,0,5000), axisEnab($Ratio)={0.25,1.0}
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText, TopOfBlueHeaderText, "The equation for the fit is"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText-30*PointToPixelConvert-30*PointToPixelConvert*PointToPixelConvert, TopOfBlueHeaderText+28*PointToPixelConvert, "y = a + b.Exp"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 14*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText+5*PointToPixelConvert*PointToPixelConvert, TopOfBlueHeaderText+25*PointToPixelConvert, "-cx"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText+50*PointToPixelConvert*PointToPixelConvert, TopOfBlueHeaderText+28*PointToPixelConvert, "+ d.Exp"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 14*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText+70*PointToPixelConvert*PointToPixelConvert+25*PointToPixelConvert, TopOfBlueHeaderText+25*PointToPixelConvert, "-ex"
			GroupBox 	DblExpComponent 		title="Double Exponential", win=$WindowName ,pos={LeftOfBoxes,TopOfFirstBox+5},size={250,227}, fsize = 14, frame = 1
			button		DblExpAuto			title="Auto"	, win=$WindowName ,fsize=15, font="Lucida Grande", pos={LeftOfBoxes+35,TopOfFirstBox+35}, fcolor=(25000,25000,64000),size={80,20},proc=VAAutoManButton, userdata = AutoSVarName		//the userdata is set to AutoSVarName for each control so that this info can be extracted later
			button		DblExpManual			title="Manual"	, win=$WindowName ,fsize=15, font="Lucida Grande", pos={LeftOfBoxes+130,TopOfFirstBox+35}, fcolor=(0,0,0),size={80,20},proc=VAAutoManButton, userdata = AutoSVarName
			//Need to define an increment here for the below variables for modifying the fit. Originally used the first point in the average wave, but this causes problems if it's a NaN.
			//Instead, do wavestats on the average wave and use the mean
			wavestats /q /m=1 average
			//can now use the variable V_avg
			SetVariable AVariable Title = "a =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+72},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_a, limits={-10,10,(0.001*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			SetVariable BVariable Title = "b =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+104},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_b, limits={-10,10,(0.002*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			SetVariable CVariable Title = "c =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+136},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_c, limits={-10,10,(0.005*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			SetVariable DVariable Title = "d =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+169},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_d, limits={-10,10,(0.005*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			SetVariable EVariable Title = "e =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+201},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_e, limits={-10,10,(0.005*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			if(cmpstr(AutoOrManual, "FullManual")==0)	//all of the above buttons are set up on the assumption that full auto is being used. if it is actually manual, need to change some things:
				modifycontrol DblExpAuto fcolor=(0,0,0), win=$WindowName
				modifycontrol DblExpManual fcolor=(25000,25000,64000), win=$WindowName
				modifycontrol AVariable, win=$WindowName, disable=0
				modifycontrol BVariable, win=$WindowName, disable=0
				modifycontrol CVariable, win=$WindowName, disable=0
				modifycontrol DVariable, win=$WindowName, disable=0
				modifycontrol EVariable, win=$WindowName, disable=0
			endif
			break
		case "Lin":
			if(cmpstr(AutoOrManual,"Initialise")==0)	//do we need to initialise stuff? i.e. is this the first time the fit has been performed (on this ratio using this fit type)?
				variable/g $ioliteDFpath("CurrentDRS","LinVarA_"+ratio) = 0	//make global variables that can be used to remember the values of each fit variable. No need to reference them here, that will be done below
				variable/g $ioliteDFpath("CurrentDRS","LinVarB_"+ratio) = 0
				AutoOrManual = "FullAuto"	//then set to FullAuto to get a normal auto fit in the next step
			endif	//now know that all the globals required exist, so can go ahead and reference them
			NVar Variable_a = $ioliteDFpath("CurrentDRS","LinVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			NVar Variable_b = $ioliteDFpath("CurrentDRS","LinVarB_"+ratio) 
			VAFitToAverageWave(ratio, ShortCurveFitType, AutoOrManual)	//send the relevant strings to a separate function that does the curve fit. Note that variables a,c,d are sent, as b is for the linear component above
			string LinFittedCurveName = "LinFitCurve_"+Ratio
			wave FittedCurve = $ioliteDFpath("CurrentDRS",LinFittedCurveName)
			AppendToGraph /W=$WindowName /B/L=$Ratio FittedCurve vs AverageBeamSeconds
			ModifyGraph /W=$WindowName  lSize($LinFittedCurveName) = 2, rgb($LinFittedCurveName)=(65535,0,5000), axisEnab($Ratio)={0.25,1.0}
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText, TopOfBlueHeaderText, "The equation for the fit is"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText-10*PointToPixelConvert, TopOfBlueHeaderText+28*PointToPixelConvert, "y = a + bx"
			GroupBox 	LinComponent 		title="linear function", win=$WindowName ,pos={LeftOfBoxes,TopOfFirstBox+80},size={250,135}, fsize = 14, frame = 1
			button		LinAuto			title="Auto"	, win=$WindowName ,fsize=15, font="Lucida Grande", pos={LeftOfBoxes+35,TopOfFirstBox+115}, fcolor=(25000,25000,64000),size={80,20},proc=VAAutoManButton, userdata = AutoSVarName		//the userdata is set to AutoSVarName for each control so that this info can be extracted later
			button		LinManual			title="Manual"	, win=$WindowName ,fsize=15, font="Lucida Grande", pos={LeftOfBoxes+130,TopOfFirstBox+115}, fcolor=(0,0,0),size={80,20},proc=VAAutoManButton, userdata = AutoSVarName
			//Need to define an increment here for the below variables for modifying the fit. Originally used the first point in the average wave, but this causes problems if it's a NaN.
			//Instead, do wavestats on the average wave and use the mean
			wavestats /q /m=1 average
			//can now use the variable V_avg
			SetVariable AVariable Title = "a =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+147},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_a, limits={-10,10,(0.001*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			SetVariable BVariable Title = "b =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+179},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_b, limits={-10,10,(0.0001*V_avg)}, format="%-12.6g", disable=2, userdata = AutoSVarName
			if(cmpstr(AutoOrManual, "FullManual")==0)	//all of the above buttons are set up on the assumption that full auto is being used. if it is actually manual, need to change some things:
				modifycontrol LinAuto fcolor=(0,0,0), win=$WindowName
				modifycontrol LinManual fcolor=(25000,25000,64000), win=$WindowName
				modifycontrol AVariable, win=$WindowName, disable=0
				modifycontrol BVariable, win=$WindowName, disable=0
			endif
			break
		case "RunMed":
			if(cmpstr(AutoOrManual,"Initialise")==0)	//do we need to initialise stuff? i.e. is this the first time the fit has been performed (on this ratio using this fit type)?
				variable/g $ioliteDFpath("CurrentDRS","SmthVarA_"+ratio) = 10	//make global variables that can be used to remember the values of each fit variable. No need to reference them here, that will be done below
				AutoOrManual = "FullAuto"	//then set to FullAuto to get a normal auto fit in the next step
			endif	//now know that all the globals required exist, so can go ahead and reference them
			NVar Variable_a = $ioliteDFpath("CurrentDRS","SmthVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			VAFitToAverageWave(ratio, ShortCurveFitType, AutoOrManual)	//send the relevant strings to a separate function that does the curve fit. Note that variables a,c,d are sent, as b is for the linear component above
			string SmthFittedCurveName = "SmthFitCurve_"+Ratio
			wave FittedCurve = $ioliteDFpath("CurrentDRS",SmthFittedCurveName)
			AppendToGraph /W=$WindowName /B/L=$Ratio FittedCurve vs AverageBeamSeconds
			ModifyGraph /W=$WindowName  lSize($SmthFittedCurveName) = 2, rgb($SmthFittedCurveName)=(65535,0,5000), axisEnab($Ratio)={0.25,1.0}
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText-10*PointToPixelConvert, TopOfBlueHeaderText, "A running median of the standard"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText-10*PointToPixelConvert, TopOfBlueHeaderText+28*PointToPixelConvert, "was used, with a window"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText+10*PointToPixelConvert, TopOfBlueHeaderText+56*PointToPixelConvert, "of 'a' seconds"
			GroupBox 	SmthComponent 		title="Smoothing", win=$WindowName ,pos={LeftOfBoxes,TopOfFirstBox+80},size={250,65}, fsize = 14, frame = 1
			SetVariable AVariable Title = "a =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+107},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_a, limits={1,200,4}, format="%-12.6g", userdata = AutoSVarName
			break
		case "Spline":
			if(cmpstr(AutoOrManual,"Initialise")==0)	//do we need to initialise stuff? i.e. is this the first time the fit has been performed (on this ratio using this fit type)?
				variable/g $ioliteDFpath("CurrentDRS","SplVarA_"+ratio) = 1.5	//make global variables that can be used to remember the values of each fit variable. No need to reference them here, that will be done below
				AutoOrManual = "FullAuto"	//then set to FullAuto to get a normal auto fit in the next step
			endif	//now know that all the globals required exist, so can go ahead and reference them
			NVar Variable_a = $ioliteDFpath("CurrentDRS","SplVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			VAFitToAverageWave(ratio, ShortCurveFitType, AutoOrManual)	//send the relevant strings to a separate function that does the curve fit. Note that variables a,c,d are sent, as b is for the linear component above
			string SplineCurveName = "SplineCurve_"+Ratio
			wave FittedCurve = $ioliteDFpath("CurrentDRS",SplineCurveName)
			wave SplineBeamSecs = $ioliteDFpath("CurrentDRS","SplineBeamSecs_"+ratio)
			AppendToGraph /W=$WindowName /B/L=$Ratio FittedCurve vs SplineBeamSecs
			ModifyGraph /W=$WindowName  lSize($SplineCurveName) = 2, rgb($SplineCurveName)=(65535,0,5000), axisEnab($Ratio)={0.25,1.0}
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText-10*PointToPixelConvert, TopOfBlueHeaderText, "A smoothing spline was used"
			SetDrawEnv textrgb=  (1,4,52428), fsize= 16*PointToPixelConvert, xcoord= abs,ycoord= abs,textxjust= 1,textyjust= 1
			DrawText /W=$WindowName LeftOfBlueHeaderText-10*PointToPixelConvert, TopOfBlueHeaderText+28*PointToPixelConvert, "with a smoothing of 'a'"
			GroupBox 	SmthComponent 		title="Smoothing", win=$WindowName ,pos={LeftOfBoxes,TopOfFirstBox+80},size={250,65}, fsize = 14, frame = 1
			SetVariable AVariable Title = "a =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+90,TopOfFirstBox+107},size={100,20}, bodyWidth=115, frame=0, proc=VAVariableFitUpdate, value=Variable_a, limits={.001,200,0.05}, format="%-12.6g", userdata = AutoSVarName
			break
	endswitch
	//controls and group box for masking
	GroupBox 	Masking 		title="masking of start/end", win=$WindowName ,pos={LeftOfBoxes,TopOfMaskingBox-2},size={250,68}, fsize = 14, frame = 1
	SetVariable StartMask Title = "start trim (seconds) =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+100,TopOfMaskingBox+18},size={130,20}, bodyWidth=60, frame=0, proc=VAVariableFitUpdate, value=Start_MaskForFit, limits={0,120,0.25}, userdata = AutoSVarName
	SetVariable EndMask Title = "end trim (seconds) =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+100,TopOfMaskingBox+40},size={130,20}, bodyWidth=60, frame=0, proc=VAVariableFitUpdate, value=End_MaskForFit, limits={0,120,0.25}, userdata = AutoSVarName
	doupdate
	VAMaskStartOrEnd(ratio, WindowName, "StartMask", Start_MaskForFit)	//calling this function here creates the grey mask boxes on the graph if required
	VAMaskStartOrEnd(ratio, WindowName, "EndMask", End_MaskForFit)
	//controls and group box for quality of fit controls/displays
	GroupBox 	FitQuality 		Title="quality of fit", win=$WindowName ,pos={LeftOfBoxes,TopOfQualityBox},size={250,247}, fsize = 14, frame = 1
	SetVariable StdErrOfFit 		Title = "Standard error ( in %) =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+105,TopOfQualityBox+21},size={130,20}, bodyWidth=60, frame=0, noproc, value=StdErrOfResids, limits={inf, inf, 0}, disable = 2, format="%-12.4g"
	SetVariable BiasOfFit		Title = "Bias of fit ( in %) =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+105,TopOfQualityBox+42},size={130,20}, bodyWidth=60, frame=0, noproc, value=BiasOfResids, limits={inf, inf, 0}, disable = 2, format="%-12.3g"
	//SetVariable HowGaussian	Title = "Gaussian =",fsize=14, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+105,TopOfQualityBox+75},size={130,20}, bodyWidth=60, frame=0, noproc, value=GaussOfFit, limits={inf, inf, 0}, disable = 2, format="%-12.3g"
	Checkbox FitGauss			Title = "Show ideal Gaussian curve",fsize=13, font="Lucida Grande", win=$WindowName, pos={LeftOfBoxes+35,TopOfQualityBox+227},size={130,20}, mode=0, value = 1, proc = VACheckboxFitUpdate, userdata = AutoSVarName
	//have now made all the control stuff down the right hand side
	//now make the waves that will be used in the histogram and gaussian curve fit
	string ResidualsName = "Residuals_"+ratio
	wave Residuals = $IoliteDFPath("CurrentDRS",ResidualsName)
	//now append residuals to the graph
	AppendToGraph /W=$WindowName /B/L=ResidualsAxis Residuals vs AverageBeamSeconds
	ModifyGraph /W=$WindowName  lsize($ResidualsName) = 0.2, rgb($ResidualsName)=(65535,0,0), axisEnab(Bottom)={0.0,0.7}, axisEnab(ResidualsAxis)={0.0,0.22}, noLabel(ResidualsAxis)=0, freePos(ResidualsAxis)=0, hbFill($ResidualsName)=2
	ModifyGraph /W=$WindowName mode($ResidualsName)=5, fsize(ResidualsAxis) = 15*PointToPixelConvert, fsize(bottom) = 15*PointToPixelConvert, fsize($Ratio) = 15*PointToPixelConvert, nticks($Ratio) = 7
	newfreeaxis/B/O /W=$WindowName  ResidualsZeroMarker
	ModifyFreeAxis ResidualsZeroMarker, master=bottom
	ModifyGraph /W=$WindowName freePos(ResidualsZeroMarker)={0,ResidualsAxis}, axisEnab(ResidualsZeroMarker)={0.0,0.7}, tick(ResidualsZeroMarker) = 3, nolabel(ResidualsZeroMarker) = 2, axisOnTop(ResidualsZeroMarker) =1
	Label /W=$WindowName bottom, "Residuals of the fit to the average (black) wave, expressed as %"
	ModifyGraph /W=$WindowName margin(left)=75, margin(right)=0, margin(bottom)=60*PointToPixelConvert, lblPos=78, highTrip(ResidualsAxis)=1000, lowTrip(ResidualsAxis)=0.0001
	ModifyGraph /W=$WindowName lblMargin(bottom)=210, lblLatPos(bottom)=0, axOffset(bottom)=-1
	SetDrawEnv textrgb=  (0,0,0), fsize= 15*PointToPixelConvert, xcoord= rel,ycoord= rel,textxjust= 1,textyjust= 1, fstyle=0, fname = "Geneva"
	DrawText /W=$WindowName .40, .98, "Seconds since shutter open"
	// and append the histogram and gaussian curve stuff
	
	//Chadchad
	//Modify this to include two Gaussians - one for all residuals data, and one for the unmasked area
	
	AppendToGraph /W=$WindowName /L=GaussLeft/B=GaussBottom GaussianFit vs GfitXWave
	modifygraph /W=$WindowName rgb($GaussianFitName)=(32000,32000,32000), lsize($GaussianFitName) = 1
	ModifyGraph lblPos(bottom)=-80*PointToPixelConvert-40*PointToPixelConvert*PointToPixelConvert
	AppendToGraph /W=$WindowName /L=GaussLeft/B=GaussBottom HistogramWave vs HistoXWave
	ModifyGraph /W=$WindowName axisEnab(GaussLeft)={0.0,0.23}, axisEnab(GaussBottom)={0.77,1}, noLabel(GaussLeft)=2
	ModifyGraph /W=$WindowName mode($HistogramWaveName)=5, hbFill($HistogramWaveName)=0, freePos(GaussLeft)={0,GaussBottom}, freePos(GaussBottom)={0,GaussLeft}
	ModifyGraph /W=$WindowName tick(GaussLeft)=3, axisOnTop(GaussBottom) =1, axisOnTop(GaussLeft) =1, fsize(GaussBottom) = 13*PointToPixelConvert, nticks(GaussBottom) = 5
end

Function VAFitToAverageWave(ratio, ShortCurveFitType, AutoOrManual)
	string ratio, ShortCurveFitType, AutoOrManual		//required strings to be passed when calling this funciton
	string AverageName = "Average_"+ratio
	string AverageErrorName = "AverageError_"+ratio
	string AverageBeamSecsName = "AverageBeamSecs_"+ratio
	wave Average = $ioliteDFpath("CurrentDRS",AverageName)
	wave AverageError = $ioliteDFpath("CurrentDRS",AverageErrorName)
	wave AverageBeamSeconds = $ioliteDFpath("CurrentDRS",AverageBeamSecsName)
	variable TotalPointsInBeamSecs = numpnts(AverageBeamSeconds)
	string ErrorsOnFitName = "ErrorsOnFit_"+ratio
	string ResidualsName = "Residuals_"+ratio
	wave ErrorsOnFit = $MakeioliteWave("CurrentDRS",ErrorsOnFitName,n=TotalPointsInBeamSecs)
	wave Residuals = $MakeioliteWave("CurrentDRS",ResidualsName,n=TotalPointsInBeamSecs)
	String WindowName = "Win_"+Ratio+"1"
	NVar Start_MaskForFit = $ioliteDFpath("CurrentDRS","SM_"+Ratio)	//reference the above 'generic' global variables so that they can be used in all of the curve fit types below
	NVar End_MaskForFit = $ioliteDFpath("CurrentDRS","EM_"+ratio)
	variable StartPoint, EndPoint
	StartPoint = BinarySearch(AverageBeamSeconds, (0+Start_MaskForFit))
	StartPoint = StartPoint<0 ? 0 : StartPoint
	EndPoint = BinarySearch(AverageBeamSeconds, (AverageBeamSeconds[TotalPointsInBeamSecs-1] - End_MaskForFit))
	NVar StdErrOfResids = $ioliteDFpath("CurrentDRS","StErr_"+ratio)
	NVar BiasOfResids = $ioliteDFpath("CurrentDRS","Bias_"+ratio)
	NVar GaussOfFit = $ioliteDFpath("CurrentDRS","Gauss_"+ratio)
	strswitch(ShortCurveFitType)	//ShortCurveFitType is the string set using the edit DRS variables window. 
		case "LinExp":
			NVar Variable_a = $ioliteDFpath("CurrentDRS","LEVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			NVar Variable_b = $ioliteDFpath("CurrentDRS","LEVarB_"+ratio) 	//this global is for the linear component. it is used here to allow the fitted curve to access the linear value
			NVar Variable_c = $ioliteDFpath("CurrentDRS","LEVarC_"+ratio)
			NVar Variable_d = $ioliteDFpath("CurrentDRS","LEVarD_"+ratio)
			duplicate/O Average $ioliteDFpath("temp","T_" + AverageName)	//this wave is duplicated so that it can be modified below for the linear component of the fit
			wave TempAverage = $ioliteDFpath("temp","T_" + AverageName)
			TempAverage = Average - Variable_b*AverageBeamSeconds	//the function of this temp wave is to temporarily subtract the linear component, do the exp fit, then add the linear component back on using the final equation
			string LEFittedCurveName = "LEFitCurve_"+Ratio
			string CoefficientLEName = "LECoeff_" + Ratio
			wave Coefficients = $MakeioliteWave("CurrentDRS",CoefficientLEName, n=3)
			if(Variable_a == 0 && Variable_c == 0 && Variable_d == 0)	//check if values do not exist for the coefficents wave. If they don't then use curvefit to generate initial guesses and put them into the Coefficients wave
				CurveFit /O/q/n exp, kwCWave= Coefficients, TempAverage[StartPoint, EndPoint] /x=AverageBeamSeconds[StartPoint, EndPoint] /i=1 /F={0.95, 4} /w=AverageError[StartPoint, EndPoint]
			else		//otherwise put the existing values into the Coefficients wave as best guesses
				Coefficients[0] = Variable_a
				Coefficients[1] = Variable_c
				Coefficients[2] = Variable_d
			endif	//have now populated the coefficients wave with best guesses, either based on the manual fit parameters, or on an automatic best guess
			if(cmpstr(AutoOrManual, "Fullauto")==0)		//Note that full auto still allows the user to tweak the linear component, as this is treated separately to the exp fit
				CurveFit /G/q/n exp, kwCWave= Coefficients, TempAverage[StartPoint, EndPoint] /x=AverageBeamSeconds[StartPoint, EndPoint] /i=1 /F={0.95, 4} /w=AverageError[StartPoint, EndPoint] ///F={0.95, 1,	Errorbar, ErrorsOnFit[StartPoint, EndPoint]} 
			elseif(cmpstr(AutoOrManual, "FullManual")==0)
				Coefficients[0] = Variable_a
				Coefficients[1] = Variable_c
				Coefficients[2] = Variable_d
				//don't actually need to do a curve fit here, as the variables are all set by the user. having updated the coefficients wave, the residuals and fitted wave will be calculated below
			else		//not supported yet. The aim here is to allow single variables to be 'held' while the others are fitted automatically. In this case the string will contain something like "100" to hold variable 1 while letting 2 and 3 fit
				Coefficients[0] = Variable_a		//set the initial guesses of all variables. those being held will be kept at these values
				Coefficients[1] = Variable_c
				Coefficients[2] = Variable_d
				CurveFit /q/n/H=(AutoOrManual) exp, kwCWave= Coefficients, TempAverage[StartPoint, EndPoint] /x=AverageBeamSeconds[StartPoint, EndPoint] /i=1 /F={0.95, 4} /w=AverageError[StartPoint, EndPoint]
			endif
			wave W_ParamConfidenceInterval	//this wave has been generated becuase the /F flag was used. it contains errors for each coefficient for the fit
			duplicate/O Average $ioliteDFpath("CurrentDRS",LEFittedCurveName)
			wave FittedCurve = $ioliteDFpath("CurrentDRS",LEFittedCurveName)
			//may need to extend the fitted curve to time=0
			FittedCurve = Coefficients[0] + Variable_b*AverageBeamSeconds + Coefficients[1]*Exp(-Coefficients[2]*AverageBeamSeconds)
			Residuals = (Average - FittedCurve)/FittedCurve*100	//calculate residuals and convert to a percentage
			Variable_a = Coefficients[0]
			Variable_c = Coefficients[1]
			Variable_d = Coefficients[2]
			break
		case "Exp":
			NVar Variable_a = $ioliteDFpath("CurrentDRS","ExpVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			NVar Variable_b = $ioliteDFpath("CurrentDRS","ExpVarB_"+ratio) 	//this global is for the linear component. it is used here to allow the fitted curve to access the linear value
			NVar Variable_c = $ioliteDFpath("CurrentDRS","ExpVarC_"+ratio)
			string ExpFittedCurveName = "ExpFitCurve_"+Ratio
			string CoefficientExpName = "ExpCoeff_" + Ratio
			wave Coefficients = $MakeioliteWave("CurrentDRS",CoefficientExpName, n=3)
			if(Variable_a == 0 && Variable_b == 0 && Variable_c == 0)	//check if values do not exist for the coefficents wave. If they don't then use curvefit to generate initial guesses and put them into the Coefficients wave
				CurveFit /O/q/n exp, kwCWave= Coefficients, Average[StartPoint, EndPoint] /x=AverageBeamSeconds[StartPoint, EndPoint] /i=1 /F={0.95, 4} /w=AverageError[StartPoint, EndPoint]
			else		//otherwise put the existing values into the Coefficients wave as best guesses
				Coefficients[0] = Variable_a
				Coefficients[1] = Variable_b
				Coefficients[2] = Variable_c
			endif	//have now populated the coefficients wave with best guesses, either based on the manual fit parameters, or on an automatic best guess
			if(cmpstr(AutoOrManual, "Fullauto")==0)		//Note that full auto still allows the user to tweak the linear component, as this is treated separately to the exp fit
				CurveFit /q/n exp, kwCWave= Coefficients, Average[StartPoint, EndPoint] /x=AverageBeamSeconds[StartPoint, EndPoint] /i=1 /F={0.95, 4} /w=AverageError[StartPoint, EndPoint] ///F={0.95, 1,	Errorbar, ErrorsOnFit[StartPoint, EndPoint]} 
			elseif(cmpstr(AutoOrManual, "FullManual")==0)
				Coefficients[0] = Variable_a
				Coefficients[1] = Variable_b
				Coefficients[2] = Variable_c
				//don't actually need to do a curve fit here, as the variables are all set by the user. having updated the coefficients wave, the residuals and fitted wave will be calculated below
			endif
			wave W_ParamConfidenceInterval	//this wave has been generated becuase the /F flag was used. it contains errors for each coefficient for the fit
			duplicate/O Average $ioliteDFpath("CurrentDRS",ExpFittedCurveName)
			wave FittedCurve = $ioliteDFpath("CurrentDRS",ExpFittedCurveName)
			//may need to extend the fitted curve to time=0
			FittedCurve = Coefficients[0] + Coefficients[1]*Exp(-Coefficients[2]*AverageBeamSeconds)
			Residuals = (Average - FittedCurve)/FittedCurve*100	//calculate residuals and convert to a percentage
			Variable_a = Coefficients[0]
			Variable_b = Coefficients[1]
			Variable_c = Coefficients[2]
			break
		case "DblExp":
			NVar Variable_a = $ioliteDFpath("CurrentDRS","DblExpVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			NVar Variable_b = $ioliteDFpath("CurrentDRS","DblExpVarB_"+ratio) 	//this global is for the linear component. it is used here to allow the fitted curve to access the linear value
			NVar Variable_c = $ioliteDFpath("CurrentDRS","DblExpVarC_"+ratio)
			NVar Variable_d = $ioliteDFpath("CurrentDRS","DblExpVarD_"+ratio)
			NVar Variable_e = $ioliteDFpath("CurrentDRS","DblExpVarE_"+ratio)
			string DblExpFittedCurveName = "DblExpFitCurve_"+Ratio
			string CoefficientName = "DblExpCoeff_" + Ratio
			wave Coefficients = $MakeioliteWave("CurrentDRS",CoefficientName, n=5)
			if(Variable_a == 0 && Variable_b == 0 && Variable_c == 0 && Variable_d == 0 && Variable_e == 0)	//check if values do not exist for the coefficents wave. If they don't then use curvefit to generate initial guesses and put them into the Coefficients wave
				CurveFit /O/q/n dblexp, kwCWave= Coefficients, Average[StartPoint, EndPoint] /x=AverageBeamSeconds[StartPoint, EndPoint] /i=1 /F={0.95, 4} /w=AverageError[StartPoint, EndPoint]
			else		//otherwise put the existing values into the Coefficients wave as best guesses
				Coefficients[0] = Variable_a
				Coefficients[1] = Variable_b
				Coefficients[2] = Variable_c
				Coefficients[3] = Variable_d
				Coefficients[4] = Variable_e
			endif	//have now populated the coefficients wave with best guesses, either based on the manual fit parameters, or on an automatic best guess
			if(cmpstr(AutoOrManual, "Fullauto")==0)		//Note that full auto still allows the user to tweak the linear component, as this is treated separately to the exp fit
				CurveFit /q/n dblexp, kwCWave= Coefficients, Average[StartPoint, EndPoint] /x=AverageBeamSeconds[StartPoint, EndPoint] /i=1 /F={0.95, 4} /w=AverageError[StartPoint, EndPoint] ///F={0.95, 1,	Errorbar, ErrorsOnFit[StartPoint, EndPoint]} 
			elseif(cmpstr(AutoOrManual, "FullManual")==0)
				Coefficients[0] = Variable_a
				Coefficients[1] = Variable_b
				Coefficients[2] = Variable_c
				Coefficients[3] = Variable_d
				Coefficients[4] = Variable_e
				//don't actually need to do a curve fit here, as the variables are all set by the user. having updated the coefficients wave, the residuals and fitted wave will be calculated below
			endif
			wave W_ParamConfidenceInterval	//this wave has been generated becuase the /F flag was used. it contains errors for each coefficient for the fit
			duplicate/O Average $ioliteDFpath("CurrentDRS",DblExpFittedCurveName)
			wave FittedCurve = $ioliteDFpath("CurrentDRS",DblExpFittedCurveName)
			//may need to extend the fitted curve to time=0
			FittedCurve = Coefficients[0] + Coefficients[1]*Exp(-Coefficients[2]*AverageBeamSeconds) + Coefficients[3]*exp(-Coefficients[4]*AverageBeamSeconds)
			Residuals = (Average - FittedCurve)/FittedCurve*100	//calculate residuals and convert to a percentage
			Variable_a = Coefficients[0]
			Variable_b = Coefficients[1]
			Variable_c = Coefficients[2]
			Variable_d = Coefficients[3]
			Variable_e = Coefficients[4]
			break
		case "Lin":
			NVar Variable_a = $ioliteDFpath("CurrentDRS","LinVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			NVar Variable_b = $ioliteDFpath("CurrentDRS","LinVarB_"+ratio) 	//this global is for the linear component. it is used here to allow the fitted curve to access the linear value
			string LinFittedCurveName = "LinFitCurve_"+Ratio
			string CoefficientLinName = "LinCoeff_" + Ratio
			wave Coefficients = $MakeioliteWave("CurrentDRS",CoefficientLinName, n=2)
			if(Variable_a == 0 && Variable_b == 0)	//check if values do not exist for the coefficents wave. If they don't then use curvefit to generate initial guesses and put them into the Coefficients wave
				CurveFit /O/q/n line, kwCWave= Coefficients, Average[StartPoint, EndPoint] /x=AverageBeamSeconds[StartPoint, EndPoint] /i=1 /F={0.95, 4} /w=AverageError[StartPoint, EndPoint]
			else		//otherwise put the existing values into the Coefficients wave as best guesses
				Coefficients[0] = Variable_a
				Coefficients[1] = Variable_b
			endif	//have now populated the coefficients wave with best guesses, either based on the manual fit parameters, or on an automatic best guess
			if(cmpstr(AutoOrManual, "Fullauto")==0)		//Note that full auto still allows the user to tweak the linear component, as this is treated separately to the exp fit
				CurveFit /q/n line, kwCWave= Coefficients, Average[StartPoint, EndPoint] /x=AverageBeamSeconds[StartPoint, EndPoint] /i=1 /F={0.95, 4} /w=AverageError[StartPoint, EndPoint]
			elseif(cmpstr(AutoOrManual, "FullManual")==0)
				Coefficients[0] = Variable_a
				Coefficients[1] = Variable_b
			endif
			wave W_ParamConfidenceInterval	//this wave has been generated becuase the /F flag was used. it contains errors for each coefficient for the fit
			duplicate/O Average $ioliteDFpath("CurrentDRS",LinFittedCurveName)
			wave FittedCurve = $ioliteDFpath("CurrentDRS",LinFittedCurveName)
			FittedCurve = Coefficients[0] + Coefficients[1]*AverageBeamSeconds
			Residuals = (Average - FittedCurve)/FittedCurve*100	//calculate residuals and convert to a percentage
			Variable_a = Coefficients[0]
			Variable_b = Coefficients[1]
			break
		case "RunMed":
			NVar Variable_a = $ioliteDFpath("CurrentDRS","SmthVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			variable SmoothInPoints = ceil(Variable_a/(AverageBeamSeconds[2] - AverageBeamSeconds[1]))	//convert the smooth variable from seconds (as provided by user) to points by dividing by the segment size of AverageBeamSeconds
			string SmthFittedCurveName = "SmthFitCurve_"+Ratio
			//regardless of if it's set to fullauto or manual there is only one option
			duplicate/O Average $ioliteDFpath("CurrentDRS",SmthFittedCurveName)
			wave FittedCurve = $ioliteDFpath("CurrentDRS",SmthFittedCurveName)
			smooth /M = (NaN) 5, FittedCurve	//first remove any NaN's from the wave
			smooth /M=0 SmoothInPoints, FittedCurve	//then smooth using running median
			Residuals = (Average - FittedCurve)/FittedCurve*100	//calculate residuals and convert to a percentage
			break
		case "Spline":
			NVar Variable_a = $ioliteDFpath("CurrentDRS","SplVarA_"+ratio) 	//reference the globals so that they can be used below in the manual fit, and later be updated after the fit is complete
			variable SplineSmooth = Variable_a/10	// divide by 10 to make a more manageable number for the user
			string SplineCurveName = "SplineCurve_"+Ratio
			string SplineBeamSecsName = "SplineBeamSecs_"+ratio
			duplicate/D/O AverageBeamSeconds $ioliteDFpath("CurrentDRS",SplineBeamSecsName)
			wave SplineBeamSeconds = $ioliteDFpath("CurrentDRS",SplineBeamSecsName)	//note that the spline method creates its own beamseconds wave that extends beyond averagebeamseconds
			//in this case need to make a special long version of the time wave and y wave, so will now add points to the start and end of the time
			variable PointsToAdd, TimeSpacingOfData, valueOfOldFirstPoint
			TimeSpacingOfData = (AverageBeamSeconds[1] - AverageBeamSeconds[0])	//because the average beam seconds wave was built to have uniform spacing, this is enough to determine it
			PointsToAdd = floor(AverageBeamSeconds[0] / TimeSpacingOfData)	//rounding down here means that no numbers below 0 will be produced. the result may not give a point at exactly zero, so this is tested below
			valueOfOldFirstPoint = AverageBeamSeconds[0]
			insertpoints 0, PointsToAdd, SplineBeamSeconds
			SplineBeamSeconds[0, PointsToAdd] = valueOfOldFirstPoint - ((PointsToAdd-p)*TimeSpacingOfData)
			if(SplineBeamSeconds[0] != 0)	//if the added points don't go all the way to 0 then add another point for 0
				insertpoints 0, 1, SplineBeamSeconds
				SplineBeamSeconds[0] = 0
			endif
			//should now have extended the spline all the way to 0, now want to extend it to greater beamseconds too
			variable PointsToProjectSpline = 50
			variable LastPointInCurrentBeamSecs = numpnts(SplineBeamSeconds)	-1//note that this is 1 higher than the point index of the last point
			make /o/d/n=(LastPointInCurrentBeamSecs+PointsToProjectSpline+1) $ioliteDFpath("CurrentDRS",SplineBeamSecsName)	//am using this to lengthen the wave without changing it's contents. the alternative would be "insertpoints"
			wave SplineBeamSeconds = $ioliteDFpath("CurrentDRS",SplineBeamSecsName)
			SplineBeamSeconds[LastPointInCurrentBeamSecs+1, LastPointInCurrentBeamSecs+PointsToProjectSpline] = SplineBeamSeconds[LastPointInCurrentBeamSecs] + (p-LastPointInCurrentBeamSecs)*TimeSpacingOfData
			//should now have a full length SplineBeamSeconds wave with the correct spacing, can now duplicate this to get a corresponding y wave, then interpolate a spline onto the y wave.
			duplicate/O SplineBeamSeconds $ioliteDFpath("CurrentDRS",SplineCurveName)
			wave Splinecurve = $ioliteDFpath("CurrentDRS",SplineCurveName)	//note that the spline method creates its own beamseconds wave that extends beyond averagebeamseconds
			//in this case need to duplicate the original average waves over the range of the mask, as ranges cannot be specified in interpolate2
			duplicate /o/d/R=[StartPoint, EndPoint] AverageBeamSeconds, $ioliteDFpath("temp","TempTrimmedBeamSecs")
			duplicate /o/R=[StartPoint, EndPoint] Average, $ioliteDFpath("temp","TempTrimmedAverage")
			duplicate /o/R=[StartPoint, EndPoint] AverageError, $ioliteDFpath("temp","TempTrimmedAverageError")
			wave TempTrimmedBeamSecs = $ioliteDFpath("temp","TempTrimmedBeamSecs")
			wave TempTrimmedAverage = $ioliteDFpath("temp","TempTrimmedAverage")
			wave TempTrimmedAverageError = $ioliteDFpath("temp","TempTrimmedAverageError")
			Interpolate2  /A=0 /F=(SplineSmooth) /I=3 /J=1 /N=200 /SWAV=TempTrimmedAverageError /T=3 /X=$ioliteDFpath("CurrentDRS",SplineBeamSecsName)  /Y=$ioliteDFpath("CurrentDRS",SplineCurveName) TempTrimmedBeamSecs, TempTrimmedAverage
			Residuals = (Average - interp(AverageBeamSeconds[p], SplineBeamSeconds, Splinecurve))/(interp(AverageBeamSeconds[p], SplineBeamSeconds, Splinecurve))*100	//calculate residuals and convert to a percentage (note that in this case interp is required, as averagebeamsecs and splinebeamsecs are different)
			break
	endswitch
	duplicate/o Residuals, $IoliteDFPath("temp","ResidsMinusNaNs")
	wave ResidsMinusNaNs = $IoliteDFPath("temp","ResidsMinusNaNs")
	TrimNaNs(ResidsMinusNaNs)
	duplicate/o ResidsMinusNaNs, $IoliteDFPath("temp","TempWtdVariance")
	wave TempWtdVariance = $IoliteDFPath("temp","TempWtdVariance")
	TempWtdVariance = (ResidsMinusNaNs)^2
	StdErrOfResids = sqrt((1/(numpnts(ResidsMinusNaNs)-1))*(sum(TempWtdVariance)))	//this is normalised, so is expressed in percent
	BiasOfResids = sum(ResidsMinusNaNs) / numpnts(ResidsMinusNaNs)
	string HistogramWaveName = "HistoWv_"+ratio		//reference the waves that have already been created in a separate function. They are already appended to the graph and will only be modified here
	string GaussianFitName = "GaussFit_"+ratio
	string HistoXWaveName = "histoX_"+ratio
	wave HistogramWave = $IoliteDFPath("CurrentDRS",HistogramWaveName)
	wave GaussianFit = $IoliteDFPath("CurrentDRS",GaussianFitName)
	Histogram /B=1 /C /N ResidsMinusNaNs, HistogramWave
	controlinfo /W = $WindowName FitGauss
	if(V_Value == 1 || V_flag == 0)	//if the curve fit checkbox is selected
		CurveFit/N/Q gauss HistogramWave /D=GaussianFit		//now fit a gaussian curve to the data to see how it looks
	else
		GaussianFit = NaN	//otherwise set the gaussian fit to NaN
	endif
	duplicate/O HistogramWave $IoliteDFPath("CurrentDRS",HistoXWaveName)		//it's quite hard to find a way to take the x scaling generated by the histogram and make it into a separate x wave. here i've started by duplicating the histo wave
	wave HistoXWave = $IoliteDFPath("CurrentDRS",HistoXWaveName)
	HistoXWave = x			//then making the duplicate equal to the x scaling of the histo wave (itself at this point)
	string GFitXWaveName = "GFitX_"+ratio
	duplicate/O HistoXWave $IoliteDFPath("CurrentDRS",GFitXWaveName)		//use a separate x wave for the curvefit, as it needs to be offset to account for bin width
	wave GfitXWave = $IoliteDFPath("CurrentDRS",GFitXWaveName)		//duplicate this before doing the below manipulation
	variable HalfBinWidth = 0.5*(HistoXWave[1] - HistoXWave[0])		//then adding half a bin width to center the bar graph properly
	HistoXWave -= HalfBinWidth
	GaussOfFit = 1			//not currently doing anything...
	//searchforthis
	//also want to add something that makes a 'how gaussian' test
	//	WaveStats /M=2 /Q /Z ResidsMinusNaNs 
	//	print num2str(v_Skew) + "__v_Skew"
	//	print num2str(v_Kurt) + "__v_Kurt"
end

Function VACheckboxFitUpdate(Controlstructure)
	STRUCT WMCheckboxAction&Controlstructure
	if( Controlstructure.eventCode != 1 && Controlstructure.eventCode != 2)
		return 0  // we only want to handle mouse up (i.e. a released click), so exit if this wasn't what caused it
	endif  //otherwise, respond to the popup click
	string WindowName =Controlstructure.win
	string NameOfButton = Controlstructure.ctrlName
	variable CheckboxTicked = Controlstructure.checked
	string AutoSVarName = Controlstructure.userdata
	NVar OptionalPartialCrunch = $ioliteDFpath("CurrentDRS","OptionalPartialCrunch")
	OptionalPartialCrunch = 0	//note that this needs to be disabled here (the window is deactivated by the curve fit status window during FitToAverageWave()) . There is no need to remember the previous setting as it will be set to one regardless below.
	SVar CurveFitType = $ioliteDFpath("DRSGlobals","CurveFitType")
	//convert the long names of CurveFitType in the user interface into short labels
	string ShortCurveFitType
	string UserInterfaceList = "Exponential plus optional linear;Linear;Exponential;Double exponential;Smoothed cubic spline;Running median"
	string ShortLabelsList = "LinExp;Lin;Exp;DblExp;Spline;RunMed"
	ShortCurveFitType = StringFromList(WhichListItem(CurveFitType, UserInterfaceList, ";", 0, 0), ShortLabelsList, ";")	//this line extracts the short label corresponding to the user interface label in the above string.
	if(cmpstr(ShortCurveFitType, "") == 0)	//if for some reason the above substitution didn't work, then need to throw an error, as that will have to be fixed
		printabort("Sorry, the DRS failed to recognise the down-hole fractionation model you chose")
	endif
	SVar AutoSetting = $ioliteDFpath("CurrentDRS",AutoSVarName)	// this global (specific to this ratio and fit type) is used to govern whether a fully automatic fit can be used, or it the user has customised settings for the fit. NOTE that these globals need to be in the current DRS folder. If they're in the temp folder they will be deleted during a save, which is bad
	string Ratio = WindowName[4, strlen(WindowName) - 2]	//pull the relevant bit from the window name, which has the form "win_"+ratio+"1"
	VAFitToAverageWave(ratio, ShortCurveFitType, AutoSetting)
	OptionalPartialCrunch=1	//set the OptionalPartialCrunch to 1, this means that when the window is deactivated the DRS will be re-crunched
end

Function VAVariableFitUpdate(Controlstructure)
	STRUCT WMSetVariableAction&Controlstructure
	if( Controlstructure.eventCode != 1 && Controlstructure.eventCode != 2)
		return 0  // we only want to handle mouse up (i.e. a released click), so exit if this wasn't what caused it
	endif  //otherwise, respond to the popup click
	string WindowName =Controlstructure.win
	string NameOfButton = Controlstructure.ctrlName
	variable ControlValue = Controlstructure.dval
	string AutoSVarName = Controlstructure.userdata
	NVar OptionalPartialCrunch = $ioliteDFpath("CurrentDRS","OptionalPartialCrunch")
	OptionalPartialCrunch = 0	//note that this needs to be disabled here (the window is deactivated by the curve fit status window during FitToAverageWave()) . There is no need to remember the previous setting as it will be set to one regardless below.
	SVar CurveFitType = $ioliteDFpath("DRSGlobals","CurveFitType")
	//convert the long names of CurveFitType in the user interface into short labels
	string ShortCurveFitType
	string UserInterfaceList = "Exponential plus optional linear;Linear;Exponential;Double exponential;Smoothed cubic spline;Running median"
	string ShortLabelsList = "LinExp;Lin;Exp;DblExp;Spline;RunMed"
	ShortCurveFitType = StringFromList(WhichListItem(CurveFitType, UserInterfaceList, ";", 0, 0), ShortLabelsList, ";")	//this line extracts the short label corresponding to the user interface label in the above string.
	if(cmpstr(ShortCurveFitType, "") == 0)	//if for some reason the above substitution didn't work, then need to throw an error, as that will have to be fixed
		printabort("Sorry, the DRS failed to recognise the down-hole fractionation model you chose")
	endif
	SVar AutoSetting = $ioliteDFpath("CurrentDRS",AutoSVarName)	// this global (specific to this ratio and fit type) is used to govern whether a fully automatic fit can be used, or it the user has customised settings for the fit. NOTE that these globals need to be in the current DRS folder. If they're in the temp folder they will be deleted during a save, which is bad
	string Ratio = WindowName[4, strlen(WindowName) - 2]	//pull the relevant bit from the window name, which has the form "win_"+ratio+"1"
	if(cmpstr(NameOfButton, "StartMask")==0)	//if the control name is StartMask, then draw a grey box over the relevant masked range
		VAMaskStartOrEnd(ratio, WindowName, "StartMask", ControlValue)
	elseif(cmpstr(NameOfButton, "EndMask")==0)	//otherwise if the control name is EndMask, then draw a grey box over the relevant masked range
		VAMaskStartOrEnd(ratio, WindowName, "EndMask", ControlValue)
	endif
	VAFitToAverageWave(ratio, ShortCurveFitType, AutoSetting)
	OptionalPartialCrunch=1	//set the OptionalPartialCrunch to 1, this means that when the window is deactivated the DRS will be re-crunched
end

Function VAMaskStartOrEnd(ratio, WindowName, StartOrEnd, MaskValue)	//this function draws the mask boxes for the relevant areas on the graph. by being a separate function it can be called during a window build
	string ratio
	string WindowName
	string StartOrEnd
	variable MaskValue
	variable boxLeft, boxRight, boxTop, boxBottom	//variables to be used below in the case of a start or end mask control being set
	if(cmpstr(StartOrEnd, "StartMask")==0)	//if the control name is StartMask, then draw a grey box over the relevant masked range
		SetDrawLayer /W=$WindowName UserBack
		DrawAction /W=$WindowName delete, getgroup=StartMaskBox	//delete the edit box if it exists already
		if(MaskValue<=0)	//if the mask has been set to 0 then leave the box removed and do nothing
			return 0
		endif
		boxLeft = 0
		boxRight = MaskValue
		GetAxis/W=$WindowName /Q $ratio
		boxTop = V_Max
		boxBottom = V_min
		SetDrawEnv /W=$WindowName xcoord= bottom,ycoord= $ratio, linethick= 0.25, gname=StartMaskBox, gstart, linefgc=(58000,58000,58000), fillfgc=(58000,58000,58000)	//set draw environment
		DrawRect /W=$WindowName boxLeft, boxTop, boxRight, boxBottom	// draw edit box
		SetDrawEnv /W=$WindowName gstop
	elseif(cmpstr(StartOrEnd, "EndMask")==0)	//otherwise if the control name is EndMask, then draw a grey box over the relevant masked range
		SetDrawLayer /W=$WindowName UserBack
		DrawAction /W=$WindowName delete, getgroup=EndMaskBox	//delete the edit box if it exists already
		if(MaskValue<=0)	//if the mask has been set to 0 then leave the box removed and do nothing
			return 0
		endif
		string AverageBeamSecsName = "AverageBeamSecs_"+ratio
		wave AverageBeamSeconds = $ioliteDFpath("CurrentDRS",AverageBeamSecsName)
		boxLeft = AverageBeamSeconds[numpnts(AverageBeamSeconds)-1] - MaskValue	//get the max value of the averagebeamsecs wave and use this as the zero point for the box, then minus the maskvalue
		GetAxis/W=$WindowName /Q bottom
		boxRight = V_Max
		GetAxis/W=$WindowName /Q $ratio
		boxTop = V_Max
		boxBottom = V_min
		SetDrawEnv /W=$WindowName xcoord= bottom,ycoord= $ratio, linethick= 0.25, gname=EndMaskBox, gstart, linefgc=(58000,58000,58000), fillfgc=(58000,58000,58000)	//set draw environment
		DrawRect /W=$WindowName boxLeft, boxTop, boxRight, boxBottom	// draw edit box
		SetDrawEnv /W=$WindowName gstop
	endif
end

Function VAAutoManButton(buttonstructure)
	STRUCT WMButtonAction&buttonstructure
	if( buttonstructure.eventCode != 2 )
		return 0  // we only want to handle mouse up (i.e. a released click), so exit if this wasn't what caused it
	endif  //otherwise, respond to the popup click
	string WindowName =buttonstructure.win
	string NameOfButton = buttonstructure.ctrlName
	string AutoSVarName = buttonstructure.userdata
	SVar AutoSetting = $ioliteDFpath("CurrentDRS",AutoSVarName)	// this global (specific to this ratio and fit type) is used to govern whether a fully automatic fit can be used, or it the user has customised settings for the fit. NOTE that these globals need to be in the current DRS folder. If they're in the temp folder they will be deleted during a save, which is bad
	SVar CurveFitType = $ioliteDFpath("DRSGlobals","CurveFitType")
	//convert the long names of CurveFitType in the user interface into short labels
	string ShortCurveFitType
	string UserInterfaceList = "Exponential plus optional linear;Linear;Exponential;Double exponential;Smoothed cubic spline;Running median"
	string ShortLabelsList = "LinExp;Lin;Exp;DblExp;Spline;RunMed"
	ShortCurveFitType = StringFromList(WhichListItem(CurveFitType, UserInterfaceList, ";", 0, 0), ShortLabelsList, ";")	//this line extracts the short label corresponding to the user interface label in the above string.
	if(cmpstr(ShortCurveFitType, "") == 0)	//if for some reason the above substitution didn't work, then need to throw an error, as that will have to be fixed
		printabort("Sorry, the DRS failed to recognise the down-hole fractionation model you chose")
	endif
	NVar OptionalPartialCrunch = $ioliteDFpath("CurrentDRS","OptionalPartialCrunch")
	OptionalPartialCrunch = 0	//note that this needs to be disabled here (the window is deactivated by the curve fit status window during FitToAverageWave()) . There is no need to remember the previous setting as it will be set to one regardless below.
	string AutoButtonName = ShortCurveFitType+"Auto"
	string ManButtonName = ShortCurveFitType+"Manual"
	if(cmpstr(NameOfButton, AutoButtonName)==0)	//if the button is for auto
		modifycontrol $AutoButtonName fcolor=(25000,25000,64000), win=$WindowName
		modifycontrol $ManButtonName fcolor=(0,0,0), win=$WindowName
		AutoSetting = "FullAuto"
		if(cmpstr(ShortCurveFitType, "LinExp")==0)	//now need to do some additional stuff specific to each fit type
			modifycontrol AVariable, win=$WindowName, disable=2
			modifycontrol CVariable, win=$WindowName, disable=2
			modifycontrol DVariable, win=$WindowName, disable=2
		elseif(cmpstr(ShortCurveFitType, "Exp")==0)
			modifycontrol AVariable, win=$WindowName, disable=2
			modifycontrol BVariable, win=$WindowName, disable=2
			modifycontrol CVariable, win=$WindowName, disable=2
		elseif(cmpstr(ShortCurveFitType, "DblExp")==0)
			modifycontrol AVariable, win=$WindowName, disable=2
			modifycontrol BVariable, win=$WindowName, disable=2
			modifycontrol CVariable, win=$WindowName, disable=2
			modifycontrol DVariable, win=$WindowName, disable=2
			modifycontrol EVariable, win=$WindowName, disable=2
		elseif(cmpstr(ShortCurveFitType, "Lin")==0)
			modifycontrol AVariable, win=$WindowName, disable=2
			modifycontrol BVariable, win=$WindowName, disable=2
		endif
	elseif(cmpstr(NameOfButton, ManButtonName)==0)	//otherwise if the button is for manual
		modifycontrol $AutoButtonName fcolor=(0,0,0), win=$WindowName
		modifycontrol $ManButtonName fcolor=(25000,25000,64000), win=$WindowName
		AutoSetting = "FullManual"
		if(cmpstr(ShortCurveFitType, "LinExp")==0)	//now need to do some additional stuff specific to each fit type
			modifycontrol AVariable, win=$WindowName, disable=0
			modifycontrol CVariable, win=$WindowName, disable=0
			modifycontrol DVariable, win=$WindowName, disable=0
		elseif(cmpstr(ShortCurveFitType, "Exp")==0)
			modifycontrol AVariable, win=$WindowName, disable=0
			modifycontrol BVariable, win=$WindowName, disable=0
			modifycontrol CVariable, win=$WindowName, disable=0
		elseif(cmpstr(ShortCurveFitType, "DblExp")==0)
			modifycontrol AVariable, win=$WindowName, disable=0
			modifycontrol BVariable, win=$WindowName, disable=0
			modifycontrol CVariable, win=$WindowName, disable=0
			modifycontrol DVariable, win=$WindowName, disable=0
			modifycontrol EVariable, win=$WindowName, disable=0
		elseif(cmpstr(ShortCurveFitType, "Lin")==0)
			modifycontrol AVariable, win=$WindowName, disable=0
			modifycontrol BVariable, win=$WindowName, disable=0
		endif
	endif
	string Ratio = WindowName[4, strlen(WindowName) - 2]
	VAFitToAverageWave(ratio, ShortCurveFitType, AutoSetting)
	OptionalPartialCrunch = 1	//set the OptionalPartialCrunch to 1, this means that when the window is deactivated the DRS will be re-crunched
end

Function DCFitWindowHook(infoStr)  // This is the window hook function for the down hole correction windows. It's only job at present is to crunch data when the window is deactivated
	String infoStr
	String event= StringByKey("EVENT",infoStr)
	if(cmpstr(event, "deactivate")==0||cmpstr(event, "kill")==0)
		NVar OptionalPartialCrunch = $ioliteDFpath("CurrentDRS","OptionalPartialCrunch")
		if(OptionalPartialCrunch==1)	//only crunch data if something has been changed -  the data crunch will be heavily abbreviated, and thus much faster
			RunActiveDRS()
			//DisplayIntegAndSpline()
			//TracesIntegAndSpline(1)
		endif
		OptionalPartialCrunch = 0
		//###########################################################			
		// JAP
		
		// Check if all of the DCFit windows are now closed and see if the user wants to hold the DC fit
		NVAR HoldDHC = root:Packages:VisualAge:Options:HoldDHC
		If (strlen(WinList("Win_Raw*", ";", "")) == 0 || ItemsInList(WinList("Win_Raw*", ";", "")) == 1)
			DoAlert/T="VisualAge" 1, "Would you like to hold the downhole fractionation correction?"
			If (V_flag == 1)
				HoldDHC = 1
			EndIf
		EndIf			
		
		// !JAP
		//###########################################################			
	endif
	return 0
End

Function ResetFitWindows()
	string CurrentDFPath = getdatafolder(1)
	setDatafolder $ioliteDFpath("CurrentDRS","")
	string ListOfAutos = StringList("Auto_*",";")
	variable Index = 0
	variable NoOfAutoStrings = ItemsInList(ListOfAutos, ";")
	do
		SVar ThisAutoString = $ioliteDFpath("CurrentDRS",StringFromList(index, ListOfAutos, ";"))
		ThisAutoString = "Initialise"
		index+=1
	while(Index<NoOfAutoStrings)
	setDatafolder CurrentDFPath
End

//****Start Export data function (optional).  If present in a DRS file, this function is called by the export Stats routine when it is about to save the export stats text matrix to disk.
Function ExportFromActiveDRS(Output_DataTable,NameOfPathToDestinationFolder) //this line must be as written here
	wave/T Output_DataTable //will be a wave reference to the Output_DataTable text wave that is about to be saved
	String NameOfPathToDestinationFolder //will be the name of the path to the destination folder for this export.
	//have eliminated the UPb specific error propagation in favour of the generic error propagation function (which is now called at the end of the normal DRS function)
	string ErrorType	//use this string to store the relevant suffix, which will change depending on whether propagated errors are being exported
	//The below needs to take account of the new option of using either internal or propagated errors, they have different names!
	//need to add in appropriate error correlations and add a column with 238/206, this will make life easier later for people wanting to use Isoplot
	variable ColumnBeforeInsert = 1 + FindDimLabel(Output_DataTable, 1, "Final206_238_Prop2SE")	//get the column after 206/238
	ErrorType = "_Prop2SE"
	if(ColumnBeforeInsert == -1)	//if that label wasn't found then try the other error label option of no propagated error
		ColumnBeforeInsert = 1 + FindDimLabel(Output_DataTable, 1, "Final206_238_Int2SE")	//get the column after 206/238
		ErrorType = "_Int2SE"	//if it's internal only then need to change the name of the suffix used below
	endif
	string NameOfNewColumnLabel
	NameOfNewColumnLabel = "Final238_206" + ErrorType
	InsertPoints /M=1 ColumnBeforeInsert, 2, Output_DataTable	//insert two columns after the above column
	SetDimLabel 1, ColumnBeforeInsert, Final238_206, Output_DataTable	//and give them labels
	SetDimLabel 1, ColumnBeforeInsert+1, $NameOfNewColumnLabel, Output_DataTable	//and give them labels
	//Note that because num2str is limited to 5 decimal places it can't be used here, instead need a loop that uses sprintf
	string InvertedRatioAsString
	string InvertedErrorAsString
	string NameOfErrorLabel
	variable OriginalRatio
	variable OriginalError
	variable Counter = 0
	variable NoOfIntegs = dimSize(Output_DataTable, 0)
	do
		OriginalRatio = str2num(Output_DataTable[Counter][%$"Final206_238"])
		NameOfErrorLabel = "Final206_238"+ErrorType
		OriginalError = str2num(Output_DataTable[Counter][%$NameOfErrorLabel])
		sprintf InvertedRatioAsString,"%6.7g", (1 / OriginalRatio)
		sprintf InvertedErrorAsString,"%6.7g", (OriginalError / (OriginalRatio^2))	//to propagate the error, need to divide by the old ratio and multiply by the new. Because the new is 1/old, this is the same as dividing by the old twice
		if(grepstring(InvertedRatioAsString, "nan")==1)		//if this row is empty a NaN will be the result. want to replace this with an empty cell
			InvertedRatioAsString = ""
		endif
		if(grepstring(InvertedErrorAsString, "nan")==1)		//if this row is empty a NaN will be the result. want to replace this with an empty cell
			InvertedErrorAsString = ""
		endif
		NameOfErrorLabel = "Final238_206"+ErrorType
		Output_DataTable[Counter][%$"Final238_206"] = InvertedRatioAsString
		Output_DataTable[Counter][%$NameOfErrorLabel] = InvertedErrorAsString
		counter += 1
	while (Counter < NoOfIntegs-1)
	//unfortunately, for the error correlation code to work, also need to make an actual wave in the currentDRS folder
	duplicate/O $ioliteDFpath("CurrentDRS","Final206_238"), $ioliteDFpath("CurrentDRS", "Final238_206")
	wave Final238_206 = $ioliteDFpath("CurrentDRS", "Final238_206")
	Final238_206 = 1 / Final238_206
	//can now do error correlations for the two ratios used by Isoplot for normal and inverse U Pb plots
	NVar Calculate_207_235 = $ioliteDFpath("CurrentDRS","Calculate_207_235")
	NVar Calculate_207_206 = $ioliteDFpath("CurrentDRS","Calculate_207_206")
	if(Calculate_207_235 == 1)
		ErrorCorrelation(Output_DataTable, "Final207_235", "Final206_238","Final206_238"+ErrorType, "ErrorCorrelation_6_38vs7_35")
		ErrorCorrelation(Output_DataTable, "FinalAnd207_235", "FinalAnd206_238", "FinalAnd206_238"+ErrorType, "ErrorCorrelAnd_6_38vs7_35")
	endif
	if(Calculate_207_206 == 1)
		ErrorCorrelation(Output_DataTable, "Final238_206", "Final207_206","Final207_206"+ErrorType, "ErrorCorrelation_38_6vs7_6")
		ErrorCorrelation(Output_DataTable, "FinalPbC207_235", "FinalPbC206_238", "FinalPbC206_238"+ErrorType, "ErrorCorrelAnd_6_38vs7_35")		
	endif
end	//end of DRS intercept of data export - export routine will now save the (~altered) stats wave in the folder it supplied.

//the below 2 function are for the automatic setup of baselines and intermediates on the traces window.
Function AutoBaselines(buttonstructure) //Build the main display and integration window --- This is based off a button, so has button structure for the next few lines
	STRUCT WMButtonAction&buttonstructure
	if( buttonstructure.eventCode != 2 )
		return 0  // we only want to handle mouse up (i.e. a released click), so exit if this wasn't what caused it
	endif  //otherwise, respond to the popup click
	ClearAllTraces()
	AutoTrace(0, "U238", -300, 600, extraflag = "Primary")	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(1, "Th232", -300, 500)	//see the autotrace function for what these mean.
	AutoTrace(3, "Pb206", -300, 1500)	//see the autotrace function for what these mean.
	AutoTrace(4, "Pb207", -200, 2000)	//see the autotrace function for what these mean.
	AutoTrace(5, "Pb208", -50, 5000, extraflag = "Right")	//see the autotrace function for what these mean.
	AutoTrace(6, "Pb204", -800, 16000)	//see the autotrace function for what these mean.
end

Function AutoIntermediates(buttonstructure) //Build the main display and integration window --- This is based off a button, so has button structure for the next few lines
	STRUCT WMButtonAction&buttonstructure
	if( buttonstructure.eventCode != 2 )
		return 0  // we only want to handle mouse up (i.e. a released click), so exit if this wasn't what caused it
	endif  //otherwise, respond to the popup click
	ClearAllTraces()
	AutoTrace(0, "U238_CPS", 0, 0, extraflag = "Right")	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(1, "Raw_206_238", 0.07, .31, extraflag = "Primary")	//see the autotrace function for what these mean.
	AutoTrace(2, "Raw_207_235", 0.2, 6.7)	//see the autotrace function for what these mean.
	AutoTrace(3, "Raw_208_232", 0.02, 0.39)	//see the autotrace function for what these mean.
	AutoTrace(4, "Pb206_CPS", 0, 0)	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(5, "Pb207_CPS", 0, 0)	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(6, "Pb208_CPS", 0, 0)	//see the autotrace function for what these mean.	set both max and min to zero for autoscale.
	AutoTrace(7, "Raw_207_206", 0.02, 0.16, extraflag = "Hidden")	//see the autotrace function for what these mean.
	AutoTrace(8, "Raw_206_208", 5, 17, extraflag = "Hidden")	//see the autotrace function for what these mean.
end

Function VAGenerate207206LookupTable()
	//First, check if it already exists, and if so don't bother to do anything
	wave LookupTable_age = $ioliteDFpath("CurrentDRS","LookupTable_age")
	if(waveexists(LookupTable_age) == 1)
		return 0
	endif
	//still going, which means this is the first time this function has been called
	//reference the 238/235 ratio to be used (it is a global variable
	NVar Sample238_235Ratio = $ioliteDFpath("DRSGlobals","Sample238_235Ratio")
	//Also make the decay constants here as a variable
	Variable DecayConstant_235 = 9.8485E-10
	Variable DecayConstant_238 = 1.55125E-10
	//now make the required waves (want a time resolution of 0.1% (this should be massive overkill), and spanning from 1 ma to 4600 ma
	//to do this requires xxx points
	variable NoOfRowsInLookup = 8440
	wave LookupTable_age = $MakeioliteWave("CurrentDRS","LookupTable_age",n=NoOfRowsInLookup)
	wave LookupTable_76 = $MakeioliteWave("CurrentDRS","LookupTable_76",n=NoOfRowsInLookup)
	wave LookupTable_238 = $MakeioliteWave("CurrentDRS","LookupTable_238",n=NoOfRowsInLookup)
	wave LookupTable_235 = $MakeioliteWave("CurrentDRS","LookupTable_235",n=NoOfRowsInLookup)
	LookupTable_age[0] = 1
	LookupTable_age[1, NoOfRowsInLookup] = LookupTable_age[p-1] * 1.001
	//Have now populated the age column with ages (in Ma) that have a spacing of 0.1%
	//Now calculate the relevant 106/238 and 207/235 ratios for each age.
	LookupTable_238 = e^(DecayConstant_238 * LookupTable_age * 1E6) - 1
	LookupTable_235 = e^(DecayConstant_235 * LookupTable_age * 1E6) - 1
	//Now calculate the 207/206 ratio from the above two values
	LookupTable_76 = (1/Sample238_235Ratio) * (LookupTable_235 / LookupTable_238)
end
