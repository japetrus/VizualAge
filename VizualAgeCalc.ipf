//########################################################
//   VisualAge add-on for Iolite                    
//   Written by Joe Petrus      
//   Version 2015.06
//########################################################
#pragma rtGlobals=1		// Use modern global access method.

//------------------------------------------------------------------------
// Calculate the weighted mean error ellipse of all integrations of the active integration type
// Based on Ludwig's GCA 62, 665-676 (1998)
//------------------------------------------------------------------------
Function CalculateWeightedMean(ConcVersion, ConcInteg, [ConcFolder, AddToPlot, TargetWin, doTW])
	String ConcVersion, ConcInteg, ConcFolder, TargetWin
	Variable AddToPlot, doTW
	
	// Use the specified folder:
	If ( !ParamIsDefault(ConcFolder) && DataFolderExists(ConcFolder))
		SetDataFolder ConcFolder
	EndIf
	
	// Set the default addToPlot to 1:
	If ( ParamIsDefault(AddToPlot) )
		AddToPlot = 1
	EndIf
	
	If ( ParamIsDefault(TargetWin) )
		TargetWin = WinName(0,1)
	EndIf
	
	If ( ParamIsDefault(doTW) )
		doTW = 0
	EndIf
	
	// Get some stuff from Iolite:
	Wave aim = $ioliteDFpath("integration", "m_" + ConcInteg)
	Variable NoOfIntegrations = DimSize(aim,0)

	// Make some waves:
	Make/O/N=(NoOfIntegrations) xWave, sxWave, yWave, syWave, pWave, xVarWave, yVarWave, covWave, O11Wave, O22Wave, O12Wave, RxWave, RyWave
	Wave ResultWave = $MakeioliteWave("CurrentDRS", "ResultWave", n = 2)

	// Make and initialize some variables:
	Variable SumO11, SumO22, SumO12, SumOXY, SumOYX
	SumO11 = 0; SumO22 = 0; SumO12 = 0; SumOXY = 0; SumOYX = 0

	// Loop through the integrations and do some statistics:
	Variable i
	For ( i = 1; i < NoOfIntegrations; i = i + 1 )
	
		If (!doTW) // Standard concordia:
			GetIntegrationFromIolite(ConcVersion+"207_235", ConcInteg, i, "ResultWave")
			xWave[i] = resultWave[0]
			sxWave[i] = resultWave[1]/2
			GetIntegrationFromIolite(ConcVersion+"206_238", ConcInteg, i, "ResultWave")
			yWave[i] = resultWave[0]
			syWave[i] = resultWave[1]/2
			pWave[i] = ChannelCorrelation(ConcVersion + "207_235", ConcVersion + "206_238", i, ActiveIntegration=ConcInteg)
		Else // Tera-Wasserburg concordia:
			GetIntegrationFromIolite(ConcVersion+"238_206", ConcInteg, i, "ResultWave")
			xWave[i] = resultWave[0]
			sxWave[i] = resultWave[1]/2
			GetIntegrationFromIolite(ConcVersion+"207_206", ConcInteg, i, "ResultWave")
			yWave[i] = resultWave[0]
			syWave[i] = resultWave[1]/2
			pWave[i] = ChannelCorrelation(ConcVersion + "238_206", ConcVersion + "207_206", i, ActiveIntegration=ConcInteg)
		EndIf
		
		xVarWave[i] = sxWave[i]^2
		yVarWave[i] = syWave[i]^2
		covWave[i] = pWave[i]*sxWave[i]*syWave[i]
			
		O11Wave[i] = yVarWave[i]/(xVarWave[i]*yVarWave[i]-covWave[i]^2)
		O22Wave[i] = xVarWave[i]/(xVarWave[i]*yVarWave[i]-covWave[i]^2)
		O12Wave[i] = -covWave[i]/(xVarWave[i]*yVarWave[i]-covWave[i]^2)

		SumO11 = SumO11 + O11Wave[i]
		SumO22 = SumO22 + O22Wave[i]
		SumO12 = SumO12 + O12Wave[i]
			
		SumOXY = SumOXY + xWave[i]*O11Wave[i] + yWave[i]*O12Wave[i]
		SumOYX = SumOYX + yWave[i]*O22Wave[i] + xWave[i]*O12Wave[i]
	EndFor	

	// Calculate the weighted mean values + error + correlation
	KillVariables/Z Xbar, Ybar, sXbar, sYbar, pbar, Nbar, Sbar
	Variable/G Xbar = (SumO22*SumOXY - SumOYX*SumO12)/(SumO11*SumO22-SumO12^2)
	Variable/G Ybar = (SumO11*SumOYX - SumOXY*SumO12)/(SumO11*SumO22-SumO12^2)
	Variable/G sXbar = sqrt(SumO22/(SumO11*SumO22-SumO12^2))
	Variable/G sYbar = sqrt(SumO11/(SumO11*SumO22-SumO12^2))
	Variable/G pbar = (-SumO12/(SumO11*SumO22-SumO12^2))/(sXbar*sYbar)
	Variable/G Nbar = NoOfIntegrations -1
	
	Variable/G Sbar = 0
	
	For (i = 1; i < NoOfIntegrations; i = i + 1)
		RxWave[i] = xWave[i] - Xbar
		RyWave[i] = yWave[i] - Ybar
		Sbar = Sbar + O11Wave[i]*RxWave[i]^2 + O22Wave[i]*RyWave[i]^2 + 2*RxWave[i]*RyWave[i]*O12Wave[i]
	EndFor
	
	If (AddToPlot)
		RemoveFromGraph/W=$TargetWin/Z WtdMeany
		AddToConcordiaByValues(Xbar, sXbar*2, Ybar, sYbar*2, pbar, TargetWin, "WtdMean", doTW=doTW)
		ModifyGraph/W=$TargetWin lsize(WtdMeany)=4
		ModifyGraph/W=$TargetWin lstyle(WtdMeany)=0
		ModifyGraph/W=$TargetWin rgb(WtdMeany)=(65000,0,0)
	EndIf
	
	KillWaves/Z xWave, sxWave, yWave, syWave, pWave, xVarWave, yVarWave, covWave, O11Wave, O22Wave, O12Wave, RxWave, RyWave
