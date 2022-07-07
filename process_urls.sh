#!/bin/bash

# Bash script for automatically viewing, storing, and processing urls

# Open Firefox with 10 random Wikipedia sites from list.txt. 
# Add 10 new sites from databse to Firefox each time you hit ENTER.
# Add lines (websites) pasted to the screen to the list file, with timestamp.
# Remove any duplicate websites, or non-web site lines at the end, utilizing sed.
# Add a hidden backup file (with timestamp in file name) at app exit.
# Delete backups older than 3 days.
# Inlcude summary at app close containing total and new websites added.


#===============================================================================
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Constants %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#===============================================================================
# User sets these two vars
PARENT_DIR="/home/kai/Desktop/mod"  # File path location
FNAME="list.txt"  # Name of file with list of sites

#===============================================================================
FILE_PATH="${PARENT_DIR}/${FNAME}"  # Name of the file only
CLEAN_LIST_TEMP="${PARENT_DIR}/.${FNAME}.CLEAN_LIST_TEMP"  # URLs only
#NUMBERED_LIST_TEMP="${PARENT_DIR}/.${FNAME}.NUMBERED_LIST_TEMP"

BATCH_SIZE=10  # Number of new tabs to add to browser
BORDER_CHAR='='  # Border

# Backup main file
TAG="AUTO_BACKUP"
TIMESTAMP=$(date +'%m%d%y_%0l%M%p')  # 100720_0906AM

# Keep only lines that begin with htttps, remove leading and trailing spaces.
# Used to create the TEMP file from which random sites are drawn.
SED_1="/^\s*https/s/\s*//p"


#===============================================================================
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#===============================================================================
# Print a line of dashes (or some other char) as border
function print_border() {

    local char="$1"
    for i in {1..80}; do echo -n "$char"; done
    echo
}

# Inserts a line with a timestamp before adding any new sites to main file
function insert_timestamp() {

	# separator after date
	sep='============================'

    # date_and_time=$(date +'DATE: %c')  # DATE: Thu 10 Feb 2022 03:01:08 PM CST
    date_and_time=$(date +'DATE: %^b_%d_%Y_%I%p')  # DATE: FEB_13_2022_05PM
    
	# Append timestamp to file and print to stdout
    #echo -e "\n${date_and_time}" |tee -a $FILE_PATH
    
    # Append timestamp to file only
    # ============================ DATE: JUL_07_2022_03PM ============================
    echo "${sep} ${date_and_time} ${sep}" >> $FILE_PATH
}


# Backup list of URLs, create a temp file containing only URLs
function backup_list() {

    # Backup main list
    # "dh_all" -> ".dh_all.100720_1022AM.AUTO_BACKUP"
    cp "$FILE_PATH" "${PARENT_DIR}/.${FNAME}.${TIMESTAMP}.${TAG}"

    # Keep only lines with valid websites, overwrite original file
    # sed -rni "$SED_1" $FILE_PATH

    # Filter out lines that do not start with "https," remove whitespace, and
    # create a new temp file ".file.CLEAN_LIST_TEMP" to pull URLs from
    sed -rn "$SED_1" < $FILE_PATH > $CLEAN_LIST_TEMP

    # Remove duplicates without sorting the lines, then save changes
    # /dev/null ensures file contents are not erased. Insteresting solution.
    (cat -n)< $CLEAN_LIST_TEMP | sort -uk2 | sort -n | cut -f2- |
    tee &>/dev/null $CLEAN_LIST_TEMP
}

