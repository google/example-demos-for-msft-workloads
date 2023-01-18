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

### CLOUD SQL SERVER INSTANCE CONFIG ### 

module "cloudsql_instance" {
  project_id          = var.provider_project
  source              = "GoogleCloudPlatform/sql-db/google//modules/mssql"
  version             = "13.0.1"
  deletion_protection = false
  depends_on = [
    google_service_networking_connection.cloud_sql_service_networking,
    google_active_directory_domain.managed_ad_domain,
    google_project_iam_binding.cloudsql_service_account_managed_ad
  ]
  active_directory_config = {
    domain = var.managed_ad_domain_name
  }
  name              = var.cloudsql_instance_name
  availability_type = "ZONAL"
  database_version  = "SQLSERVER_2019_STANDARD"
  zone              = var.default_zone
  ip_configuration = {
    allocated_ip_range  = google_compute_global_address.cloud_sql_service_networking.name
    authorized_networks = []
    ipv4_enabled        = false
    private_network     = module.network.network_id
    require_ssl         = false
  }
}