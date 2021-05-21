#!/bin/bash

#This script is a template to grab the email addresses for users in a particular Computer Group within Jamf and create a CSV from them

jamfURL=""
authorization=""
#Specify the Computer Group Number
ID=""
#Specify the output file for the CSV
outputFile="/path/to/output.csv"

#Obtain computer IDs for computers in Jamf Pro from the Smart Group
computerIDs=$( /usr/bin/curl -s \
--header "authorization: Basic $authorization" \
--header "Accept: text/xml" \
--request GET \
$jamfURL/computergroups/id/$ID | xmllint --xpath '/computer_group/computers' - | xmllint --format - | awk -F '[<>]' '/<id>/{print $3}' )

for computerID in $computerIDs;do
	specificID=$(/usr/bin/curl -s \
	--header "authorization: Basic $authorization" \
	--header "Accept: text/xml" \
	--request GET \
	$jamfURL/computers/id/$computerID )
	userEmail=$( echo $specificID | xmllint --xpath '/computer/location/email_address/text()' - )
	
	if [[ ! -e $outputFile ]];then
		touch $outputFile
	fi
	#Check the output file to see if email is already listed, if so, skip it
	DuplicateCheck=$( cat $outputFile | grep "$userEmail" )
	if [[ -z $DuplicateCheck ]];then
		echo $userEmail", " >> $outputFile
	fi
done
