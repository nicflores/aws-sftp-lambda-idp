variable "user_name" {}
variable "sftp_server_id" {}
variable "public_ssh_key" {}
variable "home_directory" {}

resource "aws_s3_bucket" "user_bucket" {
  bucket = "testsftp-${var.user_name}"
}

resource "aws_s3_object" "directory_placeholder" {
  bucket = aws_s3_bucket.user_bucket.bucket
  key    = "${var.home_directory}/welcome"
  source = "/dev/null"
}

resource "aws_secretsmanager_secret" "user_secret" {
  name = "testsftp-${var.user_name}"
}

resource "aws_secretsmanager_secret_version" "user_secret_version" {
  secret_id = aws_secretsmanager_secret.user_secret.id
  secret_string = jsonencode({
    username       = "${var.user_name}"
    bucket_name    = "${aws_s3_bucket.user_bucket.bucket}"
    ssh_key        = file(var.public_ssh_key)
    home_directory = "${var.home_directory}"
    role_arn       = "${aws_iam_role.sftp_user_access_role.arn}"
  })
}

resource "aws_iam_role" "sftp_user_access_role" {
  name = "SFTPUserAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "transfer.amazonaws.com"
        },
        Action = "sts:AssumeRole",
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sftp_user_policy_attachment" {
  role       = aws_iam_role.sftp_user_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# resource "aws_iam_policy" "sftp_user_access_policy" {
#   name = "LambdaInvocationPolicy"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Sid      = "ListBucketItems"
#         Effect   = "Allow",
#         Action   = ["s3:ListBucket", "s3:GetBucketLocation"],
#         Resource = "arn:aws:s3:::${var.unique_prefix}-*"
#       },
#       {
#         Sid      = "ListBucketItems"
#         Effect   = "Allow",
#         Action   = ["s3:GetObjectAcl", "s3:GetObject", "s3:GetObjectVersion"],
#         Resource = "arn:aws:s3:::${var.unique_prefix}-*/*"
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "sftp_user_policy_attachment" {
#   role       = aws_iam_role.sftp_user_access_role.name
#   policy_arn = aws_iam_policy.sftp_user_access_policy.arn
# }

output "bucket_name" {
  value = aws_s3_bucket.user_bucket.bucket
}

output "secret_arn" {
  value = aws_secretsmanager_secret.user_secret.arn
}
