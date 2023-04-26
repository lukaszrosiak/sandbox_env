provider "aws" {
  region                   = "eu-west-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "sandbox"
}

variable "tags" { default = { cesaws = "sandbox" } }
variable "identify_tag_name" { default = "TGW-ATID" }
variable "identify_tag_name_vpc" { default = "TGW-ATID" }

variable "create_bastion" { default = true }
variable "create_private" { default = true }
variable "create_public_nets" { default =false }

variable "intra_route_table_tags" { default = {} }
variable "public_route_table_tags" { default = {} }
variable "tgattach_route_table_tags" { default = {} }

variable "intra_subnet_tags" { default = {} }
variable "public_subnet_tags" { default = {} }
variable "private_subnet_tags" { default = {} }

module "sandbox_vpc" {
  source                    = "github.com/GLB-CES-PublicCloud/terraform-aws-vpc?ref=v4.0.0"
  name                      = "sandbox-vpc"
  cidr                      = "172.1.0.0/16"
  vpc_tags                  = merge(var.intra_route_table_tags, { "${var.identify_tag_name_vpc}" = "tgw-test" })
  azs                       = ["eu-west-1a", "eu-west-1b"]
  intra_subnets             = ["172.1.0.0/24", "172.1.1.0/24"]
  public_subnets            = var.create_bastion || var.create_public_nets == true ?  ["172.1.3.0/24", "172.1.4.0/24"] : []
  tgattach_subnets          = ["172.1.6.0/24", "172.1.7.0/24"]
  intra_subnet_tags         = merge(var.intra_route_table_tags, { "${var.identify_tag_name}" = "intra" , function = "private"})
  tgattach_subnet_tags      = merge(var.tgattach_route_table_tags, { "${var.identify_tag_name}" = "tgattach" ,function="tgattach"})
  public_subnet_tags        = merge(var.public_route_table_tags, { "${var.identify_tag_name}" = "intra" , function="public"})
  intra_route_table_tags    = merge(var.intra_route_table_tags, { "${var.identify_tag_name}" = "private" })
  public_route_table_tags   = merge(var.public_route_table_tags, { "${var.identify_tag_name}" = "public" })
  tgattach_route_table_tags = merge(var.tgattach_route_table_tags, { "${var.identify_tag_name}" = "tgattach" })


  create_individual_tgattach_route_tables = false
  create_individual_intra_route_tables    = false
  create_individual_public_route_tables   = false
  tags                                    = var.tags
  enable_dns_hostnames                    = true
  enable_dns_support                      = true

}


module "security_group_private" {
  create = var.create_private
  source = "github.com/GLB-CES-PublicCloud/terraform-aws-securitygroup.git?ref=v4.0.0"

  name        = "sandbox-private-sg"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.sandbox_vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = module.sandbox_vpc.vpc_cidr_block
    },
    {
      rule        = "https-443-tcp"
      cidr_blocks = module.sandbox_vpc.vpc_cidr_block
    }
  ]
  egress_rules = ["all-all"]
}

module "security_group_public" {
  create = var.create_bastion
  source = "github.com/GLB-CES-PublicCloud/terraform-aws-securitygroup.git?ref=v4.0.0"

  name        = "sandbox-public-sg"
  description = "Security group bastion EC2 instance"
  vpc_id      = module.sandbox_vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_rules = ["all-all"]
}

resource "aws_instance" "bastion" {
  count                       = var.create_bastion == true ? 1 : 0
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = module.sandbox_vpc.public_subnets[0]
  vpc_security_group_ids      = [module.security_group_public.this_security_group_id]
  associate_public_ip_address = true
  key_name                    = "work_np"
  tags                        = merge({ Name = "bastion-host" }, var.tags)
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.id
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  user_data                   = <<EOF
		#! /bin/bash
    sudo hostnamectl set-hostname bastion-host
  EOF

}

resource "aws_instance" "private" {
  count                  = var.create_private == true ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = module.sandbox_vpc.intra_subnets[0]
  vpc_security_group_ids = [module.security_group_private.this_security_group_id]
  key_name               = "work_np"
  tags                   = merge({ Name = "private-host" }, var.tags)
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.id
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data                   = <<EOF
		#! /bin/bash
    sudo hostnamectl set-hostname private-host
  EOF

  root_block_device {
    encrypted = true
  }
}



# ---------- EC2 IAM ROLE - SSM and S3 access ----------
# IAM instance profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_sandbox"
  role = aws_iam_role.role_ec2.id
}

# IAM role
resource "aws_iam_role" "role_ec2" {
  name               = "ec2_ssm_role_sandbox"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.policy_document.json
}

data "aws_iam_policy_document" "policy_document" {
  statement {
    sid     = "1"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

  }
}

# Policies Attachment to Role
resource "aws_iam_policy_attachment" "ssm_iam_role_policy_attachment" {
  name       = "ssm_iam_role_policy_attachment_sandbox"
  roles      = [aws_iam_role.role_ec2.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy_attachment" "s3_readonly_policy_attachment" {
  name       = "s3_readonly_policy_attachment_sandbox"
  roles      = [aws_iam_role.role_ec2.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
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

output "sandbox_vpc" {
  value = {
    vpc_id           = module.sandbox_vpc.vpc_id
    intra_subnet     = module.sandbox_vpc.intra_subnets
    tgattach_subnets = module.sandbox_vpc.tgattach_subnets
    public_subnet    = module.sandbox_vpc.public_subnets
    tgattach_rt_id   = module.sandbox_vpc.tgattach_route_table_ids
    public_rt_id     = module.sandbox_vpc.public_route_table_ids
    public_rt_id     = module.sandbox_vpc.intra_route_table_ids
  }
}

output "ec2_bastion" {
  value = var.create_bastion ? {
    public_ip   = aws_instance.bastion[0].public_ip
    public_dns  = aws_instance.bastion[0].public_dns
    private_ip  = aws_instance.bastion[0].private_ip
    private_dns = aws_instance.bastion[0].private_dns
  } : {}
}

output "ec2_private" {
  value = var.create_private ? { public_ip = aws_instance.private[0].public_ip
    public_dns  = aws_instance.private[0].public_dns
    private_ip  = aws_instance.private[0].private_ip
    private_dns = aws_instance.private[0].private_dns
  } : {}
}