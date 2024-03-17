# Automating Cloud Data Fusion Pipelines with Bash Scripting

This repository provides a bash script to automate the setup of a Cloud Data Fusion (CDF) pipeline to transfer data from a CloudSQL MySQL instance to a BigQuery table.

### Overview

The script, named `script.sh`, streamlines the following steps:

1. Creation of a CDF instance.
2. Deployment of a JDBC driver for CloudSQL MySQL.
3. Establishment of a connection with the source MySQL database.
4. Deployment of the data pipeline.
5. Activation of pipeline scheduling.

### Included files

| File                     | Description                                      |
|--------------------------|--------------------------------------------------|
| cloudsql_mysql_conn.json | Configures a connection with the source database |
| cloudsql_mysql_jdbc.json | Metadata required for the JDBC plugin            |
| employees.csv            | sample data                                      |
| mysql_schema.json        | Data schema definition                           |
| pipeline.json            | Template for setting up the Fusion data pipeline |
| query.sql                | SQL query to execute against the source table    |
| script.sh                | The bash script                                  |

Obj.: In the `query.sql` file's WHERE clause, the string `$CONDITIONS` encapsulates constraints directly managed by CDP.

### Data schema
The data to be transferred by the pipeline has the following schema:

| Column              | Type      |
|---------------------|-----------|
| id                  | integer   |
| hire_date           | timestamp |
| name                | string    |
| department          | string    |
| years_of_experience | integer   |


### Preparation steps

Before running the script, ensure the following preparatory actions are taken within your GCP project:

1. Create a test Cloud SQL instance and database.
2. Create and populate a source table with sample data from the `employees.csv` file.
3. Create a sink BigQuery dataset and table to host the transferred data. 

The BigQuery sink table must align the provided data schema. To prevent job execution failures, both the table name and the dataset name housing it should comprise only letters, numbers, or underscores. Additionally, the table name may include the dollar sign ($).

### Script input arguments

The script requires 11 positional arguments as input:

1. PROJECT_ID: Your project identifier.
2. LOCATION: The target location.
3. MYSQL_DATABASE: The name of your database.
4. MYSQL_DB_USER: Typically `root`
5. MYSQL_DB_PASSWORD: The user password.
6. MYSQL_TABLE: The source table.
7. BIGQUERY_DATASET: The sink dataset.
8. BIGQUERY_TABLE: The sink table.
9. INSTANCE_NAME: Name of the CDF instance to be created by the script.
10. INSTANCE_EDITION: The desired edition of CDF instance.
11. PIPELINE_NAME: The name of the CDF pipeline to be created by the script.
