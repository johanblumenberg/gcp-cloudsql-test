resource "google_compute_subnetwork" "europe_north1-service" {
  name                     = "${terraform.workspace}-europe-north1-service"
  private_ip_google_access = true
  region                   = "europe-north1"
  ip_cidr_range            = local.europe-north1-subnet
  network                  = google_compute_network.vpc.self_link
}

resource "google_cloud_run_v2_service" "service" {
  name                = "${terraform.workspace}-service"
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"

  template {
    execution_environment = "EXECUTION_ENVIRONMENT_GEN1"
    service_account       = google_service_account.service.email

    timeout = "600s"

    containers {
      image = var.service_image

      startup_probe {
        failure_threshold     = 230 # Max 4 minutes
        initial_delay_seconds = 5
        timeout_seconds       = 1
        period_seconds        = 1

        http_get {
          path = "/debug/info"
        }
      }
      liveness_probe {
        failure_threshold     = 3
        initial_delay_seconds = 0
        timeout_seconds       = 2
        period_seconds        = 30

        http_get {
          path = "/debug/info"
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        startup_cpu_boost = false
        cpu_idle          = true
      }

      env {
        name  = "DB_CONNECTION_URL"
        value = "jdbc:postgresql:///${google_sql_database.service-postgresql-db.name}?cloudSqlInstance=${google_sql_database_instance.postgresql-db01.connection_name}&socketFactory=com.google.cloud.sql.postgres.SocketFactory&user=${google_sql_user.service-postgresql-user.name}&password=password&enableIamAuth=true&ipTypes=PRIVATE&cloudSqlRefreshStrategy=lazy"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 5
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.vpc.name
        subnetwork = google_compute_subnetwork.europe_north1-service.name
      }
#      connector = google_vpc_access_connector.connector.id
      egress = "ALL_TRAFFIC"
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  depends_on = [
    google_service_networking_connection.cloud_sql_vpc_connection,
    google_sql_database.service-postgresql-db,
    google_sql_user.service-postgresql-user,
    google_service_account.service,
    google_compute_firewall.allow_cloud_sql_egress,
  ]
}

resource "google_sql_database" "service-postgresql-db" {
  name      = "${terraform.workspace}-db"
  project   = var.project
  instance  = google_sql_database_instance.postgresql-db01.name
  charset   = ""
  collation = ""

  depends_on = [google_sql_user.service-postgresql-user]
}

# create user
resource "google_sql_user" "service-postgresql-user" {
  name     = "${terraform.workspace}-service@${var.project}.iam"
  project  = var.project
  instance = google_sql_database_instance.postgresql-db01.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_service_account" "service" {
  account_id   = "${terraform.workspace}-service"
  display_name = "Service account for test service"
}

resource "google_project_iam_member" "service-roles" {
  for_each = toset([
    "roles/cloudsql.instanceUser",
    "roles/cloudsql.client",
    "roles/compute.networkUser",
  ])

  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.service.email}"
}

data "google_iam_policy" "cloud-run-noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "auth-gw-noauth" {
  location    = google_cloud_run_v2_service.service.location
  project     = google_cloud_run_v2_service.service.project
  service     = google_cloud_run_v2_service.service.name
  policy_data = data.google_iam_policy.cloud-run-noauth.policy_data
}
