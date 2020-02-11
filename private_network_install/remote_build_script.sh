#!/bin/bash
#purpose: builds a new AMI via packer, on a remote ec2 instance.

cd /var/tmp/

#copy down files from S3 (packer config, ansible, other artifacts)
#BUCKETREPLACEREGEX gets replaced with your bucket name

aws s3 sync s3://BUCKETREPLACEREGEX/packer/ ./

#Get packer
#Todo: Discover latest packer and always use that.
if [ ! -e packer ]; then wget https://releases.hashicorp.com/packer/1.5.1/packer_1.5.1_linux_amd64.zip && unzip packer_1.5.1_linux_amd64.zip; fi

./packer build -var-file="/var/tmp/vars.json" private_network.json >> /var/tmp/packer.log

aws s3 cp /var/tmp/packer.log s3://BUCKETREPLACEREGEX/packer/$(date +%S%M%H%h_%d_%Y).log 

#Todo: Do a build status notify. SNS/SQS endpoint seems like the best idea.