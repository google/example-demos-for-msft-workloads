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

locals {
  app_vms = {
    "app-001" = { zone = "us-east4-a" },
    "app-002" = { zone = "us-east4-a" },
    "app-003" = { zone = "us-east4-a" },
    "app-004" = { zone = "us-east4-a" },
    "app-005" = { zone = "us-east4-a" },
    "app-006" = { zone = "us-east4-a" },
    "app-007" = { zone = "us-east4-a" },
    "app-008" = { zone = "us-east4-a" },
    "app-009" = { zone = "us-east4-a" },
    "app-010" = { zone = "us-east4-a" },
  }

  sec_boot_disks_for_dr = {
    "app-001-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-001" },
    "app-002-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-002" },
    "app-003-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-003" },
    "app-004-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-004" },
    "app-005-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-005" },
    "app-006-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-006" },
    "app-007-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-007" },
    "app-008-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-008" },
    "app-009-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-009" },
    "app-010-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-010" },
  }
}