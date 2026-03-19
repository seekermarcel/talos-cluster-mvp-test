terraform {
  required_version = ">= 1.14.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.1"
    }
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
