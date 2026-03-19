# Talos MVP Cluster

Local Kubernetes cluster on Talos Linux with ArgoCD, Prometheus, and Grafana — fully declarative and GitOps-managed.

## Architecture

- **Talos Linux v1.12.5** — immutable Kubernetes OS running as QEMU/KVM VMs via libvirt
- **ArgoCD v3.3.4** — GitOps controller, manages itself and all apps (app-of-apps pattern)
- **Prometheus + Grafana** — monitoring stack via kube-prometheus-stack Helm chart
- **Terraform** — provisions VMs and bootstraps the Talos cluster declaratively

```
┌─────────────────────────────────────────────────────┐
│  Host Machine (KVM)                                 │
│                                                     │
│  ┌──────────────────┐  ┌──────────────────┐        │
│  │ Control Plane     │  │ Worker           │        │
│  │ 192.168.123.10    │  │ 192.168.123.11   │        │
│  │ 4 vCPU / 4GB RAM │  │ 4 vCPU / 8GB RAM │        │
│  │                   │  │                  │        │
│  │ - K8s API server  │  │ - Prometheus     │        │
│  │ - etcd            │  │ - Grafana        │        │
│  │ - ArgoCD          │  │ - Workloads      │        │
│  └──────────────────┘  └──────────────────┘        │
│            │                    │                    │
│            └────────┬───────────┘                    │
│                     │                                │
│           libvirt NAT network                        │
│          192.168.123.0/24                            │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| talosctl | v1.12.5+ | `talosctl version --client` |
| terraform | v1.14+ | `terraform version` |
| kubectl | v1.35+ | `kubectl version --client` |
| KVM | enabled | `kvm-ok` or `ls /dev/kvm` |
| libvirtd | installed | `virsh --connect qemu:///system list` |
| envsubst | any | `which envsubst` |

## Quick Start

```bash
# 1. Clone and configure
git clone <your-gitea-url>/mvp-talos-cluster.git
cd mvp-talos-cluster
cp config.env.example config.env
# Edit config.env — set GIT_REPO_URL to your Gitea repo URL

# 2. Set the Git repo URL in ArgoCD Application manifests
#    Replace ${GIT_REPO_URL} in these files with your actual Gitea URL:
#    - apps/argocd.yaml
#    - apps/kube-prometheus-stack.yaml
#    Then commit and push to Gitea.

# 3. Initialize Terraform
make init

# 4. Deploy everything
make up
```

`make up` runs the full lifecycle:
1. Terraform creates VMs, configures Talos, bootstraps Kubernetes, retrieves kubeconfig
2. Installs ArgoCD seed from upstream manifests
3. Applies the app-of-apps root Application (substitutes `GIT_REPO_URL` via envsubst)
4. ArgoCD takes over and syncs all applications from Git

## Access

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD UI | http://192.168.123.10:30080 | admin / `make argocd-password` |
| Grafana | http://192.168.123.10:30090 | admin / admin |
| kubectl | `export KUBECONFIG=./kubeconfig` | |
| talosctl | `export TALOSCONFIG=./talosconfig` | |

## Makefile Targets

```
make help              Show all targets
make init              Initialize Terraform providers
make plan              Preview Terraform changes
make apply             Create the cluster
make kubeconfig        Extract kubeconfig to ./kubeconfig
make talosconfig       Extract talosconfig to ./talosconfig
make wait-ready        Wait for all nodes to be Ready
make bootstrap         Install ArgoCD and apply app-of-apps
make up                Full lifecycle (apply + bootstrap)
make destroy           Tear down everything
make status            Show nodes, apps, and pods
make argocd-password   Print ArgoCD admin password
```

## Project Structure

```
├── Makefile                          # Lifecycle automation
├── config.env.example                # Template for Git repo URL config
├── terraform/
│   ├── versions.tf                   # Provider version pins
│   ├── variables.tf                  # Configurable inputs
│   ├── main.tf                       # Provider configuration
│   ├── libvirt.tf                    # VMs, network, storage (QEMU/KVM)
│   ├── talos.tf                      # Talos config, bootstrap, kubeconfig
│   └── outputs.tf                    # kubeconfig, talosconfig, IPs
├── bootstrap/
│   └── app-of-apps.yaml             # Root ArgoCD Application (applied once)
├── apps/
│   ├── argocd.yaml                   # ArgoCD manages itself via Helm
│   └── kube-prometheus-stack.yaml    # Prometheus + Grafana
└── helm-values/
    ├── argocd-values.yaml            # ArgoCD Helm overrides
    └── kube-prometheus-stack-values.yaml  # Monitoring stack overrides
```

## GitOps Flow

```
You push to Gitea
       │
       ▼
ArgoCD detects changes ──► Syncs apps/argocd.yaml
       │                        │
       │                        ▼
       │                   ArgoCD Helm chart (self-managed)
       │
       ├──────────────────► Syncs apps/kube-prometheus-stack.yaml
       │                        │
       │                        ▼
       │                   Prometheus + Grafana
       │
       └──────────────────► Any new Application CRs in apps/
```

To add a new application, create an ArgoCD `Application` manifest in `apps/` and push. ArgoCD picks it up automatically.

## Configuration

### Cluster Resources

Edit `terraform/variables.tf` or pass overrides:

```bash
terraform -chdir=terraform apply \
  -var="controlplane_memory=8192" \
  -var="worker_memory=16384" \
  -var="worker_vcpu=8"
```

### Helm Values

Modify files in `helm-values/` and push to Git. ArgoCD auto-syncs the changes.

### Network

Default network is `192.168.123.0/24` (chosen to avoid conflicts with common home networks). Change via Terraform variables if needed.

## Talos-Specific Notes

- **Control plane scheduling is enabled** — with only 2 nodes, workloads must be schedulable on the control plane
- **kubeEtcd, kubeControllerManager, kubeScheduler, kubeProxy** monitoring targets are disabled — Talos does not expose these metrics endpoints in the standard way
- **Alertmanager** is disabled to save resources (MVP scope)
- **No persistent volumes** — Prometheus data is ephemeral; acceptable for MVP

## Teardown

```bash
make destroy
```

This destroys VMs, network, storage pool, and removes local credential files.

## Versions

| Component | Version |
|-----------|---------|
| Talos Linux | v1.12.5 |
| Kubernetes | v1.35.x (bundled with Talos) |
| ArgoCD | v3.3.4 (Helm chart 9.4.15) |
| kube-prometheus-stack | Helm chart 82.12.0 |
| Terraform Talos provider | 0.10.1 |
| Terraform libvirt provider | ~0.9 |
