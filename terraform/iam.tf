# Least-privilege IAM role for the EC2 node.
# No wildcard Action or Resource — deliberate showcase of scoped permissions.

resource "aws_iam_role" "k3s" {
  name = "secure-k8s-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "secure-k8s-ec2-role" }
}

resource "aws_iam_role_policy" "k3s_scoped" {
  name = "secure-k8s-scoped-policy"
  role = aws_iam_role.k3s.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeInstances"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/secure-k8s/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k3s" {
  name = "secure-k8s-instance-profile"
  role = aws_iam_role.k3s.name
}
