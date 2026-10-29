#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="daws92s.space"
hosted_zone_id="Z0731054138SF68GPGDXV"

for instance in "$@"
do
    echo "creating instance $instance"

  instance_id=$(aws ec2 run-instances \
    --image-id $ami_id \
    --instance-type $instance_type \
	--tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-shell}]"
	 --security-groups "roboshop-common" "roboshop-$instance" \
	 --query "Instances[0].InstanceId" 
	 --output text
 )

  echo "Instance id : $instance_id"
done