variable "aws_region" {
  default = "us-east-1"
}

variable "environment" {
  default = "staging"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "db_instance_class" {
  default = "db.t3.micro"
}

variable "app_instance_type" {
  default = "t3.micro"
}