End

//------------------------------------------------------------------------
// Calculate the ConcAge with the MSWD/Prob being for equivalence + concordance
// Based on Ludwig's GCA 62, 665-676 (1998)
//------------------------------------------------------------------------
Function CalculateConcAge(ConcVersion, ConcInteg, [ConcFolder, TargetWin, AddToPlot, AddAnnotation, doTW])
	String ConcVersion, ConcInteg, ConcFolder, TargetWin
	Variable AddToPlot, AddAnnotation, doTW
	
	// Use the specified folder:
	If ( !ParamIsDefault(ConcFolder) && DataFolderExists(ConcFolder))
		SetDataFolder ConcFolder
	EndIf
	
	// Set the default addToPlot to 1:
	If ( ParamIsDefault(AddToPlot) )
		AddToPlot = 1
	EndIf
	
	If ( ParamIsDefault(AddAnnotation) )
		AddAnnotation = 0
	EndIf
	
	If( ParamIsDefault(TargetWin) )
		TargetWin = WinName(0,1)
	EndIf
	
	If (ParamIsDefault(doTW) )
		doTW = 0
	EndIf

	// Calculate the weighted mean:
	CalculateWeightedMean(ConcVersion, ConcInteg, ConcFolder=ConcFolder, AddToPlot=AddToPlot, TargetWin=TargetWin, doTW=doTW)
	NVAR Xbar = Xbar
	NVAR Ybar = Ybar
	NVAR sXbar = sXbar
	NVAR sYbar = sYbar
	NVAR pbar = pbar
	NVAR Sbar = Sbar
	NVAR Nbar = Nbar
	
	// Set some iteration parameters for Newton's method:
	Variable maxItrNum = 100000
	Variable eps = 1e-10
	
	// Create some variables:
	Variable ct, nt, itrNum, ft, dft, Rx, Ry, Rxp, Ryp, Rxpp, Rypp
	
	// Get some globals:
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR k = root:Packages:VisualAge:Constants:k
	
	// Calculate components of the covariance matrix:
	Variable O11 = sYbar^2/((sXbar^2)*(sYbar^2)-(pbar*sXbar*sYbar)^2)
	Variable O22 = sXbar^2/((sXbar^2)*(sYbar^2)-(pbar*sXbar*sYbar)^2)
	Variable O12 = -pbar*sXbar*sYbar/((sXbar^2)*(sYbar^2)-(pbar*sXbar*sYbar)^2)
	
	// Use Newton's method to find the ConcAge:
	If (!doTw)
		nt = Age6_38(Ybar)
	Else
		nt = Age6_38(1/Xbar)
	EndIf
	
	Do
		ct = nt
		
		If (!doTW) // Standard concordia:
			Rx = Ratio7_35(ct) - Xbar
			Rxp = -l235*exp(l235*ct)
			Rxpp = -l235*l235*exp(l235*ct)
			
			Ry = Ratio6_38(ct) - Ybar
			Ryp = -l238*exp(l238*ct)
			Rypp = -l238*l238*exp(l238*ct)
		
			ft = O11*Rx*Rxp + O22*Ry*Ryp + O12*(Rx*Ryp + Ry*Rxp)
			dft = O11*(Rx*Rxpp + Rxp^2) + O22*(Ry*Rypp + Ryp^2) + O12*(Rx*Rypp + Rxp*Ryp + Ry*Rxpp + Ryp*Rxp)
		Else // Tera-Wasserberg concordia:
			Rx = 1/Ratio6_38(ct) - Xbar
			Rxp = l238*exp(l238*ct)/(exp(l238*ct)-1)^2  
			Rxpp = 2*l238*l238*exp(2*l238*ct)/(exp(l238*ct)-1)^3 - l238*l238*exp(l238*ct)/(exp(l238*ct)-1)^2 
			
			Ry = Ratio7_6(ct) - Ybar
			Ryp = l235*exp(l235*ct)/(k*(exp(l238*ct)-1)) - l238*(exp(l235*ct)-1)*exp(l238*ct)/(k*(exp(l238*ct)-1)^2)
			Rypp = -2*l235*l238*exp(ct*(l235+l238))/(k*(exp(l238*ct)-1)^2)
			Rypp -= l238*l238*(exp(l235*ct)-1)*exp(l238*ct)/(k*(exp(l238*ct)-1)^2)
			Rypp += 2*l238*l238*(exp(l235*ct)-1)*exp(2*l238*ct)/(k*(exp(l238*ct)-1)^3)
			Rypp += l235*l235*exp(l235*ct)/(k*(exp(l238*ct)-1))

			ft = O11*Rx*Rxp + O22*Ry*Ryp + O12*(Rx*Ryp + Ry*Rxp)
			dft = O11*(Rx*Rxpp + Rxp^2) + O22*(Ry*Rypp + Ryp^2) + O12*(Rx*Rypp + Rxp*Ryp + Ry*Rxpp + Ryp*Rxp)
		EndIf	
		
		// Update ConcAge:
		nt = ct + ft/dft
		
		itrNum = itrNum +1
	While ( itrNum < maxItrNum && abs(ft) > eps )
	
	// Kill any old ConcAge globals:
	KillVariables/Z ConcAge, ConcAgeMSWD, ConcAgeProb, ConcAgeSigma
	
	// Store computed ConcAge:
	Variable/G ConcAge = nt
	
	// Calculate some stuff:
	If (!doTW)
		Rx = Xbar - Ratio7_35(ConcAge)
		Rxp = -l235*exp(l235*ConcAge)
		
		Ry = Ybar -Ratio6_38(ConcAge)
		Ryp = -l238*exp(l238*ConcAge)
	Else
		Rx = Xbar - 1/Ratio6_38(ConcAge)
		Rxp =  -l238*exp(l238*ConcAge)/(exp(l238*ConcAge)-1)^2  
		
		Ry = Ybar - Ratio7_6(ConcAge)
		Ryp = -l235*exp(l235*ConcAge)/(k*(exp(l238*ConcAge)-1)) + l238*(exp(l235*ConcAge)-1)*exp(l238*ConcAge)/(k*(exp(l238*ConcAge)-1)^2)
	EndIf

	// Calculate the ConcAge error:
	Variable Fisher = Rxp*Rxp*O11 + Ryp*Ryp*O22 + 2*Rxp*Ryp*O12
	Variable/G ConcAgeSigma = sqrt(1/Fisher)	
	
	// Calculate the ConcAge MSWD:
	Variable SConc = Rx*Rx*O11 + Ry*Ry*O22 + 2*Rx*Ry*O12
	
	// Ludwig GCA 62 (1998) suggests Sbar + Sconc/(2Nbar-1), but the formula below is in better agreement with isoplot (???)
	// Note: this is the MSWD for equivalence and concordance
	Variable/G ConcAgeMSWD = (SConc + Sbar)/(2*Nbar-1)
	
	// Calculate the ConcAge probability of concordance:
	Variable/G ConcAgeProb = 1-StatsFCDF(ConcAgeMSWD, 1, 1e10)
	
	// Add annotation if desired:
	If (AddAnnotation)
		String caStr = ""
		If (ConcAgeProb < 0.02 || numtype(ConcAgeProb) == 2)
			caStr = "ConcAge unlikely"
		Else
			caStr = "ConcAge = " + num2str(ConcAge/1e6) + " ± " + num2str(2*ConcAgeSigma/1e6) + " Ma\r"
			caStr += "MSWD = " + num2str(ConcAgeMSWD) + "\r"
			caStr += "Prob = " + num2str(ConcAgeProb)
		EndIf
		TextBox/W=$TargetWin/C/N=ConcAgeText/A=LT caStr	
	EndIf
