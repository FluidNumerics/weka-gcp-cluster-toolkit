variable "cluster_name" {
  type        = string
  description = "Cluster prefix for all resources"
  validation {
    condition     = length(var.cluster_name) <= 37
    error_message = "The cluster name maximum allowed length is 37."
  }
}

variable "project_id" {
  type        = string
  description = "Project id"
}

variable "nics_numbers" {
  type        = number
  description = "Number of nics per host"
  default     = -1

  validation {
    condition     = var.nics_numbers == -1 || var.nics_numbers > 0
    error_message = "The nics_number value can take values > 0 or -1 (for using defaults)."
  }
}

variable "prefix" {
  type        = string
  description = "Prefix for all resources"
  default     = "weka"

  validation {
    condition     = length(var.prefix) <= 15
    error_message = "The prefix maximum allowed length is 15."
  }
}

variable "zone" {
  type        = string
  description = "Zone name"
}

variable "machine_type" {
  type        = string
  description = "Weka cluster backends machines type"
  default     = "c2-standard-8"
  validation {
    condition     = contains(["c2-standard-8", "c2-standard-16"], var.machine_type)
    error_message = "Machine type isn't supported"
  }
}

variable "region" {
  type        = string
  description = "Region name"
}

variable "nvmes_number" {
  type        = number
  description = "Number of local nvmes per host"
  default     = 2
}

variable "assign_public_ip" {
  type        = string
  default     = "auto"
  description = "Determines whether to assign public IP to all instances deployed by TF module. Includes backends, clients and protocol gateways."
  validation {
    condition     = var.assign_public_ip == "true" || var.assign_public_ip == "false" || var.assign_public_ip == "auto"
    error_message = "Allowed assign_public_ip values: [\"true\", \"false\", \"auto\"]."
  }
}

variable "get_weka_io_token" {
  type        = string
  description = "Get get.weka.io token for downloading weka"
  sensitive   = true
  default     = ""
}

variable "install_weka_url" {
  type        = string
  description = "Path to weka installation tar object"
  default     = ""
}

variable "weka_version" {
  type        = string
  description = "Weka version"
  default     = "4.2.11"
}

variable "weka_username" {
  type        = string
  description = "Weka cluster username"
  default     = "admin"
}

variable "cluster_size" {
  type        = number
  description = "Weka cluster size"

  validation {
    condition     = var.cluster_size >= 6
    error_message = "Cluster size should be at least 6."
  }
  default = 6
}

variable "vpc_connector_range" {
  type        = string
  description = "list of connector to use for serverless vpc access"
  default     = "10.8.0.0/28"
}

variable "vpc_connector_id" {
  type        = string
  description = "exiting vpc connector id to use for cloud functions, projects/<project-id>/locations/<region>/connectors/<connector-name>"
  default     = ""
}

variable "sa_email" {
  type        = string
  description = "Service account email"
  default     = ""
}

variable "create_cloudscheduler_sa" {
  type        = bool
  description = "Create GCP cloudscheduler sa"
  default     = true
}

variable "yum_repo_server" {
  type        = string
  description = "Yum repo server address"
  default     = ""
}

variable "allow_ssh_cidrs" {
  type        = list(string)
  description = "Allow port 22, if not provided, i.e leaving the default empty list, the rule will not be included in the SG"
  default     = []
}

variable "allow_weka_api_cidrs" {
  type        = list(string)
  description = "allow connection to port 14000 on weka backends and LB(if exists and not provided with dedicated SG)  from specified CIDRs, by default no CIDRs are allowed. All ports (including 14000) are allowed within VPC"
  default     = []
}

variable "source_image_id" {
  type        = string
  description = "Source image ID to use, by default centos-7 is used, other distributions might work, but only centos-7 is tested by Weka with this TF module"
  default     = "projects/centos-cloud/global/images/centos-7-v20220719"
}

variable "protection_level" {
  type        = number
  default     = 2
  description = "Cluster data protection level."
  validation {
    condition     = var.protection_level == 2 || var.protection_level == 4
    error_message = "Allowed protection_level values: [2, 4]."
  }
}

variable "stripe_width" {
  type        = number
  default     = -1
  description = "Stripe width = cluster_size - protection_level - 1 (by default)."
  validation {
    condition     = var.stripe_width == -1 || var.stripe_width >= 3 && var.stripe_width <= 16
    error_message = "The stripe_width value can take values from 3 to 16."
  }
}

variable "hotspare" {
  type        = number
  default     = 1
  description = "Hot-spare value."
}

variable "default_disk_size" {
  type        = number
  default     = 48
  description = "The default disk size."
}

variable "default_disk_name" {
  type        = string
  default     = "wekaio-volume"
  description = "The default disk name."
}

variable "traces_per_ionode" {
  default     = 10
  type        = number
  description = "The number of traces per ionode. Traces are low-level events generated by Weka processes and are used as troubleshooting information for support purposes."
}

variable "tiering_obs_name" {
  type        = string
  default     = ""
  description = "Name of OBS cloud storage"
}

variable "tiering_enable_obs_integration" {
  type        = bool
  default     = false
  description = "Determines whether to enable object stores integration with the Weka cluster. Set true to enable the integration."
}

variable "tiering_ssd_percent" {
  type        = number
  default     = 20
  description = "When OBS integration set to true , this parameter sets how much of the filesystem capacity should reside on SSD. For example, if this parameter is 20 and the total available SSD capacity is 20GB, the total capacity would be 100GB"
}

variable "set_dedicated_fe_container" {
  type        = bool
  default     = true
  description = "Create cluster with FE containers"
}

variable "state_bucket_name" {
  type        = string
  default     = ""
  description = "Name of bucket state, cloud storage"
}

variable "proxy_url" {
  type        = string
  description = "Weka home proxy url"
  default     = ""
}

variable "create_worker_pool" {
  type        = bool
  default     = false
  description = "Create worker pool"
}

######################## From multivpc variables ##########################

variable "network_names" {
  description = "Names of the new VPC networks"
  type = list(string)
  validation {
    condition     = length(var.network_names) == 4 || length(var.network_names) == 7
    error_message = "The allowed amount of networks are 4 and 7"
  }
}

variable "subnetwork_names" {
  description = "Names of the subnetwork created in each network"
  type = list(string)
  validation {
    condition     = length(var.subnetwork_names) == 4 || length(var.subnetwork_names) == 7
    error_message = "The allowed amount of subnets are 4 and 7"
  }
}

variable "network_self_links" {
  description = "Self link of the VPC networks"
  type = list(string)
  validation {
    condition     = length(var.network_self_links) == 4 || length(var.network_self_links) == 7
    error_message = "The allowed amount of networks are 4 and 7"
  }
}

variable "local_mount" {
  description = "Mountpoint for this WEKAFS on client systems"
  type        = string
  default     = "/data"

  validation {
    condition = alltrue([substr(var.local_mount, 0, 1) == "/"
    ])
    error_message = "Local mountpoints have to start with '/'."
  }
}
variable "vpc_connector_range" {
  type        = string
  default     = "10.8.0.0/28"
  description = "Cidr range for serverless vpc access"
}