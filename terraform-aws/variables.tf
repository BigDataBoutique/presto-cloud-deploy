variable "aws_region" {
  type = "string"
}

variable "vpc_id" {
  type = "string"
}

variable "key_name" {
  default = "presto"
}

variable "environment_name" {
  description = "The name of the Presto cluster (aka environment)."
  type = "string"
}

variable "http_port" {
  description = "Port on which to expose the Presto UI."
  type = "string"
  default = "8080"
}

variable "count_workers" {
  description = "Number of workers to launch (in addition to 1 coordinator)."
  type        = "string"
  default     = "1"
}

variable "worker_heap_size" {
  type = "string"
  default = "16g"
}

variable "coordinator_instance_type" {
  default = "c5.4xlarge"
}

variable "worker_instance_type" {
  default = "c5.4xlarge"
}

variable "public_facing" {
  default = "true"
}

variable "coordinator_heap_size" {
  type = "string"
  default = "16g"
}