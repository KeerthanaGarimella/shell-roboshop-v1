#!/bin/bash

set -o pipefail

USER_ID=$(id -u)

LOGS_FOLDER="/var/log/roboshop"
LOGS_FILE="${LOGS_FOLDER}/04-rabbitmq.log"

R="\e[31m"
G="\e[32m"
N="\e[0m"

if [ "$USER_ID" -ne 0 ]; then
    echo "Please run this script with sudo access"
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

echo "$(timestamp) [INFO] Script started" | tee -a "$LOGS_FILE"

# Check repository file
if [ ! -s rabbitmq.repo ]; then
    echo "ERROR: rabbitmq.repo is missing or empty"
    exit 1
fi

# Configure RabbitMQ repositories
cp rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo
validate $? "Adding RabbitMQ repository"

# Refresh package metadata
dnf makecache --refresh &>> "$LOGS_FILE"
validate $? "Refreshing repository metadata"

# Install RabbitMQ
# Requires a compatible Erlang version
dnf install -y logrotate erlang rabbitmq-server &>> "$LOGS_FILE"
validate $? "Installing RabbitMQ server"

# Start RabbitMQ
systemctl enable --now rabbitmq-server &>> "$LOGS_FILE"
validate $? "Starting and enabling RabbitMQ"

# Verify RabbitMQ
rabbitmq-diagnostics ping &>> "$LOGS_FILE"
validate $? "Checking RabbitMQ status"

# Create application user
if rabbitmqctl list_users | grep -qw "roboshop"; then
    echo "$(timestamp) [INFO] RabbitMQ user already exists"
else
    read -rsp "Enter password for RabbitMQ roboshop user: " RABBITMQ_PASSWORD
    echo

    rabbitmqctl add_user roboshop "$RABBITMQ_PASSWORD" &>> "$LOGS_FILE"
    validate $? "Creating RabbitMQ user"

    unset RABBITMQ_PASSWORD
fi

# Set permissions
rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>> "$LOGS_FILE"
validate $? "Setting RabbitMQ permissions"

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds" | tee -a "$LOGS_FILE"