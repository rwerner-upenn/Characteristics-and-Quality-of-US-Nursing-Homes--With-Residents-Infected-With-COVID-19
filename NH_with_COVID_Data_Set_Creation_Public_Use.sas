/***********************************************************************************************************
*Step 1: Import Nursing Home Compare Provider Information data set into SAS;
***********************************************************************************************************/
proc import datafile="PATH\Provider_Info.csv" 
			out=nh_pvid_info replace
			dbms=csv;
			guessingrows=MAX;
run; *15,446;

data nh_pvid_info_2;
set nh_pvid_info (keep=Federal_Provider_Number Provider_Name Provider_County_Name Provider_State Provider_SSA_County);
run;

proc sort data=nh_pvid_info_2 nodupkey; by Federal_Provider_Number; run; *No duplicate;



/***********************************************************************************************************
*Step 2: Import data set of nursing homes that reported COVID cases and merge with Nursing Home Compare 
         Provider Information data set;
***********************************************************************************************************/
proc import datafile="PATH\covid_nh_05_01_2020.xlsx" 
			out=covid_nh replace
			dbms=xlsx;
run; *6,214;

data covid_nh_2;
length Medicare_Provider_Number $6.;
format Medicare_Provider_Number $6.;
set covid_nh;
if Medicare_Provider_Number="" then delete;
Medicare_Provider_Number_l=lengthn(Medicare_Provider_Number);
run; *3,144;

proc freq data=covid_nh_2; table Medicare_Provider_Number_l; run;

data covid_nh_3(drop=Medicare_Provider_Number_l Medicare_Provider_Number);
set covid_nh_2;
if Medicare_Provider_Number_l=5 then Medicare_Provider_Number_new="0"||Medicare_Provider_Number;
else Medicare_Provider_Number_new=Medicare_Provider_Number;
run;

proc sort data=covid_nh_3 nodupkey; by Medicare_Provider_Number_new; run; *3,106;

proc freq data=covid_nh_3; table covid; run;

*Merge Nursing Home Compare Provider Information data set with data set of nursing homes that reported COVID cases;
proc sql;
create table covid_nh_4 as 
select a.Federal_Provider_Number, a.Provider_Name, b.covid, a.Provider_State, a.Provider_County_Name, a.Provider_SSA_County
from nh_pvid_info_2 as a
left join covid_nh_3 as b
on a.Federal_Provider_Number=b.Medicare_Provider_Number_new;
quit; *15,446;

proc sql; create table check_merge as select * from covid_nh_3 
where Medicare_Provider_Number_new not in (select Federal_Provider_Number from nh_pvid_info_2);
quit; *9 unmatched;

data covid_nh_5(drop=Provider_SSA_County);
set covid_nh_4;
if covid=. then covid=0; 
County_SSA=put(Provider_SSA_County,z3.);
run;

proc freq data=covid_nh_5; table covid; run;



/***********************************************************************************************************
*Step 3: Merge in county FIPS code from SSA-FIPS crosswalk;
***********************************************************************************************************/
libname data "PATH\05_01_2020";

data ssa_fips_state_county2017;
set data.ssa_fips_state_county2017;
county_ssa=substr(ssacounty,3,3);
run;

proc sql;
create table covid_nh_6 as 
select a.*, b.fipscounty
from covid_nh_5 as a 
left join ssa_fips_state_county2017 as b
on a.provider_state=b.state and a.County_SSA=b.county_ssa;
quit; *15,446;

proc sql; create table check_merge as select * from covid_nh_6 where fipscounty=""; quit; *11;

*Manually enter the FIPS code for unmatched records;
data covid_nh_7(drop=County_SSA);
set covid_nh_6;
if Provider_state="AK" and Provider_County_Name="Valdez Cordova" then fipscounty="02261";
if Provider_state="AK" and Provider_County_Name="Kenai Peninsula" then fipscounty="02122";
if Provider_state="AK" and Provider_County_Name="Northwest Arctic" then fipscounty="02188";
if Provider_state="AK" and Provider_County_Name="Wrangell" then fipscounty="02275";
if Provider_state="VA" and Provider_County_Name="Alleghany" then fipscounty="51005";
if Provider_state="VA" and Provider_County_Name="Bedford" then fipscounty="51019";
run;

proc sql; create table check_merge as select * from covid_nh_7 where fipscounty=""; quit; *1;



/***********************************************************************************************************
*Step 4: Import data set of county-level COVID cases and deaths and merge with nursing home data set;
***********************************************************************************************************/
proc import datafile="PATH\us_counties.csv" 
			out=us_counties replace
			dbms=csv;
			guessingrows=MAX;
run; *103,960;

proc sort data=us_counties; by state county descending date; run;

