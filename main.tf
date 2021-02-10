provider "aws" {
    region = "us-east-2"
}

resource "aws_vpc" "vpc" {
  cidr_block            = "10.0.0.0/16"
  enable_dns_hostnames  = true

  tags = {
    Name = "lexagram-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "lexagramIGW"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                = aws_vpc.vpc.id
  cidr_block            = "10.0.0.0/24"
  availability_zone     = 1

  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                = aws_vpc.vpc.id
  cidr_block            = "10.0.1.0/24"
  availability_zone     = 2

  tags = {
    Name = "PublicSubnet2"
  }
}

resource "aws_subnet" "subnet3" {
  vpc_id                = aws_vpc.vpc.id
  cidr_block            = "10.0.2.0/24"
  availability_zone     = 1

  tags = {
    Name = "PrivateSubnet1"
  }
}

resource "aws_subnet" "subnet4" {
  vpc_id                = aws_vpc.vpc.id
  cidr_block            = "10.0.3.0/24"
  availability_zone     = 2

  tags = {
    Name = "PrivateSubnet2"
  }
}

resource "aws_eip" "nat_ip1" {
  vpc = true

  depends_on                = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat_ip2" {
  vpc = true

  depends_on                = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "ngw1" {
  allocation_id = aws_eip.nat_ip1.id
  subnet_id     = aws_subnet.subnet1.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "gw NAT"
  }
}

resource "aws_nat_gateway" "ngw2" {
  allocation_id = aws_eip.nat_ip2.id
  subnet_id     = aws_subnet.subnet2.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "gw NAT 2"
  }
}
