terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.13"
    }
  }
  required_version = "~> 1.1.7"
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# Create a SSH key pair to connect to the cluster nodes
# ---------------------------------------------------------------------------------------------------------------------
# This will create a key with RSA algorithm with 4096 rsa bits
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# This resource will create a key pair using above private key
resource "aws_key_pair" "ssh" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh.public_key_openssh

  #depends_on = [tls_private_key.ssh]
}

# This resource will save the private key at our specified path.
resource "local_file" "save_key_file" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${var.ssh_key_base_path}/${var.key_name}.pem"
  file_permission = "400" # Grant only read permission to owner

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf $(dirname ${self.filename})"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# The instances of the stack are RHEL-8.5 AMI's
# ---------------------------------------------------------------------------------------------------------------------
data "aws_ami" "rhel_8_5" {
  most_recent = true
  owners      = ["309956199498"] // Red Hat's Account ID
  filter {
    name   = "name"
    values = ["RHEL-8.5*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
