variable "region" {}
variable "lambda_bucket_name" {}
variable "lambda_function_name" {}
variable "lambda_handler" {}
variable "lambda_runtime" {}
variable "lambda_environment_variables" {}
variable "lambda_zip_file_name" {}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket        = var.lambda_bucket_name
  force_destroy = true
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "auth-lambda"
  output_path = "${path.module}/${var.lambda_zip_file_name}"
  excludes    = ["sftp_auth_test.py"]
}

resource "aws_s3_object" "upload_lambda_zip_to_bucket" {
  bucket      = aws_s3_bucket.lambda_bucket.id
  key         = var.lambda_zip_file_name
  source      = "${path.module}/${var.lambda_zip_file_name}"
  source_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_function" "sftp_auth" {
  function_name    = var.lambda_function_name
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = var.lambda_zip_file_name
  runtime          = var.lambda_runtime
  handler          = var.lambda_handler
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  timeout          = 100
  memory_size      = 1024

  environment {
    variables = {
      SECRETS_MANAGER_REGION = var.region
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.lambda_function_name}_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com",
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}

data "aws_iam_policy_document" "lambda_exec_policy_doc" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:*:*:*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "lambda_exec_policy" {
  name   = "${var.lambda_function_name}_exec_policy"
  policy = data.aws_iam_policy_document.lambda_exec_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_exec_policy_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_exec_policy.arn
}

resource "aws_iam_role_policy" "sm_policy" {
  name = "sm_access_permissions"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.sftp_auth.function_name}"
  retention_in_days = 14
}

output "lambda_function_arn" {
  value = aws_lambda_function.sftp_auth.arn
}
