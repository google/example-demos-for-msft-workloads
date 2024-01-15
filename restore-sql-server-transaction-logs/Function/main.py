import functions_framework
import google.auth
import google.auth.transport.requests
import googleapiclient.discovery
import logging
import os
from time import sleep
from google.cloud import storage
from google.cloud import error_reporting


# Triggered by a change in a storage bucket
@functions_framework.cloud_event
def fn_restore_log(cloud_event):
    data = cloud_event.data
    
    source_bucket_name = data["bucket"]
    object_name = data["name"]
    
    request_attempts = 0

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger()
    
    client = error_reporting.Client()

    instance_id=os.environ.get('INSTANCE_ID')
    processed_bucket_name = os.environ.get('PROCESSED_BUCKET_NAME')
        
    separator=os.environ.get('FILE_NAME_SEPARATOR')
    database_name_group_position=os.environ.get('DB_NAME_GROUP_POSITION')

    max_request_attempts = 5 if os.environ.get('MAX_REQUEST_ATTEMPTS') is None else int(os.environ.get('MAX_REQUEST_ATTEMPTS'))
    max_request_fetch_time_seconds = 30 if os.environ.get('MAX_REQUEST_FETCH_TIME_SECONDS') is None else int(os.environ.get('MAX_REQUEST_FETCH_TIME_SECONDS'))
    max_operation_fetch_time_seconds = 30 if os.environ.get('MAX_OPERATION_FETCH_TIME_SECONDS') is None else int(os.environ.get('MAX_OPERATION_FETCH_TIME_SECONDS'))


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

    if object_name.endswith('/'):
        logger.info("Folder creation encountererd. Operation skipped.")
        return "Operation skipped."

    log_file_processed = False

    creds, project_id = google.auth.default()
    auth_req = google.auth.transport.requests.Request()
    creds.refresh(auth_req)

    service = googleapiclient.discovery.build('sqladmin', 'v1beta4', credentials=creds)
    
    storage_client = storage.Client()
    source_bucket = storage_client.bucket(source_bucket_name)
    source_object = source_bucket.blob(object_name)
    
    uri="gs://"+source_bucket_name+"/"+object_name
    database_name = (object_name.split("/")[-1]).split(separator)[int(database_name_group_position)-1]
    
    if object_name.lower().startswith("full/"):
        backup_type = "FULL"
    elif object_name.lower().startswith("diff/"):
        backup_type = "DIFF"
    else:
        backup_type = "TLOG"
        

    if object_name.lower().find("recovery/") != -1:    
        noRecovery = "false"
    else:
        noRecovery = "true"

    while log_file_processed == False:

        request_attempts += 1

        try:
            
            instances_import_request_body = {
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
            
            logger.info(f"Attempt to process object {object_name}. Try {request_attempts} out of {max_request_attempts}...")

            request = service.instances().import_(project=project_id, instance=instance_id, body=instances_import_request_body)
            response = request.execute()
            
            logger.info(f"Executed request: {instances_import_request_body}")
                        
            operation_status_done = False
            operation_status_fetch_attempts=0

            while not operation_status_done:

                operation_status_fetch_attempts += 1
                operation_sleep_time_seconds = min(max_operation_fetch_time_seconds, 5*operation_status_fetch_attempts)
                logger.info(f"Waiting for {operation_sleep_time_seconds} seconds to check for the requested operation status...")
                sleep(operation_sleep_time_seconds)
                
                resp = service.operations().get(project=project_id, operation=response["name"]).execute()
                logger.info(f"Operation status: {resp['status']}")

                if resp["status"] == "DONE":
                    
                    operation_status_done = True                    

                    if resp.get("error") is not None:

                        logger.info(f"Got an error in the operation response: {resp['error']}")
                        
                        #if the import fails with error Msg 4326 - too early to apply to the database
                        #delete the object assuming it was already earlier
                        if "Msg 4326" in str(resp.get("error").get("errors")):
                            try:
                                source_bucket.delete_blob(object_name)
                                logger.info(f"Deleted object {object_name} from bucket {source_bucket_name}")
                            except Exception as err:
                                logger.info(f"Could not delete the object {object_name} from the source bucket. Error: {err.args}")
                            
                            logger.info(f"Finished processing object {object_name}")
                            return "Operation succeded.", 200

                        #if the import fails with error Msg 4305 - too recent to apply to the database
                        #leave the object on the bucket showing that it was not processed.
                        elif "Msg 4326" in str(resp.get("error").get("errors")):
                            raise RuntimeError(f"Operation failed. Got a too recent SQL error and did not process the object {object_name}")

                        #if the import fails for any other reason, display the inner error stack.
                        else:
                            raise RuntimeError(f"Operation failed. Could not process the object {object_name}. Error: {resp["error"]}.")

                    else:

                        #operation success
                        logger.info(f"IMPORT DONE. Response details: {resp}")
                        log_file_processed=True

                        #Move the object if the processed bucket is defined
                        if processed_bucket_name:
                            try:
                                processed_bucket = storage_client.bucket(processed_bucket_name)
                                destination_generation_match_precondition = 0
                                                        
                                blob_copy = source_bucket.copy_blob(
                                        source_object,
                                        processed_bucket,
                                        object_name,
                                        if_generation_match=destination_generation_match_precondition
                                    )

                                if blob_copy is None:
                                    logger.info("Could not copy to processed bucket.")

                            except Exception as err:
                                logger.info(f"Could not copy the object {object_name} to the processed bucket. Error: {err.args}")

                        try:
                            source_bucket.delete_blob(object_name)
                        except Exception as err:
                            logger.info(f"Could not delete the object {object_name} from the source bucket. Error: {err.args}")
                        
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
