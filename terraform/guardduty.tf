resource "aws_guardduty_detector" "main" {
  enable = true
  tags   = { Name = "secure-k8s-guardduty" }
}
