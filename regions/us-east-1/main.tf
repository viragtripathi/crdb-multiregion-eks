# Example region deployment
module "vpc" {
  source = "../../modules/vpc"
  region = "us-east-1"
  cidr_block = "10.0.0.0/16"
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  azs = ["us-east-1a", "us-east-1b"]
}