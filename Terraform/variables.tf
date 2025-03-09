variable "region" {
  description = "AWS region to create resource in"
  type        = string
  default     = "ap-southeast-1"
}

variable "ecs_cluster_name" {
  description = "ECS cluster's name"
  type = string
}

variable "app_name" {
  description = "Application's name"
  type = string
}

variable "vpc_id" {
  description = "The ID of VPC where resource will be created"
  type = string
}

variable "subnet_ids" {
  description = "The list of subnet IDs for the ECS Service"
  type = list(string)
}