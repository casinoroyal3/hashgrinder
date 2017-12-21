#!/bin/bash
#
# Hash Grinder   by adv		# Based on Hashcat Wiki pages and forum http://hashcat.net/forum/thread-277.html
# 
# Designed for oclHashcat-1.33
# Date:	2015 may 11

## -------------------- OUTPUT COLORS -------------------- ##
UL_GREEN='\033[04;92m'
UL_YELLOW='\033[04;93m'
BK_YELLOW='\033[05;93m'
BG_BLUE='\033[44m'
BG_UL_BLUE='\033[04;44m'
BG_UL_YELLOW='\033[04;33m'
BG_GREEN='\033[42m'
GREEN='\033[04;42m'
RED='\033[0;31m'
YELLOW='\033[00;93m'
NC='\033[0m'             # Reset Color

## -------------------- MANIFEST -------------------- ##
VERSION='4.1'
MANIFEST=$(echo -e "${BG_BLUE}                ${NC}\n${BG_UL_BLUE}Hash Grinder $VERSION${NC}\n${BG_BLUE}                ${NC}")


## -------------------- GET SCRIPT PATH -------------------- ##
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


## -------------------- SOURCE CONFIG FILE -------------------- ##
if [ -e $SCRIPT_PATH/soclhc.$(hostname -f).conf ]
then
		#source "/cracking/scripts/soclhc.$(uname -n | cut -d. -f1).conf"
        source $SCRIPT_PATH/soclhc.$(hostname -f).conf
else
	echo "$MANIFEST"
	echo -e "\n${RED}Unable to find the config file soclhc.$(hostname -f).conf. It's going to exit${NC}\n"
	
	exit 1;
fi

if [ ! -x ${OCLHASHCAT} ]
then
	echo -e "\n${RED}Unable to find oclHashcat in $OCLHASHCAT.\nVerify directory or binary path in config file soclhc.$(hostname -f).conf${NC}\n"

	exit 1;
fi


## -------------------- CMD LINE ARGUMENTS ASSIGNMENT -------------------- ##
INPUT_FILE=$1
WLDIR=$2


