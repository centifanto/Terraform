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

#create SSM role
resource "aws_iam_role" "ec2_ssm" {
  name = "EC2_SSM"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#attach AmazonSSMManagedInstanceCore policy
resource "aws_iam_role_policy_attachment" "sto-readonly-role-policy-attach" {
  role       = "EC2_SSM"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#create profile for EC2
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "EC2_SSM"
  role = "EC2_SSM"
}

#create EBS encryption key
resource "aws_kms_key" "ebs_key" {
  description = "EBS encrypt"
}

resource "aws_kms_alias" "ebs_key" {
  name          = "alias/Terraform-demo-EBS-key"
  target_key_id = aws_kms_key.ebs_key.key_id
}

# Get latest WS2019 AMI and launch DC1
data "aws_ami" "latest-WS2019" {
most_recent = true
owners = ["amazon"] 

  filter {
      name   = "name"
      values = ["Windows_Server-2019-English-Full-Base*"]
  }
}

resource "aws_instance" "DC1" {
    ami = data.aws_ami.latest-WS2019.id
    instance_type = "t3.small"
    disable_api_termination = "true"
    key_name = "<key pair>"
    subnet_id = data.terraform_remote_state.vpc.outputs.subnet_south-1
    private_ip = "10.0.0.10"
    ebs_optimized = "true"
    iam_instance_profile = "EC2_SSM"
    vpc_security_group_ids = [
        data.terraform_remote_state.vpc.outputs.default-aws-sg
      ]
    tags = {
      Name =  "DC1.domain.local"
      OS   =  "Windows"
      }
    volume_tags = {
      Name =  "DC1-C-x"
      backup-daily = "7-day"
      }
    root_block_device {
          delete_on_termination = true
          encrypted = true
          kms_key_id = aws_kms_key.ebs_key.id
          volume_size = 100
          volume_type = "gp3"
          #if you want to adjust the iops or throughput for the gp3 volume
          #iops        = 3000
          #throughput  = 200
      
      #if this DC is also going to be a file server, create a second volume for Data
      
      #     ebs_block_device {
      #     device_name = "xvdf"
      #     delete_on_termination = true
      #     encrypted = true
      #     kms_key_id = aws_kms_key.ebs_key.id
      #     volume_size = 100
      #     volume_type = "gp3"
      #     iops        = 3000
      #     throughput  = 200
      # }
    }
}

resource "aws_instance" "IT01" {
    ami = data.aws_ami.latest-WS2019.id
    instance_type = "t3.micro"
    disable_api_termination = "true"
    key_name = "<key pair>"
    subnet_id = data.terraform_remote_state.vpc.outputs.subnet_south-2
    ebs_optimized = "true"
    iam_instance_profile = "EC2_SSM"
    vpc_security_group_ids = [
        data.terraform_remote_state.vpc.outputs.default-aws-sg
      ]
    tags = {
      Name =  "DC1.domain.local"
      OS   =  "Windows"
      }
    volume_tags = {
      Name =  "DC1-C-x"
      backup-daily = "7-day"
      }
    root_block_device {
          delete_on_termination = true
          encrypted = true
          kms_key_id = aws_kms_key.ebs_key.id
          volume_size = 75
          volume_type = "gp3"
          #if you want to adjust the iops or throughput for the gp3 volume
          #iops        = 3000
          #throughput  = 200
    }
}

#Get latest OpenVPN Access Server AMI and launch. 
## seems to not be pulling latest AMI, confirm?
data "aws_ami" "latest-OpenVPN" {
most_recent = true
owners = ["679593333241"] 

  filter {
      name   = "name"
      values = ["OpenVPN Access Server*"] 
  }
}

resource "aws_instance" "VPN1" {
    ami = data.aws_ami.latest-OpenVPN.id
    instance_type = "t3.micro"
    disable_api_termination = "true"
    key_name = "<key pair>" #make sure to change!
    subnet_id = data.terraform_remote_state.vpc.outputs.subnet_north-4
    ebs_optimized = "true"
    iam_instance_profile = "EC2_SSM"
    vpc_security_group_ids = [
        data.terraform_remote_state.vpc.outputs.openvpn-sg
      ]
    tags = {
      Name =  "VPN1.domain.local"
      OS = "Linux"
      }
    volume_tags = {
      Name =  "VPN1"
      backup-daily = "7-day"
      }
    root_block_device {
          delete_on_termination = true
          encrypted = true
          kms_key_id = aws_kms_key.ebs_key.id
          volume_size = 10
          volume_type = "gp3"
      }
}