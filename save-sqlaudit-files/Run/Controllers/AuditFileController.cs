using Microsoft.AspNetCore.Mvc;
using Microsoft.SqlServer.XEvent.XELite;
using Google.Cloud.Logging.V2;
using Google.Cloud.Storage.V1;
using Newtonsoft.Json.Linq;
using System.Text.Json;
using Parquet;
using Parquet.Data;
using Parquet.Serialization;

namespace AspNetCoreWebApi6.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class AuditFileController : ControllerBase
    {
        private readonly string projectId;
        private readonly string logId;
        private readonly ILogger<AuditFileController> _logger;
        public readonly IConfiguration _configuration;
        private List<LogEntry> logEntries = new List<LogEntry>();
        private LoggingServiceV2Client loggingServiceV2Client = LoggingServiceV2Client.Create();
        private List<SqlAuditEvent> SQLAuditEventData = new List<SqlAuditEvent>();
        IDictionary<string, string> fieldMapping = new Dictionary<string, string>();
        public AuditFileController(IConfiguration configuration, ILogger<AuditFileController> logger)
        {
            _configuration = configuration;
            _logger = logger;

            projectId = _configuration["PROJECT_ID"] ?? "";

            logId = _configuration["LOG_ID"] ?? "";

            fieldMapping = new Dictionary<string, string>() {
                        {"class_type", "auditClass"},
                        {"object_name", "object"},
                        {"database_name", "database"},
                        {"session_id", "databaseSessionId"},
                        {"statement", "statement"},
                        {"sequence_number", "substatementId"},
                        {"server_principal_name", "user"},
                        {"transaction_id", "transactionId"},
                        {"object_id", "objectId"},
                        {"database_principal_name", "databasePrincipalName"},
                        {"server_instance_name", "serverInstanceName"},
                        {"application_name", "applicationName"},
                        {"duration_milliseconds", "durationMilliseconds"},
                        {"schema_name", "schemaName"},
                        {"succeeded", "succeeded"},
                        {"action_id", "actionId"},
                        {"connection_id", "connectionId"}
                    };
        }
        
        [HttpPost()]
        //public IEnumerable<AuditFile> Get(string fileName)
        public async Task<IActionResult> Post([FromBody] JsonElement body)
        {            
            string settingsFileName = (Environment.GetEnvironmentVariable("SETTINGS_FILENAME") ?? "mySettings.json");
            string topicId = Environment.GetEnvironmentVariable("TOPIC_ID") ?? "";
            bool publishToPubSub = bool.Parse(Environment.GetEnvironmentVariable("DO_PUBSUB_PUBLISH") ?? "false");
            bool saveParquetToGCS = bool.Parse(Environment.GetEnvironmentVariable("DO_PARQUET_GCS_SAVE") ?? "false");
            string saveParquetBucketName = Environment.GetEnvironmentVariable("PARQUET_GCS_BUCKETNAME") ?? "";
            bool saveToLog = bool.Parse(Environment.GetEnvironmentVariable("DO_LOG_SAVE") ?? "false");
            int batchSize = Int32.Parse(Environment.GetEnvironmentVariable("BATCH_SIZE") ?? "1000");
            string nowString = ((DateTimeOffset)DateTime.UtcNow).ToString("yyyyMMddHHmmssfff");            
            string uuidString = (Guid.NewGuid()).ToString();

            var bucketName = body.GetProperty("bucket").GetString();
            var uploadedFileName = body.GetProperty("name").GetString();

            //In case of using GCS Notifications
            //var bucketName = body.GetProperty("message").GetProperty("attributes").GetProperty("bucketId").GetString();
            //var uploadedFileName = body.GetProperty("message").GetProperty("attributes").GetProperty("objectId").GetString();

            if (!(publishToPubSub) && !(saveParquetToGCS) && !(saveToLog)){
                var errMessage = "400 Bad Request. DO_PUBSUB_PUBLISH, DO_PARQUET_GCS_SAVE and DO_LOG_SAVE cannot be false at the same time.";
                var result = new BadRequestObjectResult(new { message = errMessage, currentDate = DateTime.Now });
                _logger.LogInformation(errMessage);
                return result;
            }

            if (saveToLog && string.IsNullOrWhiteSpace(logId)){
                var errMessage = "400 Bad Request. LOG_ID must not be null.";
                var result = new BadRequestObjectResult(new { message = errMessage, currentDate = DateTime.Now });
                _logger.LogInformation(errMessage);
                return result;
            }

            if (saveParquetToGCS && string.IsNullOrWhiteSpace(saveParquetBucketName)){
                var errMessage = "400 Bad Request. PARQUET_GCS_BUCKETNAME must not be null.";
                var result = new BadRequestObjectResult(new { message = errMessage, currentDate = DateTime.Now });
                _logger.LogInformation(errMessage);
                return result;
            }

            if (string.IsNullOrWhiteSpace(uploadedFileName)) {
                var errMessage = "400 Bad Request. The name element in the post request cannot be empty.";
                var result = new BadRequestObjectResult(new { message = errMessage, currentDate = DateTime.Now });
                _logger.LogInformation(errMessage);
                return result;
            }

            if (string.IsNullOrWhiteSpace(bucketName)){
                var errMessage = "400 Bad Request. The bucket element in the post request cannot be empty.";
                var result = new BadRequestObjectResult(new { message = "400 Bad Request. The bucket element in the post request cannot be empty.", currentDate = DateTime.Now });
                _logger.LogInformation(errMessage);
                return result;
            }

            var storage = StorageClient.Create();
            var localSettingsFile = uuidString + "_" + settingsFileName;

            using (var configFileLocalPath = System.IO.File.OpenWrite(localSettingsFile))
                {
                    storage.DownloadObject(bucketName, "config/"+settingsFileName, configFileLocalPath);
                    configFileLocalPath.Close();
                }

            IConfigurationBuilder builder = new ConfigurationBuilder().AddJsonFile(localSettingsFile, true);
            IConfigurationRoot cfg = builder.Build();

            var localAuditFile = uuidString + "_" + uploadedFileName.Replace('/', '_');
            
            using (var auditLocalFilePath = System.IO.File.OpenWrite(localAuditFile))
            {
                storage.DownloadObject(bucketName, uploadedFileName, auditLocalFilePath);
                auditLocalFilePath.Close();
            }
                        
            XEFileEventStreamer XEReadStream = new XEFileEventStreamer(localAuditFile);
            await XEReadStream.ReadEventStream(
                () => {
                    return Task.CompletedTask;                    
                },
                xEvent => {

                    if (publishToPubSub)
                        Utils.WriteMessageToPubSub(projectId, topicId, _logger, xEvent);

                    if (saveToLog) {

                        Utils.ProcessXEventMessageToEntriesList(
                            projectId,
                            logId,
                            fieldMapping,
                            loggingServiceV2Client,
                            uploadedFileName,
                            xEvent,
                            _configuration,
                            logEntries);

                        if (logEntries.Count >= batchSize)
                            Utils.WriteMessageToLog(projectId, logId, loggingServiceV2Client, uploadedFileName, _logger, logEntries);
                    }

                    if (saveParquetToGCS) {
                       Utils.AddEventToList(SQLAuditEventData, _logger, xEvent);
                    }

                    return Task.CompletedTask;
                },
                CancellationToken.None).ContinueWith(ct => {
                    
                    if (saveToLog && logEntries.Count>0)
                        Utils.WriteMessageToLog(projectId, logId, loggingServiceV2Client, uploadedFileName, _logger, logEntries);
                });

            if (saveParquetToGCS) {

                string parquetObjectName = uploadedFileName.Replace(".sqlaudit",".parquet");
                string localParquetFile = uuidString + "_data.parquet";

                await ParquetSerializer.SerializeAsync(SQLAuditEventData, localParquetFile);
                using var fileStream =  System.IO.File.OpenRead(localParquetFile);
                storage.UploadObject(saveParquetBucketName, parquetObjectName, null, fileStream);
                
                _logger.LogInformation("Uploaded parquet file {fileName} with {count} entries to {bucket} ", parquetObjectName, SQLAuditEventData.Count, saveParquetBucketName);

                System.IO.File.Delete(localParquetFile);
                SQLAuditEventData.Clear();


            }
            System.IO.File.Delete(localAuditFile);
            System.IO.File.Delete(localSettingsFile);
            return Ok();
        }
    }
}