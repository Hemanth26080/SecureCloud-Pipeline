resource "aws_iam_role" "app_role" {
  name = "securecloud-app-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "securecloud-app-role" }
}

resource "aws_iam_policy" "read_secrets" {
  name = "securecloud-read-secrets-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:eu-west-3:*:secret:securecloud/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_secrets" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.read_secrets.arn
}

resource "aws_iam_instance_profile" "app" {
  name = "securecloud-app-profile-${var.environment}"
  role = aws_iam_role.app_role.name
}

output "instance_profile_name" { value = aws_iam_instance_profile.app.name }
output "app_role_arn"          { value = aws_iam_role.app_role.arn }
