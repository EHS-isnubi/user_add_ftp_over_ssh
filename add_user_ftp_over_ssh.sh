#!/usr/bin/env bash
#==========================================================================================
#
# SCRIPT NAME        :     add_user_ftp_over_ssh.sh
#
# AUTHOR             :     Louis GAMBART
# CREATION DATE      :     2023.03.20
# RELEASE            :     1.0.0
# USAGE SYNTAX       :     .\add_user_ftp_over_ssh.sh [-u|--user] <username>
#
# SCRIPT DESCRIPTION :     This script is used to create a user and a SSH key for FTP access
#
#==========================================================================================
#
#                 - RELEASE NOTES -
# v1.0.0  2023.07.05 - Louis GAMBART - Initial version
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
Green='\033[0;32m'     # Green


####################
#                  #
#  II - VARIABLES  #
#                  #
####################

SCRIPT_NAME="add_user_ftp_over_ssh.sh"
PUBKEY=$(cat ssh-rsa_keys.txt)


#####################
#                   #
#  III - FUNCTIONS  #
#                   #
#####################

print_help () {
    # Print help message
    echo -e """
    ${Green} SYNOPSIS
        ${SCRIPT_NAME} [-u|--user] <username>

     DESCRIPTION
         This script is used to create a user and a SSH key for FTP access

     OPTIONS
        -u, --user         User name
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


create_user () {
    # Create a user
    # $1: username
    echo -e "${Yellow}Creating user ${USERNAME}...${No_Color}"
    sudo useradd -m "$1"
    if [ ! "$(getent group ftp)" ]; then
        echo -e "${Yellow}Creating group ftp...${No_Color}"
        sudo groupadd ftp
    fi
    sudo usermod -aG ftp "$1"
}


create_ssh_key () {
    # Create a SSH key
    # $1: username
    echo -e "${Yellow}Creating SSH key for user ${USERNAME}...${No_Color}"
    sudo -u "$1" -H sh -c 'ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""'
}


add_public_key () {
    # Add public key to authorized_keys
    # $1: username
    sudo -u "$1" bash -c "echo '$PUBKEY' > /home/$1/.ssh/authorized_keys"
    sudo chmod 600 /home/"$1"/.ssh/authorized_keys
    sudo chown "$1":"$1" /home/"$1"/.ssh/authorized_keys
}


configure_ssh_daemon () {
    # Configure the SSH daemon to add the user to the chroot
    # $1: username
    echo "Match User $1
    ForceCommand internal-sftp
    ChrootDirectory /ftp" | sudo tee -a /etc/ssh/sshd_config
    sudo service ssh restart
}


#########################
#                       #
#  IV - SCRIPT OPTIONS  #
#                       #
#########################

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -u|--user)
            USERNAME="$2"
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

echo -e "${Yellow}Checking if you are root...${No_Color}"
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${Red}Please run as root${No_Color}"
    exit 1
else
    echo -e "${Green}You are root${No_Color}"
fi


######################
#                    #
#  VI - MAIN SCRIPT  #
#                    #
######################

echo -e "${Yellow}Starting the script...${No_Color}"

if [ -z "$USERNAME" ]; then
    echo -e "${Red}Please specify a username${No_Color}"
    exit 1
else
    create_user "$USERNAME"
    create_ssh_key "$USERNAME"
    configure_ssh_daemon "$USERNAME"
    add_public_key "$USERNAME"
fi

echo -e "${Green}Script finished${No_Color}"