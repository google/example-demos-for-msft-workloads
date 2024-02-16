//
//   Copyright 2022 Google LLC
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       https://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
//

using CloudNative.CloudEvents;
using Google.Cloud.Functions.Framework;
using Microsoft.SqlServer.XEvent.XELite;
using Google.Events.Protobuf.Cloud.Storage.V1;
using Google.Protobuf;
using Google.Protobuf.WellKnownTypes;
using Google.Cloud.PubSub.V1;
using Google.Cloud.Storage.V1;
using Microsoft.Extensions.Logging;
using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Text.Json;
using System.Linq;
using Google.Api;
using Google.Cloud.Logging.V2;
using Google.Cloud.Logging.Type;
using Google.Cloud.Audit;
using System.Collections.Generic;
using Microsoft.Extensions.Configuration;
 
namespace SqlAuditToCloudLog
{
    public class Function : ICloudEventFunction<StorageObjectData>
    {
        private readonly string projectId = Environment.GetEnvironmentVariable("PROJECT_ID");
        private readonly string logId = Environment.GetEnvironmentVariable("LOG_ID");
        private readonly string settingsFileName = Environment.GetEnvironmentVariable("SETTINGS_FILENAME");
        private string topicId = Environment.GetEnvironmentVariable("TOPIC_ID");
        private bool publishToPubSub = bool.Parse(Environment.GetEnvironmentVariable("DO_PUBSUB_PUBLISH"));
        private int batchSize = Int32.Parse(Environment.GetEnvironmentVariable("BATCH_SIZE"));

        private List<LogEntry> logEntries = new List<LogEntry>();
        private LoggingServiceV2Client loggingServiceV2Client = LoggingServiceV2Client.Create();
        private readonly ILogger _logger;

        private IDictionary<string, string> fieldMapping = new Dictionary<string, string>() {
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



        public Function(ILogger<Function> logger) =>
            _logger = logger;       

        private void DownloadFile(string destination, string pathOnTheBucket, StorageObjectData data)
        {         
            var client = StorageClient.Create();
            using var outputFile = File.OpenWrite(destination);
             
            client.DownloadObject(data.Bucket, pathOnTheBucket, outputFile);            
            outputFile.Close();
        }      
 
        private void WriteMessageToPubSub(string projectId, string topicId, IXEvent xEvent)
        {         

            PublisherServiceApiClient publisher = PublisherServiceApiClient.Create();
            TopicName topicName = new TopicName(projectId, topicId);
             
            PubsubMessage message = new PubsubMessage
            {

                Data = ByteString.CopyFromUtf8(JsonSerializer.Serialize(xEvent)),
 
                Attributes =
                {
                    { "Description", "SQL Server Audit message" }
                }
            };
 
            publisher.Publish(topicName, new[] { message });
            _logger.LogInformation("Published to PubSub Event having UUID {uuid}", xEvent.UUID.ToString());
        }

        private void WriteMessageToLog(LoggingServiceV2Client loggingServiceV2Client, string fileName, List<LogEntry> logEntries)
        {

            var fileLabel = fileName;
            var logName = new LogName(projectId, logId);

            if (fileName.Contains("_Audit"))
                fileLabel = fileName.Substring(0,fileName.IndexOf("_Audit"));

            MonitoredResource resource = new MonitoredResource
            {
                Type = "global"
            };
             
            IDictionary<string, string> entryLabels = new Dictionary<string, string>();
            entryLabels.Add("FileLabel", string.IsNullOrEmpty(fileLabel) ? "" : fileLabel);

            loggingServiceV2Client.WriteLogEntries(logName, resource, entryLabels, logEntries);
            _logger.LogInformation("Saved to Log {count} entries from {fileName}", logEntries.Count, fileName);

            logEntries.Clear();
        }

        private bool CheckFieldStatus(string configField, string eventField, IXEvent xEvent, IConfigurationRoot cfg)
        {
            bool configFlag=false;
            
            if ((cfg[configField] != null) && (bool.TryParse(cfg[configField], out configFlag)))
                {
                    if (xEvent.Fields.ContainsKey(eventField))
                        return configFlag;

                    return false;
                }
            return xEvent.Fields.ContainsKey(eventField);
        }

        private void ProcessXEventMessageToEntriesList(LoggingServiceV2Client loggingServiceV2Client, string fileName, IXEvent xEvent, IConfigurationRoot cfg, List<LogEntry> logEntries)
        {            

            var fileLabel = fileName;
            var logName = new LogName(projectId, logId);

            if (fileName.Contains("_Audit"))
                fileLabel = fileName.Substring(0,fileName.IndexOf("_Audit"));
                        
            LogEntry logEntry = new LogEntry();            
            logEntry.LogNameAsLogName = logName;
            logEntry.Severity = LogSeverity.Info;            
            
            var auditLog = new AuditLog();            
            auditLog.MethodName = "sqlAudit.custom";
            
            auditLog.Request = new Struct {
                Fields =
                    {
                        ["eventTime"] = Value.ForString(xEvent.Fields["event_time"].ToString())
                    }
                };


            foreach(KeyValuePair<string, string> entry in fieldMapping)
            {            
                if (CheckFieldStatus(entry.Value, entry.Key, xEvent, cfg))
                    auditLog.Request.Fields.Add(entry.Value, Value.ForString(xEvent.Fields[entry.Key].ToString()));             
            }        

            var payLoad = Any.Pack(auditLog);
            logEntry.ProtoPayload = payLoad;

            logEntries.Add(logEntry);
        }
 
        public Task HandleAsync(CloudEvent cloudEvent, StorageObjectData data, CancellationToken cancellationToken)
        {
            var auditLocalFilePath = Path.Combine(Path.GetTempPath(), data.Name.Replace('/', '_'));
            var configFileLocalPath = Path.Combine(Path.GetTempPath(), settingsFileName);
            var configFileBucketPath = Path.Combine("config/", settingsFileName);
            
            DownloadFile(configFileLocalPath, configFileBucketPath, data);

            IConfigurationBuilder builder = new ConfigurationBuilder().AddJsonFile(Path.Combine(Path.GetTempPath(), settingsFileName), true);
            IConfigurationRoot cfg = builder.Build();
            
            DownloadFile(auditLocalFilePath, data.Name, data);
            
            XEFileEventStreamer XEReadStream = new XEFileEventStreamer(auditLocalFilePath);
            
            XEReadStream.ReadEventStream(
                () => {                    
                    return Task.CompletedTask;
                },
                xEvent => {

                    if (publishToPubSub)
                        WriteMessageToPubSub(projectId, topicId, xEvent);

                    ProcessXEventMessageToEntriesList(loggingServiceV2Client, data.Name, xEvent, cfg, logEntries);

                    if (logEntries.Count >= batchSize)
                        WriteMessageToLog(loggingServiceV2Client, data.Name, logEntries);

                    return Task.CompletedTask;
                },
                CancellationToken.None).ContinueWith(ct => {
                    if (logEntries.Count>0)
                        WriteMessageToLog(loggingServiceV2Client, data.Name, logEntries);
                });
            return Task.CompletedTask;
        }
    }
}
