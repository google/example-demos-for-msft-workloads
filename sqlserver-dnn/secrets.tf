/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

## GENERATE RANDOM PASSWORDS ###

resource "random_password" "local_admin" {
  length           = 15
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "adds_dsrm" {
  length           = 15
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "ad_user_password" {
  length           = 11
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "sql_service_password" {
  length           = 15
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "web_service_password" {
  length           = 15
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

### STORE PASSWORDS IN SECRET MANAGER ### 

resource "google_secret_manager_secret" "local_admin" {
  project = var.provider_project
  depends_on = [
    time_sleep.api_cool_down_timer
  ]
  secret_id = "local-admin"

  labels = {
    label = "local-administrator"
  }

  replication {
    auto {

    }
  }
}

resource "google_secret_manager_secret_version" "local_admin" {
  secret      = google_secret_manager_secret.local_admin.id
  secret_data = random_password.local_admin.result
}

resource "google_secret_manager_secret" "ad_admin" {
  project = var.provider_project
  depends_on = [
    time_sleep.api_cool_down_timer
  ]
  secret_id = "${replace("${var.ad_domain_name}", ".", "-")}-admin"

  labels = {
    label = "${replace("${var.ad_domain_name}", ".", "-")}-admin"
  }

  replication {
    auto {

    }
  }
}

resource "google_secret_manager_secret" "adds_dsrm" {
  project = var.provider_project
  depends_on = [
    time_sleep.api_cool_down_timer
  ]
  secret_id = "${replace("${var.ad_domain_name}", ".", "-")}-dsrm"

  labels = {
    label = "${replace("${var.ad_domain_name}", ".", "-")}-dsrm"
  }

  replication {
    auto {

    }
  }
}

resource "google_secret_manager_secret_version" "adds_dsrm" {
  secret      = google_secret_manager_secret.adds_dsrm.id
  secret_data = random_password.adds_dsrm.result
}

resource "google_secret_manager_secret" "ad_user_password" {
  project = var.provider_project
  depends_on = [
    time_sleep.api_cool_down_timer
  ]
  secret_id = "${replace("${var.ad_domain_name}", ".", "-")}-user"

  labels = {
    label = "${replace("${var.ad_domain_name}", ".", "-")}-user"
  }

  replication {
    auto {

    }
  }
}

resource "google_secret_manager_secret_version" "ad_user_password" {
  secret      = google_secret_manager_secret.ad_user_password.id
  secret_data = random_password.ad_user_password.result
}

resource "google_secret_manager_secret" "sql_service" {
  project = var.provider_project
  depends_on = [
    time_sleep.api_cool_down_timer
  ]
  secret_id = "sql-service"

  labels = {
    label = "sql-service"
  }

  replication {
    auto {

    }
  }
}

resource "google_secret_manager_secret_version" "sql_service" {
  secret      = google_secret_manager_secret.sql_service.id
  secret_data = random_password.sql_service_password.result
}

resource "google_secret_manager_secret" "web_service" {
  project = var.provider_project
  depends_on = [
    time_sleep.api_cool_down_timer
  ]
  secret_id = "web-service"

  labels = {
    label = "web-service"
  }

  replication {
    auto {

    }
  }
}

resource "google_secret_manager_secret_version" "web_service" {
  secret      = google_secret_manager_secret.web_service.id
  secret_data = random_password.web_service_password.result
}
