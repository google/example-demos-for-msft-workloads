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

### DNS CONFIG ### 

resource "google_dns_policy" "inbound_policy" {
  name                      = "inbound-policy"
  enable_inbound_forwarding = true

  enable_logging = true

  networks {
    network_url = module.network.network_id
  }
}

resource "google_dns_managed_zone" "on_prem_ad_zone" {
  name        = replace("${var.on_prem_ad_domain_name}", ".", "-")
  dns_name    = "${var.on_prem_ad_domain_name}."
  description = "${var.on_prem_ad_domain_name} Private Cloud DNS Zone"

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = module.network.network.network_id
    }
  }

  forwarding_config {
    target_name_servers {
      ipv4_address = google_compute_instance.dc1.network_interface[0].network_ip
    }
  }
}
