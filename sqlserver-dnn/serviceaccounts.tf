/**
 * Copyright 2024 Google LLC
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

### SERVICE ACCOUNTS CONFIG ### 

resource "google_service_account" "prod_compute_service_account" {
  depends_on = [
    time_sleep.api_cool_down_timer
  ]
  project      = var.provider_project
  account_id   = "prod-compute-service-account"
  display_name = "Service Account for Compute Engine Instances in Prod"
}
