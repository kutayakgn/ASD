/* Code is editable business data. Preserve every declared reference, including
   references installed by another application sharing this database. No row is
   rewritten during deployment; SQL Server cascades only the changed key later. */
DECLARE @GroupObjectId int = OBJECT_ID(N'dbo.[Group]', N'U');
DECLARE @GroupCodeColumnId int = COLUMNPROPERTY(@GroupObjectId, N'Code', 'ColumnId');
IF @GroupObjectId IS NULL OR @GroupCodeColumnId IS NULL
    THROW 52822, N'Grup kodu ilişkileri için dbo.Group.Code bulunamadı.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.foreign_keys AS relationship
    WHERE relationship.referenced_object_id = @GroupObjectId
      AND EXISTS (SELECT 1 FROM sys.foreign_key_columns AS columnPair
                  WHERE columnPair.constraint_object_id = relationship.object_id
                    AND columnPair.referenced_column_id = @GroupCodeColumnId)
      AND (relationship.is_disabled = 1 OR relationship.is_not_trusted = 1)
)
    THROW 52823, N'Grup koduna bağlı devre dışı veya doğrulanmamış ilişki var. İlişki düzeltilmeden güncelleme kurulamaz.', 1;

DECLARE @RelationshipId int, @SchemaName sysname, @TableName sysname,
        @ConstraintName sysname, @DeleteAction nvarchar(60), @UpdateAction int,
        @NotForReplication bit, @Columns nvarchar(max), @ReferencedColumns nvarchar(max),
        @Sql nvarchar(max), @OriginalUpdateAction int, @ColumnCount int;
DECLARE groupRelationships CURSOR LOCAL FAST_FORWARD FOR
    SELECT relationship.object_id, schemaRecord.name, tableRecord.name,
           relationship.name, REPLACE(relationship.delete_referential_action_desc, N'_', N' '),
           relationship.update_referential_action, relationship.is_not_for_replication
    FROM sys.foreign_keys AS relationship
    INNER JOIN sys.tables AS tableRecord ON tableRecord.object_id = relationship.parent_object_id
    INNER JOIN sys.schemas AS schemaRecord ON schemaRecord.schema_id = tableRecord.schema_id
    WHERE relationship.referenced_object_id = @GroupObjectId
      AND EXISTS (SELECT 1 FROM sys.foreign_key_columns AS columnPair
                  WHERE columnPair.constraint_object_id = relationship.object_id
                    AND columnPair.referenced_column_id = @GroupCodeColumnId);
OPEN groupRelationships;
FETCH NEXT FROM groupRelationships INTO @RelationshipId, @SchemaName, @TableName,
    @ConstraintName, @DeleteAction, @UpdateAction, @NotForReplication;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @Columns = STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(parentColumn.name)), N', ')
               WITHIN GROUP (ORDER BY columnPair.constraint_column_id),
           @ReferencedColumns = STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(referencedColumn.name)), N', ')
               WITHIN GROUP (ORDER BY columnPair.constraint_column_id),
           @ColumnCount = COUNT(*)
    FROM sys.foreign_key_columns AS columnPair
    INNER JOIN sys.columns AS parentColumn
        ON parentColumn.object_id = columnPair.parent_object_id AND parentColumn.column_id = columnPair.parent_column_id
    INNER JOIN sys.columns AS referencedColumn
        ON referencedColumn.object_id = columnPair.referenced_object_id AND referencedColumn.column_id = columnPair.referenced_column_id
    WHERE columnPair.constraint_object_id = @RelationshipId;

    /* Each dependent lookup/cascade needs an index whose leading columns match
       this FK; never scan an unrelated table for a single group's code change. */
    IF NOT EXISTS
    (
        SELECT 1 FROM sys.indexes AS lookupIndex
        WHERE lookupIndex.object_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName))
          AND lookupIndex.is_disabled = 0 AND lookupIndex.has_filter = 0
          AND (SELECT COUNT(*) FROM sys.index_columns AS indexColumn
               INNER JOIN sys.foreign_key_columns AS columnPair
                   ON columnPair.constraint_object_id = @RelationshipId
                  AND columnPair.parent_column_id = indexColumn.column_id
                  AND columnPair.constraint_column_id = indexColumn.key_ordinal
               WHERE indexColumn.object_id = lookupIndex.object_id AND indexColumn.index_id = lookupIndex.index_id
                 AND indexColumn.key_ordinal BETWEEN 1 AND @ColumnCount) = @ColumnCount
    )
    BEGIN
        SET @Sql = N'CREATE INDEX ' + QUOTENAME(N'IX_GroupCodeCascade_' + CONVERT(nvarchar(20), @RelationshipId))
            + N' ON ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' (' + @Columns + N');';
        EXEC sys.sp_executesql @Sql;
    END;

    IF @UpdateAction <> 1
    BEGIN
        IF EXISTS
        (
            SELECT 1 FROM sys.triggers AS triggerRecord
            INNER JOIN sys.trigger_events AS triggerEvent ON triggerEvent.object_id = triggerRecord.object_id
            WHERE triggerRecord.parent_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName))
              AND triggerRecord.is_instead_of_trigger = 1 AND triggerEvent.type_desc = N'UPDATE'
        )
            THROW 52824, N'Grup koduna bağlı tabloda INSTEAD OF UPDATE trigger var. İlişki otomatik taşınamadı; migration geri alındı.', 1;

        SET @OriginalUpdateAction = @UpdateAction;
        SET @Sql = N'ALTER TABLE ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)
            + N' DROP CONSTRAINT ' + QUOTENAME(@ConstraintName) + N'; ALTER TABLE '
            + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)
            + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@ConstraintName) + N' FOREIGN KEY (' + @Columns + N')'
            + N' REFERENCES dbo.[Group] (' + @ReferencedColumns + N') ON DELETE ' + @DeleteAction
            + N' ON UPDATE CASCADE' + CASE WHEN @NotForReplication = 1 THEN N' NOT FOR REPLICATION' ELSE N'' END + N';';
        /* Unsupported cascade paths fail the transaction instead of silently
           leaving one dependent table on a different group code. */
        EXEC sys.sp_executesql @Sql;
        EXEC sys.sp_addextendedproperty @name = N'Afife:GroupCodeOriginalUpdateAction', @value = @OriginalUpdateAction,
            @level0type = N'SCHEMA', @level0name = @SchemaName,
            @level1type = N'TABLE', @level1name = @TableName,
            @level2type = N'CONSTRAINT', @level2name = @ConstraintName;
    END;
    FETCH NEXT FROM groupRelationships INTO @RelationshipId, @SchemaName, @TableName,
        @ConstraintName, @DeleteAction, @UpdateAction, @NotForReplication;
END;
CLOSE groupRelationships;
DEALLOCATE groupRelationships;
