provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "myVPC" {
  cidr_block = var.cidr
  tags = {
    Name = "ProjectVPC"
  }
}

resource "aws_subnet" "mySubnet1" {
  vpc_id                  = aws_vpc.myVPC.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "ProjectSubnet1"
  }
}

resource "aws_subnet" "mySubnet2" {
  vpc_id                  = aws_vpc.myVPC.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "ProjectSubnet2"
  }
}

#   Internet Gateway is created so that the internet can access the resources created in the VPC
#   That's why here we have provdided the vpc id
resource "aws_internet_gateway" "myIG" {
  vpc_id = aws_vpc.myVPC.id
  tags = {
    Name = "ProjectInternetGateway"
  }
}

#   Route table defines how the traffic has to flow in the subnet
resource "aws_route_table" "myRT" {
  vpc_id = aws_vpc.myVPC.id
  tags = {
    Name = "ProjectRouteTable"
  }

  # We have a public subnet now after this we will take this route table which has the destination
  # as the internet gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myIG.id
  }

}

# Here now will attach the above route table created to the two public subnets that we have created
# Without this step you will not get the traffic to the subnets.  
resource "aws_route_table_association" "myRTA1" {

  # The subnet you want the RT to attach to
  subnet_id = aws_subnet.mySubnet1.id
  # And where you want it too be attached
  route_table_id = aws_route_table.myRT.id

}

resource "aws_route_table_association" "myRTA2" {
  subnet_id      = aws_subnet.mySubnet2.id
  route_table_id = aws_route_table.myRT.id
}

#  First we have to create security groups that we are going to use for EC2 instances and load balancer
resource "aws_security_group" "mySG" {
  name   = "web-sg"
  vpc_id = aws_vpc.myVPC.id

  #ingress means inbound rule
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"] #This means everyone can access this instance
    protocol    = "tcp"
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"] #This means everyone can access this instance
    protocol    = "tcp"
  }

  #egress means outbound rule
  egress {
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1" # semantically equivalent to all ports
  }
}

# Creaing S3 bucket
resource "aws_s3_bucket" "myS3" {
  bucket = "shubham-rana-3360-bucket"
}

# Now creating instances inside the VPC we have created
resource "aws_instance" "webServer1" {
  ami                    = "ami-0f58b397bc5c1f2e8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mySG.id]
  subnet_id              = aws_subnet.mySubnet1.id
  tags = {
    Name = "Subnet1-Instance"
  }
}

resource "aws_instance" "webServer2" {
  ami                    = "ami-0f58b397bc5c1f2e8"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.mySG.id]
  subnet_id              = aws_subnet.mySubnet2.id
  tags = {
    Name = "Subnet2-Instance"
  }
}

# Now we are going to load balance the traffic using terraform
# Here we are using "Application Load Balancer" type
resource "aws_lb" "myLB" {
  name               = "myALB"
  internal           = false # This means that the LB is public
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mySG.id]
  # Here we are assigning the LB's to the subnet, because LB is managing the traffic to 2 instances
  subnets = [aws_subnet.mySubnet1.id, aws_subnet.mySubnet2.id]
  tags = {
    Name = "Web"
  }
}

# Now we are creating a target group, which will tell load balancer that this is your target
# if some is callig you then send the request to this target, and target will send the traffic to 
# the instance
resource "aws_lb_target_group" "myTG" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myVPC.id
  health_check {
    path = "/"
    port = "traffic-port"
  }
}

# Above target group is ready but is not attached to the instances
# So now we will attach it to the instance
resource "aws_lb_target_group_attachment" "myAttach1" {
  target_group_arn = aws_lb_target_group.myTG.arn
  target_id        = aws_instance.webServer1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "myAttach2" {
  target_group_arn = aws_lb_target_group.myTG.arn
  target_id        = aws_instance.webServer2.id
  port             = 80
}

# This LB is actually attached to the target group
# We will do that by defining a listener rule
resource "aws_lb_listener" "myListener" {
  load_balancer_arn = aws_lb.myLB.arn
  port              = 80
  protocol          = "HTTP"

  # Default action can be forward or redirect or show a particulat response

  default_action {
    target_group_arn = aws_lb_target_group.myTG.arn
    type             = "forward"
  }
}
