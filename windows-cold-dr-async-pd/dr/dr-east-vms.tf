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

resource "google_compute_instance" "dr-east-dc" {
  name         = var.failback-east-dc-gce-display-name
  machine_type = var.east-dc-machine-type
  zone         = var.dr-dc-zone
  project      = var.app-dr-east-project

  #  tags = ["foo", "bar"]

  boot_disk {
    source = "projects/${var.app-dr-east-project}/zones/${var.dr-dc-zone}/disks/${var.failback-east-dc-gce-display-name}-secboot"
  }

  network_interface {
    subnetwork = var.east-dr-subnet
    network_ip = var.east-dr-dc-ip
  }

  service_account {
    email  = var.east-dr-sa
    scopes = var.east-dr-sa-scopes
  }

  allow_stopping_for_update = true

}

resource "google_compute_instance" "dr-east-vms" {
  depends_on   = [google_compute_instance.dr-east-dc]
  for_each     = local.app_east_dr_vms
  name         = each.key
  machine_type = each.value.vm_size
  zone         = each.value.zone
  project      = var.app-dr-east-project

  #  tags = ["foo", "bar"]

  boot_disk {
    source      = "projects/${var.app-dr-east-project}/zones/${each.value.dr_boot_disk_zone}/disks/${each.value.dr_boot_disk}"
  }

  network_interface {
    subnetwork = var.east-dr-subnet
    network_ip = data.terraform_remote_state.east_app_server_ip.outputs.east_app_server_ip[each.value.vm_order]
  }

  service_account {
    email  = var.east-dr-sa
    scopes = var.east-dr-sa-scopes
  }

  allow_stopping_for_update = true

}