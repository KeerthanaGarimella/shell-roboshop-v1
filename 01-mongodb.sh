#!/bin/bash

user_id=$(id -u)
logs_folder="var/log/roboshop"
logs_file="${logs_folder}/${0}.log"
R="/e[31m"
G="/e[32m"
N="/e[0m"
Y="/e[33m"

if [ $user_id -ne 0 ]; then
    echo " Please run this with sudo access.."
    exit 1
fi

mkdir -p $logs_folder

echo "script started execution at:$(date +"%F %T")"&>> $logs_file

  validate(){
    if [$? -ne 0];then
    echo "${2}.. failed" | tee -a $logs_file
    exit 1
  else
    echo "${2}..success" | tee -a $logs_file
  fi
}
 
 for package in $@
 do   
     dnf list installed $package &>> $logs_file
     if [ $? -eq 0 ]; then
        echo "Going to install: ${package}"
        dnf install ${package} -y &>> $logs_file
        validate $? "${package} installation"
    else
        echo "${package} is already installed .. Skipping" 
    fi  
 done 


 