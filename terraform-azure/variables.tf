variable "azure_location" {
  type = "string"
  default = "East US"
}

variable "azure_client_id" {
  type = "string"
  default = ""
}

variable "azure_client_secret" {
  type = "string"
  default = ""
}

variable "azure_subscription_id" {
  type = "string"
}

variable "azure_tenant_id" {
  type = "string"
}

variable "presto_cluster" {
  description = "Name of the elasticsearch cluster, used in node discovery"
  default = "my-cluster"
}

variable "key_path" {
  description = "Key name to be used with the launched EC2 instances."
  default = "~/.ssh/id_rsa.pub"
}

variable "environment" {
  default = "default"
}



variable "http_port" {
  description = "Port on which to expose the Presto UI."
  type        = string
  default     = "8080"
}

variable "query_max_memory" {
  description = "Total cluster memory a single query may consume. This property may be used to ensure that single query cannot use all resources in cluster. The value should be set to be higher than what typical expected query in system will need."
  type        = number
  default     = 500
}


variable "count_clients" {
  description = "Number of nodes with Apache Superset and Redash installed."
  type        = string
  default     = 1
}

variable "count_workers" {
  description = "Number of workers to launch."
  type        = string
  default     = 0
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
  type = "string"
  default = "Standard_D12_v2"
}

variable "worker_instance_type" {
  type = "string"
  default = "Standard_D12_v2"
}

variable "worker_spot_instance_type" {
  type = "string"
  default = "Standard_D12_v2"
}

variable "client_instance_type" {
  type = "string"
  default = "Standard_A2_v2"
}

variable "coordinator_heap_size" {
  # needs to be ~80% of available machine memory
  type    = string
  default = 25
}

variable "presto_coordinator_volume_size" {
  type = string
  default = 10
}

variable "worker_heap_size" {
  description = "JVM heap size for workers. Recommended to set to 80% of instance memory"
  type        = string
  default     = 102 # 80% of available memory
}

variable "extra_worker_configs" {
  type    = string
  default = <<EOF
#task.max-partial-aggregation-memory=64MB
#node-scheduler.max-splits-per-node=1000
EOF
}

variable "public_facing" {
  type = bool
  default = false
}
