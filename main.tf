#################
# Provider
#################
provider "aws" {
  version = "~> 2.0"
  region = var.region
}


variable "stack_name" {}
variable "instance_type" {}
variable "region" {}
variable "vpc_id" {}
variable "subnet_id" {}
variable "key_pair" {}
variable "amis" {
  type = map(string)
  default = {
    "eu-north-1" = "ami-0c947472aff72870d"
    "ap-south-1" = "ami-040c7ad0a93be494e"
    "eu-west-3" = "ami-05a51ff00c1d77571"
    "eu-west-2" = "ami-00e8b55a2e841be44"
    "eu-west-1" = "ami-040ba9174949f6de4"
    "ap-northeast-2" = "ami-02b3330196502d247"
    "me-south-1" = "ami-0207e6a966ca96048"
    "ap-northeast-1" = "ami-0064e711cbc7a825e"
    "ca-central-1" = "ami-007dbcbce3118978b"
    "ap-east-1" = "ami-ff4d378e"
    "ap-southeast-1" = "ami-00942d7cd4f3ca5c0"
    "ap-southeast-2" = "ami-08a74056dfd30c986"
    "eu-central-1" = "ami-0f3a43fbf2d3899f7"
    "us-east-1" = "ami-00dc79254d0461090"
    "us-east-2" = "ami-00bf61217e296b409"
    "us-west-1" = "ami-024c80694b5b3e51a"
    "us-west-2" = "ami-0a85857bfc5345c38"
  }
}

#################
# Data
#################
data "aws_iam_policy_document" "DataBrokerAssumeRolePolicyDocumentData" {
  statement {
    actions = [
      "sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "DataBrokerIamPolicyDocumentData" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation",
      "s3:GetBucketTagging",
      "s3:GetBucketNotification",
      "s3:PutBucketNotification",
      "s3:PutObjectTagging"]

    resources = [
      "*"]
  }
}

data "aws_iam_policy_document" "DataBrokerSpotFleetAssumeRolePolicyDocumentData" {
  statement {
    actions = [
      "sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "spotfleet.amazonaws.com"]
    }
  }
}

data "aws_vpc" "DataBrokerVpc" {
  id = var.vpc_id
}
#################
# Resources
#################
resource "aws_iam_role" "DataBrokerIamRole" {
  name = var.stack_name
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.DataBrokerAssumeRolePolicyDocumentData.json
}

resource "aws_iam_role_policy" "DataBrokerIamRolePolicy" {
  name = "cloudsync_${var.stack_name}"
  role = aws_iam_role.DataBrokerIamRole.id
  policy = data.aws_iam_policy_document.DataBrokerIamPolicyDocumentData.json
}

resource "aws_iam_role" "DataBrokerSpotFleetIamRole" {
  name = "DataBrokerSpotFleetIamRole"
  path = "/"
  assume_role_policy = data.aws_iam_policy_document.DataBrokerSpotFleetAssumeRolePolicyDocumentData.json
}

resource "aws_iam_role_policy_attachment" "DataBrokerSpotFleetIamRolePolicyAttachment" {
  role = aws_iam_role.DataBrokerSpotFleetIamRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

resource "aws_iam_instance_profile" "DataBrokerInstanceProfile" {
  name = "RabiDataBrokerInstanceProfile"
  role = aws_iam_role.DataBrokerIamRole.name
}

resource "aws_security_group" "DataBrokerSecurityGroup" {
  name = var.stack_name
  description = "Security group for the NetApp Data Broker"
  vpc_id = data.aws_vpc.DataBrokerVpc.id
  tags = {
    Name = "cloudsync_${var.stack_name}"
  }
}

resource "aws_security_group_rule" "outbound_allow_all" {
  security_group_id = aws_security_group.DataBrokerSecurityGroup.id
  type = "egress"
  from_port = 0
  to_port = 65535
  protocol = "all"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "allow_all" {
  security_group_id = aws_security_group.DataBrokerSecurityGroup.id
  type = "ingress"
  from_port = 0
  to_port = 65535
  protocol = "all"
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_spot_fleet_request" "DataBrokerSpotFleetRequest" {
  iam_fleet_role = aws_iam_role.DataBrokerSpotFleetIamRole.arn
  target_capacity = 1
  replace_unhealthy_instances = true

  launch_specification {
    ami = var.amis[var.region]
    subnet_id = var.subnet_id
    ebs_optimized = true

    ebs_block_device {
      device_name = "/dev/xvda"
      volume_type = "gp2"
      volume_size = "10"
    }

    instance_type = var.instance_type
    iam_instance_profile_arn = aws_iam_instance_profile.DataBrokerInstanceProfile.arn

    key_name = var.key_pair

    tags = {
      Name = var.stack_name
    }

    associate_public_ip_address = true

    vpc_security_group_ids = [
      aws_security_group.DataBrokerSecurityGroup.id]

    user_data = file("userdata.sh")
  }

  wait_for_fulfillment = true
  terminate_instances_with_expiration = true
}