# Setting up infrastructure on AWS using Terraform

![image](https://github.com/ShubhamRRana/Terraform-Project-/assets/96970537/f1553753-2426-4257-97dc-a87debec1584)

1. AWS Cloud has VPC.
2. VPC has 2 public subnets with each having one EC2 instance configured using iam rule.
3. VPC is connected of internet gateway so that internet can access the instances created.
4. Have route tables to define that this internet gateway should be connected to the particular subnet.
5. Put the EC2 instances behind the load balancer and give them s3 access. 
