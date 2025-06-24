#!/bin/ksh
#####################################################################################################################################################
# Program Name     : install.sh
# Author           : Babu
# Description      : 
#                    
# Parameters       : 
#
# Modification History:
# Version      Date          Author                 Description 
# -----------  -----------   ---------------------  -------------------------------------------------------------------------------------------------
# 1.0          02/03/2011    Babu					Installation script
# 1.1												Update the script to display the error message (work in progress)
# 1.2												Update the script to scan for the additional DB details only if needed (work in progress)
# 1.3												Modified ldt deployment logic based on the ldt phase number to deploy the files in 
#													sequence (Example: RequestSet after request LDT)
#####################################################################################################################################################
#initialize the FORMS_PATH
FORMS_PATH=$FORMS_PATH:$AU_TOP/forms/US
export FORMS_PATH

#initialize for err
function errtrap {
	err=$(($err + $?))
}

trap errtrap ERR

err="0"; export err

#-
#-define local variables
#-

LOGFILE="XXZEN_INST.log"; export LOGFILE
LOGERR="XXZEN_INST.err"; export LOGERR

function getinput {
printf "Enter APPS password: "
stty -echo
read P_APPS_PWD
stty echo
echo

printf "Enter DB Server Name: "
read P_SERVER_NAME

printf "Enter Port Number: "
read P_PORT

printf "Enter Database SID: "
read P_DATABASE_SID
}

