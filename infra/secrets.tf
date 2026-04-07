# # secrets.tf — sensitive credentials
# resource "aws_secretsmanager_secret" "root_cred" {
#   name = "prod/gowebapp/database/root_cred"
#   tags = local.common_tags
# }

# resource "aws_secretsmanager_secret_version" "root_cred" {
#   secret_id = aws_secretsmanager_secret.root_cred.id
#   secret_string = jsonencode({
#     username = var.db_root_username
#     password = var.db_root_password
#   })
# }

resource "aws_secretsmanager_secret" "app_cred" {
  name = "${local.asm_prefix}/database/app_cred"
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app_cred" {
  secret_id = aws_secretsmanager_secret.app_cred.id
  secret_string = jsonencode({
    username           = var.db_app_username
    password           = var.db_app_password
    database           = var.db_name
    "session-secret-key" = var.session_secret_key
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}