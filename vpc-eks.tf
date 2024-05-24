
provider "aws" {
    region     = var.aws_region
    profile  = "default"

}

module "eks-pod-identity-demo" {
    source = "terraform-aws-modules/vpc/aws"
    version = "5.8.0"

    name = "eks-pod-identity-demo"
    cidr = var.vpc_cidr_block
    private_subnets = var.private_subnet_cidr_blocks
    public_subnets = var.public_subnet_cidr_blocks
    azs = data.aws_availability_zones.available.names 
    
    enable_nat_gateway = true
    single_nat_gateway = true
    enable_dns_hostnames = true

    tags = {
        "kubernetes.io/cluster/${var.k8s_cluster_name}" = "shared"
    }

    public_subnet_tags = {
        "kubernetes.io/cluster/${var.k8s_cluster_name}" = "shared"
        "kubernetes.io/role/elb" = 1 
    }

    private_subnet_tags = {
        "kubernetes.io/cluster/${var.k8s_cluster_name}" = "shared"
        "kubernetes.io/role/internal-elb" = 1 
    }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.11.0"

  cluster_name = var.k8s_cluster_name
  cluster_version = var.k8s_version

  subnet_ids = module.eks-pod-identity-demo.private_subnets
  vpc_id = module.eks-pod-identity-demo.vpc_id

  # to access cluster externally with kubectl
  cluster_endpoint_public_access = true

  node_security_group_additional_rules = {                                                                  
    all_ingress = {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = {
    environment = "development"
    application = "eks-pod-identity-demo"
  }

  eks_managed_node_groups = {
    dev = {
      min_size     = 1
      max_size     = 3
      desired_size = 3

      instance_types = ["t2.small"]

      # add permission for ebs storage creation for eks-pod-identity-demo
      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      } 
    }
  }
}
