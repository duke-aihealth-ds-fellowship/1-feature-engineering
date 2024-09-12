/******************************************************************/
/* Title: Clinical Classifications Software (CCS) for Services    */
/*        and Procedures Mapping Program                          */
/*                                                                */
/* Program: CCS_Services_Procedures_Mapping_Program_v2022-1.sas    */
/*                                                                */
/* Description: This is the SAS mapping program to add the        */
/*              CCS for Services and Procedures to data with      */
/*              HCPCS Level I codes, commonly referred to as      */
/*              Current Procedural Terminology (CPT) codes, and   */
/*              HCPCS Level II codes.                             */ 
/*              CPT is a proprietary coding system developed and  */
/*              maintained by the American Medical Association.   */
/*                                                                */
/*              There are two general sections to this program:   */ 
/*                                                                */
/*              1) The first section creates a temporary SAS      */
/*                 informat using the CCS-Services and Procedures */
/*                 tool file. This informat is used in step 2 to  */
/*                 to assign the CCS category.                    */
/*                                                                */
/*              2) The second section loops through the array of  */
/*                 CPT and HCPCS Level II codes in your SAS       */
/*                 dataset and creates an array of CCS categories */
/*                 in the output file.                            */ 
/*                                                                */
/*              The v2022-1 CSV file is compatible with CPT and   */
/*              HCPCS Level II codes valid as of April 2022.      */
/*                                                                */
/*              The v2021-2 CSV file is compatible with CPT and   */
/*              HCPCS Level II codes valid as of January 2021.    */
/*                                                                */
/*              The v2021-1 CSV file is compatible with CPT and   */
/*              HCPCS Level II codes valid as of January 2021.    */
/*                                                                */
/*              The v2020-1 CSV file is compatible with CPT and   */
/*              HCPCS Level II valid as of January 2020.          */
/*                                                                */
/*              The v2019-2 CSV file is compatible with CPT and   */
/*              HCPCS Level II codes valid at any time during     */
/*              calendar years 2018 and 2019.                     */
/*                                                                */
/* Output: This program creates a horizontal array of CCS         */
/*         categories that have a one-to-one correspondence to    */
/*         the user-provided array of CPT and HCPCS Level II      */
/*         codes.                                                 */
/*                                                                */
/******************************************************************/


/*******************************************************************/
/*      THE SAS MACRO FLAGS BELOW MUST BE UPDATED BY THE USER      */ 
/*  These macro variables must be set to define the locations,     */
/*  names, and characteristics of your input SAS formatted data.   */
/*******************************************************************/

/**************************************/
/*          FILE LOCATIONS            */
/**************************************/
FILENAME INRAW1  'c:\ccs\CCS_services_procedures_v2022-1_052422.csv ' lrecl=300;   * Location of CCS-Services and Procedures tool file. <===USER MUST MODIFY;
LIBNAME  IN1     'c:\sasdata\';                                                    * Location of input discharge data.                  <===USER MUST MODIFY;
LIBNAME  OUT1    'c:\sasdata\';                                                    * Location of output data.                           <===USER MUST MODIFY;


/**************************************/
/*            FILE NAMES              */
/**************************************/ 
* Input SAS file member name;                                      %LET CORE   = YOUR_SAS_INPUT_FILE_HERE;         *<===USER MUST MODIFY;
* Output SAS file member name;                                     %LET SASOUT = YOUR_SAS_OUTPUT_FILE_HERE;        *<===USER MUST MODIFY;


/**************************************/
/*   INPUT FILE CHARACTERISTICS       */
/**************************************/ 
* Maximum number of CPTs or HCPCS Level II codes on any record;    %LET NUMCPT = 15;                           *<===USER MUST MODIFY;
* Set the number of observations to use from 
  your dataset (use MAX for all observations,
  other values for testing);                                       %LET OBS    = MAX;                          *<===USER MAY MODIFY; 

