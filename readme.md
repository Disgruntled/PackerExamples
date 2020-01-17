# Some Packer Examples

Herein, we have two packer examples. One simple and turnkey, the second one does something a little neat.

This script assumes that you have S3:Read/WRite in one bucket, and EC2:FullACcess, The ability to modify IAM policies and roles, and Pass Iam Roles(instance profiles) to EC2 instance. Basically, you are an AWS Admin.

All instance sizes used are t2.micro so this is eligible for the AWS free tier.


## 1) Using Packer as a local build agent

This example wants you to install packer locally, and use it to build a remote system. it assumes there is a default VPC available in your AWS account, and you give it sufficient rights to create an EC2 instance, set a key pair, and ssh into it over the internet (it will need a public IP). Simple, effecient, questionably secure, and perhaps not well suited to complex corporate environments. Invoke simply via:

```
packer build over_the_internet.json
```
Uses the latest & greatest 64  bit AL2 AMI as a base. Uses ansible to install a really simple docker container I made for all my tests. Also on my github!

I chose ansible as my primary configuration tool here so I would learn something new, this was my first go at ansible and I rather like it.

variables in over_the_internet.json can be changed to your liking.

ec2_userdata.sh is provided if you want to tell ec2 to start up the container on boot. you can start the EC2 instance you made with:

```bash
aws ec2 run-instances \
    --image-id $YOUR_AM_ID_ \
    --count 1 \
    --instance-type t2.micro \
    --user-data file://ec2_userdata.sh \
    --subnet-id $YOUR_SUBNET \
    --security-group-ids $YOUR_SG\
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ContainerServer}]' \
    --associate-public-ip-address \
    --profile $PROFILE \
    --region $REGION
```

The above assumes your VPC has an internet gateway (IGW), and the SG allows port 80 inbound.

$PROFILE being optional if you're using environment variables or instance meta-data store credentials.

## 2) Using packer as a remote build agent.

Now this is a bit cool.

This will use terraform to create a simple infrastructure with public/private routing and the ability for all hosts to connect to the internet from the private subnet. it will also create an instance profile that has SSM/EC2:FullAccess/IAM:Passrole/Iam:Readonly, and spawn an instance named "RemoteBuildAgent" in the private subnet that will invoke packer on a new host.

The script will upload configuration files to an S3 bucket bucket to help "RemoteBuildAgent" perform its tasks. remote build agent pulls the files down from s3 locally then invokes packer.

Invocation of terraform to build your network:

```bash
terraform init
terraform -out packer_builder.plan -var="region=$REGION" -var="profile=$PROFILE"
```

Example:

```bash
terraform init
terraform -out packer_builder.plan -var="region=us=east=1" -var="profile=saml"
```

Example for just building a server:

```bash
build_server.sh -r us-east-1 -b liampackerbucket -p saml
```

There is no error checking on build_Server.sh, so please make sure you're using a correct profile, bucket that you own and can read/write, and a real aws region.

Terraform and build_server should be ran in the same directory. As build_server needs to query your terraform statefile to get it's assets.

RemoteBuildAgent has SSM on it, so you can 'aws ssm start-session' into it.

RemoteBuildAgent executes "remote_build_script.sh" on boot, passed in via EC2 userdata

RemoteBuildAgent's currently do not die by themselves. if you are done with them, you can stop/terminate the instance but they will attempt to build again at boot. You can stop with these cli's, or through the console:

```bash
aws ec2 describe-instances --query "Reservations[*].Instances[*].{Instance:InstanceId}" --filters "Name=tag:Name,Values=RemoteBuildAgent" --output text
aws ec2 stop-instances --instance-ids $YOUR_INSTANCE_IDS
```


Packer log files are currently written to /var/tmp/packer.log on RemoteBuildAgent. Currently you will have to retreive your new AMI from this.

remote_build_script.sh has a bucket name hardcoded at  on line 8 and 16. This will be remediated later.

I consciously made it so that the bucket exists outside of terraform so that it persist across environmental re-creations.

ssm-user is a sudoer, remember.

I always try to use the latest 64bit Amazon Linux 2 as a base.

Please note that RemoteBuildAgent has a very high level of privilege, and this introduces a not-insignificant risk.
I would never advise taking this as-is to a prod environment without considerations for how these IAM entitlements impact your organization.


## Notes

I learned a ton doing this and had a lot of fun. I hope it is useful for someone.

Please check out the terraform, packer and AWS docs for more info.