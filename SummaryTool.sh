#!/bin/bash

####################################################################################################
#
# Copyright (c) 2014, JAMF Software, LLC.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the JAMF Software, LLC nor the
#                 names of its contributors may be used to endorse or promote products
#                 derived from this software without specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
####################################################################################################
#
#	DESCRIPTION
#
#	This script was designed to read full JSS Summaries generated from version 9+.
#	The script will parse through the summary and return back a set of data that
#	should be useful when performing JSS Health Checks.
#
####################################################################################################
# 
#	HISTORY
#
#	Version 1.0 Created by Sam Fortuna on June 13th, 2014
#	Version 1.1 Updated by Sam Fortuna on June 17th, 2014
#		-Fixed issues with parsing some data types
#		-Added comments for readability
#		-Added output about check-in information
#		-Added database size parsing
#	Version 1.2 Updated by Nick Anderson August 4, 2014
#		-Added recommendations to some displayed items
#	Version 1.3 Updated by Nick Anderson on October 14, 2014
#		-Fixed the way echo works in some terminals
#	Version 1.4a Updated by Nick Anderson
#		-Check certificate expiration dates
#	Version 1.5 Updated by Sam Fortuna January 22, 2015
#		-Added check for 10+ criteria smart groups
#		-Simplified recommendations
#	Version 2.0 Updated by Sam Fortuna February 28, 2015
#		-Fixed an issue gathering ongoing update inventory policies
#		-Updated to support changes to 9.65 JSS Summaries
#	Version 2.1 Updated by Sam Fortuna March 24, 2015
#		-Added smart group counters
#		-Added log file location check
#	Version 2.2 Updated by Sam Fortuna May 26, 2015
#		-Fixed an issue parsing smart group names that included periods
#		-Added total criteria count to potentially problematic group identification
#		-Added VPP expiration output
#	Version 2.3 Updated by Nick Anderson March 15, 2019
#		- Some bug fixes and improvements
#	Version 2.4 Updated by Nick Rendulic September 25, 2023
#		- Various bug fixes and improvements in SSL, APNS and VPP parsing
#
####################################################################################################

# Check if a file was included on start
file="$1"
# Demand a valid summary
function newsummary {
	read -p "Summary Location: " file
}

while [[ "$file" == "" ]] ; do
	newsummary
done

clear
echo "--- Jamf Summary Parser 3.0 ---"

#Check to see what kind of terminal this is to make sure we use the right echo mode, no idea why some are different in this aspect
echotest=`echo -e "test"`
if [[ "$echotest" == "test" ]] ; then
	echomode="-e"
else
	echomode=""
fi

# Pull top 100 lines of the summary
t100=`head -n 100 "$file"`
# Pull 500 lines after "LDAP Servers"
middle_a=`cat "$file" | grep -A 500 "LDAP Servers"`
# Pull 500 lines after Checkin
middle_b=`cat "$file" | grep -A 500 "Check-In"`
# Pull last 500 for table entries
tables=`tail -n 500 "$file"`
# Set the date
todayepoch=`date +"%s"`


########################################################
# --- Server infrastructure

# Server OS
echo $echomode "Server OS: \t\t\t\t $(echo "$t100" | grep "Operating System" | awk '{for (i=3; i<NF; i++) printf $i " "; print $NF}')"
# JSS Version
echo $echomode "JSS Version: \t\t\t\t $(echo "$t100" | awk '/Installed Version/ {print $NF}')"
# Java version
echo $echomode "Java Version: \t\t\t\t $(echo "$t100" | awk '/Java Version/ {print $NF}')"

