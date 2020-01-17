#!/bin/bash

#Purpose: Create a network via terraform, give it internet access, 
#use this to build an image via packer without SSH commands or other traffic going over the internet

#Get args

#REGION = AWS region, eg: us-east-1
#PROFILE, profile in ~.aws/credentials
#BUCKET, the name of the bucket we're going to upload packer to.

#TODO: input validation

while getopts r:p:s:b: option
do
case "${option}"
in
r) REGION=${OPTARG};;
p) PROFILE=${OPTARG};;
b) BUCKET=${OPTARG};;
esac
done

#Remove profile if you don't need it


export SUBNET=$(terraform output private_subnet_id)
export VPC=$(terraform output vpc_id)
export SG=$(terraform output build_security_group)
export INSTANCE_PROFILE=$(terraform output instance_profile)

echo "{
  \"SUBNET\": \"$SUBNET\",
  \"VPC\": \"$VPC\",
      \"REGION\": \"$REGION\",
    \"SG\": \"$SG\"
}" >> vars.json

#Move Config to bucket, will be used by packer later
#Todo: Discover, make bucket if doesn't exist. For now, make the bucket in advance "aws s3 mb s3://bucketname"

aws s3 cp vars.json s3://$BUCKET/packer/ --region $REGION --profile $PROFILE
aws s3 cp private_network.json s3://$BUCKET/packer/ --region $REGION --profile $PROFILE
aws s3 cp *.yml s3://$BUCKET/packer/ --region $REGION --profile $PROFILE
rm vars.json



#Get the latest AL2 AMI for our region. Obviously if you want to bring your own AMI, update the filter.

export AMI=$(aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2' \
'Name=state,Values=available' \
--query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' \
--output text \
--region $REGION \
--profile $PROFILE)

#After our network is built to our specifications, we need to deploy an ec2 instance to build another EC2 instance.
#remote_build script will be excuted by our remote agent after it's booted

aws ec2 run-instances \
    --image-id $AMI \
    --count 1 \
    --instance-type t2.micro \
    --user-data file://remote_build_script.sh \
    --subnet-id $SUBNET \
    --security-group-ids $SG\
    --iam-instance-profile Name=$INSTANCE_PROFILE \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=RemoteBuildAgent}]' \
    --profile $PROFILE \ 
    --region $REGION






