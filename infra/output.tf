# Output RDS endpoint
output "rds_endpoint" {
  value = aws_db_instance.rds_instance.endpoint
}

# Output RDS address (hostname only)
output "rds_address" {
  value = aws_db_instance.rds_instance.address
}

# Output RDS port
output "rds_port" {
  value = aws_db_instance.rds_instance.port
}

output "db_master_user" {
  value = aws_db_instance.rds_instance.username
}

output "db_master_cred_arn" {
  value     = aws_db_instance.rds_instance.master_user_secret[0].secret_arn
  sensitive = true
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private_subnets : s.id]
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public_subnets : s.id]
}

# # outputs.tf
# output "ecr_repo_url" {
#   value = aws_ecr_repository.ecr_repo.repository_url
# }

# output "ecr_login_command" {
#   value = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${aws_ecr_repository.ecr_repo.repository_url}"
# }

# output "docker_build_command" {
#   value = "docker build -t ${aws_ecr_repository.ecr_repo.repository_url}:latest ."
# }

# output "docker_push_command" {
#   value = "docker push ${aws_ecr_repository.ecr_repo.repository_url}:latest"
# }

# output "docker_tag_command" {
#   value = "docker tag ${var.project}:latest ${aws_ecr_repository.ecr_repo.repository_url}:latest"
# }

output "cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "cluster_ca" {
  value     = aws_eks_cluster.eks_cluster.certificate_authority[0].data
  sensitive = true
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  value = aws_iam_openid_connect_provider.eks.url
}

output "node_group_role_arn" {
  value = aws_iam_role.node_group_role.arn
}

output "eso_role_arn" {
  value       = aws_iam_role.eso_role.arn
  description = "Annotate ESO service account with this ARN"
}

