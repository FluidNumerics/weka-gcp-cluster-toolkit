# Copyright 2024 Fluid Numerics LLC
#
# Redistribution and use in source and binary forms, with or without modification, 
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, 
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors 
#    may be used to endorse or promote products derived from this software without 
#    specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND 
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY 
# OF SUCH DAMAGE.

#Requirements
# * Must use multivpc module -- we need to add a community module to enable multivpc peering
# * Multivpc network peering between networks must be enabled
# * MTU size preferred at 8896
# * Get zone and region from multivpc 
# Map the multivpc to weka vpc variables
# locals{
#   vpcs_name = []

#   #vpcs_name                      = ["weka-vpc-0", "weka-vpc-1", "weka-vpc-2", "weka-vpc-3"]
#   #subnets_name                   = ["weka-subnet-0", "weka-subnet-1", "weka-subnet-2", "weka-subnet-3"]
# }


# From https://github.com/weka/terraform-gcp-weka/blob/95ddd39017667e43ec7f8821645c78b6d0ac5753/modules/network/main.tf
locals {
  vpcs_number = length(var.subnetwork_names)
  temp = flatten([
    for from in range(local.vpcs_number) : [
      for to in range(local.vpcs_number) : {
        from = from
        to   = to
      }
    ]
  ])
  peering_list = [for t in local.temp : t if t["from"] != t["to"]]
  vpc_connector_region_map = {
    europe-west4       = "europe-west1"
    europe-north1      = "europe-west1",
    us-east5           = "us-east1",
    southamerica-west1 = "northamerica-northeast1",
    asia-south2        = "asia-south1",
  }
}

# Add bits to set up peering between each vpc network
resource "google_compute_network_peering" "peering" {
  count        = length(local.peering_list)
  name         = "${var.prefix}-peering-${local.peering_list[count.index]["from"]}-${local.peering_list[count.index]["to"]}"
  network      = var.network_self_links[local.peering_list[count.index]["from"]]
  peer_network = var.network_self_links[local.peering_list[count.index]["to"]]
}

resource "google_dns_managed_zone" "private_zone" {
  name        = "${var.prefix}-private-zone"
  dns_name    = "${var.prefix}.private.net."
  project     = var.project_id
  description = "private dns weka.private.net"
  visibility  = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = var.network_self_links
      content {
        network_url = networks.value
      }
    }
  }
}

resource "google_compute_subnetwork" "connector_subnet" {
  name                     = "${var.prefix}-subnet-connector"
  project                  = var.project_id
  ip_cidr_range            = var.vpc_connector_range
  region                   = lookup(local.vpc_connector_region_map, var.region, var.region)
  private_ip_google_access = true
  network                  = var.network_names[0]
}

resource "google_vpc_access_connector" "connector" {
  provider = google-beta
  project  = var.project_id
  name     = "${var.prefix}-connector"
  region   = lookup(local.vpc_connector_region_map, var.region, var.region)
  subnet {
    name       = google_compute_subnetwork.connector_subnet.name
    project_id = var.project_id
  }
  lifecycle {
    ignore_changes = [network]
  }
}

module "weka_deployment" {
  source                         = "github.com/fluidnumerics/terraform-gcp-weka"
  cluster_name                   = var.cluster_name
  get_weka_io_token              = var.get_weka_io_token
  project_id                     = var.project_id
  prefix                         = var.prefix
  region                         = var.region
  zone                           = var.zone
  machine_type                   = var.machine_type
  nvmes_number                   = var.nvmes_number
  cluster_size                   = var.cluster_size
  weka_version                   = var.weka_version
  vpcs_name                      = var.network_names # From multivpc module
  subnets_name                   = var.subnetwork_names # From multivpc module
  source_image_id                = var.source_image_id
  protection_level               = var.protection_level
  stripe_width                   = var.stripe_width
  hotspare                       = var.hotspare
  default_disk_size              = var.default_disk_size
  default_disk_name              = var.default_disk_name
  traces_per_ionode              = var.traces_per_ionode
  tiering_obs_name               = var.tiering_obs_name
  tiering_enable_obs_integration = var.tiering_enable_obs_integration
  tiering_enable_ssd_percent     = var.tiering_ssd_percent
  private_dns_name               = google_dns_managed_zone.private_zone.dns_name
  private_zone_name              = google_dns_managed_zone.private_zone.name
  vpc_connector_id               = google_vpc_access_connector.connector.id
}

# Wait for the cluster to be ready
resource "null_resource" "wait_for_wekafs" {
  provisioner "local-exec" {
    command = "timeout 25m ${path.module}/scripts/wait_for_wekafs_ready.sh"
    environment = {
      WEKA_CLUSTER_STATUS_URI = module.weka_deployment.get_cluster_status_uri
    }
  }
}

# # Get the instance group for the weka backends
data "google_compute_instance_group" "weka" {
    name = "${var.prefix}-${var.cluster_name}-instance-group"
    zone = var.zone
    depends_on = [ null_resource.wait_for_wekafs ]
}

# From the instance group, we can get the list of instances
locals {
  weka_selflinks = tolist(data.google_compute_instance_group.weka.instances)
}

# # Get information about each of the weka backends
data "google_compute_instance" "weka_backend" {
  count = 1
  self_link = local.weka_selflinks[count.index]
}

# Get the full list of weka backend IP addresses
locals {
  weka_ips = [for backend in data.google_compute_instance.weka_backend : backend.network_interface.0.network_ip]
}

### Destroy WEKA backend on terraform destroy
### Weka backend servers are not maintained in Terraform
### Instead, the WEKA backend servers are provisioned by cloud functions
### that are tracked by Terraform. This null_resource is used to call the
### cloud functions to de-provision the weka backends

# resource "null_resource" "destroy_weka_backends" {
#   provisioner "local-exec" {
#     when = destroy
#     command = "timeout 5m ./scripts/destroy_weka_backends.sh"
#     environment = {
#       TERMINATE_CLUSTER_URI = module.weka_deployment.terminate_cluster_uri
#       CLUSTER_NAME = var.cluster_name
#     }
#   }
# }
