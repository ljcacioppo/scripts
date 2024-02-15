#!/bin/bash

#This script is a template to grab the email addresses for users in a particular Computer Group within Jamf and create a CSV from them

# Define Variables
jamfProURL=""
client_id=""
client_secret=""
#Specify the Computer Group Number
ID=""
#Specify the output file for the CSV
outputFile="/path/to/output.csv"

getAccessToken() {
	response=$(curl --silent --location --request POST "${jamfProURL}/api/oauth/token" \
		--header "Content-Type: application/x-www-form-urlencoded" \
		--data-urlencode "client_id=${client_id}" \
		--data-urlencode "grant_type=client_credentials" \
		--data-urlencode "client_secret=${client_secret}")
	access_token=$(echo "$response" | plutil -extract access_token raw -)
	token_expires_in=$(echo "$response" | plutil -extract expires_in raw -)
	token_expiration_epoch=$(($current_epoch + $token_expires_in - 1))
}

checkTokenExpiration() {
	current_epoch=$(date +%s)
	if [[ token_expiration_epoch -ge current_epoch ]]
	then
		echo "Token valid until the following epoch time: " "$token_expiration_epoch"
	else
		echo "No valid token available, getting new token"
		getAccessToken
	fi
}

invalidateToken() {
	responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${access_token}" $jamfProURL/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
	if [[ ${responseCode} == 204 ]]
	then
		echo "Token successfully invalidated"
		access_token=""
		token_expiration_epoch="0"
	elif [[ ${responseCode} == 401 ]]
	then
		echo "Token already invalid"
	else
		echo "An unknown error occurred invalidating the token"
	fi
}

#generate a Bearer Token and set it as a variable
checkTokenExpiration

#Obtain computer IDs for computers in Jamf Pro from the Smart Group
computerIDs=$( /usr/bin/curl -s \
--header "authorization: Bearer $access_token" \
--header "Accept: text/xml" \
--request GET \
$jamfProURL/computergroups/id/$ID | xmllint --xpath '/computer_group/computers' - | xmllint --format - | awk -F '[<>]' '/<id>/{print $3}' )

for computerID in $computerIDs;do
	specificID=$(/usr/bin/curl -s \
	--header "authorization: Bearer $access_token" \
	--header "Accept: text/xml" \
	--request GET \
	$jamfProURL/computers/id/$computerID )
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

#Invalidate Token
invalidateToken 

