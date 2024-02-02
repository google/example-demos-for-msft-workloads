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

resource "google_compute_instance" "failback-dc" {
  count = var.use-domain-controller ? 1 : 0
  name         = var.app-dc-gce-display-name
  machine_type = var.app-dc-machine-type
  zone         = var.app-prod-dc-zone
  project      = var.app-prod-project

  boot_disk {
    source = "projects/${var.app-prod-project}/zones/${var.app-prod-dc-zone}/disks/${var.app-dc-gce-display-name}-failback"
  }

  network_interface {
    subnetwork = var.app-prod-ip-subnet-self-link
    network_ip = var.app-prod-dc-ip
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = var.app-prod-service-account
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

}

resource "google_compute_instance" "failback-vms" {
  depends_on   = [google_compute_instance.failback-dc]
  for_each     = local.app_failback_vms
  name         = each.key
  machine_type = each.value.vm_size
  zone         = each.value.failback_zone
  project      = var.app-prod-project

  boot_disk {
    source = "projects/${var.app-prod-project}/zones/${each.value.failback_zone}/disks/${each.value.failback_boot_disk}"
  }

  network_interface {
    subnetwork = var.app-prod-ip-subnet-self-link
    network_ip = data.terraform_remote_state.app_server_ip.outputs.app_server_ip[each.value.vm_order]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  
  service_account {
    email  = var.app-prod-service-account
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

}