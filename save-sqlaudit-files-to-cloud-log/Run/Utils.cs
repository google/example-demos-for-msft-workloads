using Microsoft.SqlServer.XEvent.XELite;
using Google.Cloud.Logging.V2;
using Google.Cloud.Logging.Type;
using Google.Cloud.Audit;
using Google.Protobuf;
using Google.Protobuf.WellKnownTypes;
using Google.Cloud.PubSub.V1;
using System.Text.Json;
using Google.Api;

namespace AspNetCoreWebApi6
{
    public class Utils
    {
        private static bool CheckFieldStatus(string configField, string eventField, IXEvent xEvent, IConfiguration cfg)
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

        public static void WriteMessageToPubSub(string projectId, string topicId, ILogger _logger, IXEvent xEvent)
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


        public static void ProcessXEventMessageToEntriesList(
            string projectId,
            string logId,
            IDictionary<string, string> fieldMapping,
            LoggingServiceV2Client loggingServiceV2Client,
            string fileName,
            IXEvent xEvent,
            IConfiguration cfg,
            List<LogEntry> logEntries)
        {            
            var fileLabel = fileName.Substring(0,fileName.IndexOf("_Audit"));
            var logName = new LogName(projectId, logId);
                        
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

        public static void WriteMessageToLog(
            string projectId,
            string logId,
            LoggingServiceV2Client loggingServiceV2Client,
            string fileName,
            ILogger _logger,
            List<LogEntry> logEntries)
        {
            var fileLabel = fileName.Substring(0,fileName.IndexOf("_Audit"));

            var logName = new LogName(projectId, logId);
            
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



    }
}