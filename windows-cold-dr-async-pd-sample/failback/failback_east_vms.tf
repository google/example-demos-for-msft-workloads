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

resource "google_compute_instance" "failback-east-dc" {
  name         = var.failback-east-dc-gce-display-name
  machine_type = var.east-dc-machine-type
  zone         = var.app-failback-dc-zone
  project      = var.app-failback-east-project

  #  tags = ["foo", "bar"]

  boot_disk {
    source = "projects/${var.app-failback-east-project}/zones/${var.app-failback-dc-zone}/disks/${var.failback-east-dc-gce-display-name}-failback"
  }

  network_interface {
    subnetwork = var.app-failback-east-ip-subnet
    network_ip = var.east-failback-dc-ip
  }

  service_account {
    email  = var.east-failback-sa
    scopes = var.east-failback-sa-scopes
  }

  allow_stopping_for_update = true

}

resource "google_compute_instance" "failback-east-vms" {
  depends_on   = [google_compute_instance.failback-east-dc]
  for_each     = local.app_east_failback_vms
  name         = each.key
  machine_type = each.value.vm_size
  zone         = each.value.failback_zone
  project      = var.app-failback-east-project

  boot_disk {
    source      = "projects/${var.app-failback-east-project}/zones/${each.value.failback_zone}/disks/${each.value.failback_boot_disk}"
  }

  network_interface {
    subnetwork = var.app-failback-east-subnet
    network_ip = data.terraform_remote_state.east_app_server_ip.outputs.east_app_server_ip[each.value.vm_order]
  }

  service_account {
    email  = var.east-failback-sa
    scopes = var.east-failback-sa-scopes
  }

  allow_stopping_for_update = true

}