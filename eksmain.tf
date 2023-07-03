#0 - Declare the AZ data source
data "aws_availability_zones" "available" {
  state = "available"
}

#1 - Creates a VPC with one primary CIDR range
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr_block 
  enable_dns_hostnames = true #required for eks, default is false 
  enable_dns_support = true #required for eks, default is true however
  tags = local.common_tags
}
#2 - Creates an IGW and attaches it to the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = local.common_tags  

}

#3a - Creates a consul subnet in the VPC
resource "aws_subnet" "consul_subnet1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.consul_cidr_block1
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true #now required as of 04-2020 for EKS Nodes
  tags = local.common_tags
}
#3b - Creates a consul subnet in the VPC
resource "aws_subnet" "consul_subnet2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.consul_cidr_block2
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = local.common_tags
}
#3c - Creates a consul subnet in the VPC
resource "aws_subnet" "consul_subnet3" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = var.consul_cidr_block3
  availability_zone = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true

  tags = local.common_tags
}

#4 - Creates a public RT 
resource "aws_route_table" "publicrt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge (
    local.common_tags,
    {
      hc-internet-facing = true    
    },
  )
}

#5 - Associates the consul subnet with the public RT 
resource "aws_route_table_association" "consul_publicassociation1" {
  subnet_id      = aws_subnet.consul_subnet1.id
  route_table_id = aws_route_table.publicrt.id
}
resource "aws_route_table_association" "consul_publicassociation2" {
  subnet_id      = aws_subnet.consul_subnet2.id
  route_table_id = aws_route_table.publicrt.id
}
resource "aws_route_table_association" "consul_publicassociation3" {
  subnet_id      = aws_subnet.consul_subnet3.id
  route_table_id = aws_route_table.publicrt.id
}

#6 - Creates a security group that only allows SSH inbound from anywhere, while allowing all traffic outbound

resource "aws_security_group" "nEKS_sg" {
  name        = "nEKS_sg"
  description = "Allow all consul traffic inbound"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["47.144.74.245/32"]
  }
                                                                        
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8558
    to_port     = 8558
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #below only for testing
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

#7 - ################################################EKS_Cluster#######################

resource "aws_eks_cluster" "nEKS" {
  name     = "nEKS${count.index}"
  role_arn = aws_iam_role.nEKS.arn
  count = var.eks_total
  vpc_config {
    security_group_ids = ["${aws_security_group.nEKS_sg.id}"]
    subnet_ids = [aws_subnet.consul_subnet1.id, aws_subnet.consul_subnet2.id, aws_subnet.consul_subnet3.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.nEKS-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.nEKS-AmazonEKSVPCResourceController,
  ]
}

#8 - IAM roles, policies, attachments. 

resource "aws_iam_role" "nEKS" {
  name = "eks-cluster-nEKS"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "nEKS-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.nEKS.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "nEKS-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.nEKS.name
}


resource "aws_iam_role" "nEKS_node" {
  name = "eks-node-group-nEKS"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "nEKS_node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nEKS_node.name
}

resource "aws_iam_role_policy_attachment" "nEKS_node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nEKS_node.name
}

resource "aws_iam_role_policy_attachment" "nEKS_node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nEKS_node.name
}


#9 - EKS_node_group

resource "aws_eks_node_group" "nEKS" {
  count = var.eks_total
  cluster_name    = aws_eks_cluster.nEKS[count.index].name
  node_group_name = "nEKS_node_group ${count.index}"
  node_role_arn   = aws_iam_role.nEKS_node.arn
  subnet_ids      = [aws_subnet.consul_subnet1.id, aws_subnet.consul_subnet2.id, aws_subnet.consul_subnet3.id]

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  update_config {
    max_unavailable = 2
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.nEKS_node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nEKS_node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nEKS_node-AmazonEC2ContainerRegistryReadOnly,
  ]
  tags = merge (
    #local.common_tags,
    {
      Env = "consul-${random_string.env.result}"  
    },
  )
  launch_template {
   name = aws_launch_template.nEKS-launch-template.name
   version = aws_launch_template.nEKS-launch-template.latest_version
  }
}

#10 - Random
resource "random_string" "env" {
  length  = 4
  special = false
  upper   = false
  number  = false
}


#11 - launch-templates-EKS

resource "aws_launch_template" "nEKS-launch-template" {
  name = "nEKS-launch-template"
  tag_specifications {
    resource_type = "instance"
    tags = {
       Env = "consul-${random_string.env.result}"  
    }
  }
}

#12 - Data items 

data "aws_eks_cluster" "nEKS" {
  count = var.eks_total
  name = aws_eks_cluster.nEKS[count.index].name
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

#13 - CSI drivers 

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-nEKS"
  provider_url                  = replace(data.aws_eks_cluster.nEKS[count.index].identity.0.oidc.0.issuer, "https://", "")
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

#14 - CSI Addon - 

resource "aws_eks_addon" "nEKS" {
  count = var.eks_total
  cluster_name             = aws_eks_cluster.nEKS[count.index].name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.17.0-eksbuild.1"
  service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
  tags = {
    "eks_addon" = "ebs-csi"
    "terraform" = "true"
  }
}

/*
#only use where consul already exists
module "hcp-consul_k8s-demo-app" {
  source  = "hashicorp/hcp-consul/aws//modules/k8s-demo-app"
  version = "0.12.1"
}
*/



output "endpoint" {
  value = one(aws_eks_cluster.nEKS[*].endpoint)
}

output "kubeconfig-certificate-authority-data" {
  value = one(aws_eks_cluster.nEKS[*].certificate_authority[0].data)
}

output "env" {
  value = random_string.env.result
}

