#!/bin/bash

set -o pipefail

USER_ID=$(id -u)
LOGS_FOLDER="/var/log/roboshop"
LOGS_FILE="${LOGS_FOLDER}/catalogue.log"

DOMAIN_NAME="daws-92s.space"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

# Check root access
if [ "$USER_ID" -ne 0 ]; then
    echo "Please run this script with sudo access."
    exit 1
fi

mkdir -p "$LOGS_FOLDER"

timestamp() {
    date "+%F %T"
}

validate() {
    if [ "$1" -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] $2..${R}FAILED${N}" | tee -a "$LOGS_FILE"
        exit 1
    else
        echo -e "$(timestamp) [INFO] $2..${G}SUCCESS${N}" | tee -a "$LOGS_FILE"
    fi
}

echo "$(timestamp) [INFO] ==== Catalogue Installation Started ====" | tee -a "$LOGS_FILE"

# Step 1: Install Node.js
dnf module disable nodejs -y &>> "$LOGS_FILE"
dnf module enable nodejs:24 -y &>> "$LOGS_FILE"

dnf install nodejs -y &>> "$LOGS_FILE"
validate $? "Installing Node.js"

# Step 2: Create RoboShop user
if ! id roboshop &>/dev/null; then
    useradd --system \
        --home /app \
        --shell /sbin/nologin \
        --comment "RoboShop System User" \
        roboshop &>> "$LOGS_FILE"

    validate $? "Creating RoboShop user"
else
    echo -e "$(timestamp) [INFO] RoboShop user already exists..${Y}SKIPPING${N}"
fi

# Step 3: Create application directory
mkdir -p /app
validate $? "Creating application directory"

# Step 4: Download Catalogue application
curl -fL \
    -o /tmp/catalogue.zip \
    https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/catalogue-v4.zip \
    &>> "$LOGS_FILE"

validate $? "Downloading Catalogue application"

# Step 5: Extract application
unzip -o /tmp/catalogue.zip -d /app &>> "$LOGS_FILE"
validate $? "Extracting Catalogue application"

# Step 6: Install dependencies
cd /app || exit 1

npm install &>> "$LOGS_FILE"
validate $? "Installing Catalogue dependencies"

# Step 7: Set application ownership
chown -R roboshop:roboshop /app
validate $? "Setting application permissions"

# Step 8: Verify service file exists
if [ ! -s "$SCRIPT_DIR/catalogue.service" ]; then
    echo -e "$(timestamp) [ERROR] catalogue.service is missing or empty..${R}FAILED${N}" | tee -a "$LOGS_FILE"
    exit 1
fi

# Step 9: Configure Catalogue service
sed "s/DOMAIN_NAME/$DOMAIN_NAME/g" \
    "$SCRIPT_DIR/catalogue.service" \
    > /etc/systemd/system/catalogue.service

validate $? "Configuring Catalogue service"

# Step 10: Reload systemd
systemctl daemon-reload &>> "$LOGS_FILE"
validate $? "Reloading systemd"

# Step 11: Enable Catalogue
systemctl enable catalogue &>> "$LOGS_FILE"
validate $? "Enabling Catalogue service"

# Step 12: Restart Catalogue
systemctl restart catalogue &>> "$LOGS_FILE"
validate $? "Starting Catalogue service"

# Step 13: Verify service status
systemctl is-active --quiet catalogue
validate $? "Checking Catalogue service status"

# Step 14: Verify MongoDB repository file
if [ ! -s "$SCRIPT_DIR/mongodb.repo" ]; then
    echo -e "$(timestamp) [ERROR] mongodb.repo is missing or empty..${R}FAILED${N}" | tee -a "$LOGS_FILE"
    exit 1
fi

# Step 15: Configure MongoDB repository
cp "$SCRIPT_DIR/mongodb.repo" /etc/yum.repos.d/mongodb.repo
validate $? "Adding MongoDB repository"

# Step 16: Install MongoDB client
dnf install mongodb-mongosh -y &>> "$LOGS_FILE"
validate $? "Installing MongoDB client"

# Step 17: Check MongoDB connectivity
MONGO_HOST="mongodb.$DOMAIN_NAME"

getent hosts "$MONGO_HOST" &>> "$LOGS_FILE"
validate $? "Resolving MongoDB hostname"

# Step 18: Check existing products
PRODUCT_COUNT=$(mongosh \
    --host "$MONGO_HOST" \
    --quiet \
    --eval 'db.getSiblingDB("catalogue").products.countDocuments()' \
    2>> "$LOGS_FILE")

validate $? "Connecting to MongoDB"

# Step 19: Load products if required
if [ "$PRODUCT_COUNT" -eq 0 ]; then

    if [ ! -f /app/db/master-data.js ]; then
        echo -e "$(timestamp) [ERROR] master-data.js missing..${R}FAILED${N}" | tee -a "$LOGS_FILE"
        exit 1
    fi

    mongosh \
        --host "$MONGO_HOST" \
        < /app/db/master-data.js &>> "$LOGS_FILE"

    validate $? "Loading Catalogue products"

else
    echo -e "$(timestamp) [INFO] Products already loaded..${Y}SKIPPING${N}"
fi

# Step 20: Restart Catalogue
systemctl restart catalogue &>> "$LOGS_FILE"
validate $? "Restarting Catalogue service"

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds" | tee -a "$LOGS_FILE"

echo "$(timestamp) [INFO] ==== Catalogue Installation Completed ====" | tee -a "$LOGS_FILE"