End

//------------------------------------------------------------------------
// Given the m & b of y = mx+b, find the age at which the line intercepts the concordia
//------------------------------------------------------------------------
Function SolveConcordiaLine(m, b, start)
	Variable m, b, start
	
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	
	Variable itrNum = 0
	Variable cx, nx, fx, dfx
	
	cx = start
	nx = cx
	
	Do
		cx = nx
		
		fx = m*cx+b + 1 - exp( (l238/l235)*ln(cx + 1) )
		dfx = m - (l238/l235)*(1/(cx+1))*exp( (l238/l235)*ln(cx + 1) )
		
		nx = cx - fx/dfx
		
		itrNum = itrNum + 1
	While ( abs(fx) > 1e-10 && itrNum < 1e5)
	
	If (itrNum == 1e5 || nx < 1e-4)
		Return Nan
	EndIf
	
	Return 1e-6*ln(nx + 1)/l235
End

//------------------------------------------------------------------------
// Given the m & b of y = mx+b, find the age at which the line intercepts the T-W concordia
//------------------------------------------------------------------------
Function SolveTWConcordiaLine(m,b, start )
	Variable m, b, start
	
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	NVAR k = root:Packages:VisualAge:Constants:k	
	
	Variable itrNum = 0
	Variable cx, nx, fx, dfx
	Variable Cl = (l235/l238)
	
	cx = start
	nx = cx
		
	Do
		cx = nx
		
		fx = m*cx + b + (cx/k) - (cx/k)*exp( Cl*ln( (1/cx) + 1) )
		dfx = m + (1/k) - (1/k)*exp(Cl*ln( (1/cx) + 1) )*(1-Cl/(1+cx))
		
		nx = cx - fx/dfx
		
		itrNum = itrNum + 1
	While ( abs(fx) > 1e-5 && itrNum < 1e5)
	
	If (itrNum == 1e5 || nx < 0.1)
		Return NaN
	EndIf
	
	Return 1e-6*ln( (1/nx) + 1)/l238
