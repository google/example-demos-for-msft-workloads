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

app-failback-east-ip-subnet = ""

app-failback-east-region = ""

app-failback-east-project = ""

app-failback-dc-zone = ""

app-failback-region = ""

failback-east-dc-gce-display-name = ""

app-east-dc-disk-type = ""

east-dc-machine-type = ""

east-failback-dc-ip = ""

east-failback-sa = ""

east-failback-sa-scopes = [""]






app-prod-east-tpl-self-link = "https://www.googleapis.com/compute/v1/projects/epic-testing-prod-east/global/instanceTemplates/epic-app-tpl"

app-dr-east-tpl-self-link = "https://www.googleapis.com/compute/v1/projects/epic-testing-dr-east/global/instanceTemplates/epic-app-tpl"

app-prod-east-ip-subnet = "projects/epic-testing-shared-svcs/regions/us-east4/subnetworks/prod-epic-app-us-east4"

app-prod-east-ip-region = "us-east4"

app-dr-east-project = "epic-testing-dr-east"

app-prod-east-project = "epic-testing-prod-east"

app-dr-region = "us-central1"

app-dr-dc-zone = "us-central1-a"

app-dr-east-dc-gce-display-name = "ep-dc-east4-001"

app-dr-east-dc-pri-boot-disk-selflink = "projects/epic-testing-prod-east/zones/us-east4-a/disks/ep-dc-east4-001-failback"
