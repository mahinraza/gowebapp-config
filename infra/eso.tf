# ── ESO IRSA Role ─────────────────────────────────────────────
resource "aws_iam_role" "eso_role" {

  depends_on = [aws_db_instance.rds_instance]

  name = local.eso_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# ── ASM Policy ────────────────────────────────────────────────
resource "aws_iam_policy" "eso_asm_policy" {

  depends_on = [aws_db_instance.rds_instance]

  name        = local.eso_asm_policy_name
  description = "Allow ESO to read from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowASMRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ]
        Resource = [
          aws_secretsmanager_secret.app_cred.arn,
          "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:rds!db-*"
          # aws_secretsmanager_secret.root_cred.arn
        ]
      }
      # {
      #   Sid    = "AllowKMSDecryptASM"
      #   Effect = "Allow"
      #   Action = [
      #     "kms:Decrypt",
      #     "kms:DescribeKey"
      #   ]
      #   Resource = aws_kms_key.asm_key.arn
      # }
    ]
  })
}

# ── SSM Policy ────────────────────────────────────────────────
resource "aws_iam_policy" "eso_ssm_policy" {
  name        = "mahin-eks-eso-ssm-policy-${var.environment}"
  description = "Allow ESO to read from Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = "arn:aws:ssm:${var.region}:${var.account_id}:parameter${local.ssm_prefix}/*"
      }
      # {
      #   Sid    = "AllowKMSDecryptSSM"
      #   Effect = "Allow"
      #   Action = [
      #     "kms:Decrypt",
      #     "kms:DescribeKey"
      #   ]
      #   Resource = aws_kms_key.ssm_key.arn
      # }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eso_asm" {
  role       = aws_iam_role.eso_role.name
  policy_arn = aws_iam_policy.eso_asm_policy.arn
}

resource "aws_iam_role_policy_attachment" "eso_ssm" {
  role       = aws_iam_role.eso_role.name
  policy_arn = aws_iam_policy.eso_ssm_policy.arn
}