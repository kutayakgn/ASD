SET NOCOUNT ON;
SET XACT_ABORT ON;

/* Supporting indexes for the restricted audit console filters. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.AdminLogs') AND name = N'IX_AdminLogs_FilterConsole')
BEGIN
    CREATE INDEX IX_AdminLogs_FilterConsole
        ON dbo.AdminLogs (OccurredAt DESC, OperationType, SchemaName, TableName, ActionName)
        INCLUDE (CorrelationId, Username, IsPublished);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.UsersLog') AND name = N'IX_UsersLog_FilterConsole')
BEGIN
    CREATE INDEX IX_UsersLog_FilterConsole
        ON dbo.UsersLog (OccurredAt DESC, Application)
        INCLUDE (UserId, ActorUserId, Username, CorrelationId, IsPublished);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.UsersLog') AND name = N'IX_UsersLog_CorrelationId')
BEGIN
    CREATE INDEX IX_UsersLog_CorrelationId
        ON dbo.UsersLog (CorrelationId, OccurredAt DESC);
END;
GO

/* Every business table must have the generated successful-DML audit trigger. */
SELECT
    schemaInfo.name AS SchemaName,
    tableInfo.name AS TableName,
    LEFT(N'TR_AdminAudit_' + schemaInfo.name + N'_' + tableInfo.name, 128) AS ExpectedTrigger
FROM sys.tables AS tableInfo
INNER JOIN sys.schemas AS schemaInfo ON schemaInfo.schema_id = tableInfo.schema_id
LEFT JOIN sys.triggers AS triggerInfo
    ON triggerInfo.parent_id = tableInfo.object_id
   AND triggerInfo.name = LEFT(N'TR_AdminAudit_' + schemaInfo.name + N'_' + tableInfo.name, 128)
WHERE tableInfo.is_ms_shipped = 0
  AND tableInfo.temporal_type = 0
  AND NOT (schemaInfo.name = N'dbo' AND tableInfo.name IN (N'AdminLogs', N'UsersLog'))
  AND triggerInfo.object_id IS NULL
ORDER BY schemaInfo.name, tableInfo.name;

/* Metadata completeness report. NULL is legitimate for direct SQL and non-applicable fields. */
SELECT
    Source,
    COUNT_BIG(*) AS TotalRows,
    SUM(CASE WHEN CorrelationId IS NULL THEN 1 ELSE 0 END) AS MissingCorrelationId,
    SUM(CASE WHEN OperationName IS NULL OR LTRIM(RTRIM(OperationName)) = N'' THEN 1 ELSE 0 END) AS MissingOperationName,
    SUM(CASE WHEN OperationType IS NULL OR LTRIM(RTRIM(OperationType)) = N'' THEN 1 ELSE 0 END) AS MissingOperationType,
    SUM(CASE WHEN OccurredAt IS NULL THEN 1 ELSE 0 END) AS MissingOccurredAt,
    SUM(CASE WHEN Application IS NULL OR LTRIM(RTRIM(Application)) = N'' THEN 1 ELSE 0 END) AS MissingApplication,
    SUM(CASE WHEN Source IS NULL OR LTRIM(RTRIM(Source)) = N'' THEN 1 ELSE 0 END) AS MissingSource
FROM dbo.AdminLogs
GROUP BY Source
ORDER BY Source;

SELECT
    COUNT_BIG(*) AS TotalRows,
    SUM(CASE WHEN CorrelationId IS NULL THEN 1 ELSE 0 END) AS MissingCorrelationId,
    SUM(CASE WHEN EventType IS NULL OR LTRIM(RTRIM(EventType)) = N'' THEN 1 ELSE 0 END) AS MissingEventType,
    SUM(CASE WHEN OccurredAt IS NULL THEN 1 ELSE 0 END) AS MissingOccurredAt,
    SUM(CASE WHEN Application IS NULL OR LTRIM(RTRIM(Application)) = N'' THEN 1 ELSE 0 END) AS MissingApplication
FROM dbo.UsersLog;
GO