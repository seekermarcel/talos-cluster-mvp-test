output "kubeconfig" {
  description = "Kubernetes kubeconfig for the Talos cluster"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talos client configuration for talosctl"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "controlplane_ip" {
  description = "Control plane node IP address"
  value       = var.controlplane_ip
}

output "worker_ip" {
  description = "Worker node IP address"
  value       = var.worker_ip
}
