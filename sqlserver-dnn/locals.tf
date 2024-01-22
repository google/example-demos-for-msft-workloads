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


### LOCALS ### 

locals {

  project_services = [
    "secretmanager.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "dns.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ]

  ad_domain_netbios = split(".", "${var.ad_domain_name}")[0]

  secrets_ids_accessor = [
    google_secret_manager_secret.local_admin.secret_id,
    google_secret_manager_secret.adds_dsrm.secret_id,
    google_secret_manager_secret.ad_user_password.secret_id,
    google_secret_manager_secret.ad_admin.secret_id,
    google_secret_manager_secret.sql_service.secret_id,
    google_secret_manager_secret.web_service.secret_id
  ]

  secrets_ids_adder = [
    google_secret_manager_secret.ad_admin.secret_id
  ]

  instances_for_metadata_manager = [
    google_compute_instance.dc1.name,
    google_compute_instance.sql1.name,
    google_compute_instance.sql2.name,
    google_compute_instance.web1.name,
    google_compute_instance.witness.name,
    google_compute_instance.jumpbox.name
  ]

  instances_for_reset_gce_vm = [
    google_compute_instance.sql1.name,
    google_compute_instance.sql2.name,
    google_compute_instance.web1.name
  ]
}