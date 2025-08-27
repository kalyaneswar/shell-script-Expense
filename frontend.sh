#!/bin/bash

# Get the user ID of the current user running the script (UID 0 is root)
USERID=$(id -u)

# Generate a timestamp to uniquely identify the log file name (e.g., 2024-11-18)
TIMESTAMP=$(date +%F)

# Extract the base name of the script file (without file extension)
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)

# Define the log file path using the script name and timestamp (e.g., /tmp/scriptname-2024-11-18.log)
LOGFILE=/tmp/$SCRIPT_NAME-$TIMESTAMP.log

# Color codes for terminal output to make success/failure messages more visible
R="\e[31m"  # Red for failure
G="\e[32m"  # Green for success
Y="\e[33m"  # Yellow for warning/skip
N="\e[0m"   # Reset color to default

# Prompt the user to enter the MySQL root password (it will be hidden as it's entered)
# echo "Please enter DB password:"
# read -s mysql_root_password  # The -s flag hides the input (secure)

# Function to check the exit status of a command and print a success/failure message
VALIDATE() {
    # Check if the command status code is non-zero (indicating failure)
    if [ $1 -ne 0 ]; then
        echo -e "$2...$R FAILURE $N"  # If failed, print failure message in red
        exit 1  # Exit the script with an error code (1)
    else
        echo -e "$2...$G SUCCESS $N"  # If succeeded, print success message in green
    fi
}

# Ensure the script is being run as the root user (UID 0 is root)
if [ $USERID -ne 0 ]; then
    # If not root, print a message and exit with error code 1
    echo "Please run this script with root access."
    exit 1  # Exit the script if not running as root
else
    # If root, print a confirmation message
    echo "You are super user."  # Inform the user that they have root access
fi

# Install Nginx web server using dnf package manager
dnf install nginx -y &>>$LOGFILE  # The output (stdout/stderr) is appended to the log file
VALIDATE $? "Installing Nginx"  # Validate whether the installation was successful

# Enable the Nginx service to start automatically on boot
systemctl enable nginx &>>$LOGFILE  # Log output is captured in the logfile
VALIDATE $? "Enabling Nginx"  # Check if the service was enabled successfully

# Start the Nginx service immediately after enabling it
systemctl start nginx &>>$LOGFILE  # Log the output to the logfile
VALIDATE $? "Starting Nginx"  # Validate if Nginx started successfully

# Remove the default Nginx HTML content, which is usually the "Welcome" page
rm -rf /usr/share/nginx/html/* &>>$LOGFILE  # Remove existing content (if any)
VALIDATE $? "Removing Nginx default index file"  # Check if the removal was successful

# Download the frontend code (a zip file) from the provided S3 URL
curl -o /tmp/frontend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-frontend-v2.zip &>>$LOGFILE
VALIDATE $? "Downloading frontend code"  # Validate if the download was successful

# Move to the directory where Nginx serves its HTML files
cd /usr/share/nginx/html &>>$LOGFILE  # Change directory to Nginx's web root
VALIDATE $? "Moving to html Nginx path"  # Check if the directory change was successful

# Unzip the frontend code (the zip file downloaded earlier) into the Nginx HTML directory
unzip /tmp/frontend.zip &>>$LOGFILE  # Unzip the frontend content into the directory
VALIDATE $? "Unzipping the code"  # Validate if the unzip was successful

# Copy the custom Nginx configuration file (for the expense app) to the Nginx directory
cp /home/ec2-user/shell-script-Expense/expense.conf /etc/nginx/default.d/expense.conf &>>$LOGFILE
VALIDATE $? "Copying the config file"  # Validate if the config file was copied successfully

# Restart Nginx to apply the new configuration and updated frontend code
systemctl restart nginx &>>$LOGFILE  # Restart the Nginx service to load changes
VALIDATE $? "Restarting Nginx"  # Validate if Nginx restarted successfully
