import functions_framework
import google.auth
import google.auth.transport.requests
import googleapiclient.discovery
import logging
import os
from time import sleep
from google.cloud import storage
from google.cloud import error_reporting


def validate_environment_variables(instance_id, separator, database_name_group_position, processed_bucket_name, logger) -> bool:
    
    if not instance_id:
        raise RuntimeError("Operation failed. Environment variable INSTANCE_ID is None or empty.")

    if not separator:
        raise RuntimeError("Operation failed. Environment variable FILE_NAME_SEPARATOR is None or empty.")
    
    if not database_name_group_position:
        raise RuntimeError("Operation failed. Environment variable DB_NAME_GROUP_POSITION is None or empty.")

    if not database_name_group_position.isnumeric():
        raise RuntimeError("Operation failed. Environment variable DB_NAME_GROUP_POSITION is not an integer.")

    if int(database_name_group_position)<1:
        raise RuntimeError("Operation failed. Environment variable DB_NAME_GROUP_POSITION must be an integer greater than 0.")

    if not processed_bucket_name:
        logger.info("Environment variable PROCESSED_BUCKET_NAME is None or empty. Processed objects will not be copied to another bucket.")    

    return True

def get_import_context(source_bucket_name: str, object_name: str, separator: str, database_name_group_position: int) -> dict:
    
    uri="gs://"+source_bucket_name+"/"+object_name
    database_name = (object_name.split("/")[-1]).split(separator)[database_name_group_position-1]
    backup_type = "TLOG"
    noRecovery = "true"

    if object_name.lower().startswith("full/"):
        backup_type = "FULL"
    
    if object_name.lower().startswith("diff/"):
        backup_type = "DIFF"

    if object_name.lower().find("recovery/") != -1:    
        noRecovery = "false"

    instances_import_context = {
        "importContext": {
            "fileType": "BAK",
            "uri": uri,
            "database": database_name,
            "bakImportOptions": {
                    "bakType": backup_type,
                    "noRecovery": noRecovery,
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
        delete_processed_blob(source_bucket, object_name)
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
    
    request_attempts = 0

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger()
    
    if object_name.endswith('/'):
        logger.info("Folder creation encountererd. Operation skipped.")
        return "Operation skipped."
        
    #client = error_reporting.Client()

    instance_id=os.environ.get('INSTANCE_ID')
    processed_bucket_name = os.environ.get('PROCESSED_BUCKET_NAME')
    separator=os.environ.get('FILE_NAME_SEPARATOR')
    database_name_group_position=os.environ.get('DB_NAME_GROUP_POSITION')

    max_request_attempts = 5 if os.environ.get('MAX_REQUEST_ATTEMPTS') is None else int(os.environ.get('MAX_REQUEST_ATTEMPTS'))
    max_request_fetch_time_seconds = 30 if os.environ.get('MAX_REQUEST_FETCH_TIME_SECONDS') is None else int(os.environ.get('MAX_REQUEST_FETCH_TIME_SECONDS'))
    max_operation_fetch_time_seconds = 30 if os.environ.get('MAX_OPERATION_FETCH_TIME_SECONDS') is None else int(os.environ.get('MAX_OPERATION_FETCH_TIME_SECONDS'))
   
    if not validate_environment_variables(instance_id, separator, database_name_group_position, processed_bucket_name, logger):
        return "Operation abandoned.", 500

    log_file_processed = False

    creds, project_id = google.auth.default()
    auth_req = google.auth.transport.requests.Request()
    creds.refresh(auth_req)

    service = googleapiclient.discovery.build('sqladmin', 'v1beta4', credentials=creds)

    storage_client = storage.Client()
    source_bucket = storage_client.bucket(source_bucket_name)
    source_object = source_bucket.blob(object_name)
    
    import_context_body = get_import_context(source_bucket_name,object_name,separator,database_name_group_position)

    while log_file_processed == False:

        request_attempts += 1

        try:
            
            logger.info(f"Attempt to process object {object_name}. Try {request_attempts} out of {max_request_attempts}...")

            request = service.instances().import_(project=project_id, instance=instance_id, body=import_context_body)
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
                        delete_processed_blob(source_bucket, object_name)
                        
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
