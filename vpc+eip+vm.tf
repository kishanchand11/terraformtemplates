provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

# VPC
resource "aws_vpc" "terra_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "prod_vpc"
  }
}

# Subnet
resource "aws_subnet" "sub" {
  vpc_id                  = aws_vpc.terra_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    name = "sub_subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.terra_vpc.id

  tags = {
    Name = "terraigw"
  }
}

# Route Table
resource "aws_route_table" "rt_table" {
  vpc_id = aws_vpc.terra_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}

# Route Table Association
resource "aws_route_table_association" "rt-assoc" {
  subnet_id      = aws_subnet.sub.id
  route_table_id = aws_route_table.rt_table.id
}

# Security Group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.terra_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "CUSTOM"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# Network Interface
resource "aws_network_interface" "ntwk_face" {
  subnet_id       = aws_subnet.sub.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Instances
resource "aws_instance" "jenkins_master" {
  ami                    = "ami-0e001c9271cf7f3b9"
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.sub.id
  availability_zone      = "us-east-1a"
  key_name               = "key"
  vpc_security_group_ids = [aws_security_group.allow_web.id]

  tags = {
    Name = "jenkins_master"
  }
}

resource "aws_instance" "kubernetes_master" {
  ami                    = "ami-0e001c9271cf7f3b9"
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.sub.id
  availability_zone      = "us-east-1a"
  key_name               = "key"
  vpc_security_group_ids = [aws_security_group.allow_web.id]

  tags = {
    Name = "kubernetes_master"
  }
}

resource "aws_instance" "kubernetes_slave" {
  ami                    = "ami-0e001c9271cf7f3b9"
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.sub.id
  availability_zone      = "us-east-1a"
  key_name               = "key"
  vpc_security_group_ids = [aws_security_group.allow_web.id]

  tags = {
    Name = "kubernetes_slave"
  }
}

# Elastic IPs
resource "aws_eip" "jenkins_master_eip" {}

resource "aws_eip" "kubernetes_master_eip" {}

resource "aws_eip" "kubernetes_slave_eip" {}

# EIP Associations
resource "aws_eip_association" "jenkins_master_eip_assoc" {
  instance_id = aws_instance.jenkins_master.id
  allocation_id = aws_eip.jenkins_master_eip.id
}

resource "aws_eip_association" "kubernetes_master_eip_assoc" {
  instance_id = aws_instance.kubernetes_master.id
  allocation_id = aws_eip.kubernetes_master_eip.id
}

resource "aws_eip_association" "kubernetes_slave_eip_assoc" {
  instance_id = aws_instance.kubernetes_slave.id
  allocation_id = aws_eip.kubernetes_slave_eip.id
}
