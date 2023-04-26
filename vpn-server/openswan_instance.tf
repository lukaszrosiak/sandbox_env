variable "tags" {default={}}


module "security_group_vpn" {
  source = "github.com/GLB-CES-PublicCloud/terraform-aws-securitygroup.git?ref=v4.0.0"

  name        = "openswan-2"
  description = "Security Group for vpn"
  vpc_id      = data.aws_vpc.vpc.id

  ingress_with_cidr_blocks = [
    {
      rule        = "ssh-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "all-icmp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 500
      to_port     = 500
      protocol    = "udp"
      description = "Tunnel1VgwOutsideIpAddress"
      cidr_blocks = "${var.tunnel1_outside_ip_address}/32"
    },
    {
      from_port   = 500
      to_port     = 500
      protocol    = "udp"
      description = "Tunnel2VgwOutsideIpAddress"
      cidr_blocks = "${var.tunnel2_outside_ip_address}/32"
    },

    {
      from_port   = 4500
      to_port     = 4500
      protocol    = "udp"
      description = "Tunnel1VgwOutsideIpAddress"
      cidr_blocks = "${var.tunnel1_outside_ip_address}/32"
    },
    {
      from_port   = 4500
      to_port     = 4500
      protocol    = "udp"
      description = "Tunnel2VgwOutsideIpAddress"
      cidr_blocks = "${var.tunnel2_outside_ip_address}/32"
    },

   

  ]
  egress_rules = ["all-all"]
}


resource "aws_instance" "vpn" {
  ami                         = data.aws_ami.amazon_linux.id
  source_dest_check           = false
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnets.public_subnet_ids.ids[0]
  vpc_security_group_ids      = [module.security_group_vpn.this_security_group_id]
  associate_public_ip_address = false
  key_name                    = "work_np"
  tags                        = merge({ Name = "openswan-vpn-host-2" }, var.tags)
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.id
  user_data                   = <<EOF
		#! /bin/bash
    
    sudo  yum install openswan -y
    sudo echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sudo echo "net.ipv4.conf.default.rp_filter = 0" >> /etc/sysctl.conf
    sudo echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
    sudo sysctl -p
    sudo cp -rp /home/ec2-user/.ssh /root/
    sudo chown -R root.root /root/.ssh
    
    sudo echo "${data.aws_eip.vpn-address.public_ip} ${var.tunnel1_outside_ip_address} : PSK \"${var.psk_tunnel1}\"" > /etc/ipsec.d/aws.secrets
    sudo echo "${data.aws_eip.vpn-address.public_ip} ${var.tunnel2_outside_ip_address} : PSK \"${var.psk_tunnel2}\"" >> /etc/ipsec.d/aws.secrets

    sudo echo "conn Tunnel1
      authby=secret
      auto=start
      left=%defaultroute
      leftid=${data.aws_eip.vpn-address.public_ip}
      right=${var.tunnel1_outside_ip_address}
      type=tunnel
      ikelifetime=8h
      keylife=1h
      phase2alg=aes_gcm
      ike=aes256-sha2_256;dh14
      keyingtries=%forever
      keyexchange=ike
      leftsubnet=${var.cidr_left}
      rightsubnet=${var.cidr_right}
      dpddelay=10
      dpdtimeout=30
      dpdaction=restart_by_peer
    " > /etc/ipsec.d/aws.conf

    sudo systemctl enable ipsec 
    sudo systemctl start ipsec 

	EOF
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }
}

output "ec2_vpn-2" {
  value =  {
    elastic_ip  = data.aws_eip.vpn-address.public_ip
    public_dns  = aws_instance.vpn.public_dns
    private_ip  = aws_instance.vpn.private_ip
    private_dns = aws_instance.vpn.private_dns
  } 
}

resource "aws_eip_association" "demo-eip-association" {
  instance_id   = aws_instance.vpn.id
  allocation_id = data.aws_eip.vpn-address.id
}

# ---------- EC2 IAM ROLE - SSM and S3 access ----------
# IAM instance profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_vpn-instance-2"
  role = aws_iam_role.role_ec2.id
}

# IAM role
resource "aws_iam_role" "role_ec2" {
  name               = "ec2_ssm_role_vpn-instance-2"
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
  name       = "ssm_iam_role_policy_vpn-instance"
  roles      = [aws_iam_role.role_ec2.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy_attachment" "s3_readonly_policy_attachment" {
  name       = "s3_readonly_policy_attachment_vpn-instance"
  roles      = [aws_iam_role.role_ec2.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

