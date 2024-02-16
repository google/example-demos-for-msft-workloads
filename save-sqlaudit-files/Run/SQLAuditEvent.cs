using System;

namespace AspNetCoreWebApi6
{
    public class SqlAuditEvent
    {
        public string? ClassType { get; set; }
        public string? ObjectName { get; set; }
        public string? DatabaseName { get; set; }
        public int? SessionId { get; set; }
        public string? Statement { get; set; }
        public string? SequenceNumber { get; set; }
        public string? ServerPrincipalName { get; set; }
        public Int64? TransactionId { get; set; }
        public int? ObjectId { get; set; }
        public string? DatabasePrincipalName { get; set; }
        public string? ServerInstanceName { get; set; }
        public string? ApplicationName { get; set; }
        public Int64? DurationMilliseconds { get; set; }
        public DateTime EventTime { get; set; }
        public string? SchemaName { get; set; }
        public bool? Succeeded { get; set; }
        public string? ActionId { get; set; }
        public string? ConnectionId { get; set; }
    }
}
