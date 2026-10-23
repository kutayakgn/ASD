IF OBJECT_ID(N'dbo.TR_AdminAudit_dbo___EFMigrationsHistory', N'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_AdminAudit_dbo___EFMigrationsHistory;

/* Older audit installers can see a retained key table after schema rollback.
   Remove their full-row triggers before any key store can be used again. */
DECLARE @RemoveKeyAuditSql nvarchar(max) =
(
    SELECT STRING_AGG(CONVERT(nvarchar(max), N'DROP TRIGGER '
        + QUOTENAME(schemaInfo.name) + N'.' + QUOTENAME(triggerInfo.name) + N';'), NCHAR(10))
    FROM sys.triggers AS triggerInfo
    INNER JOIN sys.tables AS tableInfo ON tableInfo.object_id = triggerInfo.parent_id
    INNER JOIN sys.schemas AS schemaInfo ON schemaInfo.schema_id = tableInfo.schema_id
    WHERE schemaInfo.name = N'dbo'
      AND (tableInfo.name = N'SharedAdminDataProtectionKeys'
           OR tableInfo.name LIKE N'\_\_Archived\_SharedAdminDataProtectionKeys\_%' ESCAPE N'\')
      AND triggerInfo.name LIKE N'TR\_AdminAudit\_%' ESCAPE N'\'
);
IF @RemoveKeyAuditSql IS NOT NULL EXEC sys.sp_executesql @RemoveKeyAuditSql;
