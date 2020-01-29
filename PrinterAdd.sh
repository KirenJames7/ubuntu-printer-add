#!/bin/bash
#----AUTHOR:----------Kiren James
#----CONTRIBUTORS:----Kiren James
#
# ===================================================================
# CONFIG - Only edit the below lines to setup the script
# ===================================================================
#
# Domain controller settings
COMPANY_NAME="Zone24x7"
DOMAIN_NAME="zone24x7.lk"
DC_SERVER="ldap://ZONEDC01.${DOMAIN_NAME}:389"
PRINTER_SERVER="inf-printer-srv"
#
# Printer list --note - edits should remain in order - use `lpinfo -m | grep "<Printer Name without PS|PCL6>"` to find ppd manually recomended
printers=("Nawala Ground Printer" "Nawala First Printer" "Nawala Second Printer" "Nawala Third Printer" "Nawala Operations Printer" "Nawala Accounts Printer" "Nawala Accounts Printer 2" "Kotte Ground Printer" "Kotte First Printer")
uris=("Printer%40Ground%24" "Printer%40First%24" "Printer%40Second%24" "Printer%40Third%24" "Printer%40Operations%24" "Printer%40Account%24" "Printer%40Accounts2%24" "Printer%40KotteGround%24" "Printer%40KotteFirst%24")
ppds=("postscript-hp:0/ppd/hplip/HP/hp-laserjet_pro_m201_m202-ps.ppd" "postscript-hp:0/ppd/hplip/HP/hp-laserjet_pro_m402_m403-ps.ppd" "postscript-hp:0/ppd/hplip/HP/hp-laserjet_pro_m402_m403-ps.ppd" "postscript-hp:0/ppd/hplip/HP/hp-laserjet_pro_m201_m202-ps.ppd" "postscript-hp:0/ppd/hplip/HP/hp-color_laserjet_pro_m252-ps.ppd" "foomatic-db-compressed-ppds:0/ppd/foomatic-ppd/Toshiba-e-Studio_2500c-Postscript.ppd" "postscript-hp:0/ppd/hplip/HP/hp-laserjet_pro_m402_m403-ps.ppd" "foo2zjs:0/ppd/foo2zjs/HP-LaserJet_1022n.ppd" "postscript-hp:0/ppd/hplip/HP/hp-laserjet_pro_m201_m202-ps.ppd")
#
# ANSI color codes
COLOR_OFF='\033[0m'
LIGHT_YELLOW='\033[0;93m'
LIGHT_RED='\033[0;91m'
CYAN='\033[0;36m'
#
# ===================================================================
# DO NOT EDIT BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING
# ===================================================================
#
# FUNCTIONS START HERE

function installPrerequisites {
	dpkg -s ldap-utils dialog python3-smbc smbclient &> /dev/null
	if [ $? -eq 1 ]; then
		echo "${LIGHT_YELLOW}Installing packages... Please wait.${COLOR_OFF}"
		dpkg -s ldap-utils &> /dev/null
		if [ $? -eq 1 ]; then
			echo ${password} | sudo -S apt-get -qq install ldap-utils > /dev/null
		fi
		dpkg -s dialog &> /dev/null
		if [ $? -eq 1 ]; then
			echo ${password} | sudo -S apt-get -qq install dialog > /dev/null
		fi
		dpkg -s python3-smbc &> /dev/null
		if [ $? -eq 1 ]; then
			echo ${password} | sudo -S apt-get -qq install python3-smbc > /dev/null
		fi
		dpkg -s smbclient &> /dev/null
		if [ $? -eq 1 ]; then
			echo ${password} | sudo -S apt-get -qq install smbclient > /dev/null
		fi
		echo "${LIGHT_YELLOW}Instalation complete.${COLOR_OFF}"
	fi
}

function addUserToPrinterGroup {
	if [ -z ${currentuser} ]; then
		currentuser=`whoami`
	fi
	echo ${password} | sudo -S usermod -a -G lpadmin ${currentuser}
}

function checkPrinterGroup {
	lpadmin=`grep lpadmin /etc/group | grep -o ${currentuser}`
	if [ -z ${lpadmin} ]; then
		addUserToPrinterGroup
	fi
}

