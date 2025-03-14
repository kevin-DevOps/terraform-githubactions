terraform {
  backend "s3" {
    bucket = "terraform-githubactions"
    key = "ecs/hello-world-app/terraform.tfstate"
    region = "ap-southeast-1"
  }
}

provider "aws" {
  region = var.region # "deploying in Singapore Region"
}

resource "aws_ecs_cluster" "cluster" {
  name = var.ecs_cluster_name
}

  resource "aws_iam_role" "ecs_task_execution_role" {
    name = "ecsTaskExecutionRole1"
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
  }

resource "aws_iam_role_policy_attachments_exclusive" "ecs_task_execution_role_policies" {
  role_name = aws_iam_role.ecs_task_execution_role.name

  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_ecs_task_definition" "task" {
  family                   = var.app_name
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name          = var.app_name
      image         = "851725614145.dkr.ecr.ap-southeast-1.amazonaws.com/hello-world-app:latest"
      essential     = true
      portMappings  = [
        {
          containerPort = 3000
          hostPort      = 3000
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
    security_groups = ["sg-0634f73f6531cf0ca"]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_target_group.arn
    container_name   = var.app_name
    container_port   = 3000
  }
}

resource "aws_lb" "app_lb" {
  name               = "${var.app_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-0634f73f6531cf0ca"]
  subnets            = var.subnet_ids
}
resource "aws_lb_target_group" "app_target_group" {
  name        = "${var.app_name}-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}