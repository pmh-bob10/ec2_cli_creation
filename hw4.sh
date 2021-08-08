PROFILE_NAME=bob10
SSH_KEY_NAME=BoB10@ProductDev.6082
SECURITY_GROUP_NAME=BoB10ProductDev.cli.6082
EC2_INSTANCE_NAME=BoB10ProductDev.cli.6082
AMI_ID=ami-04876f29fd3a5e8ba

# create vpc
aws --profile $PROFILE_NAME ec2 create-vpc --cidr-block 10.13.0.0/16

vpc_id=$(aws --profile $PROFILE_NAME ec2 describe-vpcs --query "Vpcs[?CidrBlock == '10.13.0.0/16'].VpcId" --output text)
az1_id=$(aws --profile $PROFILE_NAME ec2 describe-availability-zones --query "AvailabilityZones[0].ZoneId" --output text)

#create subnet & igw
aws --profile $PROFILE_NAME ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.13.0.0/24 --availability-zone-id $az1_id
aws --profile $PROFILE_NAME ec2 create-internet-gateway

subnet1_id=$(aws --profile $PROFILE_NAME ec2 describe-subnets --query "(Subnets[?VpcId=='$vpc_id']|[?starts_with(CidrBlock, '10.13.0')])[0].SubnetId" --output text)
    igw_id=$(aws --profile $PROFILE_NAME ec2 describe-internet-gateways --query "(InternetGateways[?Attachments[0].State == null])[0].InternetGatewayId" --output text)

# attach igw & create rtb
aws --profile $PROFILE_NAME ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $igw_id
aws --profile $PROFILE_NAME ec2 create-route-table --vpc-id $vpc_id

rtable_id=$(aws --profile $PROFILE_NAME ec2 describe-route-tables --query "(RouteTables[?VpcId=='$vpc_id']|[?Associations[0].Main == null])[0].RouteTableId" --output text)

# associate & modify rtb
aws --profile $PROFILE_NAME ec2 create-route --route-table-id $rtable_id --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id
aws --profile $PROFILE_NAME ec2 associate-route-table --subnet-id $subnet1_id --route-table-id $rtable_id
aws --profile $PROFILE_NAME ec2 modify-subnet-attribute --subnet-id $subnet1_id --map-public-ip-on-launch

rtableA_id=$(aws --profile $PROFILE_NAME ec2 describe-route-tables "(RouteTables[?VpcId=='$vpcid']|[?Associations[0].SubnetId == '$subnetid1'])[0].Associations[0].RouteTableAssociationId --output text")

# create sg
aws --profile $PROFILE_NAME ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description $SECURITY_GROUP_NAME --vpc-id $vpc_id

sg_id=$(aws --profile $PROFILE_NAME ec2 describe-security-groups --query "(SecurityGroups[?VpcId=='$vpc_id']|[?contains(Description, '$SECURITY_GROUP_NAME')])[0].GroupId --output text")

# associate & modify sg
aws ec2 --profile bob10 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 --profile bob10 authorize-security-group-ingress --group-id $sg_id --protocol tcp --port 5000 --cidr 0.0.0.0/0

# create userdata.txt
echo '#!/bin/bash' > userdata.txt
echo ''                                                              >> userdata.txt
echo 'sudo apt update'                                               >> userdata.txt
echo 'sudo apt install python3.8 python3-pip -y'                     >> userdata.txt
echo ''                                                              >> userdata.txt
echo 'git clone https://github.com/SeungGiJeong/lecture-aws-ec2.git' >> userdata.txt
echo 'cd lecture-aws-ec2'                                            >> userdata.txt
echo ''                                                              >> userdata.txt
echo 'python3 -m pip install -r requirements.txt'                    >> userdata.txt
echo 'python3 manage.py'                                             >> userdata.txt

# create & run instance
aws --profile $PROFILE_NAME ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --key-name $SSH_KEY_NAME --security-group-ids $sg_id --subnet-id $subnet1_id --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=BoB10@$EC2_INSTANCE_NAME}]" --user-data file://./userdata.txt
