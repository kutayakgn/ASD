SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.AdminLogs', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AdminLogs
    (
        Id uniqueidentifier NOT NULL
            CONSTRAINT PK_AdminLogs PRIMARY KEY,
        CorrelationId uniqueidentifier NOT NULL,
        UserId uniqueidentifier NULL,
        Username nvarchar(100) NULL,
        OperationName nvarchar(256) NOT NULL,
        OperationType nvarchar(30) NOT NULL,
        SchemaName nvarchar(128) NULL,
        TableName nvarchar(128) NULL,
        EntityKey nvarchar(max) NULL,
        OldValues nvarchar(max) NULL,
        NewValues nvarchar(max) NULL,
        AffectedRowCount int NOT NULL
            CONSTRAINT DF_AdminLogs_AffectedRowCount DEFAULT (0),
        OccurredAt datetime2(7) NOT NULL,
        IpAddress nvarchar(64) NULL,
        UserAgent nvarchar(1000) NULL,
        Application nvarchar(100) NOT NULL
            CONSTRAINT DF_AdminLogs_Application DEFAULT (N'AfifeAdmin'),
        HttpMethod nvarchar(16) NULL,
        RequestPath nvarchar(2048) NULL,
        ControllerName nvarchar(128) NULL,
        ActionName nvarchar(128) NULL,
        Source nvarchar(50) NOT NULL,
        IsSuccessful bit NOT NULL
            CONSTRAINT DF_AdminLogs_IsSuccessful DEFAULT (1),
        Details nvarchar(max) NULL,
        FailureReason nvarchar(2000) NULL,
        IsPublished bit NOT NULL
            CONSTRAINT DF_AdminLogs_IsPublished DEFAULT (1)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.AdminLogs')
      AND name = N'IX_AdminLogs_UserId_OccurredAt'
)
BEGIN
    CREATE INDEX IX_AdminLogs_UserId_OccurredAt
        ON dbo.AdminLogs (UserId, OccurredAt DESC)
        INCLUDE (OperationType, TableName, IsSuccessful, IsPublished);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.AdminLogs')
      AND name = N'IX_AdminLogs_TableName_OccurredAt'
)
BEGIN
    CREATE INDEX IX_AdminLogs_TableName_OccurredAt
        ON dbo.AdminLogs (TableName, OccurredAt DESC)
        INCLUDE (OperationType, UserId, IsPublished);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.AdminLogs')
      AND name = N'IX_AdminLogs_CorrelationId'
)
BEGIN
    CREATE INDEX IX_AdminLogs_CorrelationId
        ON dbo.AdminLogs (CorrelationId, OccurredAt);
END;
GO

/* Remove legacy page visits and successful MVC duplicates without deleting history. */
UPDATE dbo.AdminLogs
SET IsPublished = 0
WHERE IsPublished = 1
  AND Source = N'MvcAction'
  AND IsSuccessful = 1;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdminLogs_SoftDelete
ON dbo.AdminLogs
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.AdminLogs AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;
END;
GO

/*
    One audit row is written for every DML statement. OldValues and NewValues are
    JSON arrays so set-based EF updates and trigger/procedure side effects preserve
    every affected row and every database column without losing statement atomicity.
*/
DECLARE
    @SchemaName sysname,
    @TableName sysname,
    @ObjectId int,
    @TriggerName sysname,
    @QualifiedTable nvarchar(517),
    @PrimaryKeyColumns nvarchar(max),
    @DeletedKeyQuery nvarchar(max),
    @InsertedKeyQuery nvarchar(max),
    @SoftDeleteDetection nvarchar(max),
    @Sql nvarchar(max);

DECLARE table_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    schemaInfo.name,
    tableInfo.name,
    tableInfo.object_id
FROM sys.tables AS tableInfo
INNER JOIN sys.schemas AS schemaInfo ON schemaInfo.schema_id = tableInfo.schema_id
WHERE tableInfo.is_ms_shipped = 0
  AND tableInfo.temporal_type = 0
  AND NOT (schemaInfo.name = N'dbo' AND tableInfo.name IN (N'AdminLogs', N'UsersLog'))
ORDER BY schemaInfo.name, tableInfo.name;

OPEN table_cursor;
FETCH NEXT FROM table_cursor INTO @SchemaName, @TableName, @ObjectId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @TriggerName = LEFT(N'TR_AdminAudit_' + @SchemaName + N'_' + @TableName, 128);
    SET @QualifiedTable = QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName);

    SELECT @PrimaryKeyColumns = STRING_AGG(
        N'keyRow.' + QUOTENAME(columnInfo.name), N', ')
        WITHIN GROUP (ORDER BY indexColumn.key_ordinal)
    FROM sys.indexes AS indexInfo
    INNER JOIN sys.index_columns AS indexColumn
        ON indexColumn.object_id = indexInfo.object_id
       AND indexColumn.index_id = indexInfo.index_id
    INNER JOIN sys.columns AS columnInfo
        ON columnInfo.object_id = indexColumn.object_id
       AND columnInfo.column_id = indexColumn.column_id
    WHERE indexInfo.object_id = @ObjectId
      AND indexInfo.is_primary_key = 1;

    IF @PrimaryKeyColumns IS NULL
    BEGIN
        SET @DeletedKeyQuery = N'NULL';
        SET @InsertedKeyQuery = N'NULL';
    END
    ELSE
    BEGIN
        SET @DeletedKeyQuery =
            N'(SELECT ' + @PrimaryKeyColumns +
            N' FROM deleted AS keyRow FOR JSON PATH, INCLUDE_NULL_VALUES)';
        SET @InsertedKeyQuery =
            N'(SELECT ' + @PrimaryKeyColumns +
            N' FROM inserted AS keyRow FOR JSON PATH, INCLUDE_NULL_VALUES)';
    END;

    IF EXISTS
    (
        SELECT 1
        FROM sys.columns
        WHERE object_id = @ObjectId
          AND name = N'IsPublished'
    )
    BEGIN
        SET @SoftDeleteDetection = N'
        IF @OperationType = N''Update''
           AND EXISTS (SELECT 1 FROM deleted WHERE IsPublished = 1)
           AND NOT EXISTS (SELECT 1 FROM inserted WHERE IsPublished = 1)
            SET @OperationType = N''SoftDelete'';';
    END
    ELSE
    BEGIN
        SET @SoftDeleteDetection = N'';
    END;

    SET @Sql = N'
