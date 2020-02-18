terraform {
  required_version = ">= 0.12"
  required_providers {
    google = "~> 2.0"
  }
}

# Provision MVP KFP infrastructure using reusable Terraform modules from
# github/jarokaz/terraform-gcp-kfp

provider "google" {
    project   = var.project_id 
}

# Create the GKE service account 
module "gke_service_account" {
  source                       = "./modules/service_account"
  service_account_id           = "${var.name_prefix}-gke-sa"
  service_account_display_name = "The GKE service account"
  service_account_roles        = var.gke_service_account_roles
}

# Create the KFP service account 
module "kfp_service_account" {
  source                       = "./modules/service_account"
  service_account_id           = "${var.name_prefix}-sa"
  service_account_display_name = "The KFP service account"
  service_account_roles        = var.kfp_service_account_roles
}

# Create the VPC for the KFP cluster
module "kfp_gke_vpc" {
  source                 = "./modules/vpc"
  region                 = var.region
  network_name           = "${var.name_prefix}-network"
  subnet_name            = "${var.name_prefix}-subnet"
}

# Create the KFP GKE cluster
module "kfp_gke_cluster" {
  source                 = "./modules/gke"
  name                   = "${var.name_prefix}-cluster"
  location               = var.zone != "" ? var.zone : var.region
  description            = "KFP GKE cluster"
  sa_full_id             = module.gke_service_account.service_account.email
  network                = module.kfp_gke_vpc.network_name
  subnetwork             = module.kfp_gke_vpc.subnet_name
  node_count             = var.cluster_node_count
  node_type              = var.cluster_node_type
}

# Create the MySQL instance for ML Metadata
module "ml_metadata_mysql" {
  source  = "./modules/mysql"
  region  = var.region
  name    = "${var.name_prefix}-metadata-3"
}

# Create Cloud Storage bucket for artifact storage
resource "google_storage_bucket" "artifact_store" {
  name          = "${var.name_prefix}-artifact-store"
  force_destroy = true
}

# Create a CAIP Notebook instance
# There are issues with provisioning AI Platform Notebook using Terraform
# As a mitigation we provision the instance using gcloud in install.sh
#module "caip_notebook" {
#  source          = "./modules/caip_notebook"
#  name            = "${var.name_prefix}-notebook"
#  zone            = var.zone
#  machine_type    = var.notebook_machine_type
#  container_image = var.notebook_image
#}