data us_counties_2;
set us_counties;
by state county descending date;
if first.county;
fips_2=put(fips, z5.); 
run; *2,890;

proc sql;
create table covid_nh_8 as 
select a.*, b.date, b.cases, b.deaths
from covid_nh_7 as a
left join us_counties_2 as b 
on a.fipscounty=b.fips_2;
quit;*15,446;

proc sql; create table check_merge as select * from covid_nh_8 where cases=.; quit; *445 (2.9%);

*Merge in county population from ACS data;
proc sql;
create table covid_nh_9 as 
select a.*, b.A00001_001 as population
from covid_nh_8 as a
left join data.acs_county_2018_pop as b 
on a.fipscounty=b.fips
where Provider_County_Name^="Guam"; /*Drop Guam*/
quit;*15,445;

proc sql; create table check_merge as select * from covid_nh_9 where population=.; quit; *0;



/***********************************************************************************************************
*Step 5: Merge in SNF quality measures from Skilled Nursing Facility Quality Reporting Program data set;
***********************************************************************************************************/
proc import datafile="PATH\Skilled_Nursing_Facility_Quality_Reporting_Program_-_Provider_Data.csv" 
			out=nh_compare replace
			dbms=csv;
			guessingrows=MAX;
run; *339,592;

proc sort data=nh_compare; by CMS_Certification_Number__CCN_ Measure_Code; run;

data nh_compare_2;
set nh_compare(keep=CMS_Certification_Number__CCN_ Measure_Code score);
where Measure_Code in ("S_001_01_OBS_RATE", "S_013_01_OBS_RATE", "S_004_01_PPR_PD_RSRR", "S_005_01_DTC_RS_RATE", "S_006_01_MSPB_SCORE");
run; *77,180;

proc sort data=nh_compare_2;
by CMS_Certification_Number__CCN_;
run;

proc transpose data=nh_compare_2 out=nh_compare_3;
by CMS_Certification_Number__CCN_;
id measure_code;
var score;
run;

data nh_compare_4;
set nh_compare_3;
label S_001_01_OBS_RATE="Percentage of SNF residents whose functional abilities were assessed and functional goals were included in their treatment plan"
      S_013_01_OBS_RATE="Percentage of SNF residents who experience one or more falls with major injury during their SNF stay" 
      S_004_01_PPR_PD_RSRR="Risk-Standardized Potentially Preventable Readmission Rate (RSRR)" 
      S_005_01_DTC_RS_RATE="Risk-Standardized Discharge to Community Rate" 
      S_006_01_MSPB_SCORE="MSPB Score";
run;

*Merge in SNF quality measures;
proc sql;
create table covid_nh_10 as 
select a.*, b.S_001_01_OBS_RATE, b.S_013_01_OBS_RATE, b.S_004_01_PPR_PD_RSRR, b.S_005_01_DTC_RS_RATE, b.S_006_01_MSPB_SCORE
from covid_nh_9 as a
left join nh_compare_4 as b 
on a.Federal_Provider_Number=b.CMS_Certification_Number__CCN_; 
quit;*15,445;

proc sql; create table check_merge as select * from covid_nh_10 where S_001_01_OBS_RATE=""; quit; *17;

proc sql;
create table covid_nh_11 as 
select a.*, b.*
from covid_nh_10 as a 
left join nh_covid_merged as b
on a.Federal_Provider_Number=b.Federal_Provider_Number;
quit;

data covid_nh_12(rename=(Federal_Provider_Number=prvdrnum)) ;
set covid_nh_11;
label Federal_Provider_Number="CMS Provider Number" Provider_Name="Provider Name" COVID="COVID" Provider_State="State"
      Provider_county_name="County" date="Date" cases="Cases" deaths="Deaths";
run;



/***********************************************************************************************************
*Step 6: Create final data set and output to Stata data set for further analysis (limit variables to those
         we will use in analysis)
***********************************************************************************************************/
data data.covid_nh_final;
set covid_nh_12;
keep Provider_State covid Overall_Rating Health_Inspection_Rating Staffing_Rating QM_Rating Total_Weighted_Health_Survey_Sco all_citation_cnt 
     Number_of_Facility_Reported_Inci Number_of_Substantiated_Complain Adjusted_Total_Nurse_Staffing_Ho Adjusted_RN_Staffing_Hours_per_R 
     Adjusted_LPN_Staffing_Hours_per Adjusted_Nurse_Aide_Staffing_Hou Ownership_Type Number_of_Certified_Beds cnsus_mdcd_cnt cnsus_rsdnt_cnt
     cases population;
run;


proc export data=data.covid_nh_final outfile="PATH\covid_nh_final.dta" dbms=dta replace; run;


