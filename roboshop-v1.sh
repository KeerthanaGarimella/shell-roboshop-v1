#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="daws92s.space"
hosted_zone_id="Z0731054138SF68GPGDXV"

for instance in "$@"
do
    echo "creating instance : $instance"

    instance_id=$(aws ec2 run-instances \
        --image-id "$ami_id" \
        --instance-type "$instance_type" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
        --security-groups "roboshop-common" "roboshop-$instance" \
        --query "Instances[0].InstanceId" \
        --output text)

    echo "$instance id : $instance_id"

    aws ec2 wait instance-running --instance-ids "$instance_id"

    if [ "$instance" != "frontend" ]; then

        IP=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query "Reservations[0].Instances[0].PrivateIpAddress" \
            --output text)

        r53_record="$instance.$domain_name"

    else

        IP=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query "Reservations[0].Instances[0].PublicIpAddress" \
            --output text)

        r53_record="$domain_name"

    fi

    # update route 53 record

    aws route53 change-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --change-batch "{
            \"Changes\": [
                {
                    \"Action\": \"UPSERT\",
                    \"ResourceRecordSet\": {
                        \"Name\": \"$r53_record\",
                        \"Type\": \"A\",
                        \"TTL\": 300,
                        \"ResourceRecords\": [
                            {
                                \"Value\": \"$IP\"
                            }
                        ]
                    }
                }
            ]
        }"

done