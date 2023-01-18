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

module "network" {
  project_id = var.provider_project
  depends_on = [
    google_project_service.single_project_services
  ]
  source       = "terraform-google-modules/network/google"
  version      = "6.0.0"
  mtu          = 1500
  network_name = var.vpc_network_name
  subnets      = var.vpc_subnets
}

resource "google_compute_global_address" "cloud_sql_service_networking" {
  name          = "cloud-sql-service-networking"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = var.cloud_sql_service_networking_cidr
  prefix_length = 24
  network       = module.network.network_id
}

resource "google_service_networking_connection" "cloud_sql_service_networking" {
  network                 = module.network.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloud_sql_service_networking.name]
}

resource "google_compute_network_peering_routes_config" "peering_routes" {
  peering = google_service_networking_connection.cloud_sql_service_networking.peering
  network = module.network.network_name

  import_custom_routes = true
  export_custom_routes = true
}