# MySQL Version
echo $echomode "MySQL Version: \t\t\t\t $(echo "$t100" | awk '/version ..................../ {print $NF}') $(echo "$t100" | awk '/version_compile_os/ {print $NF}')"
# Database driver
echo $echomode "MySQL Driver: \t\t\t\t $(echo "$t100" | awk '/Database Driver .................................../ {print $NF}')"
# Database server
echo $echomode "MySQL Server: \t\t\t\t $(echo "$t100" | awk '/Database Server/ {print $NF}')"
# Database name
echo $echomode "Database name: \t\t\t\t $(echo "$t100" | awk '/Database Name/ {print $NF}')"
# Database size
echo $echomode "Database Size: \t\t\t\t $(echo "$t100" | grep "Database Size" | awk 'NR==1 {print $(NF-1),$NF}')"
# Max pool size
echo $echomode "Max Pool Size:  \t\t\t $(echo "$t100" | awk '/Maximum Pool Size/ {print $NF}')"
# Max database connections
echo $echomode "Maximum MySQL Connections: \t\t $(echo "$t100" | awk '/Max Connections/ {print $NF}')"
# Max allowed packet
echo $echomode "Max Allowed Packet Size: \t\t $(($(echo "$t100" | awk '/Max Allowed Packet Size/ {print $NF}')/ 1048576)) MB"
# Binary logging
binlogging=`echo "$t100" | awk '/Binary Log/ {print $NF}'`
if [ "$binlogging" = "OFF" ] ; then
	echo $echomode "Bin Logging: \t\t\t\t $(echo "$t100" | awk '/Binary Log/ {print $NF}') \t$(tput setaf 2)✓$(tput sgr0)"
else
	echo $echomode "Bin Logging: \t\t\t\t $(echo "$t100" | awk '/Binary Log/ {print $NF}') \t$(tput setaf 9)[!]$(tput sgr0)"
fi
# MyISAM tables
echo $echomode "MyISAM Tables:  \t\t\t $(echo "$t100" | awk '/MyISAM Tables/ {print $NF}')"
# InnoDB tables
echo $echomode "InnoDB Tables:  \t\t\t $(echo "$t100" | awk '/InnoDB Tables/ {print $NF}')"
# Large tables
echo $echomode "Tables over 1 GB in size:"
largeTables=$(echo "$tables" | awk '/GB/ {print "\t", $(NF-1), $NF, "    ", $1}')
if [ "$largeTables" != "" ]; then
	echo $echomode "$largeTables"
else
	echo $echomode "\tNone \t$(tput setaf 2)✓$(tput sgr0)"
fi

# Tomcat version
echo $echomode "Tomcat Version: \t\t\t $(echo "$t100" | grep "Tomcat Version" | awk '/Tomcat Version ..................................../ {for (i=4; i<NF; i++) printf $i " "; print $NF}')"
# Webapp location
echo $echomode "Webapp location: \t\t\t $(echo "$t100" | grep "Web App Installed To" | awk '{for (i=5; i<NF; i++) printf $i " "; print $NF}')"
# Http threads
echo $echomode "HTTP Threads: \t\t\t\t $(echo "$middle_a" | awk '/HTTP Connector/ {print $NF}')"
# Https threads
echo $echomode "HTTPS Threads: \t\t\t\t $(echo "$middle_a" | awk '/HTTPS Connector/ {print $NF}')"

# SSL cert subject
ssl_subject=$(echo "$middle_a" | awk '/SSL Cert Subject/ {$1=$2=$3=""; print $0}')

if [[ ! "$ssl_subject" =~ "O=JAMF Software" ]]; then
    echo $echomode "SSL Certificate Subject: \t      $ssl_subject \t$(tput setaf 9)[!]$(tput sgr0)"
else
    echo $echomode "SSL Certificate Subject: \t      $ssl_subject"
fi

# SSL cert expiration
ssldate=$(echo "$middle_a" | awk '/SSL Cert Expires/ {print $NF}')

if [[ "$ssldate" != "Expires" ]] ; then
    if [[ "$ssldate" =~ ^[0-9]{4}/ ]]; then
        sslepoch=$(date -jf "%Y/%m/%d %H:%M" "$ssldate 00:00" +"%s")
    else
        sslepoch=$(date -jf "%m/%d/%y %H:%M" "$ssldate 00:00" +"%s")
    fi

    ssldifference=$(( sslepoch - todayepoch ))
    sslresult=$(( ssldifference / 86400 ))

    # If ssl is expiring in under 60 days
    if (( sslresult > 60 )) ; then
        echo $echomode "SSL Certificate Expiration: \t\t $ssldate \t$(tput setaf 2)$sslresult Days$(tput sgr0)"
    else
        echo $echomode "SSL Certificate Expiration: \t\t $ssldate \t$(tput setaf 9)$sslresult Days$(tput sgr0)"
    fi
