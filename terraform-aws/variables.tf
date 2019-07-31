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

variable "clients_lb_subnets" {
  description = "A list of subnet IDs to attach to the clients LB"
  type = "list" 
  default = []
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

variable "query_max_memory" {
  description = "Total cluster memory a single query may consume. This property may be used to ensure that single query cannot use all resources in cluster. The value should be set to be higher than what typical expected query in system will need."
  type = "string"
  default = "500GB"
}

variable "count_clients" {
  description = "Number of nodes with Apache Superset and Redash installed."
  type        = "string"
  default     = 0
}

variable "clients_use_spot" {
  description = "Whether to use spot instances for client nodes"
  type        = "string"
  default     = "false" 
}

variable "client_spot_hourly_price" {
  type        = "string"
  default     = "0.30"
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

variable "client_instance_type" {
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

variable "allow_cidr_blocks" {
  description = "Additional CIDR blocks to allow access to the Presto UI from"
  type = "list"
  default = []
}

variable "additional_security_groups" {
  description = "Additional security groups requiring access to the coordinator for submitting queries"
  type = "list"
  default = []
}
