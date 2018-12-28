// set seed
	set seed 56019981

// set desired number of resampling iterations. Set low (e.g. 5) for debugging; set high (10,000+) for final run
	local iterations=200
	
// load the LONG survey data
	use "P:\Proj_Frank Greb\JPB Project 2017-2019\JPB Survey data\outputfiles\JPB_long.dta",clear
			
	// (just for example here) create a couple of auxiliary variables needed for analysis)
		gen byte Wx=Group==1 // for cross-sectional analysis, CwT group is Wx==1; T and C groups for Wx==0
		gen byte region_MW=inlist(State,"IL","WI") // dummy variable for Midwest
		gen byte region_NYC=(State=="NY") // dummy variable for NY
		
	
	// also do a couple of manual corrections to Wx assignment (pending Three3 review...)
		replace Wx=0 if PropertyID=="IL0041"
		replace Wx=1 if PropertyID=="WI0086"
	
// flag cases where there is only a single survey reponse for a property
	preserve
		contract PropertyID id
		drop _freq
		contract PropertyID
		keep if _freq==1
		drop _freq
		tempfile singletons
		save "`singletons'"
	restore
	merge m:1 PropertyID using "`singletons'"
	gen byte singleton=_merge==3
	drop _merge
	
// Save a working version of the LONG dataset -- will be loaded before each resample
	sort id person // sort before saving (to ensure replication)
	tempfile working_long
	save "`working_long'"
	
// SET UP ANY NEEDED POST FILES FOR HOLDING THE SAMPLING STATISTIC(S) OF INTEREST FOR EACH RESAMPLING ITERATION	
	postutil clear
	tempfile outfle_b6a_num
	postfile output_b6a_num long iteration double coeff_b6a_num using "`outfle_b6a_num'"
		
// MAIN RESAMPLING LOOP		
	
	forvalues i=1/`iterations' {
	
		// display iteration # on even 100s
			if mod(`i',100)==0 | `i'==1 {
				noi di "`i'.." _c
			}
	
		// load the working LONG file	
			qui use "`working_long'",clear
					
		// implement the property level resample	
			bsample,strata(Wx) cluster(PropertyID) idcluster(resamp1)
			
			// save off the "singleton" properties, because these will be lost at the next stage of resampling
				preserve
					qui keep if singleton==1
					tempfile fle
					qui save "`fle'"
				restore
				
		// implement the respondent-level resample (of non-singletons)
			bsample if singleton==0,strata(resamp1) cluster(id) idcluster(resamp2) 
			
			// now append back the singleton cases -- and assign a resamp2 value to each
				qui append using "`fle'"
				qui bysort person (resamp2 id):replace resamp2=resamp2[_n-1]+1 if resamp2==. & resamp2[_n-1]<.
				qui bysort resamp1 resamp2:replace resamp2=resamp2[_n-1] if resamp2==. & resamp2[_n-1]<.
			
		// analyze statistic(s) of interest 
			// (for example here, just a simple regression model of b6a_num (number of times went to doctor because cold) as a function of Wx and region

			
			
			
			qui regr b6a_num Wx region_MW region_NY
			
		// post coefficient of interest to output file
			post output_b6a_num (`i') (_b[Wx])
		
	}	// END OF MAIN RESAMPLING LOOP

// CLOSE THE OUTPUT FILE(S), LOAD UP THE RESAMPLING OUTPUT, AND GET STD. ERROR
	postclose output_b6a_num
	use "`outfle_b6a_num'",clear
	summ coeff_b6a_num
	histogram coeff_b6a_num,normal freq
	
			
			
