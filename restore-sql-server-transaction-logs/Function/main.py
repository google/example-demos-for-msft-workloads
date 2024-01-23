import functions_framework
import google.auth
import google.auth.transport.requests
import googleapiclient.discovery
import logging
import os
from time import sleep
from google.cloud import storage
from google.cloud import error_reporting


def get_environment_variables() -> [bool, str, str, str, int, int, int]:
    
    err_msg=""

    if not os.environ.get('USE_FIXED_FILE_NAME_FORMAT'):
        err_msg = "Environment variable USE_FIXED_FILE_NAME_FORMAT is None or empty."
        return False, err_msg, "", "", 0, 0, 0

    if os.environ.get('USE_FIXED_FILE_NAME_FORMAT').lower() not in ["true", "false"]:
        err_msg = "Environment variable USE_FIXED_FILE_NAME_FORMAT must be either True or False."
        return False, err_msg, "", "", 0, 0, 0
        

    use_fixed_file_name_format = os.environ.get('USE_FIXED_FILE_NAME_FORMAT')
    processed_bucket_name = "" if os.environ.get('MAX_REQUEST_ATTEMPTS') is None else os.environ.get('PROCESSED_BUCKET_NAME')
    max_request_attempts = 5 if os.environ.get('MAX_REQUEST_ATTEMPTS') is None else int(os.environ.get('MAX_REQUEST_ATTEMPTS'))
    max_request_fetch_time_seconds = 30 if os.environ.get('MAX_REQUEST_FETCH_TIME_SECONDS') is None else int(os.environ.get('MAX_REQUEST_FETCH_TIME_SECONDS'))
    max_operation_fetch_time_seconds = 30 if os.environ.get('MAX_OPERATION_FETCH_TIME_SECONDS') is None else int(os.environ.get('MAX_OPERATION_FETCH_TIME_SECONDS'))

    return True, err_msg, processed_bucket_name, use_fixed_file_name_format, max_request_attempts, max_request_fetch_time_seconds, max_operation_fetch_time_seconds


def extract_info_from_file_name(object_name: str) -> [bool, str, str, str, str, str]:

    err_message=""
    file_name=(object_name.split("/")[-1])
    name_groups = file_name.split("_")

    if len(name_groups)<2:
        err_message = "The file name does not respect the imposed format <cloudsql_instance_name>_<database_name>*.*"
        return False, err_message,  "", "", "", ""

    csql_instance_name = name_groups[0]
    database_name = name_groups[1]  

    if ("_full") in file_name.lower():
        backup_type = "FULL" 
    elif ("_diff") in file_name.lower():
        backup_type = "DIFF"
    else:
        backup_type = "TLOG"    

    if ("_recovery") in file_name.lower():
        no_recovery = "false"
    else:
        no_recovery = "true"

    return True, err_message, csql_instance_name, database_name, backup_type, no_recovery


def extract_info_from_file_metadata(bucket_name: str, blob_name: str) -> [bool, str, str, str, str, str]:
    
    err_message=""
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob_metadata=(bucket.get_blob(blob_name)).metadata

    if ("CloudSqlInstance" not in (blob_metadata) or not blob_metadata["CloudSqlInstance"]):
        err_message = "The tag CloudSqlInstance must be defined and cannot be empty"
        return False, err_message, "", "", "", ""

    if ("DatabaseName" not in (blob_metadata) or not blob_metadata["DatabaseName"]):
        err_message = "The tag DatabaseName must be defined and cannot be empty"
        return False, err_message, "", "", "", ""
    
    if ("BackupType" not in (blob_metadata) or not blob_metadata["BackupType"] or
            blob_metadata["BackupType"].lower() not in ("full", "diff", "tlog")):
        err_message = "The tag BackupType must be defined and must take the values FULL, DIFF or TLOG"
        return False, err_message, "", "", "", ""
        
    if ("Recovery" not in (blob_metadata) or not blob_metadata["Recovery"] or
            blob_metadata["Recovery"].lower() not in ("true", "false")):
        err_message = "The tag Recovery must be defined and must take the values True or False"
        return False, err_message, "", "", "", ""
    
    csql_instance_name = blob_metadata["CloudSqlInstance"]
    database_name = blob_metadata["DatabaseName"]
    backup_type = blob_metadata["BackupType"].upper()
    no_recovery = not(blob_metadata["Recovery"].lower() == "true")

    return True, "", csql_instance_name, database_name, backup_type, no_recovery    


def get_import_context(source_bucket_name: str, object_name: str, database_name: str, backup_type: str, no_recovery:str) -> dict:
    
    uri="gs://"+source_bucket_name+"/"+object_name

    instances_import_context = {
        "importContext": {
            "fileType": "BAK",
            "uri": uri,
            "database": database_name,
            "bakImportOptions": {
                    "bakType": backup_type,
                    "noRecovery": no_recovery,
                }
        }
    }

    return instances_import_context


def delete_processed_blob(source_bucket: google.cloud.storage.bucket.Bucket,object_name: str, logger) -> None:

    try:
        source_bucket.delete_blob(object_name)
        logger.info(f"Deleted object {object_name} from the source bucket.")
    except Exception as err:
        logger.info(f"Could not delete the object {object_name} from the source bucket. Error: {err.args}")
    
    return