#function to call the shell scripts
function runscript {
	for i in `ls *.[sS][hH]`
	do 
		dos2unix -q -k $i
		chmod 744 $i
		echo "Running shellscript $i"
		. $i
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the shell scripts .PROG files & create a softlink
function deployshellscript {
	for i in `ls *.[pP][rR][oO][gG]`
	do 
		dos2unix -q -k $i
		echo "Deploying shellscript $i"
		cp $i $XXZEN_TOP/bin/
		chmod 777 $XXZEN_TOP/bin/$i
		fn=`echo $i|cut -d. -f1`
		if [[ ! -f $XXZEN_TOP/bin/$fn ]] then
			ln -s $FND_TOP/bin/fndcpesr $XXZEN_TOP/bin/$fn
			echo "Softlink created for $fn"
		else
			echo "$fn already exists";
		fi
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the SQL files
function deploysql {
	for i in `ls *.[sS][qQ][lL]`
	do 
		dos2unix -q -k $i
		echo "Deploying Concurrent Program SQL $i"
		echo "Return $?"
		cp $i $XXZEN_TOP/sql/
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the SQL*Loader files
function deployctl {
	for i in `ls *.[cC][tT][lL]`
	do 
		dos2unix -q -k $i
		echo "Deploying SQL*Loader $i"
		cp $i $XXZEN_TOP/bin/
		echo "Status : $?"
		echo ""
	done
}

#function to run the sql script files
function runsql {
	for i in `ls *.[sS][cC][rR]`
	do 
		dos2unix -q -k $i
		echo "Running SQL Script $i"
sqlplus -s apps/$P_APPS_PWD << EOF
set define off
@$i
show errors
EOF
		echo "Status : $?"
		echo ""
	done
}

#function to run the pl/sql script files
function runpls {
	for i in `ls *.[pP][lL][sS]`
	do 
		dos2unix -q -k $i
		echo "Running PL/SQL Script $i"
sqlplus -s apps/$P_APPS_PWD << EOF
set define off
@$i
show errors
EOF
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the pl/sql procedure
function deployprc {
	for i in `ls *.[pP][rR][cC]`
	do 
		dos2unix -q -k $i
		echo "Deploying Procedure $i"
sqlplus -s apps/$P_APPS_PWD << EOF
set define off
@$i
show errors
EOF
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the pl/sql function
function deployfnc {
	for i in `ls *.[fF][nN][cC]`
	do 
		dos2unix -q -k $i
		echo "Deploying Function $i"
sqlplus -s apps/$P_APPS_PWD << EOF
set define off
@$i
show errors
EOF
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the package specification
function deploypks {
	for i in `ls *.[pP][kK][sS]`
	do 
		dos2unix -q -k $i
		echo "Deploying Package Specification $i"
sqlplus -s apps/$P_APPS_PWD << EOF
set define off
@$i
show errors
EOF
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the package body
function deploypkb {
	for i in `ls *.[pP][kK][bB]`
	do 
		dos2unix -q -k $i
		echo "Deploying Package Body $i"
sqlplus -s apps/$P_APPS_PWD << EOF
set define off
@$i
show errors
EOF
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the FMB files
function deployfmb {
	for i in `ls *.[fF][mM][bB]`
	do 
		echo "Deploying FMB $i"
		cp $i $XXZEN_TOP/forms/US/
		frmcmp_batch module=$XXZEN_TOP/forms/US/$i userid=apps/$P_APPS_PWD module_type=form batch=yes compile_all=special
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the RDF files
function deployrdf {
	for i in `ls *.[rR][dD][fF]`
	do 
		echo "Deploying RDF $i"
		cp $i $XXZEN_TOP/reports/US/
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the XML report files
function deployxml {
	for i in `ls *.[xX][mM][lL]`
	do 
		echo "Deploying XML Data Template $i"
		lobcode=$i
		lobcode=${lobcode%%.[a-zA-Z]*}
		loblog="$lobcode"_xml.log
		java oracle.apps.xdo.oa.util.XDOLoader UPLOAD -DB_USERNAME apps -DB_PASSWORD $P_APPS_PWD -JDBC_CONNECTION $P_SERVER_NAME:$P_PORT:$P_DATABASE_SID -LOB_TYPE DATA_TEMPLATE -APPS_SHORT_NAME XXZEN -LOB_CODE "$lobcode" -FILE_TYPE "text/html" -XDO_FILE_TYPE "XML" -LOG_FILE "$loblog" -FILE_NAME "$i" -CUSTOM_MODE FORCE -UPLOAD_MODE REPLACE
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the RTF LDT files
function deployrtfldt {
	for i in `grep -l "phase=dat" *.ldt`
	do 
		echo "Deploying LDT $i"
		lctfile=`grep "dbdrv" $i`
		lctfile=${lctfile##*"UPLOAD "}
		lctfile=${lctfile%%" @~"*}
		echo "LCT File = $lctfile***"
		FNDLOAD apps/$P_APPS_PWD 0 Y UPLOAD "$lctfile" "$i" UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
		echo "Status : $?"
		echo ""
	done

}

#function to deploy the RTF templates
function deployrtf {
	for i in `ls *.[rR][tT][fF]`
	do 
		echo "Deploying RTF $i"
		lobcode=$i
		lobcode=${lobcode%%.[a-zA-Z]*}
		loblog="$lobcode"_rtf.log
		#- Retriving territory information		
territory_exits=`sqlplus -s apps/$P_APPS_PWD << EOF | grep ^territory | sed "s/^territory: //"
set heading off feedback off serveroutput on trimout on pagesize 0 
  declare
    l_territory_code   VARCHAR2(240);
    l_territory_exists varchar2(10);
  begin
    begin
      select territory
        into l_territory_code
        from xdo_lobs
       where lob_type = 'TEMPLATE_SOURCE'
         and xdo_file_type = 'RTF'
         and lob_code = '$lobcode';
    exception
      when too_many_rows then
        begin
          select territory
            into l_territory_code
            from xdo_lobs
           where lob_type = 'TEMPLATE_SOURCE'
             and xdo_file_type = 'RTF'
             and lob_code = '$lobcode'
             and territory = 'US';
        exception
          when others then
            l_territory_code := '00';
        end;
    when others then
      l_territory_code := '00';
    end;
  
    if l_territory_code = '00' THEN
       l_territory_exists := 'N';
    else
       l_territory_exists := 'Y';
    end if;
    
   dbms_output.put_line('territory'||l_territory_exists);   
   
  exception
   when others then
          l_territory_exists := 'N';
     dbms_output.put_line('territory'||l_territory_exists);
 end;
 /
EOF`
		#-
		echo "territory-"$territory_exits
		texit=`echo $territory_exits`
		#- echo 'texit-'$texit
		texists=`echo $texit | cut -c 10`
		#- echo "texits-"$texists
    	if [ $texists = N ]; then
			echo "Terrirtory N" $territory_exists
			java oracle.apps.xdo.oa.util.XDOLoader UPLOAD -DB_USERNAME apps -DB_PASSWORD $P_APPS_PWD -JDBC_CONNECTION $P_SERVER_NAME:$P_PORT:$P_DATABASE_SID -LOB_TYPE TEMPLATE -APPS_SHORT_NAME XXZEN -LOB_CODE "$lobcode" -LANGUAGE en -XDO_FILE_TYPE "RTF" -FILE_NAME "$i" -LOG_FILE "$loblog" -CUSTOM_MODE FORCE -UPLOAD_MODE REPLACE
		else
			echo "Terrirtory Y" $territory_exists
			java oracle.apps.xdo.oa.util.XDOLoader UPLOAD -DB_USERNAME apps -DB_PASSWORD $P_APPS_PWD -JDBC_CONNECTION $P_SERVER_NAME:$P_PORT:$P_DATABASE_SID -LOB_TYPE TEMPLATE -APPS_SHORT_NAME XXZEN -LOB_CODE "$lobcode" -LANGUAGE en -TERRITORY US -XDO_FILE_TYPE "RTF" -FILE_NAME "$i" -LOG_FILE "$loblog" -CUSTOM_MODE FORCE -UPLOAD_MODE REPLACE
		fi
		
		echo "Status : $?"
		echo ""
	done
}

#function to deploy the LDT files
function deployldt {
	#process the LDT files sequentially in order to make sure the LDTs are deployed correctly.
	for s in `seq 51 70`
	do
		#for i in `ls *.[lL][dD][tT]`
		for i in `grep -l "daa+$s" *.ldt`
		do 
			echo "Deploying LDT $i"
			lctfile=`grep "dbdrv" $i`
			lctfile=${lctfile##*"UPLOAD "}
			lctfile=${lctfile%%" @~"*}
			echo "LCT File = $lctfile***"
			FNDLOAD apps/$P_APPS_PWD 0 Y UPLOAD "$lctfile" "$i" UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
			echo "Status : $?"
			echo ""
		done
	done
}

#function to deploy the workflow files
function deploywft 
{
        for i in `ls *.[wW][fF][tT]`
        do
                echo "Deploying Workflow $i"
                WFLOAD apps/$P_APPS_PWD 0 Y FORCE $i
                echo "Status : $?"
                echo ""
        done
}

#function to deploy the java files
function deployjava 
{
echo ""
}

#program execution starts here
#check if the 1st argument is the help
if [[ $1 == "help" ]] then
	echo "Usage: install.sh <sourcedirectoryname>.  This will read the contents in the directory and deploy them to Oracle EBS."
fi

#check if the directory name is entered.
if [[ $1 == "" ]] then
	echo "Enter the directory name for the source code."
	echo "Usage: install.sh <sourcedirectoryname>"
	echo "Type install.sh help.  If you need more details on the install.sh"
	exit 1
fi

#change the directory to the source
cd $1

echo "Reading the input..." >> $LOGFILE 2>> $LOGERR
#read te input
getinput;
echo "Apps password  :: *****" >> $LOGFILE 2>> $LOGERR
echo "DB Server Name :: $P_SERVER_NAME" >> $LOGFILE 2>> $LOGERR
echo "DB Port Number :: $P_PORT" >> $LOGFILE 2>> $LOGERR
echo "Database SID   :: $P_DATABASE_SID" >> $LOGFILE 2>> $LOGERR
echo "Reading the input...Done" >> $LOGFILE 2>> $LOGERR
echo "" >> $LOGFILE 2>> $LOGERR
echo ""

#call the function to deploy shell scripts
echo "Running the shellscript..." >> $LOGFILE 2>> $LOGERR
echo "Running the shellscript..."
runscript >> $LOGFILE 2>> $LOGERR
echo "Running the shellscript...Done" >> $LOGFILE 2>> $LOGERR
echo "Running the shellscript...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy shell scripts
echo "Deploying the shellscript..." >> $LOGFILE 2>> $LOGERR
echo "Deploying the shellscript..."
deployshellscript >> $LOGFILE 2>> $LOGERR
echo "Deploying the shellscript...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying the shellscript...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy ctl scripts
echo "Deploying the sql*loader files..." >> $LOGFILE 2>> $LOGERR
echo "Deploying the sql*loader files..."
deployctl >> $LOGFILE 2>> $LOGERR
echo "Deploying the sql*loader files...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying the sql*loader files...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to run sql scripts
echo "Running the sql file..." >> $LOGFILE 2>> $LOGERR
echo "Running the sql file..."
runsql >> $LOGFILE 2>> $LOGERR
echo "Running the sql file...Done" >> $LOGFILE 2>> $LOGERR
echo "Running the sql file...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to run pl/sql scripts
echo "Running the pl/sql file..." >> $LOGFILE 2>> $LOGERR
echo "Running the pl/sql file..."
runpls >> $LOGFILE 2>> $LOGERR
echo "Running the pl/sql file...Done" >> $LOGFILE 2>> $LOGERR
echo "Running the pl/sql file...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy sql scripts
echo "Deploying the sql file..." >> $LOGFILE 2>> $LOGERR
echo "Deploying the sql file..."
deploysql >> $LOGFILE 2>> $LOGERR
echo "Deploying the sql file...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying the sql file...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy procedure
echo "Deploying the Procedure..." >> $LOGFILE 2>> $LOGERR
echo "Deploying the Procedure..."
deployprc >> $LOGFILE 2>> $LOGERR
echo "Deploying the Procedure...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying the Procedure...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy package specification
echo "Deploying the package specification..." >> $LOGFILE 2>> $LOGERR
echo "Deploying the package specification..."
deploypks >> $LOGFILE 2>> $LOGERR
echo "Deploying the package specification...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying the package specification...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy package body
echo "Deploying package body..." >> $LOGFILE 2>> $LOGERR
echo "Deploying package body..."
deploypkb >> $LOGFILE 2>> $LOGERR
echo "Deploying package body...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying package body...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy function
echo "Deploying the Function..." >> $LOGFILE 2>> $LOGERR
echo "Deploying the Function..."
deployfnc >> $LOGFILE 2>> $LOGERR
echo "Deploying the Function...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying the Function...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy Form files
echo "Deploying Form files..." >> $LOGFILE 2>> $LOGERR
echo "Deploying Form files..."
deployfmb >> $LOGFILE 2>> $LOGERR
echo "Deploying Form files...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying Form files...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy Report files
echo "Deploying Report files..." >> $LOGFILE 2>> $LOGERR
echo "Deploying Report files..."
deployrdf >> $LOGFILE 2>> $LOGERR
echo "Deploying Report files...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying Report files...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy LDT files
echo "Deploying ldt files..." >> $LOGFILE 2>> $LOGERR
echo "Deploying ldt files..."
deployldt >> $LOGFILE 2>> $LOGERR
echo "Deploying ldt files...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying ldt files...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy Workflow files
echo "Deploying workflows..." >> $LOGFILE 2>> $LOGERR
echo "Deploying workflows..."
deploywft >> $LOGFILE 2>> $LOGERR
echo "Deploying workflows...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying workflows...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy RTF LDT files
echo "Deploying RTF LDT Files..." >> $LOGFILE 2>> $LOGERR
echo "Deploying RTF LDT Files..."
deployrtfldt >> $LOGFILE 2>> $LOGERR
echo "Deploying RTF LDT Files...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying RTF LDT Files...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy RTF files
echo "Deploying RTF Files..." >> $LOGFILE 2>> $LOGERR
echo "Deploying RTF Files..."
deployrtf >> $LOGFILE 2>> $LOGERR
echo "Deploying RTF Files...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying RTF Files...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""

#call the function to deploy XML DataTemplate files
echo "Deploying XML Data Template Files..." >> $LOGFILE 2>> $LOGERR
echo "Deploying XML Data Template Files..."
deployxml >> $LOGFILE 2>> $LOGERR
echo "Deploying XML Data Template Files...Done" >> $LOGFILE 2>> $LOGERR
echo "Deploying XML Data Template Files...Done"
echo "" >> $LOGFILE 2>> $LOGERR
echo "Status $err"
echo ""


#add the logic to check the dependencies of objects that are being deployed
#how to differentiate the regular sql (create table, view, etc) files and sql concurrent program files

#check if the installation is success or failure
echo "" >> $LOGFILE 2>> $LOGERR
echo ""
if (( $err == 0 )); then
	echo "Installation completed Successfully. Log file $LOGFILE created." >> $LOGFILE 2>> $LOGERR
	echo "Installation completed Successfully. Log file $LOGFILE created."
else
	echo "Installation Failed. Check log file $LOGERR for errors." >> $LOGFILE 2>> $LOGERR
	echo "Installation Failed. Check log file $LOGERR for errors."
fi
echo "" >> $LOGFILE 2>> $LOGERR
echo ""

exit 0
