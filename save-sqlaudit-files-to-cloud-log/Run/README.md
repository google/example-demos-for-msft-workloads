# Save SQL Server .Sqlaudit Files to Cloud Log

This repository contains the implementation of an ASP.NET Core MVC application that can parse SQL Server 2017/2019 .sqlaudit files and save the audit events inside those files to google cloud log for further investigation and/processing

## Parsing library

The parsing of the events is done using the XELite  cross platform library. It can read XEvents from XEL/sqlaudit files or live SQL streams: https://www.nuget.org/packages/Microsoft.SqlServer.XEvent.XELite/2021.12.12.2

## Main workflow

The process starts when SQL Server audit files are being uploaded to a cloud bucket for archiving or audit purposes. These files may come from a SQL Server stand alone instance or CloudSQL for SQL Server.
An EventArc trigger is fired by the upload event and it calls the asp.net application deployed to Cloud Run. The application parses the contents of the files and stores them in a structured way in cloud log. Optionally these can be also published to a PubSub topic for further distribution.

The structure of the fields that are being logged is harmonized with the pg_audit extension for Cloud SQL for PostgreSQL. The set is extended with some other SQL Server specific fields. The storing of these fields in the log can be controlled through the config/mySettings.json file that is located on the trigger source bucket. Every time the application receives a request, this json file is parsed and taken into account as an active configuration. The default structure of this file is described below.

When calling the write to cloud log api, there is the recommendation to batch the log entries that are written there. If the batches are too small, the write performance might be degraded because of the multitude of api calls. If the batches are too big, a call might take too long to finish. The default batch size is 1000 log entries per api call.

The application should have defined a set of environment variables. They are described below, in the constraints section.

## References

* [Eventarc triggers](https://cloud.google.com/functions/docs/calling/eventarc)

* [Deploy a .NET service to Cloud Run](https://cloud.google.com/run/docs/quickstarts/build-and-deploy/deploy-dotnet-service)

* [Writing structured logs to Cloud Log](https://cloud.google.com/logging/docs/samples/logging-write-log-entry)

* [AuditLog .net reference](https://cloud.google.com/dotnet/docs/reference/Google.Cloud.Audit/latest/Google.Cloud.Audit.AuditLog)

* [LogEntry .net reference](https://cloud.google.com/dotnet/docs/reference/Google.Cloud.Logging.V2/latest/Google.Cloud.Logging.V2.LogEntry)

* [MSSQL Server 2022 sqlaudit reference](https://learn.microsoft.com/en-us/sql/relational-databases/system-functions/sys-fn-get-audit-file-transact-sql?view=sql-server-ver16)

* [CloudSQL pg_audit](https://cloud.google.com/sql/docs/postgres/pg-audit)

* [PGAudit reference](https://access.crunchydata.com/documentation/pgaudit/1.2.0/)

* [Limitations of Log Entries writes](https://cloud.google.com/logging/quotas)

## Constraints

There are some working assumptions:

1. The sqlaudit files are not updated (there is no process that opens existing files on the cloud bucket and updates them by appending content);

1. The files are supposed to be named like CloudSQL for Sql Server names them natively:
    <project_name>_<instance_name>_Audit-<database-name>_UID.sqlaudit

1. There should be a config/mySettings.json file on the source trigger bucket. The config folder is mandatory. This file decides what fields are included in the payload to save to the cloud bucket or not. The default file should look as follows

```json
{
    "auditClass": true,
    "object": true,
    "database": true,
    "databaseSessionId": true,
    "statement": true,
    "substatementId": true,
    "user": true,                        
    "transactionId": true,
    "objectId": true,
    "databasePrincipalName": true,
    "serverInstanceName": true,
    "applicationName": true,
    "durationMilliseconds": true,
    "schemaName": true,
    "succeeded": true,
    "actionId": true,
    "connectionId": true,
    "hostName": true
}
```

The name "mySettings.json" can be changed, but the change should be done in the environment variables (see below)

1. There are some Cloud log limitations. Please check https://cloud.google.com/logging/quotas

1. The Cloud Run service needs to have defined the following environment variables:

| Name | Definition |
| ---- | ---- |
| `PROJECT_ID` | the name of project that contains the Cloud Logging and optionally the  PubSub instance. |
| `LOG_ID` | the name of your log; can be something like "sql-audit-log" |
| `SETTINGS_FILENAME` | the name of the settings file|
| `TOPIC_ID` | optional; the name of the PubSub topic where logs should be written. |
| `DO_PUBSUB_PUBLISH` | boolean flag telling if the application should write to PubSub or not |
| `BATCH_SIZE` | integer, the batch size of log entries that are written in one cloud log write api call. |

Example of default environment variables:

```sh
PROJECT_ID=my-cloud-sql-project
LOG_ID=sqlaudit-log
SETTINGS_FILENAME=mySettings.json
TOPIC_ID=my-cloud-pubsub-topic
DO_PUBSUB_PUBLISH=false
BATCH_SIZE=1000
```

The environment variables can be defined upfront in the env.yml file. The application can then be deployed to Cloud Run using the following command:
gcloud run deploy sql-server-audit-file-reader --env-vars-file=env.yml