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
  availability_zone     = "us-east-2a"

  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id                = aws_vpc.vpc.id
  cidr_block            = "10.0.1.0/24"
  availability_zone     = "us-east-2b"

  tags = {
    Name = "PublicSubnet2"
  }
}

resource "aws_subnet" "privateSubnet1" {
  vpc_id                = aws_vpc.vpc.id
  cidr_block            = "10.0.2.0/24"
  availability_zone     = "us-east-2a"

  tags = {
    Name = "PrivateSubnet1"
  }
}

resource "aws_subnet" "privateSubnet2" {
  vpc_id                = aws_vpc.vpc.id
  cidr_block            = "10.0.3.0/24"
  availability_zone     = "us-east-2b"

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

# Private subnet 1 routing
resource "aws_route_table" "privateRouteTable1" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw1.id
  }

  tags = {
    Name = "PrivateRouteTable1"
  }
}

resource "aws_route_table_association" "privateSubnet1_rta" {
  subnet_id      = aws_subnet.privateSubnet1.id
  route_table_id = aws_route_table.privateRouteTable1.id
}

# Private subnet 2 routing
resource "aws_route_table" "privateRouteTable2" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw2.id
  }

  tags = {
    Name = "PrivateRouteTable2"
  }
}

resource "aws_route_table_association" "privateSubnet2_rta" {
  subnet_id      = aws_subnet.privateSubnet2.id
  route_table_id = aws_route_table.privateRouteTable2.id
}


# Public subnet routing
resource "aws_route_table" "publicRouteTable" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

resource "aws_route_table_association" "public_rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.publicRouteTable.id
}

resource "aws_route_table_association" "public_rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.publicRouteTable.id
}