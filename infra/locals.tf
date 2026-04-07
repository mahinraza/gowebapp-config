locals {
  igw_name                 = "${var.project}-igw"
  eip_name                 = "${var.project}-eip"
  nat_name                 = "${var.project}-natgateway"
  vpc_name                 = "${var.project}-vpc"
  public_route_table_name  = "${var.project}-rt-public"
  private_route_table_name = "${var.project}-rt-private"
  cluster_name             = "${var.project}-eks-cluster"
  node_group_name          = "${var.project}-eks-node-group"
  control_plane_sg_name    = "${var.project}-eks-control-plane-sg"
  node_group_sg_name       = "${var.project}-eks-node-group-sg"
  rds_sg_name              = "${var.project}-rds-sg"
  ecr_repo_name            = "${var.project}-ecr-repo"
  eso_role_name            = "${var.project}-eso-role"
  eso_asm_policy_name      = "${var.project}-eso-asm-policy"

  cluster_role_name    = "${var.project}-eks-cluster-role"
  node_group_role_name = "${var.project}-eks-node-group-role"

  common_tags = {
    project    = var.project
    managed_by = "terraform"
  }

  private_subnet_ids = [for s in aws_subnet.private_subnets : s.id]

  # SSM path prefix
  ssm_prefix = "/${var.project}/${var.environment}"

  # ASM path prefix
  asm_prefix = "${var.project}/${var.environment}"
}