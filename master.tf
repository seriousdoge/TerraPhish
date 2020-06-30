####################
#VARIABLES
####################
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "key_name" {}
variable "key_path" {}
variable "domain_name" {}
variable "dkim_value" {}
variable "dmarc" {
    default = "_dmarc"
}
variable "region" {
    default = "eu-west-1"
}

####################
#PROVIDERS
####################

provider "aws" {
    access_key = var.aws_access_key
    secret_key = var.aws_secret_key
    region = var.region
}

####################
#RESOURCES
####################

resource "aws_instance" "Ubuntu_x64" {
  ami           = "ami-008320af74136c628"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}","${aws_security_group.allow_tls.id}","${aws_security_group.allow_http.id}"]
  subnet_id = "${aws_subnet.public.id}"
  associate_public_ip_address= "true"
  key_name = var.key_name
  tags = {
    Name = "my_key"
  }
 
  connection {
      host = self.public_ip
      type = "ssh"
      user = "ubuntu"
      private_key = "${file(var.key_path)}"
      timeout     = "1m"
      agent = false
    }
  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/script.sh",
      "sudo /tmp/script.sh ${var.domain_name} ${var.dkim_value}",
    ]
  }
 }

resource "aws_vpc" "mainvpc" {
  cidr_block = "10.1.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.mainvpc.id}"

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "route-table-main" {
  vpc_id = "${aws_vpc.mainvpc.id}"
route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
tags = {
    Name = "route-table"
  }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.route-table-main.id}"
}

resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.mainvpc.id}"
  cidr_block              = "10.1.0.0/16" 
  map_public_ip_on_launch = true
  tags = {
    Name                  = "Public Subnet"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = "${aws_vpc.mainvpc.id}"

  ingress {
    description = "SSH from VPC"
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

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = "${aws_vpc.mainvpc.id}"

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
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
    Name = "allow_http"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.mainvpc.id}"

  ingress {
    description = "TLS from VPC"
    from_port   = 443
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
    Name = "allow_tls"
  }
}

resource "aws_eip" "elastic_ip" {
  instance = "${aws_instance.Ubuntu_x64.id}"
  vpc      = true
}

resource "aws_route53_record" "www" {

     zone_id = "${data.aws_route53_zone.main.zone_id}"
     name    = var.domain_name
     type    = "A"
     ttl = "300"
     records = ["${aws_instance.Ubuntu_x64.public_ip}"]
}

resource "aws_route53_record" "mail_record" {

     zone_id = "${data.aws_route53_zone.main.zone_id}"
     name    = var.domain_name
     type    = "MX"
     ttl = "300"
     records = ["10 mail.${var.domain_name}"]
}

resource "aws_route53_record" "SPF" {

     zone_id = "${data.aws_route53_zone.main.zone_id}"
     name    = var.domain_name
     type    = "TXT"
     records = ["v=spf1 mx -all"]
     ttl = "300"
}

resource "aws_route53_record" "DMARC" {

     zone_id = "${data.aws_route53_zone.main.zone_id}"
     name    = "${var.dmarc}.${var.domain_name}"
     type    = "TXT"
     records = ["v=DMARC1;p=quarantine;sp=quarantine;adkim=r;aspf=r"]
     ttl = "300"
}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

output "instance_ips" {
  value = ["${aws_instance.Ubuntu_x64.public_ip}"]
}