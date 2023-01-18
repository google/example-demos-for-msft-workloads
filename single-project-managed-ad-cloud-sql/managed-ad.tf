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

### MANAGED ACTIVE DIRECTORY CONFIG ### 

resource "google_active_directory_domain" "managed_ad_domain" {
  domain_name         = var.managed_ad_domain_name
  locations           = ["${var.default_region}"]
  reserved_ip_range   = var.managed_ad_cidr
  authorized_networks = ["${module.network.network_id}"]
}

resource "google_active_directory_domain_trust" "ad-domain-trust" {
  depends_on = [
    google_active_directory_domain.managed_ad_domain,
    google_compute_instance.dc1,
    time_sleep.wait_5_minutes
  ]
  domain                  = var.managed_ad_domain_name
  target_domain_name      = var.on_prem_ad_domain_name
  target_dns_ip_addresses = ["${google_compute_instance.dc1.network_interface[0].network_ip}"]
  trust_direction         = "OUTBOUND"
  trust_type              = "FOREST"
  trust_handshake_secret  = google_secret_manager_secret_version.adds_trust_password.secret_data
}
