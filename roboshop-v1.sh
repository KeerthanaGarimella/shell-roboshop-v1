#!/bin/bash

ami_id= "ami-0055977a6e828a4f4"
intance_type="t3.micro"
domain_name="daws92s.space"
hosted_zone-id="Z0731054138SF68GPGDXV"


for instance in $@
do 
     eco "creating instance $instance"
done