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

#get account number
data "aws_caller_identity" "current" {}

#create S3 bucket with policy for ctrail
resource "aws_s3_bucket" "log_bucket" {
  bucket = "<customer bucket name>"
  acl    = "private"
  tags = {
    Name        = "log_bucket"
    }
}

resource "aws_s3_bucket_public_access_block" "log_bucket_block" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "s3_policy" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.log_bucket.arn}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.log_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

#create ctrail key
resource "aws_kms_key" "ctrail_key" {
  description = "Terraform demo ctrail key"
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Terraform_demo",
                    "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/cross_account_admin/admin@email.com",
                    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
                ]
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow CloudTrail to encrypt logs",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "kms:GenerateDataKey*",
            "Resource": "*"            
        },
        {
            "Sid": "Allow CloudTrail to describe key",
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "kms:DescribeKey",
            "Resource": "*"
        },
        {
            "Sid": "Allow principals in the account to decrypt log files",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": [
                "kms:Decrypt",
                "kms:ReEncryptFrom"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "kms:CallerAccount": "${data.aws_caller_identity.current.account_id}"
                }
            }
        },
        {
            "Sid": "Allow alias creation during setup",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "kms:CreateAlias",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "kms:CallerAccount": "${data.aws_caller_identity.current.account_id}"
                }
            }
        }
    ]
  }
POLICY
}

resource "aws_kms_alias" "ctrail_key" {
  name          = "alias/Terraform-demo-ctrail-key"
  target_key_id = aws_kms_key.ctrail_key.key_id
}

#create CW LG
resource "aws_cloudwatch_log_group" "CW_LG" {
  name = "Terraform-demo-Log-Group"
}

#create ctrail to cwatch role
resource "aws_iam_role" "Ctrail_Cwatch" {
  name = "Terraform_demo_Ctrail_Cwatch_Logs_role"
  assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "cloudtrail.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
EOF
}

#create ctrail to cwatch policy
resource "aws_iam_policy" "Ctrail_logs" {
  name        = "Terraform_demo_Ctrail_Cwatch_Logs_policy"
  #description = "A Terraform demo policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {           
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream"
            ],
            "Resource": [
                "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.CW_LG.id}*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.CW_LG.id}*"
            ]
        }
    ]
}   
EOF
}

resource "aws_iam_role_policy_attachment" "policy-attach" {
  role       = aws_iam_role.Ctrail_Cwatch.id
  policy_arn = aws_iam_policy.Ctrail_logs.id
}

#create ctrail
resource "aws_cloudtrail" "Ctrail" {
  name                          = "Terraform-demo-Cloudtrail"
  s3_bucket_name                = aws_s3_bucket.log_bucket.id
  include_global_service_events = true
  enable_log_file_validation = true
  is_multi_region_trail = true
  kms_key_id = aws_kms_key.ctrail_key.arn
  cloud_watch_logs_role_arn = aws_iam_role.Ctrail_Cwatch.arn
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.CW_LG.arn}:*" # CloudTrail requires the Log Stream wildcard
}