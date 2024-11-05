# Define variables for the AWS region and instance details
variable "aws_region" {
  description = "The AWS region to deploy resources"
  default     = "us-west-2"
}

variable "instance_type" {
  description = "The type of instance to launch"
  default     = "t2.micro"
}

variable "ami_id" {
  description = "The ID of the AMI to use for the instance"
  default     = "ami-0c55b159cbfafe1f0" # Replace with a valid AMI ID for your region
}
