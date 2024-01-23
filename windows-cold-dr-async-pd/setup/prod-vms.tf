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

resource "google_compute_instance_from_template" "app_vms_from_tpl" {
  for_each = local.app_vms
  name     = each.key
  zone     = each.value.zone
  project  = var.app-prod-project

  source_instance_template = var.app-prod-tpl-self-link

  service_account {
    email  = var.app-prod-service-account
    scopes = var.app-prod-service-account-scopes
  }

  network_interface {
    subnetwork = var.app-prod-ip-subnet

  }

  metadata = {
    windows-startup-script-ps1 = templatefile("./templatefiles/secondary-dc.tpl")
  }
}

resource "google_compute_address" "app_server_ips" {
  for_each     = local.app_vms
  name         = "${each.key}-ip"
  project      = var.app-prod-project
  subnetwork   = var.app-prod-ip-subnet
  address_type = "INTERNAL"
  address      = google_compute_instance_from_template.app_vms_from_tpl[each.key].network_interface.0.network_ip
  region       = var.app-prod-region
}
