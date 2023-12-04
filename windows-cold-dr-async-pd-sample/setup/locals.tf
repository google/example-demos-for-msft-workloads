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
  app_east_vms = {
    "east-app-001"={zone="us-east4-a"},
    "east-app-002"={zone="us-east4-a"},
    "east-app-003"={zone="us-east4-a"},
    "east-app-004"={zone="us-east4-a"},
    "east-app-005"={zone="us-east4-a"},
    "east-app-006"={zone="us-east4-a"},
    "east-app-007"={zone="us-east4-a"},
    "east-app-008"={zone="us-east4-a"},
    "east-app-009"={zone="us-east4-a"},
    "east-app-010"={zone="us-east4-a"},
  }

  sec_boot_disks_for_dr_east = {
    "east-app-001-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-001"},
    "east-app-002-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-002"},
    "east-app-003-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-003"},
    "east-app-004-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-004"},
    "east-app-005-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-005"},
    "east-app-006-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-006"},
    "east-app-007-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-007"},
    "east-app-008-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-008"},
    "east-app-009-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-009"},
    "east-app-010-secboot"={disk_type="pd-balanced",dr_zone="us-central1-a",prim_disk_zone="us-east4-a",prim_disk="east-app-010"},
  }
}