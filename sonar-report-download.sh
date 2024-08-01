#!/bin/bash

# Create directories for JSON and text reports
mkdir -p Booleanlab-sonar-reports/json
mkdir -p Booleanlab-sonar-reports/human-readable-reports

# Set the token and server URL
TOKEN="squ_6940611dd3bb7f74a894dbf19d2105ead33a2b2a"
SERVER_URL="https://sonarqube.booleanlabs.biz"
PYTHON_SCRIPT="sonar-report-download.py"

# List of project keys and their corresponding repo names
declare -A PROJECTS
PROJECTS=(
  ["booleanlab_ecat-applications-charts-gitops_067aa2a8-b2df-4b40-86e0-dc4cb8d563ea"]="ecat-applications-charts-gitops"
  ["booleanlab_ecat-ui_63960ad4-d0e2-4bf2-8c3c-f42dc8f158d6"]="ecat-ui"
  ["booleanlab_ecat-product-service_89556f65-69d0-4145-879b-a6240f3c3984"]="ecat-product-service"
  ["booleanlab_ecat-customer-service_3a2413b4-8c10-4cce-bc83-b5d9624750f2"]="ecat-customer-service"
  ["booleanlab_ecat-notification-service_9ea2e1d8-0ad6-4d52-86d4-68b30418804b"]="ecat-notification-service"
  ["booleanlab_ecat-application-config_376b781b-4c8e-4530-bce9-eb44cfa15e10"]="ecat-application-config"
  ["booleanlab_ecat-user-service_2b53e04b-5370-4b5e-b1d1-e1c83bfce709"]="ecat-user-service"
  ["booleanlab_ecat-auth-service_5f8218d7-e45c-403b-876c-32d29082add5"]="ecat-auth-service"
  ["booleanlab_ecat-catalogue-service_2534d45a-4ec3-41b0-bb0b-439ca78bd96d"]="ecat-catalogue-service"
  ["booleanlab_ecat-api-gateway_c66d2719-68b5-40bb-aa39-124355587327"]="ecat-api-gateway"
  ["booleanlab_ecat-master-data-service_4802b29e-120b-4f32-9746-da00f6256b80"]="ecat-master-data-service"
  ["booleanlab_ecat-document-service_3363e34a-06ea-4337-9a2c-296d3ab65a6e"]="ecat-document-service"
  ["booleanlab_ecat-activity-service_98a8c2ef-76e0-45d3-9971-99ff6dc18d64"]="ecat-activity-service"
  ["booleanlab_ecat-news-service_4df99ef8-99d0-42d3-9f8c-c53b1dfb71dc"]="ecat-news-service"
  ["booleanlab_ecat-argocd-app-config_b276001c-1d94-46a8-b562-489f4d349184"]="ecat-argocd-app-config"
  ["booleanlab_ecat-analytics-service_3e2e5e90-8b45-456a-8023-6d55d9bccfad"]="ecat-analytics-service"
)

# Fetch reports and convert them
for PROJECT_KEY in "${!PROJECTS[@]}"
do
    REPO_NAME="${PROJECTS[$PROJECT_KEY]}"
    JSON_FILE="Booleanlab-sonar-reports/json/${REPO_NAME}.json"
    TEXT_FILE="Booleanlab-sonar-reports/human-readable-reports/${REPO_NAME}.txt"

    echo "Fetching report for project: $PROJECT_KEY"
    curl -s -H "Authorization: Bearer $TOKEN" "$SERVER_URL/api/issues/search?projectKeys=$PROJECT_KEY" > "$JSON_FILE"

    echo "Converting $JSON_FILE to $TEXT_FILE"
    python3 $PYTHON_SCRIPT "$JSON_FILE" "$TEXT_FILE"
done

