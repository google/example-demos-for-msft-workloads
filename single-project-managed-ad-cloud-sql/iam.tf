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

### IAM CONFIG ### 

resource "google_project_iam_binding" "cloudsql_service_account_managed_ad" {
  project = var.provider_project
  depends_on = [
    google_project_service_identity.cloudsql_service_account
  ]
  role = "roles/managedidentities.sqlintegrator"

  members = [
    "serviceAccount:${google_project_service_identity.cloudsql_service_account.email}",
  ]
}

resource "google_project_iam_member" "compute_service_account_project_IAM" {
  project  = var.provider_project
  member   = google_service_account.demo_compute.member
  for_each = toset(local.project_iam_roles)
  role     = each.value
}

resource "google_secret_manager_secret_iam_member" "compute_service_account_secretAccessor" {
  for_each  = toset(local.secrets_ids_accessor)
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.demo_compute.member
}

resource "google_secret_manager_secret_iam_member" "compute_service_account_secretVersionAdder" {
  for_each  = toset(local.secrets_ids_adder)
  secret_id = each.value
  role      = "roles/secretmanager.secretVersionAdder"
  member    = google_service_account.demo_compute.member
}

resource "google_project_iam_custom_role" "update_metadata" {
  role_id     = "update_metadata"
  title       = "Metadata Updater"
  description = "Users in this role are granted the compute.instances.setMetadata permission to update Instance metadata"
  permissions = ["compute.instances.setMetadata"]
}

resource "google_compute_instance_iam_member" "update_instance_metadata" {
  depends_on = [
    google_project_iam_custom_role.update_metadata
  ]
  zone          = var.default_zone
  for_each      = toset(local.instances_for_metadata_updater)
  instance_name = each.value
  role          = google_project_iam_custom_role.update_metadata.name
  member        = google_service_account.demo_compute.member
}