variable "region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

# add the region here
provider "aws" {
  region = "${var.region}"
}