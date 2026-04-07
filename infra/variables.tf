variable "region" {
  type        = string
  default     = ""
  description = "The AWS region to deploy resources in"
}

variable "profile" {
  type        = string
  default     = ""
  description = "The AWS profile to use"
}

variable "environment" {
  type        = string
  default     = ""
  description = "The deployment environment (e.g. dev, staging, prod)"
}

variable "vpc_cidr" {
  type = string

  description = "CIDR block for the VPC"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The vpc_cidr variable must be a valid CIDR block"
  }
}

variable "project" {
  type        = string
  description = "The project name to use in resource naming and tagging"
}

variable "public_subnets" {
  type = list(object({
    suffix            = string
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.public_subnets) > 0
    error_message = "At least one public subnet must be defined"
  }

  validation {
    condition     = length(var.public_subnets) <= 20
    error_message = "No more than 20 public subnets should be defined"
  }

  validation {
    condition     = alltrue([for s in var.public_subnets : can(cidrnetmask(s.cidr_block))])
    error_message = "All public subnet CIDR blocks must be valid CIDR notation (e.g. 10.0.1.0/24)"
  }
  // cidrnetmask --> Returns the netmask of the cidr, is cidr is invalid return error
  // can --> return true if the expression can be evaluated without error, otherwise false instead of throwing an error
  // alltrue --> returns true if all elements of the list are true, otherwise false

  validation {
    condition     = length(var.public_subnets) == length(distinct([for s in var.public_subnets : s.suffix]))
    error_message = "Public subnet names must be unique"
  }

  validation {
    condition     = length(var.public_subnets) == length(distinct([for s in var.public_subnets : s.cidr_block]))
    error_message = "Public subnet CIDR blocks must be unique"
  }
}

variable "private_subnets" {
  type = list(object({
    suffix            = string
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition     = length(var.private_subnets) > 0
    error_message = "At least one private subnet must be defined"
  }

  validation {
    condition     = length(var.private_subnets) <= 20
    error_message = "No more than 20 private subnets should be defined"
  }

  validation {
    condition     = alltrue([for s in var.private_subnets : can(cidrnetmask(s.cidr_block))])
    error_message = "All private subnet CIDR blocks must be valid CIDR notation (e.g. 10.0.1.0/24)"
  }

  validation {
    condition     = length(var.private_subnets) == length(distinct([for s in var.private_subnets : s.suffix]))
    error_message = "Private subnet names must be unique"
  }

  validation {
    condition     = length(var.private_subnets) == length(distinct([for s in var.private_subnets : s.cidr_block]))
    error_message = "Private subnet CIDR blocks must be unique"
  }
}

variable "account_id" {
  type        = string
  description = ""
  sensitive   = true
}

variable "addon_versions" {
  type = object({
    coredns        = string
    kube_proxy     = string
    vpc_cni        = string
    ebs_csi_driver = string
  })
  default = {
    coredns        = "v1.11.1-eksbuild.4"
    kube_proxy     = "v1.30.0-eksbuild.2"
    vpc_cni        = "v1.18.1-eksbuild.1"
    ebs_csi_driver = "v1.31.0-eksbuild.1"
  }
}

variable "cluster_version" {
  type        = string
  description = "The Kubernetes version for the EKS cluster (e.g. 1.24)"
}


variable "key_name" {
  type = string
}

variable "node_instance_types" {
  type        = list(string)
  description = "The EC2 instance types for the EKS worker nodes (e.g. t3.medium)"
}

variable "node_disk_size" {
  type        = number
  description = "The disk size (in GB) for the EKS worker nodes"
}

variable "node_desired_size" {
  type        = string
  description = "The desired size for the EKS worker node group"
}

variable "node_min_size" {
  type        = string
  default     = ""
  description = "The minimum size for the EKS worker node group"
}

variable "node_max_size" {
  type        = string
  default     = ""
  description = "The maximum size for the EKS worker node group"
}


variable "rds" {
  description = "RDS configuration"
  type = object({
    identifier_suffix   = string
    engine              = string
    engine_version      = string
    instance_class      = string
    allocated_storage   = number
    db_name             = string
    master_username     = string
    publicly_accessible = bool
    skip_final_snapshot = bool
  })
}

# variable "db_root_username" {
#   type        = string
#   description = "The master username for the RDS database"
# }

# variable "db_root_password" {
#   type        = string
#   description = "The master password for the RDS database"
# }

variable "db_kubernetes_service_name" {
  type        = string
  description = ""
  sensitive   = true
}

variable "db_app_username" {
  type        = string
  description = "The application username for the RDS database"
  sensitive   = true
}

variable "db_app_password" {
  type        = string
  description = "The application password for the RDS database"
  sensitive   = true
}

variable "db_name" {
  type        = string
  description = "The name of the RDS database"
  sensitive   = true
}

variable "session_secret_key" {
  type        = string
  description = "A random string used as the session secret key in the application"
  sensitive   = true
}

