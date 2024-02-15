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

### DNS CONFIG ### 

resource "google_dns_managed_zone" "prod_dns_zone" {
  project     = var.provider_project
  name        = replace("${var.ad_domain_name}", ".", "-")
  dns_name    = "${var.ad_domain_name}."
  description = "${var.ad_domain_name} Private Cloud DNS Zone"

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = module.prod_vpc.network.network_id
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address = google_compute_instance.dc1.network_interface[0].network_ip
    }
  }
}

