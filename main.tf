terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      version = ">= 5.4.0"
      source  = "hashicorp/aws"
    }
  }
}

terraform {
  backend "local" {}
}

variable "aws_region" {
  default = "us-east-1"
}

module "user_resources" {
  source         = "./modules/user_resources"
  user_name      = "exampleuser"
  public_ssh_key = "exampleuser_id_rsa.pub"
  home_directory = "myhomedir"
  sftp_server_id = module.sftp_server.sftp_server_id
}

module "lambda_auth" {
  source               = "./modules/lambda_auth"
  region               = var.aws_region
  lambda_function_name = "SFTPUserAuth"
  lambda_handler       = "sftp_auth.lambda_handler"
  lambda_zip_file_name = "auth-lambda.zip"
  lambda_bucket_name   = "auth-sftp-lambda-bucket"
  lambda_runtime       = "python3.11"
  lambda_environment_variables = {
    SECRETS_MANAGER_REGION = "${var.aws_region}"
  }
}

module "sftp_server" {
  source          = "./modules/sftp_server"
  auth_lambda_arn = module.lambda_auth.lambda_function_arn
}

output "sftp_url" {
  value = module.sftp_server.sftp_url
}