else
    echo $echomode "SSL Certificate Expiration: \t\t $(tput setaf 9)Unreadable$(tput sgr0)"
fi


# Remote IP valve
echo $echomode "Remote IP Valve: \t\t\t $(echo "$middle_a" | awk '/Remote IP Valve/ {print $NF}')"
# Proxy port, scheme
proxyportcheck=`echo "$middle_a" | awk '/Proxy Port/ {print $NF}'`
if [[ "$proxyportcheck" != "................" ]] ; then
	echo $echomode "Proxy Port: \t\t\t\t $(echo "$middle_a" | awk '/Proxy Port/ {print $NF}') $(echo "$middle_a" | awk '/Proxy Scheme/ {print $NF}')"
else
	echo $echomode "Proxy Port: \t\t\t\t $(echo "Unconfigured")"
fi
# Clustering
cluster=`echo "$middle_a" | awk '/Clustering Enabled/ {print $NF}'`
if [[ "$cluster" == "true" ]] ; then
	echo $echomode "Clustering Enabled: \t\t\t $(echo "$middle_a" | awk '/Clustering Enabled/ {print $NF}') \t$(tput setaf 9)[!]$(tput sgr0)"
else
	echo $echomode "Clustering Enabled: \t\t\t $(echo "$middle_a" | awk '/Clustering Enabled/ {print $NF}')"
fi

# --- Management framework

# Address
echo $echomode "JSS URL: \t\t\t\t $(echo "$middle_a" | awk '/HTTPS URL/ {print $NF}')"


# Managed computers
echo $echomode "Managed Computers: \t\t\t $(echo "$t100" | head -n 50 | awk '/Managed Computers/ {print $NF}')"
# Managed iOS devices
echo $echomode "Managed Mobile Devices: \t\t $(echo "$t100" | awk '/Managed iOS Devices/ {print $NF}')"
# Managed Apple TVs
echo $echomode "Managed Apple TVs 10.2 or later: \t $(echo "$t100" | awk '/Managed Apple TV Devices \(tvOS 10.2 or later\)/ {print $NF}')"
echo $echomode "Managed Apple TVs 10.1 or earlier: \t $(echo "$t100" | awk '/Managed Apple TV Devices \(tvOS 10.1 or earlier\)/ {print $NF}')"

# Fetch the APNS date
apnsdate=$(echo "$middle_a" | grep -A 4 "Push Certificates" | grep Expires | awk '{print $2}')

# Convert it to unix epoch using bash's date utility
apnsepoch=$(date -jf "%Y/%m/%d %H:%M" "$apnsdate 00:00" +"%s")

# Use Python3 for calculations
read apnsdifference apnsresult <<< $(python3 -c "apnsepoch = $apnsepoch; todayepoch = $todayepoch; difference = apnsepoch - todayepoch; result = difference/86400; print(difference, round(result))")

# Decision based on the days remaining
if (( $apnsresult <= 60 )) ; then
    echo $echomode "APNS Expiration: \t\t\t $apnsdate \t$(tput setaf 9)$apnsresult Days$(tput sgr0)"
else
    echo $echomode "APNS Expiration: \t\t\t $apnsdate \t$(tput setaf 2)$apnsresult Days$(tput sgr0)"
fi

# Push notifications enabled
pushnotifications=`echo "$middle_b" | awk '/Push Notifications Enabled/ {print $NF}'`
if [ "$pushnotifications" = "true" ] ; then
	echo $echomode "Push Notifications enabled: \t\t $(echo "$middle_b" | awk '/Push Notifications Enabled/ {print $NF}')"
else
	echo $echomode "Push Notifications enabled: \t\t $(echo "$middle_b" | awk '/Push Notifications Enabled/ {print $NF}') \t$(tput setaf 9)[!]$(tput sgr0)"