CREATE OR ALTER TRIGGER ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TriggerName) + N'
ON ' + @QualifiedTable + N'
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted)
       AND NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;

    DECLARE
        @HasInserted bit = CASE WHEN EXISTS (SELECT 1 FROM inserted) THEN 1 ELSE 0 END,
        @HasDeleted bit = CASE WHEN EXISTS (SELECT 1 FROM deleted) THEN 1 ELSE 0 END,
        @OperationType nvarchar(30),
        @EntityKey nvarchar(max),
        @OldValues nvarchar(max),
        @NewValues nvarchar(max),
        @AffectedRowCount int;

    SET @OperationType =
        CASE
            WHEN @HasInserted = 1 AND @HasDeleted = 1 THEN N''Update''
            WHEN @HasInserted = 1 THEN N''Insert''
            ELSE N''Delete''
        END;
' + @SoftDeleteDetection + N'

    SET @OldValues =
        CASE WHEN @HasDeleted = 1
            THEN (SELECT oldRow.* FROM deleted AS oldRow FOR JSON PATH, INCLUDE_NULL_VALUES)
            ELSE NULL
        END;
    SET @NewValues =
        CASE WHEN @HasInserted = 1
            THEN (SELECT newRow.* FROM inserted AS newRow FOR JSON PATH, INCLUDE_NULL_VALUES)
            ELSE NULL
        END;
    SET @EntityKey =
        CASE WHEN @HasDeleted = 1
            THEN ' + @DeletedKeyQuery + N'
            ELSE ' + @InsertedKeyQuery + N'
        END;
    SET @AffectedRowCount =
        CASE WHEN @HasInserted = 1
            THEN (SELECT COUNT_BIG(*) FROM inserted)
            ELSE (SELECT COUNT_BIG(*) FROM deleted)
        END;

    INSERT INTO dbo.AdminLogs
    (
        Id, CorrelationId, UserId, Username, OperationName, OperationType,
        SchemaName, TableName, EntityKey, OldValues, NewValues,
        AffectedRowCount, OccurredAt, IpAddress, UserAgent, Application,
        HttpMethod, RequestPath, ControllerName, ActionName, Source,
        IsSuccessful, Details, FailureReason, IsPublished
    )
    VALUES
    (
        NEWID(),
        COALESCE(
            TRY_CONVERT(uniqueidentifier, SESSION_CONTEXT(N''AdminCorrelationId'')),
            NEWID()),
        TRY_CONVERT(uniqueidentifier, SESSION_CONTEXT(N''AdminUserId'')),
        TRY_CONVERT(nvarchar(100), SESSION_CONTEXT(N''AdminUsername'')),
        COALESCE(
            TRY_CONVERT(nvarchar(256), SESSION_CONTEXT(N''AdminOperationName'')),
            N''' + REPLACE(@SchemaName + N'.' + @TableName + N'.', N'''', N'''''') + N''' + @OperationType),
        @OperationType,
        N''' + REPLACE(@SchemaName, N'''', N'''''') + N''',
        N''' + REPLACE(@TableName, N'''', N'''''') + N''',
        @EntityKey,
        @OldValues,
        @NewValues,
        @AffectedRowCount,
        DATEADD(HOUR, 3, SYSUTCDATETIME()),
        TRY_CONVERT(nvarchar(64), SESSION_CONTEXT(N''AdminIpAddress'')),
        TRY_CONVERT(nvarchar(1000), SESSION_CONTEXT(N''AdminUserAgent'')),
        COALESCE(
            TRY_CONVERT(nvarchar(100), SESSION_CONTEXT(N''AdminApplication'')),
            APP_NAME()),
        TRY_CONVERT(nvarchar(16), SESSION_CONTEXT(N''AdminHttpMethod'')),
        TRY_CONVERT(nvarchar(2048), SESSION_CONTEXT(N''AdminRequestPath'')),
        TRY_CONVERT(nvarchar(128), SESSION_CONTEXT(N''AdminController'')),
        TRY_CONVERT(nvarchar(128), SESSION_CONTEXT(N''AdminAction'')),
        CASE WHEN TRIGGER_NESTLEVEL() > 1 THEN N''DatabaseTrigger'' ELSE N''Database'' END,
        1,
        NULL,
        NULL,
        1
    );
END;';

    EXEC sys.sp_executesql @Sql;
    FETCH NEXT FROM table_cursor INTO @SchemaName, @TableName, @ObjectId;
END;

CLOSE table_cursor;
DEALLOCATE table_cursor;
GO

SELECT
    SchemaName,
    TableName,
    OperationType,
    COUNT(*) AS LogCount
FROM dbo.AdminLogs
WHERE IsPublished = 1
GROUP BY SchemaName, TableName, OperationType
ORDER BY SchemaName, TableName, OperationType;
