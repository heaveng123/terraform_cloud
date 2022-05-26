resource "aws_vpc" "provisioner_vpc" {
  cidr_block           = "172.24.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "demo123"
  }
}
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.provisioner_vpc.id

  tags = {
    Name = "main_abc"
  }
}
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.provisioner_vpc.id
  cidr_block = "172.24.1.0/24"
  # availability_zone = "us-east-1c"

  tags = {
    Name = "Public_Subnet"
  }
}
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.provisioner_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    Name = "Public_RT"
  }
}
resource "aws_route_table_association" "r" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.rt.id
}
resource "aws_instance" "web123" {
  ami                    = "ami-0022f774911c1d690"
  instance_type          = "t2.micro"
  key_name               = "main"
  vpc_security_group_ids = [aws_security_group.webSG123.id]
  subnet_id              = aws_subnet.public_subnet.id
  # availability_zone      = "us-east-1c"

  # provisioner "remote-exec" {
  # inline = [
  #   "sudo amazon-linux-extras install -y nginx1.12",
  #   "sudo systemctl start nginx"
  # ]
  provisioner "remote-exec" {
    inline = [
      "sudo yum install nginx -y",
      "sudo service nginx start",
      "sudo rm /usr/share/nginx/html/index.html",
      "echo '<html><head><title>Blue Team Server</title></head><body style=\"background-color:#1F778D\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">Blue Team</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html"
    ]
  }
  # provisioner "remote-exec" {
  #   when = destroy
  #   inline = [
  #     "sudo amazon-linux-extras remove -y nginx1.12"
  #   ]
  # }
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("./main.pem")
    host        = self.public_ip
    # host = aws_instance.web123.public_ip
    # host        = self.public_ip
  }
}
resource "aws_security_group" "webSG123" {
  name        = "allow_ssh_http_connection"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.provisioner_vpc.id

  tags = {
    Name = "allow_traffic"
  }
  # vpc_id      = aws_vpc.provisioner_vpc.id

  dynamic "ingress" {
    for_each = ["22", "80"]
    iterator = port
    content {

      description      = "TLS from VPC"
      from_port        = port.value
      to_port          = port.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
  egress {
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "Public_ip" {
  value = aws_instance.web123.public_ip
}
