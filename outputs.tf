
output "weka_deployment_output" {
  value = module.weka_deployment
}

output "network_storage" {
  description = "export of all desired folder directories"
  value = [{
    remote_mount          = "/${var.default_disk_name}"
    local_mount           = var.local_mount
    fs_type               = "wekafs"
    mount_options         = "net=udp,remove_after_secs=900"
    server_ip             = module.weka_deployment.lb_url
    client_install_runner = ""
    mount_runner          = ""
    }
  ]
}
