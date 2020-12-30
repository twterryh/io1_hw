capture log close
log using "황태원(2020711771)_log.log", replace t

********************************************************************************
cd "C:\Users\twter\Google Drive\Graduate\코스웍\2020 김현철 산업조직론1\final project"

import delim "prod.csv", clear
label variable y "log(Sales)"
label variable l "log(Employment)"
label variable k "log(Capital)"
label variable g "log(R\&D capital)"
label variable r "log(R\&D)"
label variable i "log(Investment)"

order index sic3
sort index yr sic3 

save full, replace

********************************************************************************
* Question 1
* construct panels

* Balanced Panel 
use full, clear
xtset index yr, del(5)

bys index: gen count = _N
drop if count != 4
drop count

save balanced, replace

* 2-year Panel
use full, clear
xtset index yr, del(5)

bys index: gen count = _N
drop if count == 1
drop count

save 2year, replace

* SS
foreach n in full balanced 2year{
	use `n', clear
	eststo clear
	estpost su y l k g r i, de
	esttab using ss_`n'.tex, cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) p50(fmt(2)) max(fmt(2))") ///
		nomti nonum l replace 
}

********************************************************************************
* Question 2
* construct dummies
foreach n in full balanced 2year{
use `n', clear

tab yr, gen (yr)
tab yr if sic3==357, gen (d)
forv i=1/4{
	replace d`i'=0 if d`i'==.
}

forv j=1/4{
	local k=5*(13+`j')+3
	label variable yr`j' "Year 19`k'"
	label variable d`j' "Year 19`k' \& Computer" 
}

save `n'_ready, replace
}

* (i)
eststo clear
use balanced_ready, clear
xtset index yr, del(5)

eststo: quietly reg y l k g yr1-yr4 d*, vce(cluster index)

eststo: quietly xtreg y l k g yr1-yr4 d*, fe vce(cluster index)
estimates store fixed

eststo: quietly xtreg y l k g yr1-yr4 d*, re vce(cluster index)
estimates store random

* ssc install rhausman
rhausman fixed random, cluster

esttab using 21_balanced.tex, nobaselevels compress ///
	r2(2) se(2) nodep noomit nogaps l replace ///
	mti("Pooled OLS" "FE" "RE")

* (ii)
use balanced_ready, clear
xtset index yr, del(5)

reg y l k g yr1-yr4 d*, vce(cluster index)
eststo balanced_total

predict y_hat, xb
gen w_hat = y - y_hat

eststo clear
eststo: quietly reg w_hat L1.w_hat
eststo: quietly reg w_hat L2.w_hat
esttab using 22_lag.tex, nobaselevels compress ///
	se(2) nodep noomit nogaps l nomti nocon replace ///
	coeflabels(L1.w_hat "5 Year Lag" L2.w_hat "10 Year Lag")

********************************************************************************
* Question 3
eststo clear

* (i)
* Full Panel
use full_ready, clear
xtset index yr, del(5)

* total
eststo: quietly reg y l k g yr1-yr4 d*, vce(cluster index)
eststo fu1

* first diff
quietly reg D.y D.l D.k D.g yr1-yr4 d*, vce(cluster index)
eststo fu2

* 2_year Panel
use 2year_ready, clear
xtset index yr, del(5)

quietly reg y l k g yr1-yr4 d*, vce(cluster index)
eststo yr1

* (ii)
* generate (predicted) survival rate
foreach n in full 2year {
use `n'_ready, clear
xtset index yr, del(5)

gen year = 1 if yr==73
replace year = 2 if yr==78
replace year = 3 if yr==83
replace year = 4 if yr==88

gen survive = 1
order index yr year survive
by index: replace survive = 0 if year[_n+1] != year+1
by index: replace survive = 1 if year[_n+1] == year+2
replace survive = . if year == 4

probit survive k g i, vce(cluster index)
predict phat

save `n'_survival, replace
}

* estimation
use full_survival, clear
xtset index yr, del(5)
quietly reg D.y D.l D.k D.g phat yr1-yr4 d*, vce(cluster index)
eststo fu3

use 2year_survival, clear
xtset index yr, del(5)
quietly reg y l k g phat yr1-yr4 d*, vce(cluster index)
eststo yr2

* export table
esttab fu1 fu2 fu3 yr1 yr2 using 3_full2year.tex, nobaselevels compress ///
	r2(2) se(2) nodep noomit nogaps l replace ///
	coeflabels(phat "Pr(Survival)") ///
	mti("Pooled OLS" "First Diff." "First Diff. Survival" "Pooled OLS" "Pooled OLS Survival") ///
	order(l k g D* phat)

********************************************************************************
* Question 4
use full_survival, clear
xtset index yr, del(5)

gen k2 = k*k
gen g2 = g*g
gen i2 = i*i
gen kg = k*g
gen gi = g*i
gen ki = k*i

* (i) 
eststo clear
eststo: reg y l yr1-yr4 d* k g i k2 g2 i2 kg gi ki, vce(cluster index)
esttab using 41_secondorder.tex, nobaselevels compress ///
	wide noobs se(2) nodep noomit nogaps l replace ///
	k(l yr1 yr2 yr3 d*)

* (ii) 
gen dep = y - 3.660868 		///
			- .5843907*l 	///
			- -.1692234*yr1	///
			- -.1528244*yr2	///
			- -.22005*yr3	///
			- -3.244875*d1	///
			- -2.036846*d2	///
			- -.7570156*d3	///
			- .4084257*d4

predict yhat, xb

eststo clear
eststo: quietly reg yhat k g, vce(cluster index)
esttab using 42_yhat.tex, nobaselevels compress ///
	se(2) nodep noomit nogaps noobs nocon l wide replace
	
predict h, resid

eststo clear
eststo: quietly nl (dep = {b0} + {bk}*k + {bg}*g + {bh}*h + {bh2}*h^2), vce(cluster index)		

* (iv)
eststo: quietly nl (dep = {b0} + {bk}*k + {bg}*g + /// 
		{bh}*h + {bh2}*h^2 + {bp}*phat + {bp2}*phat^2 + {bhp}*h*phat), ///
		vce(cluster index)		
esttab using 44_nl.tex, nobaselevels compress ///
	r2(2) se(2) nodep noomit nomti wide nogaps replace

********************************************************************************
log close
