#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/10-frontend.log"
domain_name="daws-92s.space"
scripts_dir=$(dirname "$(realpath "$0")")

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ "$user_id" -ne 0 ]; then
    echo "Please run this script with sudo access."
    exit 1
fi

mkdir -p "$logs_folder"

timestamp() {
    date "+%F %T"
}

validate() {
    if [ "$1" -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${2}..${R}FAILED${N}" | tee -a "$logs_file"
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${2}..${G}SUCCESS${N}" | tee -a "$logs_file"
    fi
}

echo "$(timestamp) [INFO] ==== Script started Execution =====" | tee -a "$logs_file"

# Install Nginx
dnf module disable nginx -y &>> "$logs_file"
dnf module enable nginx:1.26 -y &>> "$logs_file"

dnf install nginx -y &>> "$logs_file"
validate $? "Installing nginx"

# Enable Nginx
systemctl enable nginx &>> "$logs_file"
validate $? "Enabling nginx"

systemctl start nginx &>> "$logs_file"
validate $? "Starting nginx"

# Remove default frontend content
rm -rf /usr/share/nginx/html/*
validate $? "Removing default nginx content"

# Download frontend application
curl -fL -o /tmp/frontend.zip \
"https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/frontend-v4.zip" \
&>> "$logs_file"

validate $? "Downloading frontend application"

# Extract frontend application
cd /usr/share/nginx/html || exit 1

unzip -o /tmp/frontend.zip &>> "$logs_file"
validate $? "Extracting frontend application"

# Verify configuration file exists
if [ ! -s "$scripts_dir/roboshop.conf" ]; then
    echo -e "$(timestamp) [ERROR] roboshop.conf missing or empty..${R}FAILED${N}" | tee -a "$logs_file"
    exit 1
fi

# Replace domain name without modifying original template
sed -e "s/DOMAIN_NAME/$domain_name/g" \
    -e "s/daws92s\.store/$domain_name/g" \
    "$scripts_dir/roboshop.conf" \
    > /etc/nginx/default.d/roboshop.conf

validate $? "Configuring roboshop nginx"

# Validate Nginx configuration
nginx -t 2>&1 | tee -a "$logs_file"
validate "${PIPESTATUS[0]}" "Nginx Configuration"

# Restart Nginx
systemctl restart nginx &>> "$logs_file"
validate $? "Restarting nginx"

# Verify Nginx
systemctl is-active --quiet nginx
validate $? "Checking nginx service"

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds" | tee -a "$logs_file"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a "$logs_file"