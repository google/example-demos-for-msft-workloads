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

resource "google_compute_disk" "dr-sec-boot-disks-for-east-vms" {
  depends_on = [google_compute_instance.failback-east-vms]
  for_each = local.sec_boot_disks_for_dr_east
  name     = each.key
  type     = each.value.disk_type
  zone     = each.value.dr_zone
  project  = var.app-dr-east-project

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
    disk = "projects/${var.app-prod-east-project}/zones/${each.value.prim_disk_zone}/disks/${each.value.prim_disk}"
  }

  physical_block_size_bytes = 4096
}

resource "google_compute_disk" "dr-sec-boot-disk-for-east-dc" {
  name       = "${var.app-dr-east-dc-gce-display-name}-secboot"
  type       = var.app-east-dc-disk-type
  zone       = var.app-dr-dc-zone
  project    = var.app-dr-east-project

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
    disk = var.app-dr-east-dc-pri-boot-disk-selflink
  }

  physical_block_size_bytes = 4096
}