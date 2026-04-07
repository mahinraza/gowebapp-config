resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr

  tags = merge(local.common_tags, {
    Name = local.vpc_name
  })
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_subnets[count.index].cidr_block
  availability_zone = var.public_subnets[count.index].availability_zone

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.public_subnets[count.index].suffix}"
    "kubernetes.io/cluster/${local.cluster_name}" : "shared"
    "kubernetes.io/role/elb" : "1"
  })
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnets[count.index].cidr_block
  availability_zone = var.private_subnets[count.index].availability_zone

  tags = merge(local.common_tags, {
    Name = "${var.project}-${var.private_subnets[count.index].suffix}"
    "kubernetes.io/cluster/${local.cluster_name}" : "shared"
    "kubernetes.io/role/internal-elb" : "1"
  })
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.common_tags, {
    Name = local.igw_name
  })
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = local.eip_name
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

  depends_on = [aws_internet_gateway.igw]

  tags = merge(local.common_tags, {
    Name = local.nat_name
  })
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.common_tags, {
    Name = local.public_route_table_name
  })

  route {
    gateway_id = aws_internet_gateway.igw.id
    cidr_block = "0.0.0.0/0"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = merge(local.common_tags, {
    Name = local.private_route_table_name
  })

  route {
    nat_gateway_id = aws_nat_gateway.nat.id
    cidr_block     = "0.0.0.0/0"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = length(aws_subnet.public_subnets)
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnets[count.index].id
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = length(aws_subnet.private_subnets)
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnets[count.index].id
}

# ── Control Plane SG ──────────────────────────────────────────
resource "aws_security_group" "control_plane_sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "EKS control plane security group"

  tags = merge(local.common_tags, {
    Name                                          = local.control_plane_sg_name
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

# Allow nodes to talk to control plane API (443)
resource "aws_security_group_rule" "control_plane_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group_sg.id
  security_group_id        = aws_security_group.control_plane_sg.id
  description              = "Allow nodes to reach API server"
}

# Allow control plane to talk back to nodes (kubelet, etc.)
resource "aws_security_group_rule" "control_plane_egress_to_nodes" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group_sg.id
  security_group_id        = aws_security_group.control_plane_sg.id
  description              = "Allow control plane to reach node kubelets"
}

# Allow control plane egress to nodes on 443 (webhooks, metrics)
resource "aws_security_group_rule" "control_plane_egress_to_nodes_443" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group_sg.id
  security_group_id        = aws_security_group.control_plane_sg.id
  description              = "Allow control plane to reach nodes on 443"
}


# ── Node Group SG ─────────────────────────────────────────────
resource "aws_security_group" "node_group_sg" {
  vpc_id      = aws_vpc.vpc.id # fixed: was aws_vpc.my_vpc
  description = "EKS node group security group"

  tags = merge(local.common_tags, {
    Name                                          = local.node_group_sg_name
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

# Allow control plane to reach kubelets on nodes
resource "aws_security_group_rule" "nodes_ingress_from_control_plane" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.control_plane_sg.id
  security_group_id        = aws_security_group.node_group_sg.id
  description              = "Allow control plane to reach kubelets"
}

# Allow control plane to reach nodes on 443 (webhooks)
resource "aws_security_group_rule" "nodes_ingress_from_control_plane_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.control_plane_sg.id
  security_group_id        = aws_security_group.node_group_sg.id
  description              = "Allow control plane webhooks to nodes"
}

# Allow nodes to talk to each other (pod-to-pod communication)
resource "aws_security_group_rule" "nodes_ingress_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = aws_security_group.node_group_sg.id
  security_group_id        = aws_security_group.node_group_sg.id
  description              = "Allow nodes to communicate with each other"
}

# Allow nodes outbound (pull images, reach AWS APIs, NAT)
resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node_group_sg.id
  description       = "Allow all outbound from nodes"
}


# ── RDS SG ────────────────────────────────────────────────────
resource "aws_security_group" "rds_sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "RDS security group - allow MySQL from EKS cluster"

  tags = merge(local.common_tags, {
    Name                                          = local.rds_sg_name
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  })
}

# Allow MySQL from EKS nodes
resource "aws_security_group_rule" "rds_ingress_from_nodes" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.node_group_sg.id
  security_group_id        = aws_security_group.rds_sg.id
  description              = "Allow MySQL from EKS nodes"
}

# Allow MySQL from EKS cluster security group
resource "aws_security_group_rule" "rds_ingress_from_cluster" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.control_plane_sg.id
  security_group_id        = aws_security_group.rds_sg.id
  description              = "Allow MySQL from EKS cluster control plane"
}

# Allow MySQL from VPC CIDR (this is what actually allows pod traffic)
resource "aws_security_group_rule" "rds_ingress_from_vpc" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [aws_vpc.vpc.cidr_block]
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow MySQL from VPC CIDR (pods)"
}

# RDS egress only within VPC
resource "aws_security_group_rule" "rds_egress_vpc" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [aws_vpc.vpc.cidr_block]
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow outbound within VPC only"
}
