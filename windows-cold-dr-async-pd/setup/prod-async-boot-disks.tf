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

resource "google_compute_disk" "dr-sec-boot-disks-for-app-vms" {
  depends_on = [google_compute_instance_from_template.app_vms_from_tpl]
  for_each   = local.sec_boot_disks_for_dr
  name       = each.key
  type       = each.value.disk_type
  zone       = each.value.dr_zone
  project    = var.app-dr-project

  guest_os_features {
    type = "UEFI_COMPATIBLE"
  }

  guest_os_features {
    type = "MULTI_IP_SUBNET"
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }

  guest_os_features {
    type = "GVNIC"
  }

  guest_os_features {
    type = "WINDOWS"
  }

  licenses = ["projects/windows-cloud/global/licenses/windows-server-2022-dc"]

  async_primary_disk {
    disk = "projects/${var.app-prod-project}/zones/${each.value.prim_disk_zone}/disks/${each.value.prim_disk}"
  }

  physical_block_size_bytes = 4096
}

resource "google_compute_disk" "dr-sec-boot-disk-for-dc" {
  count = var.use-domain-controller ? 1 : 0
  name    = "${var.app-dc-gce-display-name}-secboot"
  type    = var.app-dc-disk-type
  zone    = var.app-dr-dc-zone
  project = var.app-dr-project

  guest_os_features {
    type = "UEFI_COMPATIBLE"
  }

  guest_os_features {
    type = "MULTI_IP_SUBNET"
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }

  guest_os_features {
    type = "GVNIC"
  }

  guest_os_features {
    type = "WINDOWS"
  }

  licenses = ["projects/windows-cloud/global/licenses/windows-server-2022-dc"]

  async_primary_disk {
    disk = "projects/${var.app-prod-project}/zones/${var.app-prod-dc-zone}/disks/${var.app-dc-gce-display-name}"
  }

  physical_block_size_bytes = 4096
}

resource "google_compute_disk" "dr-sec-boot-disk-for-sql" {
  count = var.use-sql ? 1 : 0
  name    = "${var.app-sql-gce-display-name}-secboot"
  type    = var.app-sql-disk-type
  zone    = var.app-dr-sql-zone
  project = var.app-dr-project

  guest_os_features {
    type = "UEFI_COMPATIBLE"
  }

  guest_os_features {
    type = "MULTI_IP_SUBNET"
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }

  guest_os_features {
    type = "GVNIC"
  }

  guest_os_features {
    type = "WINDOWS"
  }

  licenses = ["projects/windows-sql-cloud/global/licenses/sql-server-2022-web","projects/windows-cloud/global/licenses/windows-server-2022-dc"]

  async_primary_disk {
    disk = "projects/${var.app-prod-project}/zones/${var.app-prod-sql-zone}/disks/${var.app-sql-gce-display-name}"
  }

  physical_block_size_bytes = 4096
}

resource "google_compute_disk" "dr-sec-data-disk-for-sql" {
  count = var.use-sql ? 1 : 0
  name    = "${var.app-sql-data-disk-name}-secboot"
  type    = var.app-sql-disk-type
  zone    = var.app-dr-sql-zone
  project = var.app-dr-project

  async_primary_disk {
    disk = "projects/${var.app-prod-project}/zones/${var.app-prod-sql-zone}/disks/${var.app-sql-data-disk-name}"
  }

  physical_block_size_bytes = 4096
}