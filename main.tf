provider "aws" {
    region = "us-east-2"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}

#Create VPC
resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
      Name = "${var.env_prefix}-vpc"
  }
}
#Create Subnet
resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
      Name = "${var.env_prefix}-subnet-1"
  }
}

#here w created custom route table
/* resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name = "${var.env_prefix}-rtb"
  }
} */

#here we create route table association
/* resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id = aws_subnet.myapp-subnet-1.id
  route_table_id = aws_route_table.myapp-route-table.id
}
 */

#create internet gateway
resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name = "${var.env_prefix}-igw"
  }
}  


#add internet gateway to main route table

resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
      Name = "${var.env_prefix}-main-rtb"
  }
}

#create a security group
resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id
  #inbound request for ssh
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
  }
  #inbound request for machines
  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #outbound request
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

    tags = {
      Name = "${var.env_prefix}-sg"
  }
} 

#AMI EC2 instance filter to get image ID
data "aws_ami" "lastest-amazon-linux-image" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

#before we create instance, here we test filter with output resource

/* output "aws_ami_id" {
  value = data.aws_ami.lastest-amazon-linux-image.id
} */

#this output resource gives us the public IP for the ec2 which created
output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}

# automate create key-pair with terraform
resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location)
}

#Create instance AMI EC2 
#we make here dynamic because ami id may change and we need to modify it here
resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.lastest-amazon-linux-image.id
  instance_type = var.instance_type

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]
  availability_zone = var.avail_zone

  #to access this instance from browser as well as via SSH
  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

# This will start a shell script and run commands to update and install docker
# out file way
  user_data = file("entry-script.sh")
  #in file way
/*               <<EOF
                  #!/bin/bash
                  sudo yum update -y %% sudo yum install -y docker
                  sudo systemctl start docker
                  sudo usermod -aG docker ec2-user
                  docker run -p 8080:80 nginx
                EOF */

  tags = {
      Name = "${var.env_prefix}-server"
  }

}
