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

data "terraform_remote_state" "app_server_ip" {
  backend = "local"

  config = {
    path = "../dr/terraform.tfstate"
  }
}

locals {
  app_failback_vms = {
    "app-001" = { vm_order = 0, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-001-failback" },
    "app-002" = { vm_order = 1, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-002-failback" },
    "app-003" = { vm_order = 2, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-003-failback" },
    "app-004" = { vm_order = 3, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-004-failback" },
    "app-005" = { vm_order = 4, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-005-failback" },
    "app-006" = { vm_order = 5, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-006-failback" },
    "app-007" = { vm_order = 6, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-007-failback" },
    "app-008" = { vm_order = 7, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-008-failback" },
    "app-009" = { vm_order = 8, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-009-failback" },
    "app-010" = { vm_order = 9, vm_size = "e2-medium", failback_zone = "us-east4-a", failback_boot_disk = "app-010-failback" },
  }

  sec_boot_disks_for_dr = {
    "app-001-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-001-failback" },
    "app-002-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-002-failback" },
    "app-003-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-003-failback" },
    "app-004-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-004-failback" },
    "app-005-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-005-failback" },
    "app-006-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-006-failback" },
    "app-007-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-007-failback" },
    "app-008-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-008-failback" },
    "app-009-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-009-failback" },
    "app-010-secboot" = { disk_type = "pd-balanced", dr_zone = "us-central1-a", prim_disk_zone = "us-east4-a", prim_disk = "app-010-failback" },
  }
}