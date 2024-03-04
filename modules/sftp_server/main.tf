variable "auth_lambda_arn" {}

resource "aws_transfer_server" "sftp_server" {
  endpoint_type                   = "PUBLIC"
  identity_provider_type          = "AWS_LAMBDA"
  protocols                       = ["SFTP"]
  force_destroy                   = true
  logging_role                    = aws_iam_role.sft_iam_role.arn
  domain                          = "S3"
  pre_authentication_login_banner = "Welcome to SFTP"
  function                        = var.auth_lambda_arn
  security_policy_name            = "TransferSecurityPolicy-2018-11"
}

resource "aws_iam_role" "sft_iam_role" {
  name = "sftp_iam_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "transfer.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "logging_role_cloudwatch_logs" {
  role       = aws_iam_role.sft_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_policy" "lambda_invocation_policy" {
  name = "LambdaInvocationPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = "${var.auth_lambda_arn}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_invocation_policy_attachment" {
  role       = aws_iam_role.sft_iam_role.name
  policy_arn = aws_iam_policy.lambda_invocation_policy.arn
}

output "sftp_server_id" {
  value = aws_transfer_server.sftp_server.id
}

output "sftp_url" {
  value = aws_transfer_server.sftp_server.endpoint
}