function promptUserPassword {
	# Prompt for user password
	read -s -p "your domain password: " password
	echo
}

function userPasswordCheck {
	# Check input user password & continue script on success or propmt user password on fail
	ldapwhoami -x -H ${DC_SERVER} -D "${currentuser}@${DOMAIN_NAME}" -w "${password}" -n 2> /dev/null && echo
	if [ $? -eq 255 ]; then
		 echo ${LIGHT_RED}Domain unreachable, please check network and try again
		 echo Exiting...${COLOR_OFF}
		 exit 1
	fi
	if [ $? -eq 49 ]; then
		 echo (${LIGHT_RED}Incorrect password, please try again.${COLOR_OFF} && promptUserPassword)
	fi
	
}

function addPrinters {
	if [ -z ${password} ]; then
		promptUserPassword
		userPasswordCheck
	fi
	cmd=(dialog --separate-output --title "${COMPANY_NAME} | Printers" --ok-label "Add" --visit-items --checklist "Select the Printers you wish to to add: \n\nUse arrow keys or numbers to navigate, 'Sapce' to select, 'Enter' to confirm selection." 20 60 16)
	# any option can be set to default to "on"
	for printer in ${!printers[@]}
	do
		options+=($((printer+1)) "${printers[$printer]}" off)
	done
	choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
	clear
	for choice in $choices
	do
		case $choice in
			$choice)
				echo "${LIGHT_YELLOW}Installing ${printers[$((choice-1))]}..."
				lpadmin -p "${printers[$((choice-1))]//[[:blank:]]/}" -v "smb://${currentuser}@${DOMAIN_NAME}:${password}@${PRINTER_SERVER}/${uris[$((choice-1))]}" -o auth-info-required=username,password -o printer-is-shared=false -o PageSize=A4 -m "${ppds[$((choice-1))]}" -L "${printers[$((choice-1))]// Printer/}" -E
				;;
		esac
		echo "Done"
	done
	echo "Successfully added selected printers.${COLOR_OFF}"
}

function addPrinterAddToBashRC {
	# Add function to use in terminal in future
	# Check if command already exists
	bashrc=`cat ~/.bashrc | grep -o printeradd`
	if [ -z ${bashrc} ]; then
		echo "Installing as command for future use..."
		# Promt user for sudo password
		# read -s -p "Enter sudo password: " password
		# Copy script to local directory
		echo ${password} | sudo -S cp ${PWD}/PrinterAdd.sh /opt/PrinterAdd.sh
		# Make file executable
		sudo chmod +x /opt/PrinterAdd.sh
		echo >> ~/.bashrc
		# Add command to cli
		echo "alias printeradd='/opt/PrinterAdd.sh'" >> ~/.bashrc
		# Reset the shell to use this command immediately
		. ~/.bashrc
		
		echo "Successfully installed as command for future use. Run the command printeradd."
		echo "${CYAN}Exiting...${COLOR_OFF}"
		bash -c 'exec bash'
	fi
}

function continueScript {
	installPrerequisites
	checkPrinterGroup
	addPrinters
	addPrinterAddToBashRC
}

function promptSudoerPassword {
	# Prompt for sudoer password
	read -s -p "sudo password: " password
	echo
}

function sudoerPasswordCheck {
	# Check input sudoer password & continue script on success or propmt sudoer password on fail
	echo ${password} | sudo -S true 2>/dev/null && continueScript || (echo "${LIGHT_RED}Incorrect password, please try again${COLOR_OFF}" && promptSudoerPassword)
}

function currentUserSudoerCheck {
	currentuser=`whoami`
	sudoer=`getent group sudo | grep -o ${currentuser}`
	if [ -z ${sudoer} ]; then
		echo "${LIGHT_RED}Current user does not have sudo priviledges. Exiting script.${COLOR_OFF}"
		exit 1
	else
		sudoerCheck
	fi
}

function sudoerCheck {
	# Check if terminal has sudo privileges
	if sudo -n true 2>/dev/null; then
		# Continue script
		continueScript
	else
		# Prompt for sudoer password
		promptSudoerPassword
		sudoerPasswordCheck
	fi
}

# Script begins here
currentUserSudoerCheck
