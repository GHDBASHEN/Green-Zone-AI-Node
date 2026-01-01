provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "ghdb-terraform-state-bucket" 
    key    = "green-zone/terraform.tfstate"
    region = "eu-north-1"
  }
}


resource "aws_instance" "green_zone_node" {
  ami           = "ami-09a9858973b288bdd" # Ubuntu 24.04 (eu-north-1 )
  instance_type = "t3.micro"              


  vpc_security_group_ids = [aws_security_group.allow_traffic.id]
  

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y docker.io docker-compose
              

              echo "
              services:
                app:
                  image: ghdbashen/green-zone-ai-node-app:latest
                  ports: ['8000:8000']
                  restart: always
                prometheus:
                  image: prom/prometheus
                  ports: ['9090:9090']
                grafana:
                  image: grafana/grafana
                  ports: ['3000:3000']
              " > docker-compose.yml
              
              
              sudo docker-compose up -d
              EOF

  tags = {
    Name = "${var.client_name}-free-node"
  }
}


resource "aws_security_group" "allow_traffic" {
  name        = "${var.client_name}-sg"
  description = "Allow inbound traffic"

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


output "server_ip" {
  value = "http://${aws_instance.green_zone_node.public_ip}:8000"
}