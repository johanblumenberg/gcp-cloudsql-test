resource "google_compute_global_address" "cloud_sql_ip_range" {
  name          = "${terraform.workspace}-cloud-sql-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", local.cloud-sql-ip-range)[0]
  prefix_length = parseint(split("/", local.cloud-sql-ip-range)[1], 10)
  network       = google_compute_network.vpc.id
  project       = var.project
}

resource "google_service_networking_connection" "cloud_sql_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloud_sql_ip_range.name]
}

resource "random_integer" "db_suffix" {
  min = 1000
  max = 1999
}
resource "google_sql_database_instance" "postgresql-db01" {
  name                = "${terraform.workspace}-postgresql-db-${random_integer.db_suffix.result}"
  project             = var.project
  region              = var.region
  database_version    = "POSTGRES_13"
  deletion_protection = false

  settings {
    tier              = "db-custom-1-3840"
    activation_policy = "ALWAYS"
    disk_autoresize   = false
    disk_size         = 10
    disk_type         = "PD_HDD"
    pricing_plan      = "PER_USE"

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    database_flags {
      name  = "max_connections"
      value = "5000"
    }

    location_preference {
      zone = var.zone
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.self_link
    }

    maintenance_window {
      day  = "7" # sunday
      hour = "3" # 3am
    }

    backup_configuration {
      binary_log_enabled = false
      enabled            = false
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_error_verbosity"
      value = "verbose"
    }

    insights_config {
      query_insights_enabled = true
    }
  }
  depends_on = [google_service_networking_connection.cloud_sql_vpc_connection]
}

resource "google_compute_firewall" "allow_cloud_sql_egress" {
  project     = var.project
  name        = "${terraform.workspace}-allow-cloud-sql-egress"
  description = "Allow network egress to Cloud SQL"
  network     = google_compute_network.vpc.self_link
  priority    = 1000
  direction   = "EGRESS"

  destination_ranges = [
    local.cloud-sql-ip-range
  ]

  allow {
    protocol = "tcp"
    ports    = ["3307"]
  }
}