## -------------------- VERIFY ARGUMENTS -------------------- ##
if [ $# -ne 2 ]
then
    ## -------------------- HELP -------------------- ##
	echo "$MANIFEST"
	echo -e "\nUsage: $0 <hashfile> <dirwordlist>\n"
	echo -e "Example: $0 $BASEPATH/hash/myhash.hash $BASEPATH/wordlist/one\n"
	exit -1
else
    ## -------- OUTPUT PATH AND FILENAME GENERATION FROM SOURCE HASH FILE ---------- ##
	HASHFILENAME=$(basename $INPUT_FILE)
	HASHPATH=$(dirname $INPUT_FILE)
	HCPOTFILE="${HASHFILENAME%.*}"
	OUTPUT_FILE="$HASHPATH/$HCPOTFILE.hcpot"
	#POT_FILE="--outfile=$OUTPUT_FILE"
	
	if [ $USERNAME == 1 ]
	then
		USR='--username'
	else
		USR=''
	fi
	## -------------------- SHOW MOST SUPPORTED HASH -------------------- ##
    #echo -e "$SAMPLE_HASHES"
fi

## -------------------- CHK SCREEN SESSION -------------------- ##
if ! screen -list | grep -iq "$HCPOTFILE"; then
	echo -e "\n${YELLOW}No $HCPOTFILE screen session found.\nSet $HCPOTFILE screen session on[1]. Default off[0]:${NC}"
	
	read SCREEN_SESSION
	SCREEN_SESSION=${SCREEN_SESSION:-0}	
	
	if [ $SCREEN_SESSION -eq 1 ]; then
		screen -S $(echo $HCPOTFILE | tr '[a-z]' '[A-Z]') $0 $INPUT_FILE $WLDIR
		
		exit 1;
	fi
fi

## -------------------- INTERUPT HANDLING (CTRL+C) -------------------- ##
trap bashtrap INT

function bashtrap(){
	echo -e "\n${RED}Getting hit CTRL+C going to close everything up${NC}\n"
	pwdwipe
	
	exit 1;
}

## -------------------- WORDLIST ARRAY -------------------- ##

if [ -d $WLDIR ]; then

	#WLST_ARRAY=($(ls -1rS "$WLDIR"*.*))
	WLST_ARRAY=($(ls -1rS "$WLDIR"* | sort))

elif [ -r $WLDIR ]; then

	WLST_ARRAY[0]=${WLDIR}

else

	echo -e "\n${RED}Wordlist not found. Using the default wordlist file in config file.${NC}\n"

fi


## -------------------- INPUT HASH TYPE -------------------- ##

echo -n "Hash Mode (MD5 default)[0]:"

read HASH_MODE
HASH_MODE=${HASH_MODE:-0}

## -------------------- INPUT ATTACKS LIST -------------------- ##

echo -n "Turn on[1] or off[0] the seven attack modes: Straight, Mask, Rules, Combine Rules, Combinator Dict, Hybrid, Brute. Default[1010010]:"
read ATTACK_MODE
ATTACK_MODE=${ATTACK_MODE:-1010010}

i=0
while [ $i -lt 7 ]
	do
		digit[${i}]=${ATTACK_MODE:${i}:1}
		((i +=1))
done

WORDLIST=${digit[0]}
MASK=${digit[1]}
RULES=${digit[2]}
CRULES=${digit[3]}
COMBINATOR=${digit[4]}
HYBRID=${digit[5]}
BRUTEFORCE=${digit[6]}

## -------------------- STORE TOTAL HASH NUMBER -------------------- ##

TOTAL_INPUT_HASH=$(wc -l < $INPUT_FILE)

## -------------------- MAIN FUNCTION -------------------- ##

OCLHCFLAGS="\
--session=$HASHPATH/$HCPOTFILE \
--workload-profile=3 \
--gpu-temp-retain=75 \
--hash-type=$HASH_MODE \
--remove"

function grind(){
	
	$OCLHASHCAT $OCLHCFLAGS $INPUT_FILE $@ 
	
	if [ -s $OUTPUT_FILE ]
	then
		pwdstats
		#attackpwdwipe
	fi
	
	if [ $TOTAL_INPUT_HASH -eq 0 ]
	then
		echo -e "\nAll your hashes have been recovered, see $OUTPUT_FILE\n"
		pwdstats
		pwdwipe
		
		head -10 $OUTPUT_FILE

		exit
	fi
}

## -------------------- STATS ON RECOVERED HASH -------------------- ##
function pwdstats(){

	TOTAL_INPUT_HASH=$(wc -l < $INPUT_FILE)
	LINES_OUTPUT_FILE=$(wc -l < $OUTPUT_FILE)

	if [ $TOTAL_INPUT_HASH -gt $LINES_OUTPUT_FILE ]
	then
		TOTAL_INPUT_HASH=$(wc -l < $INPUT_FILE)
	else
		TOTAL_INPUT_HASH=$(($TOTAL_INPUT_HASH+$LINES_OUTPUT_FILE))
	fi

	PERC=$(echo "scale=2; $LINES_OUTPUT_FILE*100/$TOTAL_INPUT_HASH" | bc -l)
	echo
	echo "+-----------------------------------+"
	echo -e "| ${UL_YELLOW}Total Hashes:${NC}               $TOTAL_INPUT_HASH "
	echo "+-----------------------------------+"
	echo -e "| ${UL_GREEN}Total Cracked:${NC}              $LINES_OUTPUT_FILE "
	echo "+-----------------------------------+"
	echo -e "| ${UL_GREEN}Total Cracked Percentange:${NC}  $PERC% "
	echo "+-----------------------------------+"
	echo
	sleep 1
}


## -------------------- CLEAN RECOVERED HASH -------------------- ##
function pwdwipe(){

	OUTPUT_CLEANFILE="$HASHPATH/$HCPOTFILE.clean"	
	
	if [ -s $OUTPUT_FILE ]
	then	
		echo -e "\n${BK_YELLOW}...saving full attack stage password${NC}\n"
		echo

		awk -F":" '{print $NF}' $OUTPUT_FILE | sort -u > $OUTPUT_CLEANFILE
	fi
}

## -------------------- CLEAN RECOVERED HASH -------------------- ##
function attackpwdwipe(){

	OUTPUT_CLEANFILE=$HASHPATH/$HCPOTFILE"_$ATTACK_NAME.clean"
	PARTIAL_CRACKED_HASH=$(($HASHFILE_BFR-$HASHFILE_AFT))
	
	if [ $PARTIAL_CRACKED_HASH -ge 1 ]
	then
		if [ -e $OUTPUT_CLEANFILE ]; then
            echo -e "\n${BK_YELLOW}...saving stage password${NC}\n"
            #tail -n $PARTIAL_CRACKED_HASH $OUTPUT_FILE | cut -d':' -f2 | sort -u >> $OUTPUT_CLEANFILE
            tail -n $PARTIAL_CRACKED_HASH $OUTPUT_FILE | awk -F":" '{print $NF}' | sort -u >> $OUTPUT_CLEANFILE
		else
            echo -e "\n${BK_YELLOW}...saving stage password${NC}\n"
            #tail -n $PARTIAL_CRACKED_HASH $OUTPUT_FILE | cut -d':' -f2 | sort -u > $OUTPUT_CLEANFILE
            tail -n $PARTIAL_CRACKED_HASH $OUTPUT_FILE | awk -F":" '{print $NF}' | sort -u > $OUTPUT_CLEANFILE
		fi
	fi
	ATTACK_NAME=""
}


## -------------------- INIT OUTPUT FILE -------------------- ##
function attackout(){
	if [ -s $OUTPUT_FILE ]
	then
		NOW=$(date +"%Y%m%d%H%M%S")
		cp -f $OUTPUT_FILE $OUTPUT_FILE.$NOW
	fi
}


## -------------------- WORDLIST ATTACKS -------------------- ##
function oclhcWordlist() {

    echo "$MANIFEST"
	echo -e "\n${UL_GREEN}Running STRAIGHT attacks${NC}\n"
	HASHFILE_BFR=$(wc -l < $INPUT_FILE)
	
	for WLST in ${WLST_ARRAY[@]}
		do	
		grind -a 0 $USR $WLST --outfile=$OUTPUT_FILE
	done
	
	HASHFILE_AFT=$(wc -l < $INPUT_FILE)
	ATTACK_NAME="wordlist"
	attackpwdwipe $ATTACK_NAME
}


## -------------------- MASK ATTACKS -------------------- ##
function oclhcMask() {

    echo "$MANIFEST"
	echo -e "\n${UL_GREEN}Running MASK attacks${NC}\n"
	HASHFILE_BFR=$(wc -l < $INPUT_FILE)
	
	for MASK in $(echo $MASKS_LIST)
		do	
		grind -a 3 $USR --outfile=$OUTPUT_FILE $MASK
	done
	
	HASHFILE_AFT=$(wc -l < $INPUT_FILE)
	ATTACK_NAME="mask"
	attackpwdwipe $ATTACK_NAME
}


## -------------------- COMBINATOR ATTACKS -------------------- ##
function oclhcCombinator() {

    echo "$MANIFEST"
	echo -e "\n${UL_GREEN}Running COMBINATOR attacks${NC}\n"
	HASHFILE_BFR=$(wc -l < $INPUT_FILE)
	
	for WLST in ${WLST_ARRAY[@]}
		do	
		grind -a 1 $USR $WLST $WLST --outfile=$OUTPUT_FILE
		grind -a 1 $USR $WLST $WLST --rule-left='l$-' --outfile=$OUTPUT_FILE
	done
	
	HASHFILE_AFT=$(wc -l < $INPUT_FILE)
	ATTACK_NAME="combinator"
	attackpwdwipe $ATTACK_NAME
}

## -------------------- RULES ATTACKS -------------------- ##
function oclhcRules() {

    echo "$MANIFEST"
	echo -e "\n${UL_GREEN}Running RULES attacks${NC}\n"
	HASHFILE_BFR=$(wc -l < $INPUT_FILE)
	
	for WLST in ${WLST_ARRAY[@]}
		do
		for cRule in "$HCRULES"/*.rule
			do
			grind -a 0 $USR $WLST -r $cRule --outfile=$OUTPUT_FILE
		done
    done
    
	HASHFILE_AFT=$(wc -l < $INPUT_FILE)
	ATTACK_NAME="rules"
	attackpwdwipe $ATTACK_NAME
}


## -------------------- COMBINED RULES ATTACKS -------------------- ##
function oclhcCrules() {

    echo "$MANIFEST"
	echo -e "\n${UL_GREEN}Running COMBINED-RULES attacks${NC}\n"
	HASHFILE_BFR=$(wc -l < $INPUT_FILE)

	for WLST in ${WLST_ARRAY[@]}
		do
		# Load the rules' array from config file in a single variable RULES_ARRAY
		for CRULES in $(echo $RULES_ARRAY)
			do      
			for CRULES1 in $(echo $RULES_ARRAY)
				do
				grind -a 0 $USR $WLST -r $HCRULES/$CRULES -r $HCRULES/$CRULES1 --outfile=$OUTPUT_FILE
			done
		done
	done
	
	HASHFILE_AFT=$(wc -l < $INPUT_FILE)
	ATTACK_NAME="combined-rules"
	attackpwdwipe $ATTACK_NAME
}


## -------------------- HYBRID ATTACKS -------------------- ##
function oclhcHybrid() {

    echo "$MANIFEST"
	echo -e "\n${UL_GREEN}Running HYBRID attacks${NC}\n"
	HASHFILE_BFR=$(wc -l < $INPUT_FILE)

	for WLST in ${WLST_ARRAY[@]}
		do
		grind -a 6 $USR $HYBRID_CSET $WLST $HYBRID_MASK --increment --outfile=$OUTPUT_FILE		# append
		grind -a 7 $USR $HYBRID_CSET $HYBRID_MASK $WLST --increment --outfile=$OUTPUT_FILE		# prepend
	done
	
	HASHFILE_AFT=$(wc -l < $INPUT_FILE)
	ATTACK_NAME="hybrid"
	attackpwdwipe $ATTACK_NAME
}


## -------------------- BRUTEFORCE ATTACKS -------------------- ##
function oclhcBrute() {

    echo "$MANIFEST"
	echo -e "\n${UL_GREEN}Running BRUTEFORCE attacks with customs character set${NC}\n"
	HASHFILE_BFR=$(wc -l < $INPUT_FILE)

	#MASK11="?1?1?1?1?1?1?1?1?1?1?1"			# csetarr[0-1] takes till 111 days @ SHA-1
	#MASK12="?1?1?1?1?1?1?1?1?1?1?1?1"			# csetarr[2-4] takes > 20 years @ SHA-1

	for X in ${!csetarr[*]}
		do
        if [ $X -le 1 ]
        then
			#echo -e "${UL_GREEN}csetarr:" ${csetarr[$X]}${NC}"
            grind -a 3 $USR ${csetarr[$X]} $MASK10 --increment --outfile=$OUTPUT_FILE
        else
			#echo -e "${UL_GREEN}csetarr:" ${csetarr[$X]}${NC}"
            grind -a 3 $USR ${csetarr[$X]} $MASK9 --increment --outfile=$OUTPUT_FILE
        fi
	done
	
	HASHFILE_AFT=$(wc -l < $INPUT_FILE)
	ATTACK_NAME="bruteforce"
	attackpwdwipe $ATTACK_NAME
}

## -------------------- RUN FUNCTION ATTACKS -------------------- ##

if [ $WORDLIST -eq 1 ]; then
	oclhcWordlist
fi
if [ $MASK -eq 1 ]; then
	oclhcMask
fi
if [ $COMBINATOR -eq 1 ]; then
	oclhcCombinator
fi
if [ $RULES -eq 1 ]; then
	oclhcRules
fi
if [ $CRULES -eq 1 ]; then
	oclhcCrules
fi
if [ $HYBRID -eq 1 ]; then
	oclhcHybrid
fi
if [ $BRUTEFORCE -eq 1 ]; then
	oclhcBrute
fi

# --------------------------------------------------------------------------------------------------------- #