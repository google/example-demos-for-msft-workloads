# Restore SQL Server Transaction log files to a Cloud SQL for SQL Server instance



This repository contains the implementation of an python function that restores transaction log backups that are uploaded to a cloud bucket to a database of an existing Cloud SQL for SQL Server instance.



## Restore functionality



You can import transaction log backups in Cloud SQL for SQL Server since October 2023. This functionality can be used when migrating to Cloud SQL using backups or setting up Cloud SQL for SQL Server DR instances. 

https://cloud.google.com/sql/docs/sqlserver/import-export/import-export-bak#import_transaction_log_backups



## Main workflow



The process starts when SQL Server transaction log backup files are being uploaded to a cloud bucket. These files may come from a SQL Server stand alone instance or CloudSQL for SQL Server.

An EventArc trigger is fired by the upload event and it calls the python function. The function gets the path to the log file that was uploaded and constructs the request to restore the uploaded backup file to the Cloud SQL for SQL Server instance.



Once the request is made, the progress of the restore operation is checked periodically. Once the status of the operation is DONE - which means that it has an outcome, the following actions are executed:



 1. If the outcome of the operation returned SUCCESS (determined by the absence of the 'error' element in the response json), then the transaction log file is copied to a 'processed' storage bucket if one is defined and then finally it is deleted from the original storage bucket, signaling that it was processed successfully.



 1. If the outcome of the operation returned ERROR, then the error response is inspected and depending on the details inside, one of the options are considered:



    * If the import failed with SQL Server error 4326 - too early to apply to the database - then it is assumed that the log file was processed already and it is deleted from the bucket. An OK (200) is returned by the function.



    * If the import failed with SQL Server error 4305 - too recent to apply to the database - it is assumed that there are some synchronization issues and the file will be scheduled for a later restore attempt. The number of attempts is given by the MAX_REQUEST_ATTEMPTS configuration parameter. In this case, the file is not deleted from the bucket where it was uploaded.



    * If the import fails for any other reason, the file will be scheduled for a later restore attempt and the number of attempts is given by the MAX_REQUEST_ATTEMPTS configuration parameter. The file is not deleted in case of errors.



The function can also be used to restore full and differential backup files. To achieve this functionality, these files have to be uploaded to the "full" respective "diff" top level folders in the bucket. By default, the function restores backups with the norecovery option, leaving the database in a state to expect further sequential restores. If the recovery option is needed for example switching to the DR instance - simply create a "recovery" folder and upload the last log backup to that folder. This will trigger the recovery option and leave the database in the accessible state.


This repository also contains a powershell script for regularly uploading new files to cloud storage. The command to create a scheduled task in Windows to run it on a regular basis. For example, the scheduled task below script starts execution at 2:45 PM and runs every 5 minutes.



    schtasks /create /sc minute /mo 5 /tn "GCS Upload script" /tr "powershell <script_full_path>" /st 14:45 /ru <local_account_username> /rp 



Replace <script_full_path> with the path to your powershell script and <username> with a local user account with privileges to read and edit the settings.json files on your machine. You will be prompted to provide the password for the local <local_account_username> when you create the task.



The function must have defined a set of environment variables defined in the env.yml file. Details about them are described below, in the constraints section.



## Constraints and working assumptions:



1. The transaction log backup files are uploaded on a continuous, regular and batched manner to the cloud storage bucket. Ideally ordered.

1. There special keyword folders in the bucket as follows:

    - all files under the top full folder will be treated as full backups
    - all files under the top diff folder will be treated as diff backups
    - any other files are treated as transaction log backups
    - all files under the recovery folder (wheter this folder is situated at the top level or nested under full or diff or any other folders) will be restored with the recovery option.

1. The files should follow a consistent naming scheme that includes certain elements. For example, an element describing the database name distinguishable by separators. The underscore character can be used as a separator"_". The function expects the separator and in the FILE_NAME_SEPARATOR respectively the DB_NAME_GROUP_POSITION environment variables. The DB_NAME_GROUP_POSITION works as a 1-based index, from left to right. 

For example, if the transaction log backup files name use the following pattern:

        <instance_name>_<database-name>_<timestamp>.TRN

The values for the FILE_NAME_SEPARATOR and DB_NAME_GROUP_POSITION look like this:


        FILE_NAME_SEPARATOR = "_"
        DB_NAME_GROUP_POSITION = "2"


1. As the function can also be used to restore full and differential backups, the transaction log backup files should be uploaded to any folder except the top folder "full" respectively "diff" (case insensitive) which is used for restoring full respectively differential backup files.

1. The environment variables can be defined upfront in the env.yml file. The function can then be deployed to Cloud Run using the following command:


    gcloud functions deploy YOUR_FUNCTION_NAME \
    [--gen2] \
    --region=YOUR_REGION \
    --runtime=YOUR_RUNTIME \
    --source=YOUR_SOURCE_LOCATION \
    --entry-point=YOUR_CODE_ENTRYPOINT \
    TRIGGER_FLAGS
    --env-vars-file=env.yml


## References


* [Eventarc triggers](https://cloud.google.com/functions/docs/calling/eventarc)

* [Deploy a Cloud Function](https://cloud.google.com/functions/docs/deploy)

* [Import data from a BAK file to Cloud SQL for SQL Server](https://cloud.google.com/sql/docs/sqlserver/import-export/import-export-bak#import_data_from_a_bak_file_to)

* [Recovery and the transaction log](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/restore-and-recovery-overview-sql-server?view=sql-server-ver16#TlogAndRecovery)