def handle_error(error_response: dict, source_bucket: google.cloud.storage.bucket.Bucket, object_name: str, logger) -> [str, bool]:
    logger.info(f"Got an error in the operation response: {error_response}")
    
    #if the import fails with error Msg 4326 - too early to apply to the database
    #delete the object assuming it was already processed earlier
    if "Msg 4326" in str(error_response.get("errors")):
        delete_processed_blob(source_bucket, object_name, logger)
        logger.info(f"Finished processing object {object_name}")
        return "Operation succeded.", True

    #if the import fails with error Msg 4305 - too recent to apply to the database
    #leave the object on the bucket showing that it was not processed.
    elif "Msg 4326" in str(error_response.get("errors")):
        return f"Operation failed. Got a too recent SQL error and did not process the object {object_name}", False

    #if the import fails for any other reason, display the inner error stack.
    else:
        return f"Operation failed. Could not process the object {object_name}. Error: {error_response}.", False


def copy_blob_to_processed_bucket(processed_bucket_name: str, storage_client, source_bucket: google.cloud.storage.bucket.Bucket, object_name: str, logger) -> None:
    
    if processed_bucket_name:
        try:
            processed_bucket = storage_client.bucket(processed_bucket_name)
            source_object = source_bucket.blob(object_name)

            blob_copy = source_bucket.copy_blob(
                    source_object,
                    processed_bucket,
                    object_name,
                    if_generation_match=None
                )

            if blob_copy is None:
                logger.info("Could not copy to processed bucket.")

        except Exception as err:
            logger.info(f"Could not copy the object {object_name} to the processed bucket. Error: {err.args}")

# Triggered by a change in a storage bucket
@functions_framework.cloud_event
def fn_restore_log(cloud_event):
    data = cloud_event.data
    
    source_bucket_name = data["bucket"]
    object_name = data["name"]
    
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger()
    
    if object_name.endswith('/'):
        logger.info("Folder creation encountererd. Operation skipped.")
        return "Operation skipped."

    valid_env_v, msg, processed_bucket_name, use_fixed_file_name_format, max_request_attempts, max_request_fetch_time_seconds, max_operation_fetch_time_seconds = get_environment_variables()

    if not(valid_env_v):        
        raise RuntimeError(f"Operation failed. Environment variables validation failed: {msg}.")        
    
    if (use_fixed_file_name_format.lower()=="true"):        
        logger.info("Using fixed file name format")
        valid_file_name, msg, csql_instance_name, database_name, backup_type, no_recovery = extract_info_from_file_name(object_name)

        if not(valid_file_name):
            raise RuntimeError(f"Operation failed. File Name validation failed: {msg}.")
    else:
        logger.info(f"Using metadata")
        valid_metadata, msg, csql_instance_name, database_name, backup_type, no_recovery = extract_info_from_file_metadata(source_bucket_name, object_name)        

        if not(valid_metadata):
            raise RuntimeError(f"Operation failed. Metadta validation failed: {msg}.")

    request_attempts = 0
    log_file_processed = False

    creds, project_id = google.auth.default()
    auth_req = google.auth.transport.requests.Request()
    creds.refresh(auth_req)

    service = googleapiclient.discovery.build('sqladmin', 'v1beta4', credentials=creds)

    storage_client = storage.Client()
    source_bucket = storage_client.bucket(source_bucket_name)    

    import_context_body = get_import_context(source_bucket_name,object_name,database_name,backup_type, no_recovery)

    while log_file_processed == False:

        request_attempts += 1

        try:
            
            logger.info(f"Attempt to process object {object_name}. Try {request_attempts} out of {max_request_attempts}...")

            request = service.instances().import_(project=project_id, instance=csql_instance_name, body=import_context_body)
            response = request.execute()
            
            logger.info(f"Executed request: {import_context_body}")
                        
            operation_status_done = False
            operation_status_fetch_attempts=0

            while not operation_status_done:

                operation_status_fetch_attempts += 1
                operation_sleep_time_seconds = min(max_operation_fetch_time_seconds, 5*operation_status_fetch_attempts)
                
                logger.info(f"Waiting for {operation_sleep_time_seconds} seconds to check for the operation status...")
                
                sleep(operation_sleep_time_seconds)
                
                resp = service.operations().get(project=project_id, operation=response["name"]).execute()

                logger.info(f"Fetched operation status: {resp['status']}")

                if resp["status"] == "DONE":
                    
                    operation_status_done = True                    

                    if resp.get("error") is not None:
                        
                        outcome_message, finished_state = handle_error(resp.get("error"), source_bucket, object_name, logger)

                        if finished_state:
                            return outcome_message, 200
                        else:
                            raise RuntimeError(outcome_message)

                    else:

                        #operation success
                        logger.info(f"IMPORT DONE. Response details: {resp}")
                        log_file_processed=True
                        
                        copy_blob_to_processed_bucket(processed_bucket_name, storage_client, source_bucket, object_name, logger)
                        delete_processed_blob(source_bucket, object_name, logger)
                        
                        return "Operation succeded.", 200

        except Exception as err:
            logger.info(f"Request error: {err.args}")
            request_sleep_time_seconds = min(max_request_fetch_time_seconds, 5*request_attempts)
            logger.info(f"Another operation might be in progress. Retrying after {request_sleep_time_seconds} seconds...")
            sleep(request_sleep_time_seconds)

        finally:
            if request_attempts >= max_request_attempts:
                logger.info(f"Number of retries ({request_attempts}) reached. Exiting function.")
                return "Operation abandoned.", 500
