/**********************************************************************************************************************
*Stata code for creating tables in the article
**********************************************************************************************************************/
use "PATH/COVID_NH_Final.dta"

*Limit sample to DC and 23 states
keep if Provider_State=="CA" | Provider_State=="CO" | Provider_State=="CT"| Provider_State=="DC" | Provider_State=="DE" | Provider_State=="FL" | Provider_State=="GA" | Provider_State=="IA"| Provider_State=="IL"| Provider_State=="KY"| Provider_State=="MA"| Provider_State=="MD"| Provider_State=="MI"| Provider_State=="MN"| Provider_State=="NC"| Provider_State=="ND"| Provider_State=="NJ"| Provider_State=="NM"| Provider_State=="NV"| Provider_State=="NY"| Provider_State=="OH"| Provider_State=="OK"| Provider_State=="OR"| Provider_State=="TN"

*Summary of nursing homes with and without COVID-19 cases
tab covid
 
*Star ratings
table covid, c(mean Overall_Rating sd Overall_Rating) 
table covid, c(mean Health_Inspection_Rating sd Health_Inspection_Rating)
table covid, c(mean Staffing_Rating mean RN_Staffing_Rating )
table covid, c(mean QM_Rating sd QM_Rating)
 
*Citations
table covid, c(mean Total_Weighted_Health_Survey_Sco sd Total_Weighted_Health_Survey_Sco)

*Emergency preparedness citations
table covid, c(mean all_citation_cnt sd all_citation_cnt)

*Incidents
table covid, c(mean Number_of_Facility_Reported_Inci sd Number_of_Facility_Reported_Inci)

*Substantiated complaints
table covid, c(mean Number_of_Substantiated_Complain sd Number_of_Substantiated_Complain)

*Staffing
table covid, c(mean Adjusted_Total_Nurse_Staffing_Ho sd Adjusted_Total_Nurse_Staffing_Ho)
table covid, c(mean Adjusted_RN_Staffing_Hours_per_R sd Adjusted_RN_Staffing_Hours_per_R)
table covid, c(mean Adjusted_LPN_Staffing_Hours_per sd Adjusted_LPN_Staffing_Hours_per)
table covid, c(mean Adjusted_Nurse_Aide_Staffing_Hou sd Adjusted_Nurse_Aide_Staffing_Hou)
  
*NH characteristics
gen forprofit=(Ownership_Type=="For profit - Corporation" | Ownership_Type=="For profit - Individual" | Ownership_Type=="For profit - Limited Liability company" | Ownership_Type=="For profit - Partnership")
tab forprofit covid
table covid, c(mean forprofit)
table covid, c(mean Number_of_Certified_Beds sd Number_of_Certified_Beds)

*%Mcaid
gen pctmcaid=cnsus_mdcd_cnt/cnsus_rsdnt_cnt
table covid, c(mean pctmcaid sd pctmcaid)

*County case rate
gen cases_pop=(cases/population)*100000
table covid, c(mean cases_pop sd cases_pop)