* Facilitating macro used in multiple places; %LET CCS_version = "2022.1" ;      *<=== DO NOT MODIFY;

TITLE1 'CREATE CCS-SERVICES AND PROCEDURES CATEGORIES';
TITLE2 'USE WITH ADMINISTRATIVE DATA THAT HAVE CPT OR HCPCS LEVEL II CODES';


%macro ccscpt;
%if &numcpt > 0 %then %do; 
options obs=max;
/*******************  SECTION 1: CREATE INFORMAT   ****************/
/*  SAS Load the CCS-Services and Procedures tool and convert     */
/*  it into a temporary SAS informat used to assign the           */
/*  CCS-Services and Procedures variables in the next step.       */
/******************************************************************/
data cptccs;
   infile INRAW1 dsd dlm=',' firstobs=3 end=eof;
   input
      code_range  : $char11.
      label       : 3.
      ccs_label   : $char80.
      ;
   start = scan(code_range,1);
   end   = scan(code_range,2);

   retain hlo " ";
   fmtname = "cptccs" ;
   type    = "i" ;
   output ;
   if eof then do ;
      start = " " ;
      end   = " " ;
      label = .   ;
      hlo   = "o" ;
      output ;
   end ;
run;

proc format lib=work cntlin = cptccs;
run;


options obs=&obs.;
/***** SECTION 2: CREATE CPT OR HCPCS Level II CCS-SERVICES AND PROCEDURES CATEGORIES *****/
/*  Create CCS-Services and Procedures categories for CPT or HCPCS Level II codes using   */
/*  the SAS informat created in Step 1 and the SAS input file you wish to augment. Users  */
/*  can change the names of the output CCS-Services and Procedures variables if needed    */
/*  here. It is also important to make sure that the correct CPT or HCPCS Level II code   */
/*  variable names from your SAS file are used in the array 'cpts' below.                 */
/******************************************************************************************/  
data out1.&SASOUT. (drop = i);  
   set in1.&CORE.;

   array cptccs  (*)      cpt_ccs1-cpt_ccs&numcpt;  * Name for CPT or HCPCS Level II CCS-Services and Procedures variables. <===USER MAY MODIFY;
   array cpts    (*)   $  cpt1-cpt&numcpt;          * Name for CPT or HCPCS Level II variable in your file.                 <===USER MAY MODIFY;

     label cpt_ccs_version = "Version of CCS-Services and Procedures" ;
     retain cpt_ccs_version &CCS_version;
 
   /***************************************************/
   /*  Loop through the array of CPT and HCPCS Level II */
   /*  codes on your SAS dataset and create the       */
   /*  CCS-Services and Procedures variables.         */
   /***************************************************/
   do i = 1 to &NUMCPT;
      cptccs(i) = input(cpts(i),cptccs.);
   end;  

   %do i = 1 %to &NUMCPT;
      label cpt_ccs&i. = "CCS-Services and Procedures &i.";      * Labels for CCS Variables      <===USER MAY MODIFY;    
   %end;
run;

proc print data=out1.&SASOUT. (obs=10); * Change the number of observations if you wish to display more or less than 10.   <=== USER MAY MODIFY;
   var  cpt1-cpt&NUMCPT. cpt_ccs1-cpt_ccs&NUMCPT. cpt_ccs_version;
   TITLE3 "PARTIAL PRINT OF THE OUTPUT CCS-SERVICES AND PROCEDURES FILE";
run;

proc freq data=out1.&SASOUT. ; 
   tables cpt_ccs1 cpt_ccs_version / missing list;
   TITLE3 "FREQUENCY OF CERTAIN FIELDS FROM THE CCS-SERVICES AND PROCEDURES FILE";
run;
%end;
%else %do;
   %put;
   %put 'ERROR: NO CPT CODES SPECIFIED FOR MACRO VARIABLE NUMCPT, PROGRAM ENDING';
   %put;
%end;

%mend ccscpt;
%ccscpt;

