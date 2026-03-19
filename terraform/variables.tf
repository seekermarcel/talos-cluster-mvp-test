variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "talos-mvp"
}

variable "controlplane_ip" {
  description = "Static IP for the control plane node"
  type        = string
  default     = "192.168.123.10"
}

variable "worker_ip" {
  description = "Static IP for the worker node"
  type        = string
  default     = "192.168.123.11"
}

variable "network_cidr" {
  description = "CIDR for the libvirt network"
  type        = string
  default     = "192.168.123.0/24"
}

variable "gateway_ip" {
  description = "Gateway IP (libvirt host bridge)"
  type        = string
  default     = "192.168.123.1"
}

variable "controlplane_memory" {
  description = "Memory for control plane node in MiB"
  type        = number
  default     = 4096
}

variable "controlplane_vcpu" {
  description = "vCPUs for control plane node"
  type        = number
  default     = 4
}

variable "worker_memory" {
  description = "Memory for worker node in MiB"
  type        = number
  default     = 8192
}

variable "worker_vcpu" {
  description = "vCPUs for worker node"
  type        = number
  default     = 4
}

variable "disk_size_gb" {
  description = "Disk size for each node in GB"
  type        = number
  default     = 20
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "v1.12.5"
}

variable "controlplane_mac" {
  description = "MAC address for control plane node"
  type        = string
  default     = "52:54:00:ab:cd:10"
}

variable "worker_mac" {
  description = "MAC address for worker node"
  type        = string
  default     = "52:54:00:ab:cd:11"
}
