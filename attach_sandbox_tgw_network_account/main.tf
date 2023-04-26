provider "aws" {
  region                   = "eu-west-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "dev-network"
}

provider "aws" {
  alias                    = "resource_account"
  region                   = "eu-west-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "sandbox"
}

provider "aws" {
  alias                    = "network_account"
  region                   = "eu-west-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "dev-network"
}


variable "ns_side_asn" { default = "64512" }
variable "ns_default_tgw_name" { default = "network-service-default-tgw" }
variable "ns_default_tgw_route_table_name" { default = "test" }
variable "ns_create_resource_vpc" { default = "true" }
variable "ns_identify_tag_name" { default = "TGW-ATID" }
variable "ns_identify_tag_name_vpc" { default = "TGW-ATID" }
variable "ns_ipv6_support" { default = "false" }
variable "ns_shared_service_name" { default = "shared-network-service" }
variable "vpc_attachment" { default = [] }
variable "ns_endpoints" { default = ["s3", "ssm", "ssmmessages", "ec2messages"] }
variable "ns_private_hosted_zone" { default = { "cesaws-dev-eviden.org" = { comment = "poc-network-service.company.net", tags = { Function = "functional test service-network-dns" } } } }


module "shared-service-data-resource" {
  providers = {
    aws.resource_account = aws.resource_account
    aws.network_account  = aws.network_account
  }

  source = "github.com/GLB-CES-PublicCloud/shared-service-data?ref=v4.0.5"

  # to identify the vpc
  vpc_tag_name  = var.ns_identify_tag_name_vpc
  vpc_tag_value = "tgw-test"

  # to identyfy the subnets and route tables
  route_tgattach_subnet = true
  route_intra_subnet    = true
  identify_tag_name     = var.ns_identify_tag_name

  # to identify transit gateway data
  tgw_name             = var.ns_default_tgw_name
  tgw_route_table_name = "test"

  # non default default route for route tables of private networks
  default_ipv4_route_private = "10.0.0.0/8"

  # subnets hosting tgw interfaces
  subnets_to_attach = "tgattach"

  # enable phz-association for vpc
  endpoints            = var.ns_endpoints
  private_hosted_zones = var.ns_private_hosted_zone

  # enable route propagation to inspection_vpc 
  propagate_inspect = true
}

output "vpc_attachment_map" {
  value = module.shared-service-data-resource
}

output "local_att" {
  value=module.shared-service-data-resource.local_att
}


variable "attach_vpc" {default= true}

module "attach_vpc_to_tgw" {
  count = var.attach_vpc ? 1 : 0
  providers = {

    aws.resource_account = aws.resource_account
    aws.network_account  = aws.network_account
  }
  
  source="github.com/GLB-CES-PublicCloud/atos-transitgateway-peer?ref=feature-cesaws-1241"
  #source = "../../atos-transitgateway-peer"

  vpc_attachments=module.shared-service-data-resource.vpc_attachemnet_data
  tgw_id =module.shared-service-data-resource.tgw-id

 local_att = module.shared-service-data-resource.local_att
 local_rt = module.shared-service-data-resource.local_rt
 remote_att = module.shared-service-data-resource.remote_att
 remote_rt = module.shared-service-data-resource.remote_rt
 map_rt_to_attachment_local = module.shared-service-data-resource.map_rt_to_attachment_local
 map_rt_to_attachment_remote = module.shared-service-data-resource.map_rt_to_attachment_remote
 list_remote_rt_to_local_attachments = module.shared-service-data-resource.list_remote_rt_to_local_attachments


}

output "tgw-attachment" {
  value=try(module.attach_vpc_to_tgw[0],"")
}