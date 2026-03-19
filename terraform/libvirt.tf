# Storage pool for Talos VM images
resource "libvirt_pool" "talos" {
  name = var.cluster_name
  type = "dir"

  target = {
    path = "/var/lib/libvirt/images/${var.cluster_name}"
  }
}

# Download Talos metal ISO
resource "libvirt_volume" "talos_iso" {
  name = "talos-${var.talos_version}-amd64.iso"
  pool = libvirt_pool.talos.name

  create = {
    content = {
      url = "https://github.com/siderolabs/talos/releases/download/${var.talos_version}/metal-amd64.iso"
    }
  }
}

# Control plane disk
resource "libvirt_volume" "cp_disk" {
  name     = "${var.cluster_name}-cp.qcow2"
  pool     = libvirt_pool.talos.name
  capacity = var.disk_size_gb * 1024 * 1024 * 1024
}

# Worker disk
resource "libvirt_volume" "worker_disk" {
  name     = "${var.cluster_name}-worker.qcow2"
  pool     = libvirt_pool.talos.name
  capacity = var.disk_size_gb * 1024 * 1024 * 1024
}

# NAT network with DHCP reservations
resource "libvirt_network" "talos" {
  name      = var.cluster_name
  autostart = true

  forward = {
    mode = "nat"
    nat = {
      ports = [{ start = 1024, end = 65535 }]
    }
  }

  bridge = {
    name = "virbr-talos"
    stp  = "on"
  }

  ips = [
    {
      family  = "ipv4"
      address = var.gateway_ip
      netmask = "255.255.255.0"

      dhcp = {
        ranges = [
          { start = "192.168.123.100", end = "192.168.123.200" }
        ]

        hosts = [
          {
            mac  = var.controlplane_mac
            name = "${var.cluster_name}-cp"
            ip   = var.controlplane_ip
          },
          {
            mac  = var.worker_mac
            name = "${var.cluster_name}-worker"
            ip   = var.worker_ip
          },
        ]
      }
    }
  ]

  dns = {
    enable = "yes"
  }
}

# Control plane VM
resource "libvirt_domain" "controlplane" {
  name        = "${var.cluster_name}-cp"
  type        = "kvm"
  memory      = var.controlplane_memory
  memory_unit = "MiB"
  vcpu        = var.controlplane_vcpu

  os = {
    type      = "hvm"
    type_arch = "x86_64"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_pool.talos.name
            volume = libvirt_volume.cp_disk.name
          }
        }
        target = { dev = "vda", bus = "virtio" }
        driver = { type = "qcow2" }
        boot   = { order = 2 }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_pool.talos.name
            volume = libvirt_volume.talos_iso.name
          }
        }
        target = { dev = "sda", bus = "sata" }
        boot   = { order = 1 }
      },
    ]

    interfaces = [
      {
        type  = "network"
        model = { type = "virtio" }
        source = {
          network = { network = libvirt_network.talos.name }
        }
        mac = {
          address = var.controlplane_mac
        }
      }
    ]
  }

  running = true
}

# Worker VM
resource "libvirt_domain" "worker" {
  name        = "${var.cluster_name}-worker"
  type        = "kvm"
  memory      = var.worker_memory
  memory_unit = "MiB"
  vcpu        = var.worker_vcpu

  os = {
    type      = "hvm"
    type_arch = "x86_64"
  }

  devices = {
    disks = [
      {
        source = {
          volume = {
            pool   = libvirt_pool.talos.name
            volume = libvirt_volume.worker_disk.name
          }
        }
        target = { dev = "vda", bus = "virtio" }
        driver = { type = "qcow2" }
        boot   = { order = 2 }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_pool.talos.name
            volume = libvirt_volume.talos_iso.name
          }
        }
        target = { dev = "sda", bus = "sata" }
        boot   = { order = 1 }
      },
    ]

    interfaces = [
      {
        type  = "network"
        model = { type = "virtio" }
        source = {
          network = { network = libvirt_network.talos.name }
        }
        mac = {
          address = var.worker_mac
        }
      }
    ]
  }

  running = true
}
