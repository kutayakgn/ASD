using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class GroupManagement_v_20261027112722 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {

            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "GroupManagement_v_20261027112722", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Introduced in this version; remove before schema rollback.
            migrationBuilder.Sql("DROP TRIGGER IF EXISTS [dbo].[TR_Users_ValidateGroupAssignment];\r\nDROP TRIGGER IF EXISTS [dbo].[TR_Group_ProtectAssignments];");


            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "GroupManagement_v_20261027112722", "Down.sql");
            // Restore only FK update rules changed by this version. Keys and
            // dependent rows retain their current values; pre-existing CASCADE
            // relationships have no marker and are deliberately left intact.
            migrationBuilder.Sql("""
                DECLARE @RelationshipId int, @SchemaName sysname, @TableName sysname,
                        @ConstraintName sysname, @DeleteAction nvarchar(60), @OriginalUpdateAction int,
                        @NotForReplication bit, @Columns nvarchar(max), @ReferencedColumns nvarchar(max),
                        @Sql nvarchar(max);
                DECLARE originalGroupRelationships CURSOR LOCAL FAST_FORWARD FOR
                    SELECT relationship.object_id, schemaRecord.name, tableRecord.name,
                           relationship.name, REPLACE(relationship.delete_referential_action_desc, N'_', N' '),
                           TRY_CONVERT(int, originalRule.value), relationship.is_not_for_replication
                    FROM sys.foreign_keys AS relationship
                    INNER JOIN sys.tables AS tableRecord ON tableRecord.object_id = relationship.parent_object_id
                    INNER JOIN sys.schemas AS schemaRecord ON schemaRecord.schema_id = tableRecord.schema_id
                    INNER JOIN sys.extended_properties AS originalRule
                        ON originalRule.class = 1 AND originalRule.major_id = relationship.object_id
                       AND originalRule.minor_id = 0 AND originalRule.name = N'Afife:GroupCodeOriginalUpdateAction'
                    WHERE relationship.referenced_object_id = OBJECT_ID(N'dbo.[Group]');
                OPEN originalGroupRelationships;
                FETCH NEXT FROM originalGroupRelationships INTO @RelationshipId, @SchemaName, @TableName,
                    @ConstraintName, @DeleteAction, @OriginalUpdateAction, @NotForReplication;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    IF @OriginalUpdateAction IS NULL OR @OriginalUpdateAction NOT BETWEEN 0 AND 3
                        THROW 52825, N'Önceki grup kodu ilişki kuralı okunamadı; migration geri alınamadı.', 1;
                    SELECT @Columns = STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(parentColumn.name)), N', ')
                               WITHIN GROUP (ORDER BY columnPair.constraint_column_id),
                           @ReferencedColumns = STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(referencedColumn.name)), N', ')
                               WITHIN GROUP (ORDER BY columnPair.constraint_column_id)
                    FROM sys.foreign_key_columns AS columnPair
                    INNER JOIN sys.columns AS parentColumn
                        ON parentColumn.object_id = columnPair.parent_object_id AND parentColumn.column_id = columnPair.parent_column_id
                    INNER JOIN sys.columns AS referencedColumn
                        ON referencedColumn.object_id = columnPair.referenced_object_id AND referencedColumn.column_id = columnPair.referenced_column_id
                    WHERE columnPair.constraint_object_id = @RelationshipId;
                    SET @Sql = N'ALTER TABLE ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)
                        + N' DROP CONSTRAINT ' + QUOTENAME(@ConstraintName) + N'; ALTER TABLE '
                        + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName)
                        + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@ConstraintName) + N' FOREIGN KEY (' + @Columns + N')'
                        + N' REFERENCES dbo.[Group] (' + @ReferencedColumns + N') ON DELETE ' + @DeleteAction
                        + N' ON UPDATE ' + CASE @OriginalUpdateAction WHEN 0 THEN N'NO ACTION' WHEN 1 THEN N'CASCADE'
                            WHEN 2 THEN N'SET NULL' WHEN 3 THEN N'SET DEFAULT' END
                        + CASE WHEN @NotForReplication = 1 THEN N' NOT FOR REPLICATION' ELSE N'' END + N';';
                    EXEC sys.sp_executesql @Sql;
                    FETCH NEXT FROM originalGroupRelationships INTO @RelationshipId, @SchemaName, @TableName,
                        @ConstraintName, @DeleteAction, @OriginalUpdateAction, @NotForReplication;
                END;
                CLOSE originalGroupRelationships;
                DEALLOCATE originalGroupRelationships;
                """);
        }
    }
}
