#!/bin/bash
#purpose: builds a new AMI via packer, on a remote ec2 instance.

cd /var/tmp/

#copy down files from S3 (packer config, ansible, other artifacts)
#todo: accept variable for bucket name
aws s3 sync s3://liampackerbucket/packer/ ./

#Get packer
#Todo: Discover latest packer and always use that.
if [ ! -e packer ]; then wget https://releases.hashicorp.com/packer/1.5.1/packer_1.5.1_linux_amd64.zip && unzip packer_1.5.1_linux_amd64.zip; fi

./packer build -var-file="/var/tmp/vars.json" private_network.json >> /var/tmp/packer.log

#Todo, persist these logs somewhere, shut down this insance