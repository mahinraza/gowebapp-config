resource "aws_ssm_parameter" "db_host" {
  name  = "${local.ssm_prefix}/database/host"
  type  = "String"
  value = var.db_kubernetes_service_name
  tags  = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "db_port" {
  name  = "${local.ssm_prefix}/database/port"
  type  = "String"
  value = aws_db_instance.rds_instance.port
  tags  = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}