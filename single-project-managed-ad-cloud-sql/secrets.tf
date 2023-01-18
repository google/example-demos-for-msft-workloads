/**
 * Copyright 2023 Google LLC
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

### SECRETS CONFIG ### 

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

resource "random_password" "on_prem_ad_user_password" {
  length           = 11
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "adds_trust_password" {
  length           = 15
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_secret_manager_secret" "local_admin" {
  depends_on = [
    time_sleep.wait_90_seconds
  ]
  secret_id = "local-admin"

  labels = {
    label = "local-administrator"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "local_admin" {
  secret      = google_secret_manager_secret.local_admin.id
  secret_data = random_password.local_admin.result
}

resource "google_secret_manager_secret" "managed_ad_admin" {
  depends_on = [
    time_sleep.wait_90_seconds
  ]
  secret_id = "${replace("${var.managed_ad_domain_name}", ".", "-")}-admin"

  labels = {
    label = "${replace("${var.managed_ad_domain_name}", ".", "-")}-admin"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "on_prem_ad_admin" {
  depends_on = [
    time_sleep.wait_90_seconds
  ]
  secret_id = "${replace("${var.on_prem_ad_domain_name}", ".", "-")}-admin"

  labels = {
    label = "${replace("${var.on_prem_ad_domain_name}", ".", "-")}-admin"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "adds_dsrm" {
  depends_on = [
    time_sleep.wait_90_seconds
  ]
  secret_id = "${replace("${var.on_prem_ad_domain_name}", ".", "-")}-dsrm"

  labels = {
    label = "${replace("${var.on_prem_ad_domain_name}", ".", "-")}-dsrm"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "adds_dsrm" {
  secret      = google_secret_manager_secret.adds_dsrm.id
  secret_data = random_password.adds_dsrm.result
}

resource "google_secret_manager_secret" "on_prem_ad_user_password" {
  depends_on = [
    time_sleep.wait_90_seconds
  ]
  secret_id = "${replace("${var.on_prem_ad_domain_name}", ".", "-")}-user"

  labels = {
    label = "${replace("${var.on_prem_ad_domain_name}", ".", "-")}-user"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "on_prem_ad_user_password" {
  secret      = google_secret_manager_secret.on_prem_ad_user_password.id
  secret_data = random_password.on_prem_ad_user_password.result
}

resource "google_secret_manager_secret" "adds_trust_password" {
  depends_on = [
    time_sleep.wait_90_seconds
  ]
  secret_id = "adds-trust-password"

  labels = {
    label = "adds-trust-password"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "adds_trust_password" {
  secret      = google_secret_manager_secret.adds_trust_password.id
  secret_data = random_password.adds_trust_password.result
}

resource "google_secret_manager_secret" "cloudsql_admin_password" {
  depends_on = [
    time_sleep.wait_90_seconds
  ]
  secret_id = "cloudsql-admin"

  labels = {
    label = "cloudsql-admin"
  }

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "cloudsql_admin_password" {
  secret      = google_secret_manager_secret.cloudsql_admin_password.id
  secret_data = module.cloudsql_instance.root_password
}