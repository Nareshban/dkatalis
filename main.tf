provider "aws" {
    region = "us-east-1"
    access_key = "AKIAIJ3VP36I2L4RUWPQ"
    secret_key = "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"
}

resource "aws_vpc" "main" {
    cidr_block = "192.168.0.0/24"
    instance_tenancy = "default"
    tags = {
        Name = "main"
    }
}


resource "aws_subnet" "public_subnet" {
    vpc_id = aws_vpc.main.id
    cidr_block = "192.168.0.0/25"
    availability_zone = "us-east-1a"
    tags = {
        Name = "public_subnet"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "igw"
    }
    }

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "main"
  }
}

resource "aws_route_table_association" "r" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.r.id
}





resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "ssh from MY Ip"
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "http from VPC"
    from_port   = 0
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "https from VPC"
    from_port   = 0
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_web"
  }
}

resource "aws_network_interface" "web_priv_ip" {
  subnet_id       = aws_subnet.public_subnet.id
  private_ips     = ["192.168.0.10"]
  security_groups = [aws_security_group.allow_ssh.id]
}

resource "aws_eip" "public_ip" {
  vpc                       = true
  network_interface         = aws_network_interface.web_priv_ip.id
  associate_with_private_ip = "192.168.0.10"
  depends_on = [aws_internet_gateway.igw]
}


resource "aws_instance" "web" {
    ami = "ami-0dba2cb6798deb6d8"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "dockerkey"
    depends_on = [aws_eip.public_ip,aws_network_interface.web_priv_ip]
    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web_priv_ip.id
    }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install openjdk-8-jdk
                sudo wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
                sudo apt-get install apt-transport-https
				echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
				sudo apt-get install elasticsearch
				sudo /bin/systemctl daemon-reload
				sudo /bin/systemctl enable elasticsearch.service
				sudo systemctl start elasticsearch
				EOF
    tags = {
        Name = "webserver"
    }
}

output "instance_ip_addr" {
  value = aws_eip.public_ip
}