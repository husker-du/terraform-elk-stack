
variable "aws_region" {
  description = "The AWS region to deploy into (e.g. us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Instance type of the nodes of the ELK cluster."
  type        = string
  default     = "t2.medium"
}

variable "cluster_name" {
  description = "The name of the elasticsearch cluster."
  type        = string
  default     = "playground"
}

variable "node_names" {
  description = "The name for the EC2 Instance and all other resources in this module."
  type        = list(string)
  default     = ["master-1", "data-1", "data-2"]
}

variable "elastic_port" {
  description = "The port the EC2 Instance should listen on for elasticsearch requests"
  type        = number
  default     = 9200
}

variable "kibana_port" {
  description = "The port the EC2 Instance should listen on for kibana requests"
  type        = number
  default     = 5601
}

variable "logstash_port" {
  description = "The port number of logstash for the beats input"
  type        = number
  default     = 5044
}

variable "key_name" {
  description = "The name of the EC2 Key Pair that can be used to SSH to the EC2 Instance. Leave blank to not associate a Key Pair with the Instance."
  type        = string
  default     = "ec2-key-pair"
}

variable "ssh_key_base_path" {
  description = "Base path of the ssh key file"
  type        = string
  default     = "./.ssh" # Caution! Include this path in the .gitignore file
}

variable "user_name" {
  description = "User name to connect to the instance through SSH"
  type        = string
  default     = "ec2-user"
}

variable "elk_version" {
  description = "Version of the ELK stack"
  type        = string
  default     = "7.6.0"
}

variable "aws_profile" {
  description = "The AWS profile"
  type        = string
  default     = "acg-sandbox"
}

variable "elastic_pwd" {
  description = "The password of the elastic user"
  type        = string
  sensitive   = true
}

variable "kibana_pwd" {
  description = "The password of the kibana user"
  type        = string
  sensitive   = true
}

variable "ca_pass" {
  description = "The password of the root CA"
  type        = string
  sensitive   = true
}

variable "cert_pass" {
  description = "Passwords of the elasticsearch nodes certificates"
  type        = map(string)
  sensitive   = true
}

variable "logstash_pass" {
  description = "Passwords of the logstash certificate"
  type        = string
  sensitive   = true
}

variable "metricbeat_pass" {
  description = "Passwords of the metricbeat certificate"
  type        = string
  sensitive   = true
}
