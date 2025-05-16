#!/bin/bash

USERID=$(id -u)
TIMESTAMP=$(date +%F)
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOGFILE=/tmp/$SCRIPT_NAME-$TIMESTAMP.log

# Color codes for terminal output
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

# Ask for the MySQL root password
echo "Please enter DB password:"
read -s mysql_root_password

# Function to validate the success of commands
VALIDATE() {
    if [ $1 -ne 0 ]; then
        echo -e "$2...$R FAILURE $N"
        exit 1
    else
        echo -e "$2...$G SUCCESS $N"
    fi
}

# Ensure the script is being run as root
if [ $USERID -ne 0 ]; then
    echo "Please run this script with root access."
    exit 1
else
    echo "You are super user."
fi

# Install MySQL server
dnf install mysql-server -y &>>$LOGFILE
VALIDATE $? "Installing MySQL Server"

# Enable MySQL service to start on boot
systemctl enable mysqld &>>$LOGFILE
VALIDATE $? "Enabling MySQL Server"

# Start the MySQL service
systemctl start mysqld &>>$LOGFILE
VALIDATE $? "Starting MySQL Server"

# Check if MySQL root password is already set
mysql -h db.kalyaneswar.online -uroot -p${mysql_root_password} -e 'show databases;' &>>$LOGFILE

# If the MySQL root password is not set, configure it
if [ $? -ne 0 ]; then
    echo "Root password not set. Running mysql_secure_installation..."
    mysql_secure_installation --set-root-pass ${mysql_root_password} &>>$LOGFILE
    VALIDATE $? "MySQL Root password setup"
else
    echo -e "MySQL Root password is already set...$Y SKIPPING $N"
fi
