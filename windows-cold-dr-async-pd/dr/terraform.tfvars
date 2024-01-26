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

####################
### DR Variables ###
####################

use-domain-controller = false
# Default value is FALSE
# Set value to TRUE if you plan to manually build a Domain Controller as part of the demo

app-dr-project = "REPLACE_WITH_SERVICE_PROJECT_FOR_DR_PROJECT_ID"

app-dr-ip-subnet-self-link = "REPLACE_WITH_IP_SUBNET_FOR_PROD_SELF_LINK"
# Run this gcloud command to get the self link
# > gcloud compute networks subnets describe dr-app-us-east4 --region=us-central1 --project=REPLACE_WITH_YOUR_SHARED_VPC_PROJECT_ID --format="value(selfLink)"

app-dr-service-account = "REPLACE_WITH_COMPUTE_ENGINE_DEFAULT_SERVICE_ACCOUNT"
# Run this gcloud command to get the Service Account
# > gcloud iam service-accounts list --project=REPLACE_WITH_SERVICE_PROJECT_FOR_DR_PROJECT_ID

app-dc-gce-display-name = ""
# Leave the variable value as blank if you are not using a Domain Controller

app-dc-disk-type = ""
# Leave the variable value as blank if you are not using a Domain Controller

app-dc-machine-type = ""
# Leave the variable value as blank if you are not using a Domain Controller

app-dr-dc-ip = ""
# Leave the variable value as blank if you are not using a Domain Controller

app-dr-dc-zone = ""
# Leave the variable value as blank if you are not using a Domain Controller

#####################################
### Failback/Production Variables ###
#####################################
app-prod-project = "REPLACE_WITH_SERVICE_PROJECT_FOR_PRODUCTION_PROJECT_ID"

app-prod-dc-zone = ""
# Leave the variable value as blank if you are not using a Domain Controller