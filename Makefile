SHELL := /bin/bash
TERRAFORM_DIR := terraform
KUBECONFIG_FILE := $(shell pwd)/kubeconfig
TALOSCONFIG_FILE := $(shell pwd)/talosconfig
ARGOCD_VERSION := v3.3.4

export KUBECONFIG := $(KUBECONFIG_FILE)
export TALOSCONFIG := $(TALOSCONFIG_FILE)

# Load Git repo URL from config.env
ifneq (,$(wildcard config.env))
  include config.env
  export GIT_REPO_URL
endif

.PHONY: help check-config init plan apply kubeconfig talosconfig wait-ready bootstrap up destroy status argocd-password

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

check-config: ## Verify config.env exists and GIT_REPO_URL is set
	@if [ -z "$(GIT_REPO_URL)" ]; then \
		echo "ERROR: GIT_REPO_URL is not set. Copy config.env.example to config.env and set your Gitea repo URL."; \
		exit 1; \
	fi
	@echo "GIT_REPO_URL=$(GIT_REPO_URL)"

init: ## Initialize Terraform providers
	terraform -chdir=$(TERRAFORM_DIR) init

plan: ## Show Terraform execution plan
	terraform -chdir=$(TERRAFORM_DIR) plan

apply: ## Create the cluster with Terraform
	terraform -chdir=$(TERRAFORM_DIR) apply -auto-approve

kubeconfig: ## Extract kubeconfig from Terraform output
	terraform -chdir=$(TERRAFORM_DIR) output -raw kubeconfig > $(KUBECONFIG_FILE)
	@chmod 600 $(KUBECONFIG_FILE)
	@echo "Kubeconfig written to $(KUBECONFIG_FILE)"

talosconfig: ## Extract talosconfig from Terraform output
	terraform -chdir=$(TERRAFORM_DIR) output -raw talosconfig > $(TALOSCONFIG_FILE)
	@chmod 600 $(TALOSCONFIG_FILE)
	@echo "Talosconfig written to $(TALOSCONFIG_FILE)"

wait-ready: ## Wait for all nodes to be Ready
	@echo "Waiting for nodes to become Ready..."
	kubectl wait --for=condition=Ready nodes --all --timeout=300s

bootstrap: check-config ## Install ArgoCD seed and apply app-of-apps
	@echo "Creating argocd namespace..."
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@echo "Installing ArgoCD $(ARGOCD_VERSION) seed..."
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	@echo "Waiting for ArgoCD server to be ready..."
	kubectl -n argocd rollout status deployment argocd-server --timeout=300s
	@echo "Applying app-of-apps (substituting GIT_REPO_URL)..."
	envsubst < bootstrap/app-of-apps.yaml | kubectl apply -f -
	@echo ""
	@echo "Bootstrap complete! ArgoCD will now sync all applications."
	@echo "Run 'make status' to check progress."

up: apply kubeconfig talosconfig wait-ready bootstrap ## Full lifecycle: create cluster + bootstrap ArgoCD
	@echo ""
	@echo "================================================"
	@echo " Cluster is up and ArgoCD is bootstrapped!"
	@echo "================================================"
	@echo " ArgoCD UI:  http://192.168.123.10:30080"
	@echo " Grafana:    http://192.168.123.10:30090"
	@echo " ArgoCD password: make argocd-password"
	@echo " Grafana login:   admin / admin"
	@echo "================================================"

destroy: ## Tear down the entire cluster
	terraform -chdir=$(TERRAFORM_DIR) destroy -auto-approve
	@rm -f $(KUBECONFIG_FILE) $(TALOSCONFIG_FILE)
	@echo "Cluster destroyed and credentials cleaned up."

status: ## Show cluster and ArgoCD status
	@echo "=== Nodes ==="
	kubectl get nodes -o wide 2>/dev/null || echo "Cluster not reachable"
	@echo ""
	@echo "=== ArgoCD Applications ==="
	kubectl -n argocd get applications 2>/dev/null || echo "ArgoCD not installed"
	@echo ""
	@echo "=== Pods (argocd) ==="
	kubectl -n argocd get pods 2>/dev/null || true
	@echo ""
	@echo "=== Pods (monitoring) ==="
	kubectl -n monitoring get pods 2>/dev/null || true

argocd-password: ## Retrieve ArgoCD initial admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d && echo || echo "Secret not found. ArgoCD may have been redeployed by Helm (check ArgoCD docs for Helm-managed password)."
