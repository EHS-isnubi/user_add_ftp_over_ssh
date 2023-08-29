#!/usr/bin/env bash
#==========================================================================================
#
# SCRIPT NAME        :     add_user_ftp_over_ssh.sh
#
# AUTHOR             :     Louis GAMBART
# CREATION DATE      :     2023.07.19
# RELEASE            :     2.1.2
# USAGE SYNTAX       :     .\add_user_ftp_over_ssh.sh [-f|--file] <file>
#
# SCRIPT DESCRIPTION :     This script is used to create a user and a SSH key for FTP access
#                          Imagine for Oracle Linux hosts
#
#==========================================================================================
#
#                 - RELEASE NOTES -
# v1.0.0  2023.07.19 - Louis GAMBART - Initial version
# v1.1.0  2023.07.20 - Louis GAMBART - Add --username option
# v2.0.0  2023.07.20 - Louis GAMBART - Rework the script to be based on public key list
# v2.1.0  2023.07.21 - Louis GAMBART - Add existent check to avoid overwriting or entry duplication
# v2.1.1  2023.07.21 - Louis GAMBART - Change color for script output
# v2.1.2  2023.07.21 - Louis GAMBART - Change error message when no file were given
#
#==========================================================================================


#####################
#                   #
#  I - COLOR CODES  #
#                   #
#####################

No_Color='\033[0m'      # No Color
Red='\033[0;31m'        # Red
Yellow='\033[0;33m'     # Yellow
Green='\033[0;32m'      # Green
Blue='\033[0;34m'       # Blue


####################
#                  #
#  II - VARIABLES  #
#                  #
####################

SCRIPT_NAME="add_user_ftp_over_ssh.sh"


#####################
#                   #
#  III - FUNCTIONS  #
#                   #
#####################

print_help () {
    # Print help message

    echo -e """
    ${Green} SYNOPSIS
        ${SCRIPT_NAME} [-f|--file] <file>

     DESCRIPTION
         This script is used to create a user and a SSH key for FTP access
         Imagine for Oracle Linux hosts

     OPTIONS
        -f, --file         Specify the file to read
        -h, --help         Print the help message
        -v, --version      Print the script version
    ${No_Color}
    """
}


print_version () {
    # Print version message

    echo -e """
    ${Green}
    version       ${SCRIPT_NAME} 1.0.0
    author        Louis GAMBART
    license       GNU GPLv3.0
    script_id     0
    """
}


check_ftp_group () {
    # Check if "ftp" group exist

    echo -e -n "${Yellow}Checking if group ftp exist...${No_Color}"
    if [ ! "$(getent group ftp)" ]; then
        echo -e "${Red} ERROR - Group ftp doesn't exist${No_Color}"
        exit 1
    else
        echo -e "${Green} OK${No_Color}\n"
    fi
}


create_user () {
    # Create a user and add it to the "ftp" group
    # $1: username

    echo -e -n "${Yellow}Creating user $1 and add it to group ftp...${No_Color}"
    if id -u "$1" >/dev/null 2>&1; then
        echo -e "${Red} WARN - User $1 already exist${No_Color}"
        return
    fi
    sudo useradd -m "$1"
    sudo usermod -aG "ftp" "$1"
    echo -e "${Green} OK${No_Color}"
}


create_ssh_key () {
    # Create a SSH key
    # $1: username

    echo -e -n "${Yellow}Creating SSH key for user ${USERNAME}...${No_Color}"
    if [ -f "/home/$1/.ssh/id_rsa_ftp.pub" ]; then
        echo -e "${Red} WARN - RSA key already exist"
        return
    fi
    sudo -u "$1" -H sh -c 'ssh-keygen -t rsa -f ~/.ssh/id_rsa_ftp -q -N ""'
    echo -e "${Green} OK${No_Color}"
}


configure_ssh_daemon () {
    # Configure the SSH daemon to add the user to the chroot
    # $1: username

    echo -e -n "${Yellow}Adding connection authorization to SSHD configuration...${No_Color}"
    if sudo grep -q "$1" /etc/ssh/sshd_config; then
        echo -e "${Red} WARN - User $1 already exist in SSHD configuration${No_Color}"
        return
    fi
    echo "Match User $1
    ForceCommand internal-sftp
    ChrootDirectory /ftp" | sudo tee -a /etc/ssh/sshd_config > /dev/null
    echo -e "${Green} OK${No_Color}"
}


add_public_key () {
    # Add public key to authorized_keys
    # $1: username
    # $2: public key

    echo -e -n "${Yellow}Adding public key to authorized_keys...${No_Color}"
    if [ -f "/home/$1/.ssh/authorized_keys" ]; then
        if sudo grep -Fxq "$2" /home/"$1"/.ssh/authorized_keys; then
            echo -e "${Red} WARN - Public key already exist in authorized_keys${No_Color}\n"
            return
        fi
    fi
    sudo -u "$1" bash -c "echo '$2' >> /home/$1/.ssh/authorized_keys"
    sudo chmod 600 /home/"$1"/.ssh/authorized_keys
    sudo chown "$1":"$1" /home/"$1"/.ssh/authorized_keys
    echo -e "${Green} OK${No_Color}\n"
}


#########################
#                       #
#  IV - SCRIPT OPTIONS  #
#                       #
#########################

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -f|--file)
            SSH_KEYS_FILE="$2"
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        -v|--version)
            print_version
            exit 0
            ;;
        *)
            echo -e "${Red}Unknown option: $key${No_Color}"
            print_help
            exit 0
            ;;
    esac
    shift
done


####################
#                  #
#  V - ROOT CHECK  #
#                  #
####################

echo -e -n "${Yellow}Checking if you are root...${No_Color}"
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${Red} ERR - Run the script as root${No_Color}"
    exit 1
else
    echo -e "${Green} OK${No_Color}\n"
fi


######################
#                    #
#  VI - MAIN SCRIPT  #
#                    #
######################

echo -e "${Blue}Starting the script...${No_Color}\n"

if [ -z "$SSH_KEYS_FILE" ]; then
    echo -e "${Red}ERR - Please specify an input file${No_Color}"
    exit 1
else
    check_ftp_group
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        USERNAME=$(echo "$line" | cut -d " " -f3)
        create_user "$USERNAME"
        create_ssh_key "$USERNAME"
        configure_ssh_daemon "$USERNAME"
        add_public_key "$USERNAME" "$line"
    done < "$SSH_KEYS_FILE"
    echo -e -n "${Yellow}Restarting SSH daemon...${No_Color}"
    sudo systemctl restart sshd
    echo -e "${Green} OK${No_Color}\n"
fi

echo -e "${Blue}Script finished${No_Color}"