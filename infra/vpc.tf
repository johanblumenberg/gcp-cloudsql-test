locals {
  europe-north1-subnet    = "172.28.0.0/20"
  europe-north1-connector = "172.21.0.0/28"
  cloud-sql-ip-range      = "172.20.0.0/16"
}

resource "google_compute_network" "vpc" {
  name                    = "${terraform.workspace}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "europe_north1_vpc_connector" {
  name                     = "${terraform.workspace}-europe-north1-connector"
  private_ip_google_access = true
  region                   = "europe-north1"
  ip_cidr_range            = local.europe-north1-connector
  network                  = google_compute_network.vpc.self_link
}

resource "google_vpc_access_connector" "connector" {
  name     = "${terraform.workspace}-connector"
  provider = google
  project  = var.project
  region   = var.region

  min_instances = 2
  max_instances = 3

  subnet {
    name = google_compute_subnetwork.europe_north1_vpc_connector.name
  }
}
