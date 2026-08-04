IF OBJECT_ID(N'dbo.TR_AdminAudit_dbo___EFMigrationsHistory', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_AdminAudit_dbo___EFMigrationsHistory;
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
  AND NOT (schemaInfo.name = N'dbo' AND tableInfo.name IN (N'AdminLogs', N'UsersLog', N'__EFMigrationsHistory'))
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