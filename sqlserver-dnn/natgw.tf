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

### NAT GATEWAY CONFIG ###

resource "google_compute_router" "prod_nat_router" {
  project = var.provider_project
  name    = "prod-natgw-router"
  network = module.prod_vpc.network_self_link
  region  = var.prod_region
}

module "prod_vpc_cloud_nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  router     = google_compute_router.prod_nat_router.name
  project_id = var.provider_project
  name       = "prod-natgw"
  region     = var.prod_region
}