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

### TIMER CONFIG ###

# Sleep timer to allow all required APIs to be enabled and ready to use
resource "time_sleep" "api_cool_down_timer" {
  depends_on = [
    google_project_service.provider_project_apis
  ]
  create_duration = "90s"
}

# Sleep timer to allow all post deployment configuration tasks to complete
resource "time_sleep" "environment_configuration_timer" {
  depends_on = [
    google_compute_instance_iam_member.update_instance_metadata
  ]
  create_duration = "15m"
} 