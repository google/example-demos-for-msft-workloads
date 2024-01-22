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

### VPC IP RESERVATIONS ###

resource "google_compute_address" "wsfc_cluster_ip" {
  name         = "wsfc-cluster-ip"
  subnetwork   = module.prod_vpc.subnets_ids[0]
  address_type = "INTERNAL"
  region       = var.prod_region
}
