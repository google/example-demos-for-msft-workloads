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

resource "google_compute_disk_async_replication" "dr-async-replication-for-app-servers" {
  for_each     = local.sec_boot_disks_for_dr
  depends_on   = [google_compute_disk.dr-sec-boot-disks-for-app-vms]
  primary_disk = "projects/${var.app-prod-project}/zones/${each.value.prim_disk_zone}/disks/${each.value.prim_disk}"
  secondary_disk {
    disk = google_compute_disk.dr-sec-boot-disks-for-app-vms[each.key].id
  }
}

resource "google_compute_disk_async_replication" "dr-async-replication-for-dc" {
  count = var.use-domain-controller ? 1 : 0
  depends_on   = [google_compute_disk.dr-sec-boot-disk-for-dc]
  primary_disk = var.app-prod-dc-disk-selflink
  secondary_disk {
    disk = google_compute_disk.dr-sec-boot-disk-for-dc[count.index].id
  }
}

resource "google_compute_disk_async_replication" "dr-async-replication-for-sql-boot" {
  count = var.use-sql ? 1 : 0
  depends_on   = [google_compute_disk.dr-sec-boot-disk-for-sql]
  primary_disk = "projects/${var.app-prod-project}/zones/${var.app-prod-sql-zone}/disks/${var.app-sql-gce-display-name}"
  secondary_disk {
    disk = google_compute_disk.dr-sec-boot-disk-for-sql[count.index].id
  }
}

resource "google_compute_disk_async_replication" "dr-async-replication-for-sql-data" {
  count = var.use-sql ? 1 : 0
  depends_on   = [google_compute_disk.dr-sec-data-disk-for-sql]
  primary_disk = "projects/${var.app-prod-project}/zones/${var.app-prod-sql-zone}/disks/${var.app-sql-data-disk-name}"
  secondary_disk {
    disk = google_compute_disk.dr-sec-data-disk-for-sql[count.index].id
  }
}