End

//------------------------------------------------------------------------
// Calculate the equation Andersen tries to solve
//------------------------------------------------------------------------
Function ComputeAndersenFunction(xw, yw, zw, uw)
	Variable xw, yw, zw, uw

	// Decay constants:
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	NVAR l232 = root:Packages:VisualAge:Constants:l232
	
	// Define present-day 238U/235U:
	NVAR k = root:Packages:VisualAge:Constants:k
	
	Variable c7, c8

	Variable nPts = 5000
	
	Make/O/N=(nPts) andTimeWave, andFuncWave, andDFuncWave
	
	Variable i
	For (i = 0; i < nPts; i = i + 1)
		andTimeWave[i] = 4e9*i/nPts
		Variable ct1 = andTimeWave[i]
		
		Variable common64, common74, common84
		NVAR usePbComp = root:Packages:VisualAge:AndersenOption_UsePbComp
		
		If ( usePbComp )
			// Use common Pb composition specified in DRS options:
			NVAR c64 = root:Packages:VisualAge:Options:AndersenOption_Common64
			NVAR c74 = root:Packages:VisualAge:Options:AndersenOption_Common74
			NVAR c84 = root:Packages:VisualAge:Options:AndersenOption_Common84
			
			common64 = c64
			common74 = c74
			common84 = c84
		Else
			Variable Gct1 = ct1/1e9
			// Compute c7 and c8 using BSK's fits:
			common64 = 0.023*(Gct1)^3 - 0.359*(Gct1)^2 - 1.008*(Gct1) + 19.04
			common74 = -0.034*(Gct1)^4 +0.181*(Gct1)^3 - 0.448*(Gct1)^2 + 0.334*(Gct1) + 15.64
			common84 = -2.200*(Gct1) + 39.47
		EndIf

		c7 = common74/common64
		c8 = common84/common64
		
		Variable xt1 = exp(l235*ct1) -1
		Variable yt1 = exp(l238*ct1) -1
		Variable zt1 = exp(l232*ct1) -1
		
		Variable xt2, yt2, zt2
		xt2 = 0
		yt2 = 0
		zt2 = 0
		
		Variable dxt1 = l235*exp(l235*ct1)
		Variable dyt1 = l238*exp(l238*ct1)
		Variable dzt1 = l232*exp(l232*ct1)			
			
		// Andersen's version:
		Variable A1 = (yw*(xt1-xt2) - yt2*xt1 + xw*(yt2-yt1) + xt2*yt1)*yw
		Variable B1 = (zt1-zt2-c8*uw*yt1+c8*uw*yt2)
		Variable C1 = (zw*(yt2-yt1) + zt2*yt1 + yw*(zt1-zt2) -yt2*zt1)*yw
		Variable D1 = (xt1-xt2 -c7*k*yt1 + c7*k*yt2)
		Variable ft = A1*B1 - C1*D1
		Variable dft = A1*(dzt1 - c8*uw*dyt1) + B1*yw*(yw*dxt1 - yt2*dxt1 - xw*dyt1 + xt2*dyt1) - C1*(dxt1-c7*k*dyt1) - D1*yw*(-zw*dyt1+zt2*dyt1 + yw*dzt1 -yt2*dzt1)

		//Variable A1 = (yw*(xt1-xt2) - yt2*xt1 + xw*(yt2-yt1) + xt2*yt1)
		//Variable B1 = (zt1-zt2-c8*uw*yt1+c8*uw*yt2)
		//Variable C1 = (zw*(yt2-yt1) + zt2*yt1 + yw*(zt1-zt2) -yt2*zt1)
		//Variable D1 = (xt1-xt2 -c7*k*yt1 + c7*k*yt2)
		//Variable ft = (A1/D1) - (C1/B1)
		//Variable dft = (1/D1)*(yw*dxt1 - yt2*dxt1 - xw*dyt1 + xt2*dyt1) - (A1/(D1*D1))*(dxt1-c7*k*dyt1) - (1/B1)*(-zw*dyt1+zt2*dyt1 + yw*dzt1 -yt2*dzt1) + (C1/(B1*B1))*(dzt1 - c8*uw*dyt1)			

		andFuncWave[i] = ft
		andDFuncWave[i] = dft	
	EndFor
