terraform {
  backend "s3" {
    bucket = "terraform-githubactions-3-9"
    key = "ecs/hello-world-app/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

provider "AWS" {
  region = var.region # "deploying in Singapore Region"
}

resource "aws_ecs_cluster" "cluster" {
  name = var.ecs_cluster_name
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode(
    {
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "ecs-tasks.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        ]
    }
  )

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_ecs_task_definition" "task" {
  family = var.app_name
  network_mode = "awsvpc"
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
        name = var.app_name
        image = "631229639219.dkr.ecr.ap-south-1.amazonaws.com/hello-world-app:latest"
        essential = true
        portMappings = [
            {
                containerPort = 3000
                hostPort = 3000
            }
        ]
    }
  ])

}

resource "aws_ecs_service" "service" {
  name = var.app_name
  cluster = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count = 1
  launch_type = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    assign_public_ip = true
    security_groups = ["sg-074573236a018cd6c"]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_target_group.arn
    container_name   = var.app_name
    container_port   = 3000
  }
}

resource "aws_lb" "app_lb" {
  name = "${var.app_name}-lb"
  load_balancer_type = "application"
  subnets = var.subnet_ids
  security_groups = ["sg-074573236a018cd6c"] 
  internal = false
}

resource "aws_lb_target_group" "app_target_group" {
  name = "${var.app_name}-tg"
  protocol = "HTTP"
  vpc_id = var.vpc_id
  port = 3000
  target_type = "ip"
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

