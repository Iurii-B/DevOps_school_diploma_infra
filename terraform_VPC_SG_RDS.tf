provider "aws" {
access_key = "XXX"
secret_key = "XXX"
region = "eu-central-1"
}



resource "aws_internet_gateway" "terraform_igw" {
  vpc_id = aws_vpc.terraform_vpc.id

  tags = {
    Name = "terraform_igw"
  }
}



resource "aws_route_table" "terraform_route_table" {
  vpc_id = aws_vpc.terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_igw.id
  }
}

resource "aws_route_table_association" "terraform_subnet_1" {
  subnet_id      = aws_subnet.terraform_subnet_1.id
  route_table_id = aws_route_table.terraform_route_table.id
}


resource "aws_route_table_association" "terraform_subnet_2" {
  subnet_id      = aws_subnet.terraform_subnet_2.id
  route_table_id = aws_route_table.terraform_route_table.id
}

resource "aws_vpc" "terraform_vpc" {
  cidr_block       = "172.31.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "terraform_vpc"
  }
}


resource "aws_subnet" "terraform_subnet_1" {
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = "172.31.16.0/20"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "terraform_subnet_1"
  }
}


resource "aws_subnet" "terraform_subnet_2" {
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = "172.31.32.0/20"
  map_public_ip_on_launch = "true"

  tags = {
    Name = "terraform_subnet_2"
  }
}

resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["5.18.240.0/21"]
  security_group_id = "${aws_security_group.terraform_sg.id}"
}


resource "aws_security_group_rule" "flask" {
  type              = "ingress"
  from_port         = 5000
  to_port           = 5000
  protocol          = "tcp"
  cidr_blocks       = ["5.18.240.0/21"]
  security_group_id = "${aws_security_group.terraform_sg.id}"
}


resource "aws_security_group_rule" "mysql" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["5.18.240.0/21"]
  security_group_id = "${aws_security_group.terraform_sg.id}"
}


resource "aws_security_group_rule" "icmp" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.terraform_sg.id}"
}


resource "aws_security_group_rule" "tcp_inside" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["172.16.0.0/12"]
  security_group_id = "${aws_security_group.terraform_sg.id}"
}


resource "aws_security_group_rule" "allow_all_outside" {
  type              = "egress"
  from_port         = -1
  to_port           = -1
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.terraform_sg.id}"
}



resource "aws_security_group" "terraform_sg" {
  name        = "terrafrom_sg"
  description = "Allow SSH and MySQL inbound from 5.18.240.0/21"
  vpc_id      = aws_vpc.terraform_vpc.id
  tags = {
    Name = "terraform_sg"
  }
}



data "aws_subnet_ids" "subnet_ids" {
    vpc_id = aws_vpc.terraform_vpc.id
}


resource "aws_db_subnet_group" "database1-subnet-group" {
    name = "database1"
    subnet_ids = data.aws_subnet_ids.subnet_ids.ids
}


resource "aws_db_instance" "database1" {
    engine = "mariadb"
    engine_version = "10.4.13"
    instance_class = "db.t2.medium"
    name = "database1"
    identifier = "database1"
    username = "XXX"
    password = "XXX"
    parameter_group_name = "default.mariadb10.4"
    db_subnet_group_name = aws_db_subnet_group.database1-subnet-group.name
    vpc_security_group_ids = [aws_security_group.terraform_sg.id]
    publicly_accessible = true
    skip_final_snapshot = true
    allocated_storage = 20
    auto_minor_version_upgrade = false
}


output "this_db_instance_address" {
    value = aws_db_instance.database1.address
}
