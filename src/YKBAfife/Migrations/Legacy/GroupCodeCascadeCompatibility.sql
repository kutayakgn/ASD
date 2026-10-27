/* Code is editable business data. Keep one update-cascade edge for each exact
   FK mapping. Legacy/company schemas can retain an equivalent FK under another
   name; cascading both edges raises SQL Server 1785 even though their columns
   are identical. Equivalent extra constraints remain enabled NO ACTION rules. */
DECLARE @GroupObjectId int = OBJECT_ID(N'dbo.[Group]', N'U');
DECLARE @GroupCodeColumnId int = COLUMNPROPERTY(@GroupObjectId, N'Code', 'ColumnId');
IF @GroupObjectId IS NULL OR @GroupCodeColumnId IS NULL
    THROW 52822, N'Grup kodu ilişkileri için dbo.Group.Code bulunamadı.', 1;

DECLARE @GroupRelationships TABLE
(
    RelationshipId int NOT NULL PRIMARY KEY,
    ParentObjectId int NOT NULL,
    SchemaName sysname NOT NULL,
    TableName sysname NOT NULL,
    ConstraintName sysname NOT NULL,
    DeleteAction nvarchar(60) NOT NULL,
    UpdateAction int NOT NULL,
    NotForReplication bit NOT NULL,
    ParentColumns nvarchar(max) NOT NULL,
    ReferencedColumns nvarchar(max) NOT NULL,
    ColumnCount int NOT NULL,
    ColumnMapping nvarchar(4000) NOT NULL,
    DesiredUpdateAction int NOT NULL DEFAULT (1),
    HadOriginalRule bit NOT NULL,
    OriginalUpdateAction int NULL
);

IF EXISTS
(
    SELECT 1 FROM sys.foreign_keys AS relationship
    WHERE relationship.referenced_object_id = @GroupObjectId
      AND EXISTS (SELECT 1 FROM sys.foreign_key_columns AS columnPair
                  WHERE columnPair.constraint_object_id = relationship.object_id
                    AND columnPair.referenced_column_id = @GroupCodeColumnId)
      AND (relationship.is_disabled = 1 OR relationship.is_not_trusted = 1)
)
    THROW 52823, N'Grup koduna bağlı devre dışı veya doğrulanmamış ilişki var. İlişki düzeltilmeden güncelleme kurulamaz.', 1;

/* Materialize metadata before any constraint is recreated: object ids change
   after DROP/ADD and a live catalog cursor could skip an equivalent relation. */
INSERT INTO @GroupRelationships
    (RelationshipId, ParentObjectId, SchemaName, TableName, ConstraintName,
     DeleteAction, UpdateAction, NotForReplication, ParentColumns, ReferencedColumns,
     ColumnCount, ColumnMapping, HadOriginalRule, OriginalUpdateAction)
SELECT relationship.object_id, relationship.parent_object_id,
       schemaRecord.name, tableRecord.name, relationship.name,
       REPLACE(relationship.delete_referential_action_desc, N'_', N' '),
       relationship.update_referential_action, relationship.is_not_for_replication,
       columnList.ParentColumns, columnList.ReferencedColumns, columnList.ColumnCount,
       columnList.ColumnMapping, CASE WHEN originalRule.name IS NULL THEN 0 ELSE 1 END,
       TRY_CONVERT(int, originalRule.value)
FROM sys.foreign_keys AS relationship
INNER JOIN sys.tables AS tableRecord ON tableRecord.object_id = relationship.parent_object_id
INNER JOIN sys.schemas AS schemaRecord ON schemaRecord.schema_id = tableRecord.schema_id
LEFT JOIN sys.extended_properties AS originalRule
    ON originalRule.class = 1 AND originalRule.major_id = relationship.object_id
   AND originalRule.minor_id = 0 AND originalRule.name = N'Afife:GroupCodeOriginalUpdateAction'
CROSS APPLY
(
    SELECT STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(parentColumn.name)), N', ')
               WITHIN GROUP (ORDER BY columnPair.constraint_column_id) AS ParentColumns,
           STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(referencedColumn.name)), N', ')
               WITHIN GROUP (ORDER BY columnPair.constraint_column_id) AS ReferencedColumns,
           COUNT(*) AS ColumnCount,
           CONVERT(nvarchar(4000), STRING_AGG(CONVERT(nvarchar(max),
               CONCAT(columnPair.constraint_column_id, N':', columnPair.parent_column_id,
                      N'>', columnPair.referenced_column_id)), N';')
               WITHIN GROUP (ORDER BY columnPair.constraint_column_id)) AS ColumnMapping
    FROM sys.foreign_key_columns AS columnPair
    INNER JOIN sys.columns AS parentColumn
        ON parentColumn.object_id = columnPair.parent_object_id AND parentColumn.column_id = columnPair.parent_column_id
    INNER JOIN sys.columns AS referencedColumn
        ON referencedColumn.object_id = columnPair.referenced_object_id AND referencedColumn.column_id = columnPair.referenced_column_id
    WHERE columnPair.constraint_object_id = relationship.object_id
) AS columnList
WHERE relationship.referenced_object_id = @GroupObjectId
  AND EXISTS (SELECT 1 FROM sys.foreign_key_columns AS columnPair
              WHERE columnPair.constraint_object_id = relationship.object_id
                AND columnPair.referenced_column_id = @GroupCodeColumnId);

