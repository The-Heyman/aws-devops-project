provider "aws" {
    region = "us-east-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
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

# route
# resource "aws_route" "private_nat_gateway" {
#   route_table_id         = aws_route_table.privateRouteTable1.id
#   destination_cidr_block = "0.0.0.0/0"
#   nat_gateway_id             = aws_nat_gateway.ngw1.id
# }

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

  tags = {
    Name = "PublicRouteTable"
  }
}

# route public
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.publicRouteTable.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.publicRouteTable.id
}

resource "aws_route_table_association" "public_rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.publicRouteTable.id
}

# Add Network Security Groups for LB and Web Server
resource "aws_security_group" "webServerSG" {
  name        = "webServerSG"
  description = "Allow HTTP to hosts and SSH from local only"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "http to hosts"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh from local host"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  }
  resource "aws_security_group" "loadBalancerSG" {
  name        = "loadBalancerSG"
  description = "Allow HTTP to load balancer"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "http to hosts"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  }

# Add webapp launch config
resource "aws_launch_configuration" "appLaunchConfig" {
  name_prefix            = "launch-config-"
  user_data       = file("install_server.sh")
  image_id        = data.aws_ami.ubuntu.id
  instance_type   = "t3.medium"
  key_name        = "awstestingkeys"
  security_groups = [aws_security_group.webServerSG.id]

  lifecycle {
    create_before_destroy = true
  }

}

# Add load balancer target group 
resource "aws_lb_target_group" "webAppTargetGroup" {
  name     = "webAppTargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    unhealthy_threshold = 5
    healthy_threshold   = 2
    timeout             = 8
    interval            = 10
  }
}

# Add autoscaling group
resource "aws_autoscaling_group" "webappASG" {
  name                  = "webappASG"
  vpc_zone_identifier   = [aws_subnet.privateSubnet1.id, aws_subnet.privateSubnet2.id]
  min_size              = 2
  max_size              = 4
  launch_configuration  = aws_launch_configuration.appLaunchConfig.name
  target_group_arns     = [aws_lb_target_group.webAppTargetGroup.arn]

  lifecycle {
    create_before_destroy = true
  }
}

# Add load balancer
resource "aws_lb" "webAppLB" {
  name               = "webapp-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
  security_groups    = [aws_security_group.loadBalancerSG.id]

  enable_deletion_protection = true
}

# Add listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.webAppLB.arn
  port              = "80"
  protocol          = "HTTP"
  # ssl_policy        = "ELBSecurityPolicy-2016-08"
  # certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webAppTargetGroup.arn
  }
}

# Add listener
resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webAppTargetGroup.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

# Add jumphost for troubleshooting
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name = "MyEC2-Keys"
  subnet_id                   = aws_subnet.subnet1.id
  vpc_security_group_ids      = [aws_security_group.webServerSG.id]
  associate_public_ip_address = true

  tags = {
    Name = "Jumphost"
  }
}

output "public_ip" {
  value = aws_instance.web.public_ip
}