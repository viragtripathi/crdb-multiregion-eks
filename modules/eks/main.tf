
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = var.cluster_name
  cluster_version = "1.27"
  subnets         = var.private_subnet_ids
  vpc_id          = var.vpc_id

  node_groups = {
    default = {
      desired_capacity = 3
      max_capacity     = 4
      min_capacity     = 1
      instance_types   = ["t3.medium"]
    }
  }

  manage_aws_auth = true
  aws_auth_roles  = var.aws_auth_roles
}
