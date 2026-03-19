# Generate machine secrets
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# Generate control plane machine configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.controlplane_ip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = talos_machine_secrets.this.talos_version
  docs             = false
  examples         = false
}

# Generate worker machine configuration
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.controlplane_ip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = talos_machine_secrets.this.talos_version
  docs             = false
  examples         = false
}

# Generate talosctl client configuration
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [var.controlplane_ip, var.worker_ip]
  endpoints            = [var.controlplane_ip]
}

# Apply configuration to control plane node
resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [libvirt_domain.controlplane]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.controlplane_ip
  endpoint                    = var.controlplane_ip

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
        network = {
          hostname = "${var.cluster_name}-cp"
        }
      }
      cluster = {
        allowSchedulingOnControlPlanes = true
      }
    }),
  ]

  timeouts = {
    create = "10m"
  }
}

# Apply configuration to worker node
resource "talos_machine_configuration_apply" "worker" {
  depends_on = [libvirt_domain.worker]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = var.worker_ip
  endpoint                    = var.worker_ip

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = "/dev/vda"
        }
        network = {
          hostname = "${var.cluster_name}-worker"
        }
      }
    }),
  ]

  timeouts = {
    create = "10m"
  }
}

# Bootstrap the cluster on the control plane
resource "talos_machine_bootstrap" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane,
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ip
  endpoint             = var.controlplane_ip

  timeouts = {
    create = "10m"
  }
}

# Retrieve kubeconfig
resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    talos_machine_configuration_apply.worker,
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.controlplane_ip
  endpoint             = var.controlplane_ip

  timeouts = {
    create = "10m"
  }
}