fi
# Set current Unix epoch time
todayepoch=$(date +%s)

# Extract VPP expiration dates
vppdates=$(grep -A 100 "VPP Accounts" "$file" | awk '/Expiration Date/ {print $NF}')

if [[ -n $vppdates ]] ; then
    for i in $vppdates; do
        # Convert date to Unix epoch
        vppepoch=$(date -jf "%Y/%m/%d %H:%M" "$i 00:00" +"%s")
        
        # Calculate difference and convert to days
        vppdifference=$(( vppepoch - todayepoch ))
        vppresult=$(( vppdifference / 86400 ))

        # Check and print in appropriate color
        if (( vppresult > 60 )) ; then
            echo $echomode "VPP Token Expiration: \t\t\t $i \t$(tput setaf 2)$vppresult Days$(tput sgr0)"
        else
            echo $echomode "VPP Token Expiration: \t\t\t $i \t$(tput setaf 9)$vppresult Days$(tput sgr0)"
        fi
    done
fi


########################################################


#Find problematic policies that are ongoing, enabled, update inventory and have a scope defined
list=`cat "$file" | grep -n "Ongoing" | awk -F : '{print $1}'`

echo $echomode
echo $echomode "The following policies are Ongoing, Enabled and update inventory:"

for i in $list 
do

	#Check if policy is enabled
	test=`head -n $i "$file" | tail -n 13`
	enabled=`echo $echomode "$test" | awk /'Enabled/ {print $NF}'`
	
	#Check if policy has an active trigger
	if [[ "$enabled" == "true" ]]; then
		trigger=`echo $echomode "$test" | grep Triggered | awk '/true/ {print $NF}'`
	fi
		
	#Check if the policy updates inventory
	if [[ "$enabled" == "true" ]]; then
		line=$(($i + 40))
		inventory=`head -n $line "$file" | tail -n 15 | awk '/Update Inventory/ {print $NF}'`
	fi
		
	#Get the name and scope of the policy
	if [[ "$trigger" == *"true"* && "$inventory" == "true" && "$enabled" == "true" ]]; then
		scope=`head -n $(($i + 5)) "$file" |tail -n 5 | awk '/Scope/ {$1=""; print $0}'`
		name=`echo $echomode "$test" | awk -F '[\.]+[\.]' '/Name/ {print $NF}'`
		echo $echomode $(tput setaf 6)"Name: \t $name" $(tput sgr0)
		echo $echomode "Scope: \t $scope"
	fi
done

echo $echomode
echo $echomode "Ongoing at recurring check-in, but do not update inventory:"

for i in $list 
do
	#Check if policy is enabled
	test=`head -n $i "$file" | tail -n 13`
	enabled=`echo $echomode "$test" | awk /'Enabled/ {print $NF}'`
	
	#Check if policy is on the recurring trigger
	if [[ "$enabled" == "true" ]]; then
		recurring=`echo $echomode "$test" | awk '/Triggered by Check-in/ {print $NF}'`
	fi
		
	#Check if the policy updates inventory
	if [[ "$enabled" == "true" ]]; then
		line=$(($i + 40))
		inventory=`head -n $line "$file" | tail -n 15 | awk '/Update Inventory/ {print $NF}'`
	fi
	
	#Get the scope
	scope=`head -n $(($i + 5)) "$file" |tail -n 5 | awk '/Scope/ {$1=""; print $0}'`
		
	#Get the name of the policy
	if [[ "$recurring" == "true" && "$inventory" == "false" && "$enabled" == "true" ]]; then
		name=`echo $echomode "$test" | awk -F '[\.]+[\.]' '/Name/ {print $NF}'`
		echo $echomode $(tput setaf 6)"Name: \t $name" $(tput sgr0)
		echo $echomode "Scope: \t $scope"
	fi
done

#Count number of policies that update inventory once per day

list2=`cat "$file" | grep -n "Once every day" | awk -F : '{print $1}'`

#Create a counter
inventoryDaily=0

