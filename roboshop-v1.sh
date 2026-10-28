#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="daws92s.space"
hosted_zone_id="Z0731054138SF68GPGDXV"

for instance in "$@"
do
    echo "creating instance $instance"
done