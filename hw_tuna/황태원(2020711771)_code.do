capture log close
cd "C:\Users\twter\Google Drive\Graduate\코스웍\2020 김현철 산업조직론1\hw1_tuna"

log using "황태원(2020711771)_log.log", replace t

********************************************************************************
* Part I
* 1. Merge the Nielsen week data into the sales data and save the two-year data in a separate file.
use WTNA, clear
sort week store
merge m:1 week using nielsen-week.dta, keep(match) nogen
gen sales = price*move/qty

* 1.(a) Transform the date variables into a date format.
gen date_start = date(start, "MD19Y")
gen date_end = date(end, "MD19Y")
drop start end ok
format date_start date_end %td
keep if week >= 277 & week <= 381

* 1.(b) Generate dummies for the event weeks.
gen holiday = event!=""
order week date_start date_end events holiday store
sort week store upc
save part1_1, replace

* 1.(c) Pick the 10 best-selling UPCs, report summary statistics, plot time-series of weekly prices.
use part1_1, clear
collapse (sum) sales_per_upc=sales, by(upc)
egen rank = rank(-sales_per_upc)
sort upc
tempfile rank
save `rank', replace

use part1_1, clear
sort upc
merge m:1 upc using `rank', nogen
save part1_2, replace

use part1_2, replace
keep if rank<=10
order rank week
sort rank week
collapse (mean) price, by(rank week upc)

tw  (connected price week if rank==1, msize(tiny)) ///
	(connected price week if rank==2, msize(tiny)) ///
	(connected price week if rank==3, msize(tiny)) ///
	(connected price week if rank==4, msize(tiny)) ///
	(connected price week if rank==5, msize(tiny)) ///
	(connected price week if rank==6, msize(tiny)) ///
	(connected price week if rank==7, msize(tiny)) ///
	(connected price week if rank==8, msize(tiny)) ///
	(connected price week if rank==9, msize(tiny)) ///
	(connected price week if rank==10, msize(tiny)) ///
	, legend(col(5) label(1 1) label(2 2) label(3 3) label(4 4) label(5 5) label(6 6) ///
	label(7 7) label(8 8) label(9 9) label(10 10)) ///
	plotregion(lcolor(none) ilcolor(none) style(none) lwidth(thick)) scheme(s1color) ///
	ytitle("Mean Price") xtitle("Week")

drop if price == 0 
sort rank
estpost tabstat price, by(rank) s(mean sd q min max)
esttab . using summary.tex, cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace
	
* 2. summary statistics of the sales data and the demographic variables for sample stores
use demo, clear
keep city zip zone store ethnic educ income hsizeavg
sort store
tempfile store
save `store', replace

use part1_2, clear
sort store
merge m:1 store using `store'
keep if _merge==1|_merge==3
drop _merge

merge m:1 upc using UPCTNA
drop if _merge==2
drop _merge
drop COM_CODE

sort week zone store 
order week events holiday zone store 

*tabstat price, s(mean sd q cv min max)
*tabstat ethnic, s(mean sd q min max) by(store)
*tabstat educ, s(mean sd q min max) by(store)
*tabstat income, s(mean sd q min max) by(store)
*tabstat hsizeavg, s(mean sd q min max) by(store)

estpost tabstat sales, s(mean sd q min max) 
esttab . using summary1.tex, cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace
estpost tabstat profit, s(mean sd q min max) by(store)
esttab . using summary2.tex, cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace

save part1_3, replace

* 3. HHI for each UPC
use part1_3, replace

keep if city=="CHICAGO"
collapse (max) sales_per_upc (sum) sales, by(upc store)
gen share2 = (sales/sales_per_upc*100)^2
collapse (sum) share2, by(upc)
rename share2 HHI
replace HHI = int(HHI)

