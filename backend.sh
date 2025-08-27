#!/bin/bash

# Get the user ID of the current user running the script
USERID=$(id -u)

# Generate a timestamp to uniquely identify the log file name (e.g., 2024-11-18)
TIMESTAMP=$(date +%F)

# Extract the base name of the script file without its extension
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)

# Define the log file path using the script name and timestamp
LOGFILE=/tmp/$SCRIPT_NAME-$TIMESTAMP.log

# Color codes for terminal output to make success/failure messages more visible
R="\e[31m"  # Red for failure
G="\e[32m"  # Green for success
Y="\e[33m"  # Yellow for warning/skip
N="\e[0m"   # Reset color

# Prompt the user to enter the MySQL root password
echo "Please enter DB password:"
read -s mysql_root_password  # Read the password without echoing it to the terminal

# Function to check the exit status of a command and print a success/failure message
VALIDATE() {
    if [ $1 -ne 0 ]; then
        echo -e "$2...$R FAILURE $N"  # If the command failed, print failure message in red
        exit 1  # Exit the script with a non-zero status
    else
        echo -e "$2...$G SUCCESS $N"  # If the command succeeded, print success message in green
    fi
}

# Ensure the script is being run by the root user (UID 0)
if [ $USERID -ne 0 ]; then
    echo "Please run this script with root access."
    exit 1  # Exit if not run as root
else
    echo "You are super user."  # Inform the user that they have root access
fi

# Disable the default Node.js module stream (if any)
dnf module disable nodejs -y &>>$LOGFILE
VALIDATE $? "Disabling NodeJS Module"  # Check if disabling Node.js was successful

# Enable the Node.js module stream version 20
dnf module enable nodejs:20 -y &>>$LOGFILE
VALIDATE $? "Enabling NodeJS Module"  # Check if enabling Node.js version 20 was successful

# Install Node.js and related dependencies
dnf install nodejs -y &>>$LOGFILE
VALIDATE $? "Installing NodeJS Module"  # Check if Node.js installation was successful

# Check if the 'expense' user already exists
id expense  &>>$LOGFILE  # Check the user ID for 'expense' (redirect output to the log)
if [ $? -eq 0 ]; then
    # If the user exists, print a message in the log
    echo "Expense user already exists"  &>>$LOGFILE
else
    # If the user does not exist, create the 'expense' user
    echo "Expense user doesn't exist, creating expense user" &>>$LOGFILE
    useradd expense  &>>$LOGFILE  # Add the user to the system
fi

# Create the application directory in /app
mkdir -p /app &>>$LOGFILE
VALIDATE $? "Creating Application Directory"

# Download the application backend code (a ZIP file) from an S3 bucket
curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>$LOGFILE
VALIDATE $? "Downloading the application backend code "

# Unzip the downloaded backend code into the /app directory
cd /app
# Unzip the backend.zip file located at /tmp and overwrite any existing files
# without prompting for user confirmation using the '-o' option.
unzip -o /tmp/backend.zip &>>$LOGFILE
# unzip /tmp/backend.zip &>>$LOGFILE  # Unzip the downloaded backend.zip file
VALIDATE $? "Unziping the downloaded backend code"

# Install the application dependencies via npm (Node.js package manager)
cd /app  # Ensure we're in the /app directory
npm install &>>$LOGFILE  # Install dependencies defined in package.json
VALIDATE $? "Install dependencies defined "

# Setup the backend service as a systemd service (so it can start automatically)
# Copy the systemd service unit file to the systemd directory
cp /home/ec2-user/shell-script-Expense/backend.service /etc/systemd/system/backend.service &>>$LOGFILE
VALIDATE $? "Copying the backend.service file"

# Reload the systemd manager configuration to recognize the new service
systemctl daemon-reload  &>>$LOGFILE
VALIDATE $? "Reloading the systemd manager configuration"

# Start the backend service
systemctl start backend  &>>$LOGFILE
VALIDATE $? "Starting the backend service"

# Enable the backend service to start automatically on boot
systemctl enable backend  &>>$LOGFILE
VALIDATE $? "Enabling the backend service"

# Install MySQL server
dnf install mysql -y &>>$LOGFILE
VALIDATE $? "Installing MySQL server"

# Load the schema (database structure) into MySQL
# This assumes that the backend.sql schema file exists at /app/schema/backend.sql
mysql -h db.kalyaneswar.site -uroot -p${mysql_root_password} < /app/schema/backend.sql &>>$LOGFILE
VALIDATE $? "Loading the schema into MySQL"

# Restart the backend service to apply changes
systemctl restart backend &>>$LOGFILE
VALIDATE $? "Restarting the backend service."
