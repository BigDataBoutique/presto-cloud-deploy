variable "aws_region" {
  type = string
}

variable "subnet_ids" {
  description = "The subnets to deploy Trino in. At least two subnets must be in different availability zones. All subnets must be in the same VPC."
  type        = list(string)
}

variable "key_name" {
  default = "office-key"
}

variable "environment_name" {
  description = "The name of the Trino cluster (aka environment)."
  type        = string
  validation {
    condition     =  can(regex("^[0-9A-Za-z]+$", var.environment_name))
    error_message = "Trino environment name can only contain alphanumerics."
  }

}

variable "http_port" {
  description = "Port on which to expose the Trino UI."
  type        = string
  default     = "8080"
}

variable "query_max_memory" {
  description = "Total cluster memory a single query may consume. This property may be used to ensure that single query cannot use all resources in cluster. The value should be set to be higher than what typical expected query in system will need."
  type        = number
  default     = 500
}

variable "count_workers" {
  description = "Number of workers to launch."
  type        = string
  default     = 1
}

variable "count_workers_spot" {
  description = "Number of workers on spot instances to launch."
  type        = string
  default     = 0
}

variable "worker_spot_hourly_price" {
  type    = string
  default = "0.99"
}

variable "coordinator_instance_type" {
  default = "r5.xlarge"
}

variable "worker_instance_type" {
  default = "r5.4xlarge"
}

variable "coordinator_heap_size" {
  # needs to be ~80% of available machine memory
  type    = string
  default = 25
}


variable "worker_heap_size" {
  description = "JVM heap size for workers. Recommended to set to 80% of instance memory"
  type        = string
  default     = 102 # 80% of available memory
}

variable "extra_worker_configs" {
  type    = string
  default = <<EOF
#node-scheduler.max-splits-per-node=1000
EOF
}

variable "public_facing" {
  type = bool
  default = false
}

variable "s3_buckets" {
  type = list(string)
  default = [
    "arn:aws:s3:::athena-examples",
    "arn:aws:s3:::athena-examples/*",
  ]
}


variable "allow_cidr_blocks" {
  description = "Additional CIDR blocks to allow access to the Trino UI from"
  type        = list(string)
  default     = []
}

variable "additional_security_groups" {
  description = "Additional security groups requiring access to the coordinator for submitting queries"
  type        = list(string)
  default     = []
}

# Example usage
# additional_bootstrap_scripts = [
#   {
#     script_url = "s3://path/to/script/setup-custom-plugin.sh"
#     type = "s3"
#     script_name = "setup-plugin.sh"
#     params = [
#       "--arg1", "val1",
#       "--arg2", "val2",
#     ]
#   }
# ]
variable "additional_bootstrap_scripts" {
  description = "Additional scripts to run on the nodes as they are being bootstrapped"
  type        = list(object({
    script_url = string,
    type = string,
    script_name = string,
    params = list(string)
  }))
  default     = []
}
