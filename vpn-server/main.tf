provider "aws" {
  region                   = "eu-west-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "sandbox"
}

provider "aws" {
  alias = "resource_account"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "sandbox"
}

provider "aws" {
  alias = "network_account"
  region                   = "eu-west-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "dev-network"
}