drop if HHI==0
estpost tabstat HHI, s(mean sd q min max)
esttab . using summary3.tex,cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) p25(fmt(2)) p50(fmt(2)) p75(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace

********************************************************************************
* Part II
use part1_3, replace

* standardize price
split size, p("/")
tab size1 if size2=="", mis
tab size1 if size2~="", mis

gen tmp=size1 if size2~=""
destring tmp, gen(pack)
replace pack=1 if pack==.
drop tmp

replace size2=size1 if size2==""
tab size2, mis
destring size2, gen(sizen) ignore(L LT OZ O NR CANS EA EACH FREE C MELONB)
tab sizen, mis
unique upc if sizen==.
tab sizen, mis
drop if sizen==.
drop size1 size2

* price per 16 ounces, 12 pack
gen sprice=(price/qty)*(12/pack)*(16/sizen)
gen lsprice=log(sprice)

save part2_1, replace

* 1. Price Variation across Cities
use part2_1, replace

drop if income==.
bys store: gen count_store = _n
keep if count_store==1
collapse (mean) income, by(city)
quietly su income, d
gen lowinc = (income<r(p10))
gen highinc = (income>r(p90))
sort city
tempfile city_inc
save `city_inc', replace

use part2_1, clear
drop if income==.
sort city
merge m:1 city using `city_inc', nogen
save part2_2, replace

use part2_2, clear
tab city if highinc==1
tab city if lowinc==1

bys city: egen sd = sd(sprice)
bys city: gen count = _n
keep if count==1
drop count

estpost tabstat sd if lowinc==1, s(mean sd min max)
esttab . using summary4.tex,cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace
estpost tabstat sd if highinc==1, s(mean sd min max)
esttab . using summary5.tex,cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace

* 2. Price Variation across Zones
use part2_1, clear

collapse (sd) sd=sprice, by (zone)
estpost tabstat sd, s(mean sd min max)
esttab . using summary5.tex,cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace


* 3. Price Dispersion between Online/Offline Markets
use part2_1, clear

gen nozone = (zone==.)
bys nozone upc: egen sd = sd(sprice)
bys nozone upc: gen count = _n
keep if count==1

estpost tabstat sd if nozone==1, s(mean sd min max)
esttab . using summary6.tex,cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace
estpost tabstat sd if nozone==0, s(mean sd min max)
esttab . using summary7.tex,cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace

* 4. Variation in Markups across Zones
use part2_1, clear

collapse (mean) markup=profit, by (zone)
estpost tabstat markup, s(mean sd min max)
esttab . using summary7.tex,cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2))") nomtitle nonumber noobs replace

hist markup, w(1) plotregion(lcolor(none) ilcolor(none) style(none) lwidth(thick)) scheme(s1color)
********************************************************************************
* Part III
* Table 2, CKR(2003)

use nielsen-week, clear

gen date_start = date(start, "MD19Y")
gen date_end = date(end, "MD19Y")
drop start end
format date_start date_end %td
keep if week >= 277 & week <= 381

/*
[Holiday Dummies]

Generate dummy variables that take the value 1 
for two shopping weeks before each holiday.

For Thursday holidays, 
the variable was set to 1 for the two weeks prior to the holiday, 
but 0 for the week including the holiday.

1995 November 23	Thursday	Thanksgiving Day
1996 July 4			Thursday	Independence Day
1996 October 31		Thursday	Halloween
1996 November 28	Thursday	Thanksgiving Day

For holidays taking place on all other days, 
the dummy variable was set to 1 for the week before the holiday 
and for the week including the holiday.

Christmas dummy to remain equal to 1 
for the week following the holiday, instead of New-Year.

Post-Thanksgiving takes the value of 1 
for the week following Thanksgiving.

Lent variable takes the value of 1 
for the four weeks preceding the two-week Easter shopping period.
*/

replace event="Christmas" if event=="New-Year"
tab events, gen(hol_)
forvalues h=1/8 {
replace hol_`h'=0 if hol_`h'==.
replace hol_`h'=1 if hol_`h'[_n+1]==1
}

gen hol_thurs = (hol_8[_n+1]==1)
drop hol_8
rename hol_thurs hol_8
label var hol_8 "events==Thanksgiving"

gen hol_9 = (hol_8[_n-1]==1)
replace hol_9 = 0 if hol_8==1
label var hol_9 "events==Post-Thanksgiving"

replace hol_1 = 1 if week==354
replace hol_1 = 0 if week==356
replace hol_4 = 1 if week==370
replace hol_4 = 0 if week==372

gen hol_10=0
forv i=1/4{
replace hol_10=1 if hol_3[_n+`i']==1
}
replace hol_10=0 if hol_3==1
label var hol_10 "events==Lent"

save hol_dummy, replace

********************************************************************************
use part2_1, clear
merge m:1 week using hol_dummy, nogen keep(3)

keep if upc==1780000012 | upc==1780000024 | upc==4800000012 | upc==4800000024 | upc==4800000120
edit

drop if move==0
drop if price==0 

eststo clear
eststo: quietly reg sprice hol_*, r
eststo: quietly areg sprice hol_*, r a(upc)

esttab using "regression1.tex", noomitted nobaselevels compress wide replace ///
	coef(hol_1 "Independence Day" hol_2 "Christmas" hol_3 "Easter" hol_4 "Halloween" hol_5 "Labor Day" ///
	hol_6 "Memorial Day" hol_7 "Presidents Day" hol_8 "Thanksgiving" hol_9 "Post-Thanksgiving" hol_10 "Lent")

log close
