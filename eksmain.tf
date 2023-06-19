# PREBUILT CONSUL AND ENVOY PACKER IMAGE 
/*
data "aws_ami" "ubuntu" {
  owners = ["self"]

  most_recent = true

  filter {
    name   = "name"
    values = ["HRS1-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
*/
# Declare the data source
data "aws_availability_zones" "available" {
  state = "available"
}

#Creates a VPC with one primary CIDR range
resource "aws_vpc" "nia_vpc" {
  cidr_block = var.vpc_cidr_block 
  enable_dns_hostnames = true #required for eks, default is false 
  enable_dns_support = true #required for eks, default is true however
  tags = local.common_tags
}
#Creates an IGW and attaches it to the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.nia_vpc.id

  tags = local.common_tags

}

#Creates a consul subnet in the VPC
resource "aws_subnet" "consul_subnet1" {
  vpc_id            = aws_vpc.nia_vpc.id
  cidr_block        = var.consul_cidr_block1
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true #now required as of 04-2020 for EKS Nodes
  tags = local.common_tags
}
#Creates a consul subnet in the VPC
resource "aws_subnet" "consul_subnet2" {
  vpc_id            = aws_vpc.nia_vpc.id
  cidr_block        = var.consul_cidr_block2
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = local.common_tags
}
#Creates a consul subnet in the VPC
resource "aws_subnet" "consul_subnet3" {
  vpc_id            = aws_vpc.nia_vpc.id
  cidr_block        = var.consul_cidr_block3
  availability_zone = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true

  tags = local.common_tags
}
#Creates a cts subnet in the VPC
/*resource "aws_subnet" "cts_subnet" {
  vpc_id            = aws_vpc.nia_vpc.id
  cidr_block        = var.cts_cidr_block
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = local.common_tags
}

#Creates a service subnet in the VPC
resource "aws_subnet" "service_subnet" {
  vpc_id            = aws_vpc.nia_vpc.id
  cidr_block        = var.service_cidr_block
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = local.common_tags
}
*/
#Creates a public RT 
resource "aws_route_table" "publicrt" {
  vpc_id = aws_vpc.nia_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  #adding an extra route for vpc peering
  #route {
   # cidr_block = "10.69.0.0/16"
    #vpc_peering_connection_id = "pcx-0bcf0f9cccca03f28" # typically this should be part of the same code for client side and use VPC ID from a module
  #}
  tags = merge (
    local.common_tags,
    {
      hc-internet-facing = true    
    },
  )
}
#Associates the consul subnet with the public RT 
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
#Associates the cts subnet with the public RT 
/*resource "aws_route_table_association" "cts_publicassociation" {
  subnet_id      = aws_subnet.cts_subnet.id
  route_table_id = aws_route_table.publicrt.id
}
#Associates the service subnet with the public RT 
resource "aws_route_table_association" "service_publicassociation" {
  subnet_id      = aws_subnet.service_subnet.id
  route_table_id = aws_route_table.publicrt.id
}
*/
#Creates a security group that only allows SSH inbound from anywhere, while allowing all traffic outbound
resource "aws_security_group" "reinvent_sg" {
  name        = "reinvent_sg"
  description = "Allow all consul traffic inbound"
  vpc_id      = aws_vpc.nia_vpc.id

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

################################################EKS_Cluster#######################
resource "aws_eks_cluster" "reinvent" {
  name     = "reinvent"
  role_arn = aws_iam_role.reinvent.arn

  vpc_config {
    security_group_ids = ["${aws_security_group.reinvent_sg.id}"]
    subnet_ids = [aws_subnet.consul_subnet1.id, aws_subnet.consul_subnet2.id, aws_subnet.consul_subnet3.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.reinvent-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.reinvent-AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.reinvent.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.reinvent.certificate_authority[0].data
}

resource "aws_iam_role" "reinvent" {
  name = "eks-cluster-reinvent"

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

resource "aws_iam_role_policy_attachment" "reinvent-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.reinvent.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "reinvent-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.reinvent.name
}

#EKS_node_group
resource "aws_eks_node_group" "reinvent" {
  cluster_name    = aws_eks_cluster.reinvent.name
  node_group_name = "reinvent_node_group"
  node_role_arn   = aws_iam_role.reinvent_node.arn
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
    aws_iam_role_policy_attachment.reinvent_node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.reinvent_node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.reinvent_node-AmazonEC2ContainerRegistryReadOnly,
  ]
  tags = merge (
    #local.common_tags,
    {
      Env = "consul-${random_string.env.result}"  
    },
  )
  launch_template {
   name = aws_launch_template.reinvent-launch-template.name
   version = aws_launch_template.reinvent-launch-template.latest_version
  }
}


resource "aws_iam_role" "reinvent_node" {
  name = "eks-node-group-reinvent"

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

resource "aws_iam_role_policy_attachment" "reinvent_node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.reinvent_node.name
}

resource "aws_iam_role_policy_attachment" "reinvent_node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.reinvent_node.name
}

resource "aws_iam_role_policy_attachment" "reinvent_node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.reinvent_node.name
}
resource "random_string" "env" {
  length  = 4
  special = false
  upper   = false
  number  = false
}

output "env" {
  value = random_string.env.result
}

resource "aws_launch_template" "reinvent-launch-template" {
  name = "reinvent-launch-template"
  tag_specifications {
    resource_type = "instance"
    tags = {
       Env = "consul-${random_string.env.result}"  
    }
  }
}

data "aws_eks_cluster" "reinvent" {
  name = aws_eks_cluster.reinvent.name
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.7.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-reinvent"
  provider_url                  = replace(data.aws_eks_cluster.reinvent.identity.0.oidc.0.issuer, "https://", "")
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}

resource "aws_eks_addon" "reinvent" {
  cluster_name             = aws_eks_cluster.reinvent.name
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