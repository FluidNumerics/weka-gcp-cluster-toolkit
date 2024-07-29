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
}

# Add bits to set up peering between each vpc network
resource "google_compute_network_peering" "peering" {
  count        = length(local.peering_list)
  name         = "${var.prefix}-peering-${local.peering_list[count.index]["from"]}-${local.peering_list[count.index]["to"]}"
  network      = var.network_self_links[local.peering_list[count.index]["from"]]
  peer_network = var.network_self_links[local.peering_list[count.index]["to"]]
}


module "weka_deployment" {
  source                         = "github.com/weka/terraform-gcp-weka?ref=v4.0.12"
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
  containers_config_map          = var.containers_config_map
  protection_level               = var.protection_level
  stripe_width                   = var.stripe_width
  hotspare                       = var.hotspare
  default_disk_size              = var.default_disk_size
  default_disk_name              = var.default_disk_name
  traces_per_ionode              = var.traces_per_ionode
  tiering_obs_name               = var.tiering_obs_name
  tiering_enable_obs_integration = var.tiering_enable_obs_integration
  tiering_ssd_percent            = var.tiering_ssd_percent
}

# Resource needed to get ip addresses of the weka backends -- use the lb url

# # Get the instance group for the weka backends
# data "google_compute_instance_group" "weka" {
#     name = "${var.prefix}-${var.cluster_name}-instance-group"
#     zone = var.zone
# }

# # Need to wait for the 

# # From the instance group, we can get the list of instances
# locals {
#   weka_selflinks = data.google_compute_instance_group.weka.instances
# }

# # Get information about each of the weka backends
# data "google_compute_instance" "weka_backend" {
#   count = length(weka_selflinks)
#   self_link = local.weka_selflinks[count.index]
# }

# # Get the full list of weka backend IP addresses
# locals {
#   weka_ips = [for backend in data.google_compute_instance.weka_backend : backend.network_interface.0.network_ip]
# }