IF EXISTS (SELECT 1 FROM @GroupRelationships WHERE HadOriginalRule = 1
           AND (OriginalUpdateAction IS NULL OR OriginalUpdateAction NOT BETWEEN 0 AND 3))
    THROW 52825, N'Önceki grup kodu ilişki kuralı okunamadı; ilişki değiştirilemedi.', 1;

;WITH RankedMappings AS
(
    SELECT RelationshipId,
           ROW_NUMBER() OVER
           (
               PARTITION BY ParentObjectId, ColumnMapping
               ORDER BY CASE WHEN UpdateAction = 1 THEN 0
                             WHEN UpdateAction IN (2, 3) THEN 1
                             WHEN ParentObjectId = OBJECT_ID(N'dbo.Users')
                                  AND ConstraintName = N'FK_Users_Group'
                                  AND ParentColumns = N'[GroupCode]'
                                  AND ReferencedColumns = N'[Code]' THEN 2 ELSE 3 END,
                        ConstraintName, RelationshipId
           ) AS MappingOccurrence
    FROM @GroupRelationships
)
UPDATE relationship
SET DesiredUpdateAction = CASE WHEN mapping.MappingOccurrence = 1 THEN 1 ELSE 0 END
FROM @GroupRelationships AS relationship
INNER JOIN RankedMappings AS mapping ON mapping.RelationshipId = relationship.RelationshipId;

DECLARE @RelationshipId int, @SchemaName sysname, @TableName sysname,
        @ConstraintName sysname, @DeleteAction nvarchar(60), @UpdateAction int,
        @DesiredUpdateAction int, @NotForReplication bit, @Columns nvarchar(max),
        @ReferencedColumns nvarchar(max), @Sql nvarchar(max),
        @OriginalUpdateAction int, @ColumnCount int;
DECLARE groupRelationships CURSOR LOCAL FAST_FORWARD FOR
    SELECT RelationshipId, SchemaName, TableName, ConstraintName, DeleteAction,
           UpdateAction, DesiredUpdateAction, NotForReplication, ParentColumns,
           ReferencedColumns, COALESCE(OriginalUpdateAction, UpdateAction), ColumnCount
    FROM @GroupRelationships
    /* Keep an existing cascading winner; when repair is necessary, demote
       extra edges before promoting a winner so no transient duplicate exists. */
    ORDER BY DesiredUpdateAction, SchemaName, TableName, ConstraintName;
OPEN groupRelationships;
FETCH NEXT FROM groupRelationships INTO @RelationshipId, @SchemaName, @TableName,
    @ConstraintName, @DeleteAction, @UpdateAction, @DesiredUpdateAction,
    @NotForReplication, @Columns, @ReferencedColumns, @OriginalUpdateAction, @ColumnCount;
WHILE @@FETCH_STATUS = 0
BEGIN
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

    IF @UpdateAction <> @DesiredUpdateAction
    BEGIN
        IF @DesiredUpdateAction = 1 AND EXISTS
        (
            SELECT 1 FROM sys.triggers AS triggerRecord
            INNER JOIN sys.trigger_events AS triggerEvent ON triggerEvent.object_id = triggerRecord.object_id
            WHERE triggerRecord.parent_id = OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName))
              AND triggerRecord.is_instead_of_trigger = 1 AND triggerEvent.type_desc = N'UPDATE'
        )
            THROW 52824, N'Grup koduna bağlı tabloda INSTEAD OF UPDATE trigger var. İlişki otomatik taşınamadı; migration geri alındı.', 1;

        SET @Sql = N'ALTER TABLE ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)
            + N' DROP CONSTRAINT ' + QUOTENAME(@ConstraintName) + N'; ALTER TABLE '
            + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)
            + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@ConstraintName) + N' FOREIGN KEY (' + @Columns + N')'
            + N' REFERENCES dbo.[Group] (' + @ReferencedColumns + N') ON DELETE ' + @DeleteAction
            + N' ON UPDATE ' + CASE @DesiredUpdateAction WHEN 1 THEN N'CASCADE' ELSE N'NO ACTION' END
            + CASE WHEN @NotForReplication = 1 THEN N' NOT FOR REPLICATION' ELSE N'' END + N';';
        /* Distinct mappings are never skipped: genuinely unsupported cascade
           graphs fail the transaction instead of leaving references stranded. */
        EXEC sys.sp_executesql @Sql;
        EXEC sys.sp_addextendedproperty @name = N'Afife:GroupCodeOriginalUpdateAction', @value = @OriginalUpdateAction,
            @level0type = N'SCHEMA', @level0name = @SchemaName,
            @level1type = N'TABLE', @level1name = @TableName,
            @level2type = N'CONSTRAINT', @level2name = @ConstraintName;
    END;
    FETCH NEXT FROM groupRelationships INTO @RelationshipId, @SchemaName, @TableName,
        @ConstraintName, @DeleteAction, @UpdateAction, @DesiredUpdateAction,
        @NotForReplication, @Columns, @ReferencedColumns, @OriginalUpdateAction, @ColumnCount;
END;
CLOSE groupRelationships;
DEALLOCATE groupRelationships;
