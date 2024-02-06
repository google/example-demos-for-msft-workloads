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
###########################
### Configure Variables ###
###########################

# Set this variable first in your command line interface
# Bash
# > export app_prod_project=REPLACE_WITH_SERVICE_PROJECT_FOR_PRODUCTION_PROJECT_ID
# > export shared_vpc_host_project=REPLACE_WITH_YOUR_SHARED_VPC_PROJECT_ID

#####################################
### Failback/Production Variables ###
#####################################

use-domain-controller = false
# Default value is FALSE
# Set value to TRUE if you plan to manually build a Domain Controller as part of the demo

app-prod-project = "epic-testing-prod-east"

app-prod-ip-subnet-self-link = "projects/epic-testing-shared-svcs/regions/us-east4/subnetworks/prod-epic-app-us-east4"
# Run this gcloud command to get the self link
# > gcloud compute networks subnets describe prod-app-us-east4 --region=us-east4 --project=$shared_vpc_host_project --format="value(selfLink)"

app-prod-service-account = "770779208912-compute@developer.gserviceaccount.com"
# Run this gcloud command to get the Service Account
# > gcloud iam service-accounts list --project=$app_prod_project

app-prod-dc-zone = "us-east4-a"
# Default is us-east4-a

app-dc-gce-display-name = ""
# Leave the variable value as blank if you are not using a Domain Controller

app-prod-dc-ip = ""
# Leave the variable value as blank if you are not using a Domain Controller

app-dc-disk-type = ""
# Leave the variable value as blank if you are not using a Domain Controller

app-dc-machine-type = ""
# Leave the variable value as blank if you are not using a Domain Controller

####################
### DR Variables ###
####################
app-dr-project = "epic-testing-dr-east"

app-dr-region = "us-central1"
# Default is us-central1

app-dr-dc-zone = ""
# Leave the variable value as blank if you are not using a Domain Controller