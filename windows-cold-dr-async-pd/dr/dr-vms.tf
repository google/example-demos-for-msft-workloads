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

resource "google_compute_instance" "dr-vms" {
  depends_on   = [google_compute_instance.dr-dc]
  for_each     = local.app_dr_vms
  name         = each.key
  machine_type = each.value.vm_size
  zone         = each.value.zone
  project      = var.app-dr-project

  #  tags = ["foo", "bar"]

  boot_disk {
    source = "projects/${var.app-dr-project}/zones/${each.value.dr_boot_disk_zone}/disks/${each.value.dr_boot_disk}"
  }

  network_interface {
    subnetwork = var.app-dr-ip-subnet-self-link
    network_ip = data.terraform_remote_state.app_server_ip.outputs.app_server_ip[each.value.vm_order]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = var.app-dr-service-account
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

}

resource "google_compute_instance" "dr-dc" {
  count = var.use-domain-controller ? 1 : 0
  name         = var.app-dc-gce-display-name
  machine_type = var.app-dc-machine-type
  zone         = var.app-dr-dc-zone
  project      = var.app-dr-project

  #  tags = ["foo", "bar"]

  boot_disk {
    source = "projects/${var.app-dr-project}/zones/${var.app-dr-dc-zone}/disks/${var.app-dc-gce-display-name}-secboot"
  }

  network_interface {
    subnetwork = var.app-dr-ip-subnet-self-link
    network_ip = var.app-dr-dc-ip
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = var.app-dr-service-account
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

}

resource "google_compute_instance" "dr-sql" {
  count = var.use-sql ? 1 : 0
  depends_on   = [google_compute_instance.dr-dc]
  name         = var.app-sql-gce-display-name
  machine_type = var.app-sql-machine-type
  zone         = var.app-dr-sql-zone
  project      = var.app-dr-project

  boot_disk {
    source = "projects/${var.app-dr-project}/zones/${var.app-dr-sql-zone}/disks/${var.app-sql-gce-display-name}-secboot"
  }

  attached_disk {
    source = "projects/${var.app-dr-project}/zones/${var.app-dr-sql-zone}/disks/${var.app-sql-data-disk-name}-secboot"
  }

  network_interface {
    subnetwork = var.app-dr-ip-subnet-self-link
    network_ip = var.app-dr-sql-ip
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = var.app-dr-service-account
    scopes = ["cloud-platform"]
  }

  allow_stopping_for_update = true

}