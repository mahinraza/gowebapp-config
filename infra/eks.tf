resource "aws_eks_cluster" "eks_cluster" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids = concat(
      [for s in aws_subnet.private_subnets : s.id],
      [for s in aws_subnet.public_subnets : s.id]
    )
    security_group_ids      = [aws_security_group.control_plane_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true          # set false in prod, use VPN/bastion
    public_access_cidrs     = ["0.0.0.0/0"] # restrict to your IP in prod
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks_key.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_policy
  ]

  tags = merge(local.common_tags, {
    Name = local.cluster_name
  })
}

# KMS key for EKS secrets encryption
resource "aws_kms_key" "eks_key" {
  description             = "EKS secrets encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-eks-key"
  })
}

resource "aws_kms_alias" "eks_key" {
  name          = "alias/${local.cluster_name}-eks"
  target_key_id = aws_kms_key.eks_key.key_id
}

resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = local.node_group_name
  node_role_arn   = aws_iam_role.node_group_role.arn
  version         = var.cluster_version

  # Deploy nodes in private subnets only
  subnet_ids = [for s in aws_subnet.private_subnets : s.id]

  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size
  capacity_type  = "ON_DEMAND" # use SPOT for cost savings in dev

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable_percentage = 25 # rolling update — 25% nodes down at a time
  }

  # launch_template {
  #   id      = aws_launch_template.node.id
  #   version = aws_launch_template.node.latest_version
  # }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy
  ]

  tags = merge(local.common_tags, {
    Name = local.node_group_name
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size] # let cluster autoscaler manage this
  }
}

# # Launch template for custom node config
# resource "aws_launch_template" "node" {
#   name_prefix   = "${local.cluster_name}-node-"
#   instance_type = var.node_instance_types[0]

#   block_device_mappings {
#     device_name = "/dev/xvda"
#     ebs {
#       volume_size           = var.node_disk_size
#       volume_type           = "gp3"
#       encrypted             = true
#       kms_key_id            = aws_kms_key.eks_key.arn
#       delete_on_termination = true
#     }
#   }

#   metadata_options {
#     http_endpoint               = "enabled"
#     http_tokens                 = "required"    # enforces IMDSv2
#     http_put_response_hop_limit = 1
#   }

#   monitoring {
#     enabled = true
#   }

#   tag_specifications {
#     resource_type = "instance"
#     tags = merge(local.common_tags, {
#       Name = "${local.cluster_name}-node"
#     })
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# ── CoreDNS ───────────────────────────────────────────────────
# Handles DNS resolution inside the cluster
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "coredns"
  addon_version               = var.addon_versions.coredns
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.nodes]

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-coredns"
  })
}

# ── Kube Proxy ────────────────────────────────────────────────
# Maintains network rules on nodes for pod communication
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "kube-proxy"
  addon_version               = var.addon_versions.kube_proxy
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.nodes]

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-kube-proxy"
  })
}

# ── VPC CNI ───────────────────────────────────────────────────
# Assigns VPC IPs directly to pods (native VPC networking)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "vpc-cni"
  addon_version               = var.addon_versions.vpc_cni
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  # service_account_role_arn    = aws_iam_role.vpc_cni_role.arn  # IRSA

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true" # more IPs per node
      WARM_PREFIX_TARGET       = "1"
    }
  })

  depends_on = [
    aws_eks_node_group.nodes
    # aws_iam_role_policy_attachment.vpc_cni_policy
  ]

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-vpc-cni"
  })
}

# ── EBS CSI Driver ────────────────────────────────────────────
# Allows pods to use EBS volumes as persistent storage
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.eks_cluster.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.addon_versions.ebs_csi_driver
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE" # Add this line

  # service_account_role_arn    = aws_iam_role.ebs_csi_role.arn  # IRSA

  depends_on = [
    aws_eks_node_group.nodes
    # aws_iam_role_policy_attachment.ebs_csi_policy
  ]

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-ebs-csi"
  })
}