End	

//------------------------------------------------------------------------
// Calculate the 207/206 age given the ratio and a guess
//------------------------------------------------------------------------
Function CalculatePbPbAge(m, guess)
	Variable m, guess
	
	// Decay constants:
	NVAR l235 = root:Packages:VisualAge:Constants:l235
	NVAR l238 = root:Packages:VisualAge:Constants:l238
	NVAR l232 = root:Packages:VisualAge:Constants:l232
	
	// Define present-day 238U/235U:
	NVAR k = root:Packages:VisualAge:Constants:k
	
	// Define variables to use in Newton's method:
	Variable cAge = guess
	Variable nAge = cAge
	Variable ft, dft	
	
	// Define iteration parameters:
	Variable itrNum = 0
	NVAR maxItrNum = root:Packages:VisualAge:Options:PbPbOption_MaxIters
	NVAR eps = root:Packages:VisualAge:Options:PbPbOption_Epsilon
	
	// Main calculation loop:
	Do
		// Make current age the old new age:
		cAge = nAge
		
		// Calculate function:
		ft = m - (1/k)*(exp(l235*cAge)-1)/(exp(l238*cAge)-1)
		
		// Calculate derivative of function:
		dft = -(l235/k)*exp(l235*cAge)/(exp(l238*cAge)-1) + (l238/k)*exp(l238*cAge)*(exp(l235*cAge)-1)/(exp(l238*cAge)-1)^2
		
		// An alternate form of the function + derivative that seems to crap out more for young analyses:
		//ft = 1 - exp(9.8485e-10*cAge) + 137.88*m*(exp(1.55125e-10*cAge) - 1)
		//dft = -9.8485e-10*exp(9.8485e-10*cAge) + 137.88*m*1.55125e-10*exp(1.55125e-10*cAge)
		
		// Update the new age based on the old age and the computed values:
		nAge = cAge - ft/dft
		
		// Loop until the root is found or some other critera is met:
		itrNum = itrNum + 1
	While ( abs(ft) > eps && itrNum < maxItrNum)
	
	// If the age doesn't make sense return NaN
	If (nAge < 0 || nAge > 5e9)
		Return NaN
	EndIf
		
	// Return age in Ma
	Return nAge/1e6
End