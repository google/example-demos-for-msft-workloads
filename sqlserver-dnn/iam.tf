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

### IAM CONFIG ### 

resource "google_secret_manager_secret_iam_member" "prod_compute_service_account" {
  project   = var.provider_project
  for_each  = toset(local.secrets_ids_accessor)
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.prod_compute_service_account.member
}

resource "google_secret_manager_secret_iam_member" "prod_compute_service_account_secretVersionAdder" {
  project   = var.provider_project
  for_each  = toset(local.secrets_ids_adder)
  secret_id = each.value
  role      = "roles/secretmanager.secretVersionAdder"
  member    = google_service_account.prod_compute_service_account.member
}

resource "google_service_account_iam_member" "prod_compute_service_account_serviceAccountUser" {
  service_account_id = google_service_account.prod_compute_service_account.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.prod_compute_service_account.member
}

resource "google_project_iam_custom_role" "metadata_manager" {
  depends_on = [
    time_sleep.api_cool_down_timer
  ]
  project     = var.provider_project
  role_id     = "metadata_manager"
  title       = "Metadata Manager"
  description = "Custom Role to allow Read and Update of Instance Metadata"
  permissions = [
    "compute.instances.setMetadata",
    "compute.instances.get"
  ]
}

resource "google_compute_instance_iam_member" "update_instance_metadata" {
  depends_on = [
    google_project_iam_custom_role.metadata_manager
  ]
  project       = var.provider_project
  zone          = var.prod_zone
  for_each      = toset(local.instances_for_metadata_manager)
  instance_name = each.value
  role          = google_project_iam_custom_role.metadata_manager.name
  member        = google_service_account.prod_compute_service_account.member
}

resource "google_project_iam_custom_role" "reset_gce_vm" {
  depends_on = [
    time_sleep.api_cool_down_timer
  ]
  project     = var.provider_project
  role_id     = "reset_gce_vm"
  title       = "GCE Reset"
  description = "Custom Role to allow resetting a GCE VM"
  permissions = [
    "compute.instances.reset",
    "compute.instances.stop",
    "compute.instances.start"
  ]
}

resource "google_compute_instance_iam_member" "reset_gce_vm" {
  depends_on = [
    google_project_iam_custom_role.reset_gce_vm
  ]
  project       = var.provider_project
  zone          = var.prod_zone
  for_each      = toset(local.instances_for_reset_gce_vm)
  instance_name = each.value
  role          = google_project_iam_custom_role.reset_gce_vm.name
  member        = google_service_account.prod_compute_service_account.member
}