for i in $list2
do

	#Check if policy is enabled
	test=`head -n $i "$file" | tail -n 13`
	enabled=`echo $echomode "$test" | awk /'Enabled/ {print $NF}'`
	
	#Check if policy has an active trigger
	if [[ "$enabled" == "true" ]]; then
		trigger=`echo $echomode "$test" | grep Triggered | awk '/true/ {print $NF}'`
	fi
		
	#Check if the policy updates inventory
	if [[ "$enabled" == "true" ]]; then
		line=$(($i + 40))
		inventory=`head -n $line "$file" | tail -n 15 | awk '/Update Inventory/ {print $NF}'`
	fi
	
	
		
	#Increment count if all above criteria are true
	if [[ "$trigger" == *"true"* && "$inventory" == "true" && "$enabled" == "true" ]]; then
		let inventoryDaily=inventoryDaily+1
	fi
done

echo $echomode
echo $echomode "There are" $inventoryDaily "policies that update inventory daily."

#List smart group names that include 10 or more criteria

while read line
do
#Count current line number
let lineNumber=lineNumber+1

if [[ "${line}" == *"Smart Computer Groups"* ]]; then
	lineNumber=`cat "$file"  | awk '/Smart Computer Groups/{print NR; exit}'`
	echo $echomode $line":"
	groups=0
elif [[ "${line}" == *"Smart Mobile Device Groups"* ]]; then
	echo $echomode "$(tput setaf 8)Total number of smart groups: $groups$(tput sgr0)"
	echo $echomode
	echo $echomode $line":"
	groups=0
elif [[ "${line}" == *"User Groups"* ]]; then
	echo $echomode "$(tput setaf 8)Total number of smart groups: $groups$(tput sgr0)"
	echo $echomode
	echo $echomode $line":"
	groups=0
elif [[ "${line}" == *"Device Enrollment Program"* ]]; then
	echo $echomode "$(tput setaf 8)Total number of smart groups: $groups$(tput sgr0)"
fi

	#Start counting number of criteria per group
	if [[ "${line}" == *"Membership Criteria"* ]]; then
		counter=1
		let groups=groups+1
		
		#Check for nested groups
		if [[ "${line}" == *"member of"* ]]; then
			nested=1
		else
			nested=0
		fi
	
	#Increment for each criteria found
	elif [[ "${line}" == *"- and -"* || "${line}" == *"- or -"* ]]; then
		let counter=counter+1
		
		#Check for nested groups
		if [[ "${line}" == *"member of"* ]]; then
			let nested=nested+1
		fi
		
		if [ $nested -eq 4 ]; then
			lineName=$(($lineNumber-$counter-1))
			nestedName=$(head -n $lineName "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{print $NF}')
			if [[ "$nestedName" == *"Site "* ]]; then
				lineName=$(($lineNumber-$counter-2))
				nestedName=$(head -n $lineName "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{print $NF}')
			fi
		fi

		#Print the group names that have more than 10 criteria
		if [ $counter -eq 10 ]; then
			name=$(($lineNumber-11))
			groupName=$(head -n $name "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{print $NF}')
			if [[ "$groupName" == *"Site "* ]]; then
				name=$(($lineNumber-12))
				groupName=$(head -n $name "$file" | tail -n 1 | awk -F '[\.]+[\ ]' '{print $NF}')
			fi
		fi
	elif [[ "${line}" == *"==="* && $counter -ge 10 ]]; then
		if [ $nested -gt 3 ]; then
			echo $echomode "$(tput setaf 9)$counter criteria, $nested nested$(tput sgr0) \t\t $(tput setaf 6)$groupName"
			counter=1
			nested=0
		else
			echo $echomode "$(tput setaf 9)$counter criteria,$(tput sgr0) $nested nested \t\t $(tput setaf 6)$groupName"
			counter=1
		fi
	elif [[ "${line}" == *"==="* && $nested -gt 3 && $counter -lt 10 ]]; then
		echo $echomode "$(tput sgr0)$counter criteria, $(tput setaf 9)$nested nested$(tput sgr0) \t\t $(tput setaf 6)$nestedName "
		nested=0
	fi
done < "$file"

exit 0
