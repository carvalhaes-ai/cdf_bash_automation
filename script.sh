#!/bin/bash

if [ "$#" -ne 11 ]; then
  echo "Usage: $0 <PROJECT_ID> <LOCATION> <MYSQL_DATABASE> <MYSQL_DB_USER> <MYSQL_DB_PASSWORD> <MYSQL_TABLE> <BIGQUERY_DATASET> <BIGQUERY_TABLE> <INSTANCE_NAME> <INSTANCE_EDITION> <PIPELINE_NAME>"
  exit 1
fi

# Handle input arguments
PROJECT_ID="$1"
LOCATION="$2"
MYSQL_DATABASE="$3"
MYSQL_DB_USER="$4"
MYSQL_DB_PASSWORD="$5"
MYSQL_TABLE="$6"
BIGQUERY_DATASET="$7"
BIGQUERY_TABLE="$8"
INSTANCE_NAME="$9"
INSTANCE_EDITION="${10}"
PIPELINE_NAME="${11}"

# Additional variables
ACCESS_TOKEN=$(gcloud auth print-access-token)
NAMESPACE_ID=default
CONNECTION_NAME=cloudsql-mysql-connection
JDBC_PLUGIN_NAME=$PROJECT_ID:$LOCATION:$MYSQL_DATABASE
TMP_FILE=$(mktemp)

# Paths to local files
PATH_TO_CLOUDSQL_MYSQL_CONN=cloudsql_mysql_conn.json  # Database connection
PATH_TO_CLOUDSQL_MYSQL_JDBC=cloudsql_mysql_jdbc.json  # Driver's metadata
PATH_TO_MYSQL_SCHEMA=mysql_schema.json  # Describes the data schema
PATH_TO_PIPELINE=pipeline.json  # Pipeline template file
PATH_TO_QUERY=query.sql  # Sql query to extract the data from the source table

# Url to download the mysql JAR file
URL_JDBC_FACTORY_RELEASES=https://github.com/GoogleCloudPlatform/cloud-sql-jdbc-socket-factory/releases/download/v1.0.16
URL_JDBC_DRIVER=${URL_JDBC_FACTORY_RELEASES}/mysql-socket-factory-connector-j-8-1.0.16-jar-with-driver-and-dependencies.jar

 # Create a new Fusion instance
 gcloud beta data-fusion instances create "${INSTANCE_NAME}" \
   --edition="${INSTANCE_EDITION}" \
   --location="${LOCATION}" \
   --zone="${LOCATION}-a"

# Capture the instance endpoint
CDAP_ENDPOINT=$(gcloud beta data-fusion instances describe \
  --location="${LOCATION}" \
  --format="value(apiEndpoint)" \
  "${INSTANCE_NAME}")


 # Download and deploy the CloudSQL MySQL driver
 curl -L "${URL_JDBC_DRIVER}" -o "${TMP_FILE}"
 curl -X POST "${CDAP_ENDPOINT}/v3/namespaces/${NAMESPACE_ID}/artifacts/cloudsql-mysql" \
   -H "Authorization: Bearer ${ACCESS_TOKEN}" \
   -H "Artifact-Version: 8-1.0.16-jar-with-driver-and-dependencies" \
   -H "Artifact-Plugins: $(cat $PATH_TO_CLOUDSQL_MYSQL_JDBC)" \
   -H "Content-Type: application/octet-stream" \
   --data-binary @"$TMP_FILE"

 # Update the connection template file
 jq --arg nm "$CONNECTION_NAME" --arg db "$MYSQL_DATABASE" --arg cn "$JDBC_PLUGIN_NAME" --arg ur "$MYSQL_DB_USER" --arg pw "$MYSQL_DB_PASSWORD" '
   .name = $nm |
   .plugin.properties.database = $db |
   .plugin.properties.connectionName = $cn |
   .plugin.properties.user = $ur |
   .plugin.properties.password = $pw' \
   "$PATH_TO_CLOUDSQL_MYSQL_CONN" > "$TMP_FILE"

 # Deploy the connection
 curl -X PUT -H "Authorization: Bearer ${ACCESS_TOKEN}" \
   -H "Content-Type: application/json" \
   --data-binary "@${TMP_FILE}" \
 "${CDAP_ENDPOINT}/v3/namespaces/system/apps/pipeline/services/studio/methods/v1/contexts/${NAMESPACE_ID}/connections/${CONNECTION_NAME}"

# Loads the SQL query, replace placeholders, and export to a string
STR_QUERY=$(<"$PATH_TO_QUERY" tr '\n' ' ' | sed 's/"/\\"/g' | sed "s/\$database/${MYSQL_DATABASE}/g" | sed "s/\$table/${MYSQL_TABLE}/g")

# Load the data schema into a string
STR_SCHEMA=$(<"$PATH_TO_MYSQL_SCHEMA" jq -c .)

# Update the pipeline template file
jq --arg qu "$STR_QUERY" --arg db "$MYSQL_DATABASE" --arg sc "$STR_SCHEMA" --arg ds "$BIGQUERY_DATASET" --arg tb "$BIGQUERY_TABLE" '
   (.config.stages[] | select(.name == "CloudSQL MySQL").plugin.properties.importQuery) |= $qu |
   (.config.stages[] | select(.name == "CloudSQL MySQL").plugin.properties.database) |= $db |
   (.config.stages[] | select(.name == "CloudSQL MySQL").plugin.properties.schema) |= $sc |
   (.config.stages[] | select(.name == "CloudSQL MySQL").outputSchema[].schema) |= $sc |
   (.config.stages[] | select(.name == "BigQuery").plugin.properties.dataset) |= $ds |
   (.config.stages[] | select(.name == "BigQuery").plugin.properties.table) |= $tb |
   (.config.stages[] | select(.name == "BigQuery").inputSchema[].schema) |= $sc
' "$PATH_TO_PIPELINE" > "$TMP_FILE"

# Deploy the pipeline
curl -X PUT -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    --data-binary "@${TMP_FILE}" \
    "${CDAP_ENDPOINT}/v3/namespaces/${NAMESPACE_ID}/apps/${PIPELINE_NAME}"

 # Enable the pipeline schedule if desired
 curl -X POST -H "Authorization: Bearer ${ACCESS_TOKEN}" \
 "${CDAP_ENDPOINT}/v3/namespaces/${NAMESPACE_ID}/apps/${PIPELINE_NAME}/schedules/dataPipelineSchedule/enable"


rm "${TMP_FILE}"
