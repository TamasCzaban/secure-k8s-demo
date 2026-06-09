variable "aws_region" {
  default = "eu-north-1"
}

variable "your_ip" {
  description = "Your public IP for SSH access (e.g. 1.2.3.4/32)"
  type        = string
}
