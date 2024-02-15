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

### NETWORK CONFIG ###

module "prod_vpc" {
  depends_on = [
    google_project_service.provider_project_apis
  ]

  source       = "terraform-google-modules/network/google"
  version      = "6.0.0"
  project_id   = var.provider_project
  mtu          = 1500
  network_name = var.prod_network_name
  subnets      = var.prod_subnets
}
