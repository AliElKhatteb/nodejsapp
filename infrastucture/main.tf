provider "aws" {
  region = var.region
<<<<<<< HEAD
  access_key = "AKIAVDTENUFV3Y7YG2IA"
  secret_key = "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"
=======
  access_key = "sa"
  secret_key = "sa"
>>>>>>> 879d39eb4a0b959507f13d15740b961779e6298c
}

locals {
  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = var.vpc-name
  cidr = "10.99.0.0/18"

  azs              = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnets   = ["10.99.0.0/24","10.99.1.0/24","10.99.2.0/24"]

  tags = local.tags
}
resource "aws_subnet" "database_subnet1" {
  vpc_id     = module.vpc.vpc_id
  cidr_block = "10.99.8.0/24"
  availability_zone = "${var.region}a"
}

resource "aws_subnet" "database_subnet2" {
  vpc_id     = module.vpc.vpc_id
  cidr_block = "10.99.7.0/24"
  availability_zone = "${var.region}b"
}
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.database_subnet2.id, aws_subnet.database_subnet1.id]

  tags = {
    Name = "My DB subnet group"
  }
}
resource "aws_db_instance" "default" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "mydb"
  username              = "ali"
  password             = "Just4trial1999"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.default.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = var.sg-name
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "all-icmp","http-8080-tcp","ssh-tcp"]
  egress_rules        = ["all-all"]

  tags = local.tags
}


resource "aws_lb" "main_lb" {
    name               = var.alb_name
    internal           = false
    load_balancer_type = "application" 
    security_groups    = [module.security_group.security_group_id]
    subnets            = [element(module.vpc.public_subnets, 0),element(module.vpc.public_subnets, 1)]
    enable_cross_zone_load_balancing = "true"
    tags = {
         Environment = "dev"
         Role        = "main-lb"
    }
}

resource "aws_lb_target_group" "tg" {
   name               = var.alb_name
   target_type        = "instance"
   port               = 80
   protocol           = "HTTP"
   vpc_id             = module.vpc.vpc_id
   health_check {
      healthy_threshold   = var.health_check["healthy_threshold"]
      interval            = var.health_check["interval"]
      unhealthy_threshold = var.health_check["unhealthy_threshold"]
      timeout             = var.health_check["timeout"]
      path                = var.health_check["path"]
      port                = var.health_check["port"]
  }
  depends_on = [
    aws_lb.main_lb
  ]
  }
resource "aws_lb_listener" "lb_listener_http" {
   load_balancer_arn    = aws_lb.main_lb.arn
   port                 = "80"
   protocol             = "HTTP"
   default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}


resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "myKey3"       # Create "myKey" to AWS!!
  public_key = tls_private_key.pk.public_key_openssh
}
resource "local_file" "pem_file" {
  filename = pathexpand("./myKey3.pem")
  file_permission = "400"
  sensitive_content = tls_private_key.pk.private_key_pem
}
output "ssh_key" {
  description = "ssh key generated by terraform"
  sensitive = true
  value       = tls_private_key.pk.private_key_pem
}
resource  "aws_instance" "docker-machine1" {

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
  key_name = aws_key_pair.kp.key_name
  user_data = file("./docker-machine-userdata.sh")

  tags = {
        Name = "${var.machine-name}-t1"
   }
}
resource  "aws_instance" "jenkins-master" {

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
  key_name = aws_key_pair.kp.key_name
  user_data = file("./jenkins-userdata.sh")

  tags = {
        Name = "Jenkins"
   }
}
resource  "aws_instance" "docker-machine2" {

  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
  key_name = aws_key_pair.kp.key_name
  user_data = file("./docker-machine-userdata.sh")

  tags = {
        Name = "${var.machine-name}-t2"
   }
}
resource "aws_lb_target_group_attachment" "tg_attachment_machin1" {   
    target_group_arn = aws_lb_target_group.tg.arn
    target_id        = aws_instance.docker-machine1.id
    port             = 80
}
resource "aws_lb_target_group_attachment" "tg_attachment_machine2" {   
    target_group_arn = aws_lb_target_group.tg.arn
    target_id        = aws_instance.docker-machine2.id
    port             = 80
}



