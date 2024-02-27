# Define AWS access key ID variable
variable "AWS_ACCESS_KEY_ID" {
  description = "AWS access key ID"
}

# Define AWS secret access key variable
variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS secret access key"
}

# Configure Terraform settings
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "skillab-ansible"

    workspaces {
      name = "ansible"
    }
  }
}

# Configure AWS provider settings
provider "aws" {
  region = "eu-central-1"
}

# Generate an ED25519 SSH key pair for Ansible
# This is used by Ansible to connect to the nodes it manages
resource "tls_private_key" "ansible_key" {
  algorithm   = "ED25519"
  ecdsa_curve = "P521"
}

# Create an AWS key pair for the EC2 user
# This is used by the user to connect to the Ansible node.
resource "tls_private_key" "ec2_user_key" {
  algorithm   = "ED25519"
  ecdsa_curve = "P521"
}

output "ec2_user_private_key" {
  value     = tls_private_key.ec2_user_key.private_key_openssh
  sensitive = true
}

output "ansible_private_key" {
  value     = tls_private_key.ansible_key.private_key_openssh
  sensitive = true
}

# Create an AWS key pair for the Ansible managed nodes
resource "aws_key_pair" "ansible_public_key_pair" {
  key_name   = "ansible-public-key"
  public_key = tls_private_key.ansible_key.public_key_openssh
}

# Create an AWS key pair for EC2 user
resource "aws_key_pair" "ec2_user_public_key_pair" {
  key_name   = "ec2-user-public-key"
  public_key = tls_private_key.ec2_user_key.public_key_openssh
}

# Create a security group for WordPress instances
resource "aws_security_group" "wordpress_security_group" {
  name = "wordpress_security_group"

  # Allow inbound HTTP traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound SSH traffic only from Ansible node
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a security group for Ansible instances
resource "aws_security_group" "ansible_security_group" {
  name = "ansible_security_group"

  # Allow inbound SSH traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch an EC2 instance for Ansible
resource "aws_instance" "aws_ec2_ansible" {
  ami             = "ami-0a23a9827c6dab833"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.ec2_user_public_key_pair.key_name
  security_groups = [aws_security_group.ansible_security_group.name]

  user_data = file("${path.module}/install-ansible.sh")

  tags = {
    Name = "Ansible-Instance"
  }
}

# Output the public DNS of the Ansible EC2 instance
output "ansible_public_ip" {
  value = aws_instance.aws_ec2_ansible.public_ip
}

# Launch an EC2 instance for WordPress
resource "aws_instance" "aws_ec2_wordpress" {
  ami             = "ami-0a23a9827c6dab833"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.ansible_public_key_pair.key_name
  security_groups = [aws_security_group.wordpress_security_group.name]

  tags = {
    Name = "WordPress-Instance"
  }
}

# Output the public DNS of the Wordpress EC2 instance
output "wordpress_public_ip" {
  value = aws_instance.aws_ec2_wordpress.public_ip
}

#
resource "aws_ebs_volume" "ebs" {
  availability_zone = aws_instance.aws_ec2_wordpress.availability_zone
  size              = 4
  tags = {
    Name = "Data"
  }
}

#
resource "aws_volume_attachment" "ebs_att" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.ebs.id
  instance_id  = aws_instance.aws_ec2_wordpress.id
  force_detach = true
}


