variable "aws_region" {
  type = "string"
}

variable "vpc_id" {
  description = "VPC ID to create the Presto cluster in"
  type = "string"
}

variable "subnet_id" {
  description = "The subnets to deploy Presto in"
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
  description = "Number of workers to launch."
  type        = "string"
  default     = 0
}
variable "count_workers_spot" {
  description = "Number of workers on spot instances to launch."
  type        = "string"
  default     = 0
}

variable "worker_spot_hourly_price" {
  type        = "string"
  default     = "0.30"
}

variable "coordinator_instance_type" {
  default = "c5.4xlarge"
}

variable "worker_instance_type" {
  default = "c5.4xlarge"
}

variable "coordinator_memory_size" {
  # needs to be heapsize - ~5GB
  type = "string"
  default = 12
}

variable "coordinator_heap_size" {
  type = "string"
  default = 24
}

variable "worker_memory_size" {
  # needs to be heapsize - ~5GB
  type = "string"
  default = 12
}

variable "worker_heap_size" {
  description = "JVM heap size for workers. Recommended to set to 70% of instance memory"
  type = "string"
  default = 24 # 75% of available memory
}

variable "public_facing" {
  default = "false"
}

variable "s3_buckets" {
  type = "list"
  default = [
    "arn:aws:s3:::athena-examples",
    "arn:aws:s3:::athena-examples/*"
  ]
}

variable "additional_security_groups" {
  description = "Additional security groups requiring access to the coordinator for submitting queries"
  type = "list"
  default = []
}