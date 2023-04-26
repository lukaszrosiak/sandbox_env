#
# vpc data from resource account
#

data "aws_vpc" "vpc" {
  provider = aws.resource_account
  tags = {
    Name = var.vpc_name
  }
}

output "vpc_id" {
  value=data.aws_vpc.vpc.id
}

data "aws_subnets" "public_subnet_ids" {
  provider = aws.resource_account

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    function = "public"
  }

}

output "subnet_id" {
  value=data.aws_subnets.public_subnet_ids.ids[0]
}


data "aws_caller_identity" "resource_account" {
  provider = aws.resource_account
}

data "aws_caller_identity" "network_account" {
  provider = aws.network_account
}

data "aws_region" "resource_account" {
     provider = aws.resource_account
}

data "aws_region" "network_account" {
     provider = aws.network_account
}

data "aws_eip" "vpn-address" {
  filter {
    name   = "tag:Name"
    values = ["vpn-test"]
  }
}

output "elastic_ip_id" {
  value=data.aws_eip.vpn-address.id
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn2-ami-kernel-*-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

data "aws_ami" "amazon_linux1" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

output "ami_id" {
  value=data.aws_ami.amazon_linux1
}