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


### LOCALS ### 

locals {

  project_services = [
    "secretmanager.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "managedidentities.googleapis.com",
    "orgpolicy.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com"
  ]

  on_prem_ad_netbios = split(".", "${var.on_prem_ad_domain_name}")[0]

  managed_ad_netbios = split(".", "${var.managed_ad_domain_name}")[0]

  secrets_ids_accessor = [
    google_secret_manager_secret.local_admin.secret_id,
    google_secret_manager_secret.adds_dsrm.secret_id,
    google_secret_manager_secret.managed_ad_admin.secret_id,
    google_secret_manager_secret.on_prem_ad_user_password.secret_id,
    google_secret_manager_secret.adds_trust_password.secret_id,
    google_secret_manager_secret.cloudsql_admin_password.secret_id,
    google_secret_manager_secret.on_prem_ad_admin.secret_id
  ]

  secrets_ids_adder = [
    google_secret_manager_secret.managed_ad_admin.secret_id,
    google_secret_manager_secret.on_prem_ad_admin.secret_id
  ]

  project_iam_roles = [
    "roles/managedidentities.admin",
    "roles/managedidentities.domainAdmin",
    "roles/compute.networkViewer",
    "roles/iam.serviceAccountUser"
  ]

  instances_for_metadata_updater = [
    google_compute_instance.dc1.name,
    google_compute_instance.mgmt_vm.name,
    google_compute_instance.jumpbox.name
  ]
}