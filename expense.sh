#!/bin/bash

# List of instance names to be created (frontend, backend, db)
INSTANCES=("frontend" "backend" "db")

# The hosted zone for your domain in AWS Route53.
HOSTED_ZONE="kalyaneswar.online"

# The AMI ID for RHEL(assumed to be 'devops-practice' AMI).
IMAGE_ID="ami-09c813fb71547fc4f"

# The security group ID which allows at least SSH (port 22) access to the instances.
SG_ID="sg-087068de447654b44"

# Fetch the hosted zone ID from AWS Route53 using the hosted zone name
ZONE_ID=$(aws route53 list-hosted-zones --query "HostedZones[?Name == '$HOSTED_ZONE.'].Id" --output text)

# Check if the hosted zone exists and extract its ID
if [ -n "$ZONE_ID" ]; then
    echo "Hosted zone '$HOSTED_ZONE' exists with ID: $ZONE_ID"
    # Extract the numeric hosted zone ID (strip the '/hostedzone/' part)
    ZONE_ID=$(echo $ZONE_ID | cut -d / -f3)
else
    # If hosted zone does not exist, print an error and exit the script
    echo "Hosted zone '$HOSTED_ZONE' does not exist."
    exit 1
fi

# Loop over each instance type in the INSTANCES array (frontend, backend, db)
for instance in "${INSTANCES[@]}"
do
    echo "creating instance for: $instance"
       # Default instance type for most instances
    INSTANCE_TYPE="t2.micro"

     # Change the instance type to "t3.small" for certain instances (e.g., mongodb, mysql, shipping)
    if [[ $instance == "mongodb"* || $instance == "mysql*"* || $instance == "shipping"* ]]
    then
        INSTANCE_TYPE="t3.small"
    else
        INSTANCE_TYPE="t2.micro"
    fi

     # For frontend instance, create the instance and retrieve the public IP address
    if [ ! $instance == "frontend" ]
    then
        # Create EC2 instance and get its private IP address (since it's not frontend, it's backend or db)
        IP_ADDRESS=$(aws ec2 run-instances --image-id $IMAGE_ID --instance-type $INSTANCE_TYPE --security-group-ids $SG_ID --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" --query 'Instances[0].PrivateIpAddress' --output text)
    else
         # For the frontend instance, create the instance and retrieve its public IP address
        INSTANCE_ID=$(aws ec2 run-instances --image-id $IMAGE_ID --instance-type $INSTANCE_TYPE --security-group-ids $SG_ID --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" --query 'Instances[0].InstanceId' --output text)
         # Wait for 60 seconds to allow instance to initialize before fetching the public IP
        sleep 60
         # Fetch the public IP address of the frontend instance
        IP_ADDRESS=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    fi

    # Print the IP address of the created instance
    echo "Instance: $IP_ADDRESS "
    
    # Create or update a DNS record in Route53 for the created instance (A record)
    # If the record does not exist, it will be created, otherwise, it will be updated.
    aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" \
    --change-batch '{
        "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
            "Name": "'"$instance.$HOSTED_ZONE"'",
            "Type": "A",
            "TTL": 300,
            "ResourceRecords": [
                {
                "Value": "'"$IP_ADDRESS"'"
                }
            ]
            }
        }
        ]
    }'

    # Confirmation that the DNS record has been created or updated
    echo "Record created."
done