# Clean up file, backup, print exit message
function clean_up() {

	# Removes leading and trailing spaces from lines containing https, then prints
	# only lines containing https, DATE, =====, and empty lines. Used to beautify.
	sed -ni "/^\s*https/s/\s*//; /https/p ; /DATE/p; /^$/p; /$BORDER_CHAR/p" $FILE_PATH

	# If there's a date without body text, it removes it (superfluous)
	# sed -ri -e '/./{H;$!d} ; x ; ' -e "s/DATE.*\n$BORDER_CHAR+$//;" $FILE_PATH

	# Delete more than one empty lines i.e. one empty line max
	sed -i '/^$/N;/^\n$/D' $FILE_PATH
	
	# Removes non sorted duplicate lines (to avoid using uniq)
	awk '!seen[$0]++' $FILE_PATH > .tmp
	cat .tmp > $FILE_PATH && rm .tmp
	
	# Adds a newline before every date line i.e. starting with =
	sed -i 's/^=/\n=/' $FILE_PATH

} 


function main () {
    
new_URLs=0
is_date_added=false
total_urls=$(wc -l < ${CLEAN_LIST_TEMP})  # Number of lines in list file
    
# MAIN LOOP
while true; do

    # Print menu options
    echo -e "Paste URL and press ENTER to add it to file.\
	\nPress ENTER to open 10 random sites on Firefox, or Q to exit.\n"

    # Save user input to variable user_input
    read user_input

    # MAIN MENU
    if [[ $user_input == ['q':-'Q'] ]]; then  # Exit program if "Q"
        break  # exit loop

    elif [[ $user_input == '' ]]; then  # Open 10 random sites if "ENTER"

        # Generate random numbers depending on the desired batch size
        for rand in $(shuf -i 1-$total_urls -n $BATCH_SIZE); do
            #echo "--> rand = $rand"  # DEBUG

            # Select line number that matches randomly generated number
            sed -rn "/^\s*$rand\s+/p" <(cat -n $CLEAN_LIST_TEMP) |
            while read i URL; do
                # Separate process by creating new subshell with (cmd)
                # Execute process in backgrounded immediately using &
                # Silence command with </dev/null &>/dev/null
                (firefox $URL </dev/null &>/dev/null) &

                # Delete line that was just used, to avoid using same site twice
                sed -i "${i}d" $CLEAN_LIST_TEMP
            done

        done

    else  # If user PASTE line + ENTER, append it to main file
		
		# Insert timestamp into file when adding the first URL per reading session
		if [[ $is_date_added == false ]]; then
			insert_timestamp
			is_date_added=true
		fi
		
        # Print new site to stdout and add it to the file
        echo $user_input >> "${FILE_PATH}"

        # Increment line count by one
        ((total_urls+=1))
        # Increment the count of new URLs added
        ((new_URLs+=1))

        # Print the last 10 lines of the list
        #echo; cat -n "${FILE_PATH}" | tail; echo

        # Print new line count
        echo -e "Added! Total lines: $total_urls\n"
    fi
    
# Print border
print_border "$BORDER_CHAR"

done

}

#===============================================================================
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Main Body %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#===============================================================================
# Print border
print_border "$BORDER_CHAR"

# Backup list of URLs, create a temp file containing only URLs
backup_list

# Call main function
main

# Clean up file, backup, print exit message
clean_up

# Print a list of backed up files
echo -e "\nBackups:"
ls -ar | grep "${TAG}" # | tail -3

# Print end stats about files and changes
echo -e	"\nNew backup: \t${PARENT_DIR}/.${FNAME}.${TIMESTAMP}.${TAG}\
		 \nUpdated file: \t${FILE_PATH}\
		 \nTotal URLs: \t$total_urls\
		 \nNew URLs: \t$new_URLs"

# Print goodbye messasge
echo -e '\nProgram exit.'

# Print border
print_border "$BORDER_CHAR"

#===============================================================================
# Delete backup files older than 3 days
find $HOME/Desktop/ -iname "*${TAG}*" -atime +3 -print -exec mv {} /tmp/ \;

# Obtain number of line at the end and calculate number of lines added
lines_final=$(wc -l < "${FILE_PATH}")
lines_added=$(($lines_final-$total_urls))


# Delete lines with http from history (if accidentally added a site to terminal)
sed -i '/^http/d' "$HISTFILE" 2> /tmp/err


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% End %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
