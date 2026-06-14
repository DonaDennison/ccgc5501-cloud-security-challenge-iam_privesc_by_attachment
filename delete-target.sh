#!/bin/bash
set -eux
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y awscli curl
aws sts get-caller-identity > /tmp/whoami.txt 2>&1
aws ec2 terminate-instances --instance-ids i-0255a36523e1b98df --region us-east-1 > /tmp/terminate-result.txt 2>&1