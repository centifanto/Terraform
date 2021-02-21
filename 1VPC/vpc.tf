provider "aws" {
  #here you can use hard coded credentials, or AWS CLI profile credentials
  access_key = "123456789"
  secret_key = "123456789123456789"
  #OR
  #profile = "TF_demo"
  
  region  = var.region
}

variable "region" {
}

variable "vpc_cidr" {
}

#get account number
data "aws_caller_identity" "current" {}

# Create VPC
resource "aws_vpc" "Main" {
    cidr_block = var.vpc_cidr
    instance_tenancy = "default"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
          Name = "Main VPC"
    }
}

#Generate CIDR blocks
locals {
  cb1 = cidrsubnet(var.vpc_cidr, 3, 0)
  cb2 = cidrsubnet(var.vpc_cidr, 3, 1)
  cb3 = cidrsubnet(var.vpc_cidr, 3, 2)
  cb4 = cidrsubnet(var.vpc_cidr, 3, 3)
  cb5 = cidrsubnet(var.vpc_cidr, 3, 4)
  cb6 = cidrsubnet(var.vpc_cidr, 3, 5)
  cb7 = cidrsubnet(var.vpc_cidr, 3, 6)
  cb8 = cidrsubnet(var.vpc_cidr, 3, 7)
} 


#Create PRIVATE Subnets
resource "aws_subnet" "SOUTH-1" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "${local.cb1}"
  availability_zone = "us-east-1a"
  tags = {
    Name = "SOUTH 1 - ${local.cb1}"
  }
}
resource "aws_subnet" "SOUTH-2" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "${local.cb2}"
  availability_zone = "us-east-1b"
  tags = {
    Name = "SOUTH 2 - ${local.cb2}"
  }
}
resource "aws_subnet" "SOUTH-3" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "${local.cb3}"
  availability_zone = "us-east-1c"
  tags = {
    Name = "SOUTH 3 - ${local.cb3}"
  }
}
resource "aws_subnet" "SOUTH-4" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "${local.cb4}"
  availability_zone = "us-east-1d"
  tags = {
    Name = "SOUTH 4 - ${local.cb4}"
  }
}

#Create PUBLIC Subnets
resource "aws_subnet" "NORTH-1" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "${local.cb5}"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true 
  tags = {
    Name = "NORTH 1 - ${local.cb5}"
  }
}
resource "aws_subnet" "NORTH-2" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "${local.cb6}"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true  
  tags = {
    Name = "NORTH 2 - ${local.cb6}"
  }
}
resource "aws_subnet" "NORTH-3" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "${local.cb7}"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = true  
  tags = {
    Name = "NORTH 3 - ${local.cb7}"
  }
}
resource "aws_subnet" "NORTH-4" {
  vpc_id     = aws_vpc.Main.id
  cidr_block = "${local.cb8}"
  availability_zone = "us-east-1d"
  map_public_ip_on_launch = true  
  tags = {
    Name = "NORTH 4 - ${local.cb8}"
  }
}

#Create IGW and attach to VPC
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.Main.id
  tags = {
    Name = "IGW"
  }
}
#Allocate EIP for NAT Gateway
resource "aws_eip" "NATGW-EIP" {
  vpc      = true
  tags = {
    Name = "NATGW-EIP"

  }
}
#Create NAT Gateway in Public NORTH 4
resource "aws_nat_gateway" "NATGW" {
  allocation_id = aws_eip.NATGW-EIP.id
  subnet_id     = aws_subnet.NORTH-4.id

  tags = {
    Name = "NATGW"
  }
}

#Create peering connnection to OH
#resource "aws_vpc_peering_connection" "to_OH" {
#  peer_owner_id  = "${data.aws_caller_identity.current.account_id}"
#  peer_vpc_id = "vpc-123456789"
#  vpc_id      = aws_vpc.Main.id
#  peer_region   = "us-east-2"
#  tags = {
#    Name = "to OH"
#  }
#}


#Create Public Route Table
resource "aws_route_table" "NORTH-RT" {
  vpc_id = aws_vpc.Main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  route {
    cidr_block = "10.1.0.0/24"
    vpc_peering_connection_id  = aws_vpc_peering_connection.to_OH.id
  }

    tags = {
    Name = "NORTH-RT"
  }
}

#Associate Public Subnets to Public Route Table
resource "aws_route_table_association" "NORTH-1-NORTH-RT" {
  subnet_id      = aws_subnet.NORTH-1.id
  route_table_id = aws_route_table.NORTH-RT.id
}
resource "aws_route_table_association" "NORTH-2-NORTH-RT" {
  subnet_id      = aws_subnet.NORTH-2.id
  route_table_id = aws_route_table.NORTH-RT.id
}
resource "aws_route_table_association" "NORTH-3-NORTH-RT" {
  subnet_id      = aws_subnet.NORTH-3.id
  route_table_id = aws_route_table.NORTH-RT.id
}
resource "aws_route_table_association" "NORTH-4-NORTH-RT" {
  subnet_id      = aws_subnet.NORTH-4.id
  route_table_id = aws_route_table.NORTH-RT.id
}

#Create Private Route Table
resource "aws_route_table" "SOUTH-RT" {
  vpc_id = aws_vpc.Main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NATGW.id
  }

  route {
    cidr_block = "10.1.0.0/24"
    vpc_peering_connection_id  = aws_vpc_peering_connection.to_OH.id
  }
    
  tags = {
    Name = "PRIVATE-RT"
  }
}

#Associate Private Subnets to Private Route Table
resource "aws_route_table_association" "SOUTH-1-SOUTH-RT" {
  subnet_id      = aws_subnet.SOUTH-1.id
  route_table_id = aws_route_table.SOUTH-RT.id
}
resource "aws_route_table_association" "SOUTH-2-SOUTH-RT" {
  subnet_id      = aws_subnet.SOUTH-2.id
  route_table_id = aws_route_table.SOUTH-RT.id
}
resource "aws_route_table_association" "SOUTH-3-SOUTH-RT" {
  subnet_id      = aws_subnet.SOUTH-3.id
  route_table_id = aws_route_table.SOUTH-RT.id
}
resource "aws_route_table_association" "SOUTH-4-SOUTH-RT" {
  subnet_id      = aws_subnet.SOUTH-4.id
  route_table_id = aws_route_table.SOUTH-RT.id
}

#Create and associate DHCP Options Set
resource "aws_vpc_dhcp_options" "domain-local" {
  domain_name          = "domain.local"
  domain_name_servers  = ["10.0.0.10"]
  ntp_servers          = ["10.0.0.10"]
}
resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = aws_vpc.Main.id
  dhcp_options_id = aws_vpc_dhcp_options.domain-local.id
}


#Create OpenVPN SG
resource "aws_security_group" "OpenVPN" {
  vpc_id = aws_vpc.Main.id
  name = "OpenVPN Access Group"
  description = "OpenVPN Access Group"
    ingress {
    from_port = 943
    to_port = 943
    protocol = "tcp"
    cidr_blocks = ["1.1.1.1/32"]
    description = "Admin"
  }    
  ingress {
    from_port = 1194
    to_port = 1194
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Create Default.AWS SG
resource "aws_security_group" "Default-AWS" {
  vpc_id = aws_vpc.Main.id
  name = "Default.AWS Group"
  description = "Default.AWS Group"
    ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["1.1.1.1/32"]
    description = "Admin"
  }    
    
    ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["10.1.0.0/24"]
    description = "VPC - OH"
  }    

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}