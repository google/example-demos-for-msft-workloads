import pytest
from unittest.mock import MagicMock, patch
from cloudevents.http import CloudEvent
from main import (
    get_environment_variables,
    extract_info_from_file_name,
    extract_info_from_file_metadata,
    get_import_context,
    delete_processed_blob,
    handle_error,
    copy_blob_to_processed_bucket,
    fn_restore_log,
)


@pytest.fixture
def mock_storage_client():
    return MagicMock()


@pytest.fixture
def mock_source_bucket():
    return MagicMock()


@pytest.fixture
def mock_logger():
    return MagicMock()


def test_get_environment_variables(mock_logger):
    with patch('main.os.environ', {'USE_FIXED_FILE_NAME_FORMAT': 'True',
                                   'PROCESSED_BUCKET_NAME': 'bucket',
                                   'MAX_OPERATION_FETCH_TIME_SECONDS': '60'}):
        result = get_environment_variables(mock_logger)
        assert result == ('bucket', 'True', 60)


def test_extract_info_from_file_name():
    result = extract_info_from_file_name(
            'csql-instance-name_database-name_full_backup.bak')
    assert result == ('csql-instance-name',
                      'database-name',
                      'FULL',
                      'true')

    with pytest.raises(RuntimeError):
        extract_info_from_file_name('invalid-filename.bak')


def test_extract_info_from_file_metadata(mock_storage_client,
                                         mock_source_bucket):
    # Test case when metadata is correctly defined
    mock_blob = MagicMock()
    mock_blob.metadata = {'CloudSqlInstance': 'instance',
                          'DatabaseName': 'db',
                          'BackupType': 'FULL',
                          'Recovery': 'false'}
    mock_source_bucket.get_blob.return_value = mock_blob
    mock_storage_client.bucket.return_value = mock_source_bucket

    result = extract_info_from_file_metadata(mock_storage_client, 'bucket',
                                             'object_name')
    assert result == ('instance', 'db', 'FULL', 'true')

    # Test case when metadata is missing
    mock_blob.metadata = {}
    with pytest.raises(RuntimeError):
        extract_info_from_file_metadata(mock_storage_client, 'bucket',
                                        'object_name')


def test_get_import_context():
    result = get_import_context('source_bucket', 'object_name',
                                'db', 'FULL', 'true')
    expected_result = {
        "importContext": {
            "fileType": "BAK",
            "uri": "gs://source_bucket/object_name",
            "database": "db",
            "bakImportOptions": {"bakType": "FULL", "noRecovery": "true"},
        }
    }
    assert result == expected_result


def test_delete_processed_blob(mock_source_bucket, mock_logger):
    delete_processed_blob(mock_source_bucket, 'object_name', mock_logger)
    mock_source_bucket.delete_blob.assert_called_with('object_name')
    mock_logger.info.assert_called_with(
        "Deleted object object_name from the source bucket.")


def test_handle_error(mock_source_bucket, mock_logger):
    error_response = {"errors": "Msg 4326"}
    handle_error(error_response, mock_source_bucket, 'object_name',
                 mock_logger)
    mock_source_bucket.delete_blob.assert_called_with('object_name')

    error_response = {"errors": "Msg 4305"}
    with pytest.raises(RuntimeError):
        handle_error(error_response, mock_source_bucket, 'object_name',
                     mock_logger)

    error_response = {"errors": "Other error"}
    with pytest.raises(RuntimeError):
        handle_error(error_response, mock_source_bucket, 'object_name',
                     mock_logger)


def test_copy_blob_to_processed_bucket(mock_storage_client,
                                       mock_source_bucket,
                                       mock_logger):
    mock_processed_bucket = MagicMock()
    mock_storage_client.bucket.side_effect = [mock_source_bucket,
                                              mock_processed_bucket]
    copy_blob_to_processed_bucket('processed_bucket', mock_storage_client,
                                  mock_source_bucket, 'object_name',
                                  mock_logger)
    mock_source_bucket.blob.assert_called_with('object_name')
    mock_source_bucket.copy_blob.assert_called()

    # Test case when copy operation fails
    mock_source_bucket.copy_blob.side_effect = Exception('Copy failed')
    with pytest.raises(RuntimeError):
        copy_blob_to_processed_bucket('processed_bucket', mock_storage_client,
                                      mock_source_bucket, 'object_name',
                                      mock_logger)


@patch('main.logging')
@patch('main.get_environment_variables')
@patch('main.extract_info_from_file_metadata')
@patch('main.get_import_context')
@patch('main.delete_processed_blob')
@patch('main.copy_blob_to_processed_bucket')
@patch('main.sleep')
@patch('main.googleapiclient.discovery.build')
@patch('main.google.auth.default')
def test_fn_restore_log(
        mock_auth_default, mock_build, mock_sleep,
        mock_copy_blob, mock_delete_blob, mock_get_import_context,
        mock_extract_info, mock_env_variables, mock_logging,
        mock_storage_client, mock_source_bucket, mock_logger
):
    mock_auth = MagicMock()
    mock_auth_default.return_value = (mock_auth, 'project_id')
    mock_service = MagicMock()
    mock_build.return_value = mock_service
    mock_sleep.side_effect = [None, RuntimeError]
    mock_get_import_context.return_value = {'importContext': 'context'}
    mock_env_variables.return_value = ('processed_bucket', 'True', 60)
    mock_extract_info.return_value = ('instance-name', 'database-name',
                                      'FULL', "true")
    cloud_event_object = CloudEvent(
        attributes={"type": "com.example.sampletype1",
                    "source": "https://example.com/event-producer"},
        data={'bucket': 'source_bucket',
              'name': 'instance-name_database-name_somemoreinfo.bak'})
    cloud_event_folder = CloudEvent(
        attributes={"type": "com.example.sampletype1",
                    "source": "https://example.com/event-producer"},
        data={'bucket': 'source_bucket',
              'name': 'foldername/'})

    # Test case for successful import
    mock_operation_response_done = {'name': 'operation_name', 'status': 'DONE'}
    mock_operation_response_done_error = {'name': 'operation_name',
                                          'status': 'ERROR',
                                          'error': 'some_error'}
    mock_service = mock_build.return_value
    mock_service.operations \
                .return_value \
                .get \
                .return_value \
                .execute \
                .return_value = mock_operation_response_done
    result = fn_restore_log(cloud_event_object)
    assert result == ('Operation succeded.', 200)

    # Test case for failed import
    mock_service.operations \
                .return_value \
                .get \
                .return_value \
                .execute \
                .return_value = mock_operation_response_done_error

    with pytest.raises(RuntimeError):
        fn_restore_log(cloud_event_object)

    # Test case for folder creation
    result = fn_restore_log(cloud_event_folder)
    assert result == 'Operation skipped.'
