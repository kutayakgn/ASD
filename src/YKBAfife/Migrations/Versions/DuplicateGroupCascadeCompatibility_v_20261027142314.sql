-- Immutable SQL package: DuplicateGroupCascadeCompatibility_v_20261027142314
-- Generated with the EF migration. Edit canonical DatabaseObjects, not this history.
-- SHA256 preserves original UTF-8 text; paired SHA256-LF tolerates CRLF/LF transport only.
-- <AFIFE:MODULES>
-- 00-Prerequisites/GroupCodeCascade.sql
-- 00-Prerequisites/ProgrammabilityPrerequisites.sql
-- 10-Functions/ufn_CreatePlaySlug.sql
-- 20-StoredProcedures/usp_ReassignFormSeasons.sql
-- 20-StoredProcedures/usp_RefreshRankings.sql
-- 20-StoredProcedures/usp_RefreshSeasonStatistics.sql
-- 20-StoredProcedures/usp_SynchronizeFormCandidates.sql
-- 20-StoredProcedures/usp_SynchronizeFormsToPlays.sql
-- 20-StoredProcedures/usp_SynchronizePlayDataToForms.sql
-- 30-Triggers/TR_AdditionalVotingJuries_SoftDelete.sql
-- 30-Triggers/TR_AdditionalVotingPlays_SoftDelete.sql
-- 30-Triggers/TR_AdditionalVotings_SoftDelete.sql
-- 30-Triggers/TR_AdditionalVotingUsages_SoftDelete.sql
-- 30-Triggers/TR_AdminLogs_SoftDelete.sql
-- 30-Triggers/TR_Announcements_SoftDelete.sql
-- 30-Triggers/TR_AwardCategories_SoftDelete.sql
-- 30-Triggers/TR_Blacklist_BlockAdminPlay.sql
-- 30-Triggers/TR_Blacklist_BlockInactiveSourceForm.sql
-- 30-Triggers/TR_Blacklist_DeactivateJuryVotes.sql
-- 30-Triggers/TR_Blacklist_SoftDelete.sql
-- 30-Triggers/TR_Configs_ProtectJuryHomePageSettings.sql
-- 30-Triggers/TR_Configs_SoftDelete.sql
-- 30-Triggers/TR_Form_NormalizeSeasonAndSynchronize.sql
-- 30-Triggers/TR_Form_SoftDelete.sql
-- 30-Triggers/TR_Group_ProtectAssignments.sql
-- 30-Triggers/TR_Group_SoftDelete.sql
-- 30-Triggers/TR_Images_EnforceMaximumSize.sql
-- 30-Triggers/TR_Images_SoftDelete.sql
-- 30-Triggers/TR_JuryAssignedPlays_BlockInactiveSourceForm.sql
-- 30-Triggers/TR_JuryAssignedPlays_SoftDelete.sql
-- 30-Triggers/TR_JuryGameTicketFees_BlockInactiveSourceForm.sql
-- 30-Triggers/TR_JuryGameTicketFees_SoftDelete.sql
-- 30-Triggers/TR_JuryLogs_SoftDelete.sql
-- 30-Triggers/TR_JuryVotes_BlockBlacklistedJuryPlay.sql
-- 30-Triggers/TR_JuryVotes_BlockInactiveSourceForm.sql
-- 30-Triggers/TR_JuryVotes_RefreshRankings.sql
-- 30-Triggers/TR_JuryVotes_RefreshSeasonStatistics.sql
-- 30-Triggers/TR_JuryVotes_SingleRecordPerPlayCategoryRole.sql
-- 30-Triggers/TR_JuryVotes_SoftDelete.sql
-- 30-Triggers/TR_Log_SoftDelete.sql
-- 30-Triggers/TR_Manager_SoftDelete.sql
-- 30-Triggers/TR_PlayAwardCategories_BlockAdminPlay.sql
-- 30-Triggers/TR_PlayAwardCategories_BlockInactiveSourceForm.sql
-- 30-Triggers/TR_PlayAwardCategories_BlockPreviousProduction.sql
-- 30-Triggers/TR_PlayAwardCategories_EnforceMultiplicity.sql
-- 30-Triggers/TR_PlayAwardCategories_ProtectDefaultCategory.sql
-- 30-Triggers/TR_PlayAwardCategories_RefreshRankings.sql
-- 30-Triggers/TR_PlayAwardCategories_RefreshSeasonStatistics.sql
-- 30-Triggers/TR_PlayAwardCategories_SoftDelete.sql
-- 30-Triggers/TR_PlayAwardCategories_SynchronizeJuryVotes.sql
-- 30-Triggers/TR_PlayAwardCategories_SynchronizeSourceForm.sql
-- 30-Triggers/TR_Plays_BlockAdminRecordTypeWithCandidates.sql
-- 30-Triggers/TR_Plays_EnsureDefaultAwardCategory.sql
-- 30-Triggers/TR_Plays_RecordTypeImmutable.sql
-- 30-Triggers/TR_Plays_RefreshRankings.sql
-- 30-Triggers/TR_Plays_RefreshSeasonStatistics.sql
-- 30-Triggers/TR_Plays_SoftDelete.sql
-- 30-Triggers/TR_Plays_SoftDeleteDependents.sql
-- 30-Triggers/TR_Plays_SynchronizeSlug.sql
-- 30-Triggers/TR_Plays_SynchronizeSourceForm.sql
-- 30-Triggers/TR_PlayStatuses_SoftDelete.sql
-- 30-Triggers/TR_Rankings_BlockManualDelete.sql
-- 30-Triggers/TR_Rankings_BlockManualWrite.sql
-- 30-Triggers/TR_Roles_SoftDelete.sql
-- 30-Triggers/TR_Seasons_PreventPublishedDateOverlap.sql
-- 30-Triggers/TR_Seasons_ReassignForms.sql
-- 30-Triggers/TR_Seasons_RefreshStatistics.sql
-- 30-Triggers/TR_Seasons_SoftDelete.sql
-- 30-Triggers/TR_SharedAdminDataProtectionKeys_AppendOnly.sql
-- 30-Triggers/TR_Users_SoftDelete.sql
-- 30-Triggers/TR_Users_SoftDeleteDependents.sql
-- 30-Triggers/TR_Users_ValidateGroupAssignment.sql
-- 30-Triggers/TR_UsersLog_SoftDelete.sql
-- 40-Audit/01-AuditTriggerMaintenance.sql
-- 40-Audit/02-AuditTriggerMaintenance.sql
-- 50-ReferenceData/CanonicalReferenceData.sql
-- 50-ReferenceData/JuryHomePageTableSettings.sql
-- </AFIFE:MODULES>
-- <AFIFE:SHA256:CANONICAL=30A7BBAFC5DCEB868A631AD7A4E0657B507603FE7EE3FEC0658A8ABEF2814FD7>
-- <AFIFE:SHA256-LF:CANONICAL=30A7BBAFC5DCEB868A631AD7A4E0657B507603FE7EE3FEC0658A8ABEF2814FD7:55696383D3136DADACDCECAC287261EDC2140E7E802174A73DF8E5B83A5DCEE0>
-- <AFIFE:BATCHES:CANONICAL=77>
-- <AFIFE:CANONICAL>
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
GO

SET XACT_ABORT ON;

/* Legacy releases enforced one current row per play/category and therefore
   blocked the RoleCode-based multi-candidate contract introduced for 1003-1012.
   Remove only the known obsolete index before any historical migration invokes
   the current Form synchronization procedure. Rows are not changed. */
IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name = N'UX_PlayAwardCategories_PlayId_IsCurrent_AwardCategoryCode'
)
    DROP INDEX [UX_PlayAwardCategories_PlayId_IsCurrent_AwardCategoryCode]
        ON [dbo].[PlayAwardCategories];

/* Some company databases use a different name for the same obsolete filtered
   index. Detect its shape as well: unique PlayId+AwardCategoryCode keys, filtered
   to current rows, without RoleCode. Canonical indexes all include RoleCode or
   have a different key shape. */
DECLARE @ObsoleteCurrentCategoryIndex sysname;
SELECT TOP (1) @ObsoleteCurrentCategoryIndex = candidateIndex.name
FROM sys.indexes AS candidateIndex
WHERE candidateIndex.object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
  AND candidateIndex.is_unique = 1
  AND candidateIndex.has_filter = 1
  AND candidateIndex.filter_definition LIKE N'%IsCurrent%'
  AND
  (
      SELECT COUNT(*)
      FROM sys.index_columns AS indexColumn
      WHERE indexColumn.object_id = candidateIndex.object_id
        AND indexColumn.index_id = candidateIndex.index_id
        AND indexColumn.key_ordinal > 0
  ) = 2
  AND EXISTS
  (
      SELECT 1
      FROM sys.index_columns AS indexColumn
      INNER JOIN sys.columns AS columnRecord
          ON columnRecord.object_id = indexColumn.object_id
         AND columnRecord.column_id = indexColumn.column_id
      WHERE indexColumn.object_id = candidateIndex.object_id
        AND indexColumn.index_id = candidateIndex.index_id
        AND indexColumn.key_ordinal > 0
        AND columnRecord.name = N'PlayId'
  )
  AND EXISTS
  (
      SELECT 1
      FROM sys.index_columns AS indexColumn
      INNER JOIN sys.columns AS columnRecord
          ON columnRecord.object_id = indexColumn.object_id
         AND columnRecord.column_id = indexColumn.column_id
      WHERE indexColumn.object_id = candidateIndex.object_id
        AND indexColumn.index_id = candidateIndex.index_id
        AND indexColumn.key_ordinal > 0
        AND columnRecord.name = N'AwardCategoryCode'
  );

IF @ObsoleteCurrentCategoryIndex IS NOT NULL
BEGIN
    DECLARE @DropObsoleteCurrentCategoryIndexSql nvarchar(max) =
        N'DROP INDEX ' + QUOTENAME(@ObsoleteCurrentCategoryIndex) +
        N' ON dbo.PlayAwardCategories;';
    EXEC sys.sp_executesql @DropObsoleteCurrentCategoryIndexSql;
END;

/*
   CREATE OR ALTER still validates referenced columns while compiling modules.
   Keep every additive column required by Programmability.sql here so historical
   migrations that execute the current resource can safely upgrade legacy tables.
*/
IF OBJECT_ID(N'dbo.Form', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
BEGIN
    EXEC sys.sp_executesql
        N'ALTER TABLE dbo.Form ADD YoungGenerationArtist nvarchar(max) NULL;';
END;

IF OBJECT_ID(N'dbo.Form', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
    THROW 52421, N'Programmability ön koşulu başarısız: dbo.Form.YoungGenerationArtist oluşturulamadı.', 1;

IF OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.PlayAwardCategories', N'SourceFormCandidateOrder') IS NULL
BEGIN
    EXEC sys.sp_executesql
        N'ALTER TABLE dbo.PlayAwardCategories ADD SourceFormCandidateOrder int NULL;';
END;

IF OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.PlayAwardCategories', N'SourceFormCandidateOrder') IS NULL
    THROW 52422, N'Programmability ön koşulu başarısız: dbo.PlayAwardCategories.SourceFormCandidateOrder oluşturulamadı.', 1;
GO

CREATE OR ALTER FUNCTION dbo.ufn_CreatePlaySlug(@Value nvarchar(255))
RETURNS varchar(255)
AS
BEGIN
    DECLARE @Input nvarchar(255) = ISNULL(@Value, N'');
    DECLARE @Result varchar(255) = '';
    DECLARE @Position int = 1;
    DECLARE @PendingSeparator bit = 0;
    DECLARE @Character nchar(1);
    DECLARE @CodePoint int;

    WHILE @Position <= LEN(@Input) AND LEN(@Result) < 255
    BEGIN
        SET @Character = SUBSTRING(@Input, @Position, 1);
        SET @Character = CASE @Character COLLATE Latin1_General_100_BIN2
            WHEN N'ç' THEN N'c' WHEN N'Ç' THEN N'c'
            WHEN N'ğ' THEN N'g' WHEN N'Ğ' THEN N'g'
            WHEN N'ı' THEN N'i' WHEN N'İ' THEN N'i'
            WHEN N'ö' THEN N'o' WHEN N'Ö' THEN N'o'
            WHEN N'ş' THEN N's' WHEN N'Ş' THEN N's'
            WHEN N'ü' THEN N'u' WHEN N'Ü' THEN N'u'
            ELSE LOWER(@Character COLLATE Latin1_General_100_CI_AS)
        END;
        SET @CodePoint = UNICODE(@Character);

        IF @CodePoint BETWEEN 48 AND 57 OR @CodePoint BETWEEN 97 AND 122
        BEGIN
            IF @PendingSeparator = 1 AND LEN(@Result) > 0
            BEGIN
                IF LEN(@Result) >= 254
                    BREAK;

                SET @Result += '-';
            END;

            IF LEN(@Result) < 255
                SET @Result += CONVERT(varchar(1), @Character);

            SET @PendingSeparator = 0;
        END
        ELSE IF LEN(@Result) > 0
            SET @PendingSeparator = 1;

        SET @Position += 1;
    END;

    RETURN CASE WHEN LEN(@Result) = 0 THEN 'oyun' ELSE @Result END;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ReassignFormSeasons]
    @ChangedSeasonsJson nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    CREATE TABLE #ChangedSeasonRanges
    (Id uniqueidentifier NOT NULL, StartDate date NOT NULL, EndDate date NOT NULL);
    IF @ChangedSeasonsJson IS NOT NULL
    BEGIN
        IF ISJSON(@ChangedSeasonsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@ChangedSeasonsJson, CHAR(9), N' '), CHAR(10), N' '), CHAR(13), N' ')), 1) <> N'['
            THROW 52742, N'Changed seasons must be an array.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@ChangedSeasonsJson) AS item
            OUTER APPLY OPENJSON(CASE WHEN item.type = 5 THEN item.value ELSE N'{}' END)
                WITH (Id nvarchar(max), StartDate nvarchar(max), EndDate nvarchar(max)) AS scope
            WHERE item.type <> 5 OR scope.Id IS NULL OR DATALENGTH(scope.Id) <> 72
               OR TRY_CONVERT(uniqueidentifier, scope.Id) IS NULL
               OR scope.StartDate IS NULL OR scope.EndDate IS NULL
               OR TRY_CONVERT(date, scope.StartDate, 23) IS NULL
               OR TRY_CONVERT(date, scope.EndDate, 23) IS NULL
               OR TRY_CONVERT(date, scope.StartDate, 23) >= TRY_CONVERT(date, scope.EndDate, 23)
        ) THROW 52742, N'Changed season range is invalid.', 1;
        INSERT #ChangedSeasonRanges
        SELECT DISTINCT CONVERT(uniqueidentifier, Id), CONVERT(date, StartDate, 23), CONVERT(date, EndDate, 23)
        FROM OPENJSON(@ChangedSeasonsJson) WITH (Id nvarchar(36), StartDate nvarchar(10), EndDate nvarchar(10));
    END;

    CREATE TABLE #SeasonForms (Id uniqueidentifier NOT NULL PRIMARY KEY);
    IF @ChangedSeasonsJson IS NULL
        INSERT #SeasonForms SELECT Id FROM dbo.Form;
    ELSE
        INSERT #SeasonForms
        SELECT formRecord.Id FROM #ChangedSeasonRanges AS changed
        INNER JOIN dbo.Form AS formRecord
            ON formRecord.CreatedDate >= CONVERT(datetime, changed.StartDate)
           AND formRecord.CreatedDate < CONVERT(datetime, changed.EndDate)
        UNION
        SELECT formRecord.Id FROM #ChangedSeasonRanges AS changed
        INNER JOIN dbo.Form AS formRecord ON formRecord.SeasonId = changed.Id;

    BEGIN TRY
        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = 1;

        UPDATE formRecord
        SET SeasonId = selectedSeason.Id
        FROM dbo.Form AS formRecord
        INNER JOIN #SeasonForms AS affected ON affected.Id = formRecord.Id
        OUTER APPLY
        (
            SELECT TOP (1) season.Id
            FROM dbo.Seasons AS season
            WHERE season.IsPublished = 1
              AND formRecord.CreatedDate IS NOT NULL
              AND formRecord.CreatedDate >= CONVERT(datetime, season.SeasonStartDate)
              AND formRecord.CreatedDate < CONVERT(datetime, season.SeasonEndDate)
            ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
        ) AS selectedSeason
        WHERE formRecord.SeasonId <> selectedSeason.Id
           OR (formRecord.SeasonId IS NULL AND selectedSeason.Id IS NOT NULL)
           OR (formRecord.SeasonId IS NOT NULL AND selectedSeason.Id IS NULL);

        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_RefreshRankings]
    @CategoryCodesJson nvarchar(max) = NULL,
    @CandidateIdsJson nvarchar(max) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'RankingsRefreshInProgress')) = 1
        RETURN;

    /* Explicit maintenance keeps the historical full-rebuild contract. Normal
       DML supplies old/new categories and dirty candidate IDs. Rankings depend
       on peers in the same category, but their unchanged votes need no reread. */
    DECLARE @FullRefresh bit = CASE WHEN @CategoryCodesJson IS NULL THEN 1 ELSE 0 END;
    CREATE TABLE #RankingAffectedCategories (CategoryCode int NOT NULL PRIMARY KEY);
    CREATE TABLE #RankingDirtyCandidates (CandidateId uniqueidentifier NOT NULL PRIMARY KEY);
    CREATE TABLE #RankingCategoryLocks
    (
        CategoryCode int NOT NULL PRIMARY KEY,
        IsAcquired bit NOT NULL DEFAULT (0)
    );

    IF @CategoryCodesJson IS NULL AND @CandidateIdsJson IS NOT NULL
        THROW 52740, N'Aday kapsamı için ödül kategorisi kapsamı da gereklidir.', 1;

    IF @CategoryCodesJson IS NOT NULL
    BEGIN
        IF ISJSON(@CategoryCodesJson) <> 1 OR LEFT(LTRIM(@CategoryCodesJson), 1) <> N'['
            THROW 52740, N'Sıralama kapsamı geçerli bir CategoryCode dizisi olmalıdır.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@CategoryCodesJson) AS item
            WHERE item.[type] <> 5 OR TRY_CONVERT(int,
                JSON_VALUE(CASE WHEN item.[type] = 5 THEN item.[value] ELSE N'{}' END, N'$.CategoryCode')) IS NULL
        )
            THROW 52740, N'Sıralama kapsamı geçerli bir CategoryCode dizisi olmalıdır.', 1;
        INSERT INTO #RankingAffectedCategories (CategoryCode)
        SELECT DISTINCT CONVERT(int, JSON_VALUE(item.[value], N'$.CategoryCode'))
        FROM OPENJSON(@CategoryCodesJson) AS item;
    END;

    IF @CandidateIdsJson IS NOT NULL
    BEGIN
        IF ISJSON(@CandidateIdsJson) <> 1 OR LEFT(LTRIM(@CandidateIdsJson), 1) <> N'['
            THROW 52740, N'Sıralama aday kapsamı geçerli bir Id dizisi olmalıdır.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@CandidateIdsJson) AS item
            WHERE item.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN item.[type] = 5 THEN item.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier,
                   JSON_VALUE(CASE WHEN item.[type] = 5 THEN item.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52740, N'Sıralama aday kapsamı geçerli bir Id dizisi olmalıdır.', 1;
        INSERT INTO #RankingDirtyCandidates (CandidateId)
        SELECT DISTINCT CONVERT(uniqueidentifier, JSON_VALUE(item.[value], N'$.Id'))
        FROM OPENJSON(@CandidateIdsJson) AS item;
    END;

    IF @FullRefresh = 0
       AND NOT EXISTS (SELECT 1 FROM #RankingAffectedCategories)
       AND NOT EXISTS (SELECT 1 FROM #RankingDirtyCandidates)
        RETURN;

    DECLARE @ApplicationLockResult int;
    DECLARE @GlobalLockMode nvarchar(32) = CASE WHEN @FullRefresh = 1 THEN N'Exclusive' ELSE N'Shared' END;
    DECLARE @LockedCategory int;
    DECLARE @CategoryLockResource nvarchar(255);
    /* Scalar variables survive a deadlock victim's transaction rollback. A
       temp-table acquisition log does not, while session-owned locks survive. */
    DECLARE @AcquiredCategoryLocks nvarchar(max) = N'';
    DECLARE @CategoryLockDelimiter int;
    EXEC @ApplicationLockResult = sys.sp_getapplock
        @Resource = N'AfifeAdmin.Rankings.Refresh',
        @LockMode = @GlobalLockMode,
        @LockOwner = N'Session',
        @LockTimeout = 30000;

    IF @ApplicationLockResult < 0
        THROW 52001, N'Rankings refresh lock could not be acquired.', 1;

    EXEC sys.sp_set_session_context
        @key = N'RankingsRefreshInProgress',
        @value = 1;
    EXEC sys.sp_set_session_context
        @key = N'RankingsRefreshAuthorized',
        @value = 1;

    BEGIN TRY
        IF @FullRefresh = 1
            INSERT INTO #RankingAffectedCategories (CategoryCode)
            SELECT DISTINCT AwardCategoryCode FROM dbo.PlayAwardCategories;
        ELSE
            /* A moved dirty candidate brings its new category even if a caller
               only supplied its previous category. */
            INSERT INTO #RankingAffectedCategories (CategoryCode)
            SELECT DISTINCT candidate.AwardCategoryCode
            FROM dbo.PlayAwardCategories AS candidate
            INNER JOIN #RankingDirtyCandidates AS dirty ON dirty.CandidateId = candidate.Id
            WHERE NOT EXISTS
            (
                SELECT 1 FROM #RankingAffectedCategories AS affected
                WHERE affected.CategoryCode = candidate.AwardCategoryCode
            );

        /* Different categories can refresh concurrently. Full maintenance takes
           the global lock exclusively; scoped callers share it and acquire all
           their category locks in numeric order, including both sides of moves. */
        IF @FullRefresh = 0
        BEGIN
            INSERT INTO #RankingCategoryLocks (CategoryCode)
            SELECT CategoryCode FROM #RankingAffectedCategories;
            WHILE EXISTS (SELECT 1 FROM #RankingCategoryLocks WHERE IsAcquired = 0)
            BEGIN
                SELECT TOP (1) @LockedCategory = CategoryCode
                FROM #RankingCategoryLocks WHERE IsAcquired = 0 ORDER BY CategoryCode;
                SET @CategoryLockResource = N'AfifeAdmin.Rankings.Category.' + CONVERT(nvarchar(12), @LockedCategory);
                EXEC @ApplicationLockResult = sys.sp_getapplock
                    @Resource = @CategoryLockResource, @LockMode = N'Exclusive',
                    @LockOwner = N'Session', @LockTimeout = 30000;
                IF @ApplicationLockResult < 0
                    THROW 52001, N'Rankings category refresh lock could not be acquired.', 1;
                SET @AcquiredCategoryLocks += CONVERT(nvarchar(12), @LockedCategory) + N';';
                UPDATE #RankingCategoryLocks SET IsAcquired = 1 WHERE CategoryCode = @LockedCategory;
            END;
        END;

        CREATE TABLE #RankingTargetScope (CandidateId uniqueidentifier NOT NULL PRIMARY KEY);
        INSERT INTO #RankingTargetScope (CandidateId)
        SELECT candidate.Id
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #RankingAffectedCategories AS affected ON affected.CategoryCode = candidate.AwardCategoryCode
        UNION
        SELECT CandidateId FROM #RankingDirtyCandidates
        UNION
        SELECT PlayAwardCategoryId FROM dbo.Rankings WHERE @FullRefresh = 1;

        CREATE TABLE #RankingEligibleCandidates
        (
            PlayAwardCategoryId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL,
            AwardCategoryCode int NOT NULL
        );
        INSERT INTO #RankingEligibleCandidates (PlayAwardCategoryId, PlayId, AwardCategoryCode)
        SELECT candidate.Id, candidate.PlayId, candidate.AwardCategoryCode
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #RankingAffectedCategories AS affected ON affected.CategoryCode = candidate.AwardCategoryCode
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE play.RecordType = 0 AND play.IsPublished = 1 AND play.IsActive = 1
          AND candidate.IsPublished = 1 AND candidate.IsCurrent = 1 AND candidate.IsActive = 1;

        CREATE TABLE #RankingRecalculate (CandidateId uniqueidentifier NOT NULL PRIMARY KEY);
        INSERT INTO #RankingRecalculate (CandidateId)
        SELECT eligible.PlayAwardCategoryId
        FROM #RankingEligibleCandidates AS eligible
        LEFT JOIN dbo.Rankings AS previous ON previous.PlayAwardCategoryId = eligible.PlayAwardCategoryId
        LEFT JOIN #RankingDirtyCandidates AS dirty ON dirty.CandidateId = eligible.PlayAwardCategoryId
        WHERE @CandidateIdsJson IS NULL OR dirty.CandidateId IS NOT NULL
           OR previous.Id IS NULL OR previous.IsPublished = 0;

        ;WITH OrderedActiveVotes AS
        (
            SELECT
                dirty.CandidateId AS PlayAwardCategoryId,
                vote.Score,
                ROW_NUMBER() OVER
                (
                    PARTITION BY dirty.CandidateId
                    ORDER BY vote.Score, vote.Id
                ) AS ScoreOrder,
                COUNT_BIG(*) OVER
                (
                    PARTITION BY dirty.CandidateId
                ) AS VoteCount
            FROM #RankingRecalculate AS dirty
            INNER JOIN dbo.JuryVotes AS vote
                ON vote.PlayAwardCategoryId = dirty.CandidateId
            WHERE vote.IsPublished = 1
              AND vote.IsActive = 1
        ),
        VoteStatistics AS
        (
            SELECT
                PlayAwardCategoryId,
                COUNT_BIG(*) AS NumberOfActiveVote,
                AVG(CONVERT(float, Score)) AS ArithmeticMean,
                VAR(CONVERT(float, Score)) AS ArithmeticVariance
            FROM OrderedActiveVotes
            GROUP BY PlayAwardCategoryId
        ),
        TrimmedStatistics AS
        (
            SELECT
                PlayAwardCategoryId,
                AVG(CONVERT(float, Score)) AS TrimmedMean
            FROM OrderedActiveVotes
            WHERE VoteCount >= 3
              AND ScoreOrder > 1
              AND ScoreOrder < VoteCount
            GROUP BY PlayAwardCategoryId
        ),
        CandidateStatistics AS
        (
            SELECT
                eligible.PlayAwardCategoryId,
                eligible.PlayId,
                eligible.AwardCategoryCode,
                CASE WHEN dirty.CandidateId IS NOT NULL
                    THEN CONVERT(int, COALESCE(voteStats.NumberOfActiveVote, 0))
                    ELSE previous.NumberOfActiveVote END
                    AS NumberOfActiveVote,
                CASE WHEN dirty.CandidateId IS NOT NULL THEN voteStats.ArithmeticMean ELSE previous.ArithmeticMean END AS ArithmeticMean,
                CASE WHEN dirty.CandidateId IS NOT NULL THEN trimmed.TrimmedMean ELSE previous.TrimmedMean END AS TrimmedMean,
                CASE WHEN dirty.CandidateId IS NOT NULL THEN voteStats.ArithmeticVariance ELSE previous.ArithmeticVariance END AS ArithmeticVariance
            FROM #RankingEligibleCandidates AS eligible
            LEFT JOIN #RankingRecalculate AS dirty ON dirty.CandidateId = eligible.PlayAwardCategoryId
            LEFT JOIN dbo.Rankings AS previous ON previous.PlayAwardCategoryId = eligible.PlayAwardCategoryId
            LEFT JOIN VoteStatistics AS voteStats
                ON voteStats.PlayAwardCategoryId =
                    eligible.PlayAwardCategoryId
            LEFT JOIN TrimmedStatistics AS trimmed
                ON trimmed.PlayAwardCategoryId =
                    eligible.PlayAwardCategoryId
        ),
        RankedStatistics AS
        (
            SELECT
                PlayAwardCategoryId,
                PlayId,
                NumberOfActiveVote,
                ArithmeticMean,
                TrimmedMean,
                CASE
                    WHEN ArithmeticMean IS NULL THEN NULL
                    ELSE CONVERT
                    (
                        int,
                        RANK() OVER
                        (
                            PARTITION BY AwardCategoryCode
                            ORDER BY
                                CASE WHEN ArithmeticMean IS NULL THEN 1 ELSE 0 END,
                                ArithmeticMean DESC
                        )
                    )
                END AS ArithmeticRank,
                CASE
                    WHEN TrimmedMean IS NULL THEN NULL
                    ELSE CONVERT
                    (
                        int,
                        RANK() OVER
                        (
                            PARTITION BY AwardCategoryCode
                            ORDER BY
                                CASE WHEN TrimmedMean IS NULL THEN 1 ELSE 0 END,
                                TrimmedMean DESC
                        )
                    )
                END AS TrimmedRank,
                ArithmeticVariance,
                CASE
                    WHEN ArithmeticVariance IS NULL THEN NULL
                    WHEN ArithmeticVariance >= 6.064 THEN 1
                    WHEN ArithmeticVariance >= 4.987 THEN 2
                    WHEN ArithmeticVariance >= 4.141 THEN 3
                    ELSE 4
                END AS ConfidenceValue
            FROM CandidateStatistics
        )
        MERGE dbo.Rankings WITH (HOLDLOCK) AS target
        USING RankedStatistics AS source
            ON source.PlayAwardCategoryId = target.PlayAwardCategoryId
        WHEN MATCHED AND
        (
            target.PlayId <> source.PlayId
            OR target.NumberOfActiveVote <> source.NumberOfActiveVote
            OR target.IsPublished = 0
            OR target.ArithmeticMean <> source.ArithmeticMean
            OR (target.ArithmeticMean IS NULL AND source.ArithmeticMean IS NOT NULL)
            OR (target.ArithmeticMean IS NOT NULL AND source.ArithmeticMean IS NULL)
            OR target.TrimmedMean <> source.TrimmedMean
            OR (target.TrimmedMean IS NULL AND source.TrimmedMean IS NOT NULL)
            OR (target.TrimmedMean IS NOT NULL AND source.TrimmedMean IS NULL)
            OR target.ArithmeticRank <> source.ArithmeticRank
            OR (target.ArithmeticRank IS NULL AND source.ArithmeticRank IS NOT NULL)
            OR (target.ArithmeticRank IS NOT NULL AND source.ArithmeticRank IS NULL)
            OR target.TrimmedRank <> source.TrimmedRank
            OR (target.TrimmedRank IS NULL AND source.TrimmedRank IS NOT NULL)
            OR (target.TrimmedRank IS NOT NULL AND source.TrimmedRank IS NULL)
            OR target.ArithmeticVariance <> source.ArithmeticVariance
            OR
            (
                target.ArithmeticVariance IS NULL
                AND source.ArithmeticVariance IS NOT NULL
            )
            OR
            (
                target.ArithmeticVariance IS NOT NULL
                AND source.ArithmeticVariance IS NULL
            )
            OR target.ConfidenceValue <> source.ConfidenceValue
            OR (target.ConfidenceValue IS NULL AND source.ConfidenceValue IS NOT NULL)
            OR (target.ConfidenceValue IS NOT NULL AND source.ConfidenceValue IS NULL)
        )
            THEN UPDATE SET
                PlayId = source.PlayId,
                NumberOfActiveVote = source.NumberOfActiveVote,
                ArithmeticMean = source.ArithmeticMean,
                TrimmedMean = source.TrimmedMean,
                ArithmeticRank = source.ArithmeticRank,
                TrimmedRank = source.TrimmedRank,
                ArithmeticVariance = source.ArithmeticVariance,
                ConfidenceValue = source.ConfidenceValue,
                IsPublished = 1
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                Id,
                PlayId,
                PlayAwardCategoryId,
                NumberOfActiveVote,
                ArithmeticMean,
                TrimmedMean,
                ArithmeticRank,
                TrimmedRank,
                ArithmeticVariance,
                ConfidenceValue,
                IsPublished
            )
            VALUES
            (
                NEWID(),
                source.PlayId,
                source.PlayAwardCategoryId,
                source.NumberOfActiveVote,
                source.ArithmeticMean,
                source.TrimmedMean,
                source.ArithmeticRank,
                source.TrimmedRank,
                source.ArithmeticVariance,
                source.ConfidenceValue,
                1
            );

        /* Restrict retirement separately: a partial source must never unpublish
           rankings from other categories. Dirty IDs also cover removed rows. */
        UPDATE target
        SET IsPublished = 0
        FROM dbo.Rankings AS target
        INNER JOIN #RankingTargetScope AS affected ON affected.CandidateId = target.PlayAwardCategoryId
        LEFT JOIN #RankingEligibleCandidates AS eligible ON eligible.PlayAwardCategoryId = target.PlayAwardCategoryId
        WHERE target.IsPublished = 1 AND eligible.PlayAwardCategoryId IS NULL;

        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshAuthorized',
            @value = NULL;
        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshInProgress',
            @value = NULL;
        WHILE LEN(@AcquiredCategoryLocks) > 0
        BEGIN
            SET @CategoryLockDelimiter = CHARINDEX(N';', @AcquiredCategoryLocks);
            SET @LockedCategory = CONVERT(int, LEFT(@AcquiredCategoryLocks, @CategoryLockDelimiter - 1));
            SET @CategoryLockResource = N'AfifeAdmin.Rankings.Category.' + CONVERT(nvarchar(12), @LockedCategory);
            EXEC sys.sp_releaseapplock @Resource = @CategoryLockResource, @LockOwner = N'Session';
            SET @AcquiredCategoryLocks = SUBSTRING(@AcquiredCategoryLocks, @CategoryLockDelimiter + 1, LEN(@AcquiredCategoryLocks));
        END;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Rankings.Refresh',
            @LockOwner = N'Session';
    END TRY
    BEGIN CATCH
        BEGIN TRY
            EXEC sys.sp_set_session_context @key = N'RankingsRefreshAuthorized', @value = NULL;
            EXEC sys.sp_set_session_context @key = N'RankingsRefreshInProgress', @value = NULL;
        END TRY
        BEGIN CATCH
            PRINT N'Rankings session-context cleanup failed.';
        END CATCH;
        /* No temp-table access here: SQL 1205 can remove those tables. Cleanup
           failures must not prevent release of other locks or mask the error. */
        WHILE LEN(@AcquiredCategoryLocks) > 0
        BEGIN
            SET @CategoryLockDelimiter = CHARINDEX(N';', @AcquiredCategoryLocks);
            SET @LockedCategory = CONVERT(int, LEFT(@AcquiredCategoryLocks, @CategoryLockDelimiter - 1));
            SET @AcquiredCategoryLocks = SUBSTRING(@AcquiredCategoryLocks, @CategoryLockDelimiter + 1, LEN(@AcquiredCategoryLocks));
            SET @CategoryLockResource = N'AfifeAdmin.Rankings.Category.' + CONVERT(nvarchar(12), @LockedCategory);
            BEGIN TRY
                EXEC sys.sp_releaseapplock @Resource = @CategoryLockResource, @LockOwner = N'Session';
            END TRY
            BEGIN CATCH
                PRINT N'Rankings category-lock cleanup failed.';
            END CATCH;
        END;
        BEGIN TRY
            EXEC sys.sp_releaseapplock @Resource = N'AfifeAdmin.Rankings.Refresh', @LockOwner = N'Session';
        END TRY
        BEGIN CATCH
            PRINT N'Rankings global-lock cleanup failed.';
        END CATCH;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_RefreshSeasonStatistics]
    @FromDate datetime2(7) = NULL,
    @ToDate datetime2(7) = NULL,
    @SeasonIdsJson nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @FromDate IS NOT NULL AND @ToDate IS NULL SET @ToDate = @FromDate;
    IF @ToDate IS NOT NULL AND @FromDate IS NULL SET @FromDate = @ToDate;
    CREATE TABLE #StatisticSeasons (Id uniqueidentifier NOT NULL PRIMARY KEY);
    IF @SeasonIdsJson IS NOT NULL
    BEGIN
        IF ISJSON(@SeasonIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@SeasonIdsJson, CHAR(9), N' '), CHAR(10), N' '), CHAR(13), N' ')), 1) <> N'['
            THROW 52741, N'Season scope must be an array of Id objects.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@SeasonIdsJson) AS item
            OUTER APPLY OPENJSON(CASE WHEN item.type = 5 THEN item.value ELSE N'{}' END)
                WITH (Id nvarchar(max) '$.Id') AS scope
            WHERE item.type <> 5 OR scope.Id IS NULL OR DATALENGTH(scope.Id) <> 72
               OR TRY_CONVERT(uniqueidentifier, scope.Id) IS NULL
        ) THROW 52741, N'Season scope contains an invalid Id.', 1;
        INSERT #StatisticSeasons SELECT DISTINCT CONVERT(uniqueidentifier, Id)
        FROM OPENJSON(@SeasonIdsJson) WITH (Id nvarchar(36) '$.Id');
    END
    ELSE
        INSERT #StatisticSeasons
        SELECT Id FROM dbo.Seasons
        WHERE IsPublished = 1 AND (@FromDate IS NULL OR
            (@FromDate < CONVERT(datetime2(7), SeasonEndDate)
             AND @ToDate >= CONVERT(datetime2(7), SeasonStartDate)));

    /* Trigger callers pass exact identities, not a min/max interval spanning
       unrelated seasons. Date covering indexes serve the range aggregates. */
    UPDATE season
    SET PlayCount = plays.PlayCount, ActivePlayCount = plays.ActivePlayCount,
        VoteCount = votes.VoteCount
    FROM dbo.Seasons AS season
    INNER JOIN #StatisticSeasons AS affected ON affected.Id = season.Id
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS PlayCount,
               COALESCE(SUM(CONVERT(bigint, CASE WHEN play.StatusCode = 1 THEN 1 ELSE 0 END)), 0) AS ActivePlayCount
        FROM dbo.Plays AS play
        WHERE play.IsPublished = 1 AND play.IsActive = 1
          AND play.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
          AND play.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
    ) AS plays
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS VoteCount
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE vote.IsPublished = 1 AND vote.IsActive = 1
          AND candidate.IsPublished = 1 AND candidate.IsActive = 1
          AND play.IsPublished = 1 AND play.IsActive = 1
          AND vote.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
          AND vote.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
    ) AS votes
    WHERE season.IsPublished = 1
      AND (season.PlayCount <> plays.PlayCount OR season.ActivePlayCount <> plays.ActivePlayCount
           OR season.VoteCount <> votes.VoteCount);
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_SynchronizeFormCandidates]
    @FormIdsJson nvarchar(max) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
    DECLARE @MaximumImageBytes bigint = 150 * 1024 * 1024;

    /* NULL retains the explicit full-maintenance contract. Trigger callers pass
       [{"Id":"guid"}] so a single Form never repairs or decodes unrelated plays. */
    CREATE TABLE #CandidateAffectedForms
    (
        FormId uniqueidentifier NOT NULL PRIMARY KEY
    );
    CREATE TABLE #CandidateAffectedPlays
    (
        PlayId uniqueidentifier NOT NULL PRIMARY KEY
    );

    IF @FormIdsJson IS NULL
    BEGIN
        INSERT INTO #CandidateAffectedForms (FormId)
        SELECT Id FROM dbo.Form;

        /* Historical full repairs also cover mapped legacy slots on plays that
           no longer have a Form link. Scoped calls must never touch them. */
        INSERT INTO #CandidateAffectedPlays (PlayId)
        SELECT Id FROM dbo.Plays;
    END
    ELSE
    BEGIN
        IF ISJSON(@FormIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@FormIdsJson,
               NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ')), 1) <> N'['
            THROW 52433, N'Form senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM OPENJSON(@FormIdsJson) AS scopeItem
            WHERE scopeItem.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier,
                   JSON_VALUE(CASE WHEN scopeItem.[type] = 5 THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52433, N'Form senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        INSERT INTO #CandidateAffectedForms (FormId)
        SELECT DISTINCT CONVERT(uniqueidentifier, JSON_VALUE(scopeItem.[value], N'$.Id'))
        FROM OPENJSON(@FormIdsJson) AS scopeItem;

        /* Include inactive/unpublished Forms: only source creation is filtered
           by active flags; legacy slot repair keeps its previous semantics. */
        INSERT INTO #CandidateAffectedPlays (PlayId)
        SELECT play.Id
        FROM dbo.Plays AS play
        INNER JOIN #CandidateAffectedForms AS affected ON affected.FormId = play.SourceFormId;
    END;

    IF NOT EXISTS (SELECT 1 FROM #CandidateAffectedPlays)
        RETURN;

    /* A previous production has only acting categories. Retire every forbidden
       row on the affected plays, including manually created/unmapped slots.
       A normal Form without a director likewise has no category 1002 candidate.
       Keep identities and past votes; lifecycle/ranking triggers retain their
       existing history rules while the flags exclude these rows from voting. */
    UPDATE candidate
    SET IsPublished = 0,
        IsActive = 0,
        IsCurrent = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE
        (
            (formRecord.previousProductionVersion = 1
             AND (candidate.AwardCategoryCode = 1002
                  OR candidate.AwardCategoryCode BETWEEN 1007 AND 1011))
            OR (candidate.AwardCategoryCode = 1002
                AND NULLIF(LTRIM(RTRIM(formRecord.Director)), N'') IS NULL)
        )
      AND (candidate.IsPublished = 1 OR candidate.IsActive = 1 OR candidate.IsCurrent = 1);

    CREATE TABLE #CandidateSource
    (
        SourceOrder int NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        Role nvarchar(200) NULL,
        RoleCode int NULL,
        ImageUrl nvarchar(255) NULL,
        Base64 nvarchar(max) NULL
    );

    /* A non-empty director on a normal production is the category 1002 slot. */
    INSERT INTO #CandidateSource
        (SourceOrder, PlayId, AwardCategoryCode, Candidate, Role, RoleCode, ImageUrl, Base64)
    SELECT 0, play.Id, 1002, LEFT(LTRIM(RTRIM(formRecord.Director)), 250),
           NULL, 0, NULL, NULL
    FROM dbo.Form AS formRecord
    INNER JOIN #CandidateAffectedForms AS affectedForm ON affectedForm.FormId = formRecord.Id
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    INNER JOIN #CandidateAffectedPlays AS affectedPlay ON affectedPlay.PlayId = play.Id
    WHERE formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.RecordType = 0
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND formRecord.previousProductionVersion = 0
      AND NULLIF(LTRIM(RTRIM(formRecord.Director)), N'') IS NOT NULL;

    /* Every category except 1001/1002 creates one role-scoped row per JSON item. */
    INSERT INTO #CandidateSource
        (SourceOrder, PlayId, AwardCategoryCode, Candidate, Role, RoleCode, ImageUrl, Base64)
    SELECT CONVERT(int, jsonItem.[key]) + 1,
           play.Id,
           category.AwardCategoryCode,
           LEFT(LTRIM(RTRIM(candidateValue.[Name])), 250),
           LEFT(COALESCE
           (
               NULLIF(LTRIM(RTRIM(candidateValue.[Role])), N''),
               NULLIF(LTRIM(RTRIM(candidateValue.[Name])), N'')
           ), 200),
           NULL,
           LEFT(NULLIF(LTRIM(RTRIM(candidateValue.ImageUrl)), N''), 255),
           NULLIF(LTRIM(RTRIM(candidateValue.Base64)), N'')
    FROM dbo.Form AS formRecord
    INNER JOIN #CandidateAffectedForms AS affectedForm ON affectedForm.FormId = formRecord.Id
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    INNER JOIN #CandidateAffectedPlays AS affectedPlay ON affectedPlay.PlayId = play.Id
    CROSS APPLY
    (
        VALUES
            (1003, formRecord.LeadActress),
            (1004, formRecord.LeadActor),
            (1005, formRecord.SupportActress),
            (1006, formRecord.SupportActor),
            (1007, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.StageDesign END),
            (1008, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.ClothesDesign END),
            (1009, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.StageMusic END),
            (1010, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.LightDesign END),
            (1011, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.Choreography END)
    ) AS category(AwardCategoryCode, CandidateJson)
    CROSS APPLY OPENJSON
    (
        CASE
            WHEN ISJSON(category.CandidateJson) <> 1 THEN N'[]'
            WHEN LEFT(LTRIM(category.CandidateJson), 1) = N'[' THEN category.CandidateJson
            ELSE N'[' + category.CandidateJson + N']'
        END
    ) AS jsonItem
    /* Legacy payloads can mix objects with scalar array items. Only objects
       carry named candidate fields; leave the original Form JSON untouched. */
    CROSS APPLY OPENJSON(CASE WHEN jsonItem.[type] = 5 THEN jsonItem.value ELSE N'{}' END)
    WITH
    (
        [Name] nvarchar(250) N'$.Name',
        [Role] nvarchar(200) N'$.Role',
        ImageUrl nvarchar(255) N'$.ImageUrl',
        /* JSON_VALUE silently returns NULL above 4000 characters. Candidate
           photos are intentionally read as nvarchar(max) instead. */
        Base64 nvarchar(max) N'$.Base64'
    ) AS candidateValue
    WHERE formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.RecordType = 0
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND NULLIF(LTRIM(RTRIM(candidateValue.[Name])), N'') IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #CandidateSource
        WHERE AwardCategoryCode BETWEEN 1003 AND 1011
          AND NULLIF(LTRIM(RTRIM(Role)), N'') IS NULL
    )
        THROW 52410, N'Çok adaylı kategorilerde Role alanı zorunludur.', 1;

    /* Repair legacy rows that point to the same Form array slot. Keep the most
       relevant row on the slot; release later rows so the remaining-source
       backfill below can map them to slot 2, 3, ... without deleting history. */
    ;WITH RankedMappedSlots AS
    (
        SELECT candidate.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode,
                                candidate.SourceFormCandidateOrder
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC,
                            candidate.Id
               ) AS SlotOccurrence
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
        WHERE candidate.SourceFormCandidateOrder IS NOT NULL
          AND candidate.AwardCategoryCode BETWEEN 1002 AND 1011
    )
    UPDATE candidate
    SET SourceFormCandidateOrder = NULL,
        IsCurrent = 0,
        IsActive = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN RankedMappedSlots AS mappedSlot ON mappedSlot.Id = candidate.Id
    WHERE mappedSlot.SlotOccurrence > 1;

    /* SourceOrder is the stable Form slot identity. Candidate and Role are
       editable descriptions; duplicate role names are valid distinct slots. */
    ;WITH SourceMatches AS
    (
        SELECT source.*,
               ROW_NUMBER() OVER
               (
                   PARTITION BY source.PlayId, source.AwardCategoryCode,
                                LOWER(LTRIM(RTRIM(source.Candidate))),
                                LOWER(LTRIM(RTRIM(COALESCE(source.Role, N''))))
                   ORDER BY source.SourceOrder
               ) AS MatchOrder
        FROM #CandidateSource AS source
    ),
    ExistingMatches AS
    (
        SELECT candidate.Id, candidate.PlayId, candidate.AwardCategoryCode,
               candidate.Candidate, candidate.Role,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode,
                                LOWER(LTRIM(RTRIM(candidate.Candidate))),
                                LOWER(LTRIM(RTRIM(COALESCE(candidate.Role, N''))))
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            candidate.RoleCode, candidate.Id
               ) AS MatchOrder
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
        WHERE candidate.SourceFormCandidateOrder IS NULL
          AND candidate.CreatedBy IS NULL
          AND candidate.AwardCategoryCode BETWEEN 1002 AND 1011
    )
    UPDATE candidate
    SET SourceFormCandidateOrder = source.SourceOrder,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN ExistingMatches AS existing ON existing.Id = candidate.Id
    INNER JOIN SourceMatches AS source
        ON source.PlayId = existing.PlayId
       AND source.AwardCategoryCode = existing.AwardCategoryCode
       AND LOWER(LTRIM(RTRIM(source.Candidate))) = LOWER(LTRIM(RTRIM(existing.Candidate)))
       AND LOWER(LTRIM(RTRIM(COALESCE(source.Role, N'')))) =
           LOWER(LTRIM(RTRIM(COALESCE(existing.Role, N''))))
       AND source.MatchOrder = existing.MatchOrder
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories AS mapped
        WHERE mapped.PlayId = source.PlayId
          AND mapped.AwardCategoryCode = source.AwardCategoryCode
          AND mapped.SourceFormCandidateOrder = source.SourceOrder
    );

    /* Backfill old procedure-created rows which predate source-slot tracking. */
    ;WITH RemainingSources AS
    (
        SELECT source.*,
               ROW_NUMBER() OVER
               (
                   PARTITION BY source.PlayId, source.AwardCategoryCode
                   ORDER BY source.SourceOrder
               ) AS SlotOrder
        FROM #CandidateSource AS source
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.PlayAwardCategories AS mapped
            WHERE mapped.PlayId = source.PlayId
              AND mapped.AwardCategoryCode = source.AwardCategoryCode
              AND mapped.SourceFormCandidateOrder = source.SourceOrder
        )
    ),
    RemainingCandidates AS
    (
        SELECT candidate.Id, candidate.PlayId, candidate.AwardCategoryCode,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            candidate.RoleCode, candidate.Id
               ) AS SlotOrder
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
        WHERE candidate.SourceFormCandidateOrder IS NULL
          AND candidate.CreatedBy IS NULL
          AND candidate.AwardCategoryCode BETWEEN 1002 AND 1011
    )
    UPDATE candidate
    SET SourceFormCandidateOrder = source.SourceOrder,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN RemainingCandidates AS existing ON existing.Id = candidate.Id
    INNER JOIN RemainingSources AS source
        ON source.PlayId = existing.PlayId
       AND source.AwardCategoryCode = existing.AwardCategoryCode
       AND source.SlotOrder = existing.SlotOrder;

    UPDATE source
    SET RoleCode = existing.RoleCode
    FROM #CandidateSource AS source
    CROSS APPLY
    (
        SELECT TOP (1) candidate.RoleCode
        FROM dbo.PlayAwardCategories AS candidate
        WHERE candidate.PlayId = source.PlayId
          AND candidate.AwardCategoryCode = source.AwardCategoryCode
          AND candidate.SourceFormCandidateOrder = source.SourceOrder
        ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                 COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC, candidate.Id
    ) AS existing
    WHERE source.AwardCategoryCode <> 1002;

    /* Only an exact (play, category, RoleCode, candidate) repetition is
       forbidden. Different candidates may intentionally share a RoleCode.
       Repair only legacy slots that would become an exact duplicate. */
    ;WITH DuplicateSourceRoles AS
    (
        SELECT source.PlayId, source.AwardCategoryCode, source.SourceOrder,
               ROW_NUMBER() OVER
               (
                   PARTITION BY source.PlayId, source.AwardCategoryCode, source.RoleCode,
                                LOWER(LTRIM(RTRIM(source.Candidate)))
                   ORDER BY source.SourceOrder
               ) AS RoleOccurrence
        FROM #CandidateSource AS source
        WHERE source.AwardCategoryCode BETWEEN 1003 AND 1011
          AND source.RoleCode > 0
    )
    UPDATE source
    SET RoleCode = NULL
    FROM #CandidateSource AS source
    INNER JOIN DuplicateSourceRoles AS duplicateRole
        ON duplicateRole.PlayId = source.PlayId
       AND duplicateRole.AwardCategoryCode = source.AwardCategoryCode
       AND duplicateRole.SourceOrder = source.SourceOrder
    WHERE duplicateRole.RoleOccurrence > 1;

    ;WITH MissingRoles AS
    (
        SELECT source.PlayId, source.AwardCategoryCode, source.SourceOrder,
               COALESCE
               (
                   (SELECT MAX(candidate.RoleCode)
                    FROM dbo.PlayAwardCategories AS candidate
                    WHERE candidate.PlayId = source.PlayId AND candidate.RoleCode > 0),
                   0
               ) + ROW_NUMBER() OVER
                   (PARTITION BY source.PlayId ORDER BY source.AwardCategoryCode, source.SourceOrder) AS NewRoleCode
        FROM #CandidateSource AS source
        WHERE source.Role IS NOT NULL AND source.RoleCode IS NULL
    )
    UPDATE source
    SET RoleCode = missing.NewRoleCode
    FROM #CandidateSource AS source
    INNER JOIN MissingRoles AS missing
        ON missing.PlayId = source.PlayId
       AND missing.AwardCategoryCode = source.AwardCategoryCode
       AND missing.SourceOrder = source.SourceOrder;

    /* Form changes update only the mapped slot. Existing published/current
       candidates retain their manually selected status. A retired source slot
       becoming current again starts active, just like a newly created slot. */
    ;WITH CurrentTargets AS
    (
        SELECT candidate.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode,
                                candidate.SourceFormCandidateOrder
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC,
                            candidate.Id
               ) AS TargetOrder
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
        WHERE candidate.SourceFormCandidateOrder IS NOT NULL
    )
    UPDATE candidate
    SET Candidate = source.Candidate,
        Role = source.Role,
        RoleCode = source.RoleCode,
        IsPublished = 1,
        IsActive = CASE
            WHEN candidate.IsPublished = 1 AND candidate.IsCurrent = 1
                THEN candidate.IsActive
            ELSE 1 END,
        IsCurrent = 1,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN CurrentTargets AS target
        ON target.Id = candidate.Id AND target.TargetOrder = 1
    INNER JOIN #CandidateSource AS source
        ON source.PlayId = candidate.PlayId
       AND source.AwardCategoryCode = candidate.AwardCategoryCode
       AND source.SourceOrder = candidate.SourceFormCandidateOrder
    /* Avoid audit/ranking work for unchanged slots. Binary text comparisons
       preserve case and trailing-space edits, and EXCEPT treats NULLs equally.
       Published/current candidates retain their manual IsActive value above. */
    WHERE EXISTS
    (
        SELECT CONVERT(varbinary(max), candidate.Candidate),
               CONVERT(varbinary(max), candidate.Role),
               candidate.RoleCode, candidate.IsPublished, candidate.IsCurrent
        EXCEPT
        SELECT CONVERT(varbinary(max), source.Candidate),
               CONVERT(varbinary(max), source.Role),
               source.RoleCode, CONVERT(bit, 1), CONVERT(bit, 1)
    );

    /* A non-empty valid Base64 value replaces the mapped candidate photo.
       Empty/invalid legacy values preserve the existing image. */
    CREATE TABLE #UpdatedCandidateImages
    (
        CandidateId uniqueidentifier NOT NULL PRIMARY KEY,
        OldImageId uniqueidentifier NULL,
        NewImageId uniqueidentifier NOT NULL,
        ImageUrl nvarchar(255) NULL,
        CleanBase64 nvarchar(max) NOT NULL,
        ImageData varbinary(max) NULL,
        ContentType nvarchar(100) NULL
    );

    INSERT INTO #UpdatedCandidateImages
        (CandidateId, OldImageId, NewImageId, ImageUrl, CleanBase64)
    SELECT candidate.Id, candidate.PhotoImageId, NEWID(), source.ImageUrl,
           CASE
               WHEN source.Base64 LIKE N'data:%;base64,%'
                   THEN REPLACE(REPLACE(REPLACE(SUBSTRING(source.Base64,
                        CHARINDEX(N',', source.Base64) + 1, LEN(source.Base64)), CHAR(13), N''), CHAR(10), N''), N' ', N'')
               ELSE REPLACE(REPLACE(REPLACE(source.Base64, CHAR(13), N''), CHAR(10), N''), N' ', N'')
           END
    FROM #CandidateSource AS source
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.PlayId = source.PlayId
       AND candidate.AwardCategoryCode = source.AwardCategoryCode
       AND candidate.SourceFormCandidateOrder = source.SourceOrder
       AND candidate.IsCurrent = 1
    WHERE source.Base64 IS NOT NULL;

    UPDATE image
    SET ImageData = CAST(N'' AS xml).value(
            'xs:base64Binary(sql:column("image.CleanBase64"))', 'varbinary(max)')
    FROM #UpdatedCandidateImages AS image
    WHERE LEN(image.CleanBase64) % 4 = 0
      AND image.CleanBase64 COLLATE Latin1_General_100_BIN2 NOT LIKE N'%[^A-Za-z0-9+/=]%';

    UPDATE image
    SET ContentType = CASE
        WHEN SUBSTRING(image.ImageData, 1, 3) = 0xFFD8FF THEN N'image/jpeg'
        WHEN SUBSTRING(image.ImageData, 1, 8) = 0x89504E470D0A1A0A THEN N'image/png'
        WHEN SUBSTRING(image.ImageData, 1, 4) = 0x52494646
         AND SUBSTRING(image.ImageData, 9, 4) = 0x57454250 THEN N'image/webp'
        ELSE NULL END
    FROM #UpdatedCandidateImages AS image
    WHERE image.ImageData IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #UpdatedCandidateImages
        WHERE DATALENGTH(ImageData) > @MaximumImageBytes
    )
        THROW 52431, N'Görsel boyutu 150 MB''dan büyük olamaz.', 1;

    INSERT INTO dbo.Images
        (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
    SELECT image.NewImageId,
           /* Legacy ImageUrl may have an unrelated extension or URL suffix.
              Keep the Form source; name the projected image for its bytes. */
           COALESCE(CASE
                        WHEN image.ContentType = N'image/jpeg'
                         AND (LOWER(image.ImageUrl) LIKE N'%.jpg' OR LOWER(image.ImageUrl) LIKE N'%.jpeg')
                            THEN image.ImageUrl
                        WHEN image.ContentType = N'image/png' AND LOWER(image.ImageUrl) LIKE N'%.png'
                            THEN image.ImageUrl
                        WHEN image.ContentType = N'image/webp' AND LOWER(image.ImageUrl) LIKE N'%.webp'
                            THEN image.ImageUrl
                    END,
                    CONCAT(N'form-candidate-', CONVERT(nvarchar(36), image.CandidateId),
                           CASE image.ContentType WHEN N'image/png' THEN N'.png'
                                WHEN N'image/webp' THEN N'.webp' ELSE N'.jpg' END)),
           image.ContentType, image.ImageData, @Now, image.CandidateId, 1
    FROM #UpdatedCandidateImages AS image
    LEFT JOIN dbo.Images AS currentImage ON currentImage.Id = image.OldImageId
    WHERE image.ContentType IS NOT NULL
      AND DATALENGTH(image.ImageData) BETWEEN 1 AND @MaximumImageBytes
      AND
      (
          currentImage.Id IS NULL
          OR currentImage.IsPublished = 0
          OR currentImage.ContentType <> image.ContentType
          OR DATALENGTH(currentImage.ImageData) <> DATALENGTH(image.ImageData)
          OR currentImage.ImageData <> image.ImageData
      );

    UPDATE candidate
    SET PhotoImageId = image.NewImageId,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN #UpdatedCandidateImages AS image ON image.CandidateId = candidate.Id
    INNER JOIN dbo.Images AS newImage ON newImage.Id = image.NewImageId;

    UPDATE oldImage
    SET IsPublished = 0,
        UpdatedAt = @Now
    FROM dbo.Images AS oldImage
    INNER JOIN #UpdatedCandidateImages AS replacement
        ON replacement.OldImageId = oldImage.Id
    INNER JOIN dbo.Images AS newImage ON newImage.Id = replacement.NewImageId
    WHERE oldImage.IsPublished = 1
      /* Reference checks intentionally span all plays: a photo shared with an
         unscoped published candidate must remain published. */
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.PlayAwardCategories AS candidate
          WHERE candidate.PhotoImageId = oldImage.Id
            AND candidate.IsPublished = 1
      );

    UPDATE candidate
    SET IsPublished = 0,
        IsActive = 0,
        IsCurrent = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE candidate.SourceFormCandidateOrder IS NOT NULL
      AND formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND NOT EXISTS
      (
          SELECT 1 FROM #CandidateSource AS source
          WHERE source.PlayId = candidate.PlayId
            AND source.AwardCategoryCode = candidate.AwardCategoryCode
            AND source.SourceOrder = candidate.SourceFormCandidateOrder
      )
      AND (candidate.IsPublished = 1 OR candidate.IsActive = 1 OR candidate.IsCurrent = 1);

    CREATE TABLE #NewCandidates
    (
        CandidateId uniqueidentifier NOT NULL PRIMARY KEY,
        ImageId uniqueidentifier NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        Role nvarchar(200) NULL,
        RoleCode int NOT NULL,
        SourceOrder int NOT NULL,
        ImageUrl nvarchar(255) NULL,
        CleanBase64 nvarchar(max) NULL,
        ImageData varbinary(max) NULL,
        ContentType nvarchar(100) NULL
    );

    INSERT INTO #NewCandidates
        (CandidateId, ImageId, PlayId, AwardCategoryCode, Candidate, Role,
         RoleCode, SourceOrder, ImageUrl, CleanBase64)
    SELECT NEWID(), CASE WHEN source.Base64 IS NULL THEN NULL ELSE NEWID() END,
           source.PlayId, source.AwardCategoryCode, source.Candidate, source.Role,
           COALESCE(source.RoleCode, 0), source.SourceOrder, source.ImageUrl,
           CASE
               WHEN source.Base64 LIKE N'data:%;base64,%'
                   THEN REPLACE(REPLACE(REPLACE(SUBSTRING(source.Base64,
                        CHARINDEX(N',', source.Base64) + 1, LEN(source.Base64)), CHAR(13), N''), CHAR(10), N''), N' ', N'')
               ELSE REPLACE(REPLACE(REPLACE(source.Base64, CHAR(13), N''), CHAR(10), N''), N' ', N'')
           END
    FROM #CandidateSource AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.PlayAwardCategories AS existing
        WHERE existing.PlayId = source.PlayId
          AND existing.AwardCategoryCode = source.AwardCategoryCode
          AND existing.RoleCode = COALESCE(source.RoleCode, 0)
          AND LOWER(LTRIM(RTRIM(existing.Candidate))) =
              LOWER(LTRIM(RTRIM(source.Candidate)))
          AND existing.IsPublished = 1
    );

    /* Legacy/test Forms can contain placeholder strings in Base64. They must not
       block candidate backfill and must never be persisted as image bytes. */
    UPDATE candidate
    SET ImageId = NULL, CleanBase64 = NULL
    FROM #NewCandidates AS candidate
    WHERE candidate.CleanBase64 IS NOT NULL
      AND
      (
          LEN(candidate.CleanBase64) % 4 <> 0
          OR candidate.CleanBase64 COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Za-z0-9+/=]%'
      );

    UPDATE candidate
    SET ImageData = CAST(N'' AS xml).value(
            'xs:base64Binary(sql:column("candidate.CleanBase64"))', 'varbinary(max)')
    FROM #NewCandidates AS candidate
    WHERE candidate.CleanBase64 IS NOT NULL;

    UPDATE candidate
    SET ContentType = CASE
        WHEN SUBSTRING(candidate.ImageData, 1, 3) = 0xFFD8FF THEN N'image/jpeg'
        WHEN SUBSTRING(candidate.ImageData, 1, 8) = 0x89504E470D0A1A0A THEN N'image/png'
        WHEN SUBSTRING(candidate.ImageData, 1, 4) = 0x52494646
         AND SUBSTRING(candidate.ImageData, 9, 4) = 0x57454250 THEN N'image/webp'
        ELSE NULL END
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageData IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #NewCandidates
        WHERE DATALENGTH(ImageData) > @MaximumImageBytes
    )
        THROW 52431, N'Görsel boyutu 150 MB''dan büyük olamaz.', 1;

    UPDATE candidate
    SET ImageId = NULL, ImageData = NULL, CleanBase64 = NULL
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageData IS NOT NULL
      AND
      (
          DATALENGTH(candidate.ImageData) = 0
          OR DATALENGTH(candidate.ImageData) > @MaximumImageBytes
          OR candidate.ContentType IS NULL
      );

    INSERT INTO dbo.Images
        (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
    SELECT candidate.ImageId,
           COALESCE(CASE
                        WHEN candidate.ContentType = N'image/jpeg'
                         AND (LOWER(candidate.ImageUrl) LIKE N'%.jpg' OR LOWER(candidate.ImageUrl) LIKE N'%.jpeg')
                            THEN candidate.ImageUrl
                        WHEN candidate.ContentType = N'image/png' AND LOWER(candidate.ImageUrl) LIKE N'%.png'
                            THEN candidate.ImageUrl
                        WHEN candidate.ContentType = N'image/webp' AND LOWER(candidate.ImageUrl) LIKE N'%.webp'
                            THEN candidate.ImageUrl
                    END,
                    CONCAT(N'form-candidate-', CONVERT(nvarchar(36), candidate.CandidateId),
                           CASE candidate.ContentType WHEN N'image/png' THEN N'.png'
                                WHEN N'image/webp' THEN N'.webp' ELSE N'.jpg' END)),
           candidate.ContentType, candidate.ImageData, @Now, candidate.CandidateId, 1
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageId IS NOT NULL;

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
        IsPublished, IsActive, Candidate, AwardCategoryCode,
        IsCurrent, Role, RoleCode, PhotoImageId, SourceFormCandidateOrder
    )
    SELECT candidate.CandidateId, candidate.PlayId, @Now, NULL, NULL, NULL,
           1, 1, candidate.Candidate, candidate.AwardCategoryCode,
           1, candidate.Role, candidate.RoleCode, candidate.ImageId, candidate.SourceOrder
    FROM #NewCandidates AS candidate;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_SynchronizeFormsToPlays]
    @FormIdsJson nvarchar(max) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    /* Trigger calls carry the complete statement's Form IDs. NULL is reserved
       for the existing explicit full-repair/migration entry point. */
    CREATE TABLE #SyncForms (FormId uniqueidentifier NOT NULL PRIMARY KEY);

    IF @FormIdsJson IS NULL
        INSERT INTO #SyncForms (FormId) SELECT Id FROM dbo.Form;
    ELSE
    BEGIN
        IF ISJSON(@FormIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@FormIdsJson,
               NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ')), 1) <> N'['
            THROW 52433, N'Form senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@FormIdsJson) AS scopeItem
            WHERE scopeItem.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier,
                   JSON_VALUE(CASE WHEN scopeItem.[type] = 5 THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52433, N'Form senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        INSERT INTO #SyncForms (FormId)
        SELECT DISTINCT CONVERT(uniqueidentifier, JSON_VALUE(scopeItem.[value], N'$.Id'))
        FROM OPENJSON(@FormIdsJson) AS scopeItem;
    END;

    IF @FormIdsJson IS NOT NULL AND NOT EXISTS (SELECT 1 FROM #SyncForms)
        RETURN;

    DECLARE @LockResult int;
    EXEC @LockResult = sys.sp_getapplock
        @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
        @LockMode = N'Exclusive',
        @LockOwner = N'Session',
        @LockTimeout = 30000;

    IF @LockResult < 0
        THROW 52403, N'Form senkronizasyon kilidi alınamadı.', 1;

    EXEC sys.sp_set_session_context
        @key = N'FormLifecycleSyncInProgress', @value = 1;

    BEGIN TRY
        DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

        /* Search only affected Forms for legacy matches. Ambiguity must still
           be checked against ALL Forms: a scoped call must not steal a legacy
           play that also matches an unrelated (even inactive) Form. */
        ;WITH ExactMatches AS
        (
            SELECT
                formRecord.Id AS FormId,
                play.Id AS PlayId,
                COUNT_BIG(*) OVER (PARTITION BY formRecord.Id) AS PlayMatchCount
            FROM dbo.Form AS formRecord
            INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
            INNER JOIN dbo.Plays AS play
                ON play.RecordType = 0
               AND play.SourceFormId IS NULL
               AND LOWER(LTRIM(RTRIM(play.PlayName))) =
                   LOWER(LTRIM(RTRIM(formRecord.RepertoireName)))
               AND LOWER(LTRIM(RTRIM(play.TheaterName))) =
                   LOWER(LTRIM(RTRIM(formRecord.TheatreName)))
        )
        UPDATE play
        SET SourceFormId = exact.FormId,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN ExactMatches AS exact ON exact.PlayId = play.Id
        WHERE exact.PlayMatchCount = 1
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Form AS otherForm
              WHERE otherForm.Id <> exact.FormId
                AND LOWER(LTRIM(RTRIM(otherForm.RepertoireName))) =
                    LOWER(LTRIM(RTRIM(play.PlayName)))
                AND LOWER(LTRIM(RTRIM(otherForm.TheatreName))) =
                    LOWER(LTRIM(RTRIM(play.TheaterName)))
          );

        INSERT INTO dbo.Plays
        (
            Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt,
            UpdatedBy, IsPublished, Slug, TheaterName, Phone,
            ContactPersonName, ContactPersonPhone, Address, Email,
            JuriOylamaStatus, KunyeGirisStatus, RecordType,
            SourceFormId, IsActive
        )
        SELECT
            NEWID(),
            formRecord.RepertoireName,
            1,
            formRecord.CreatedDate,
            NULL,
            formRecord.UpdatedDate,
            NULL,
            1,
            LOWER
            (
                CONCAT
                (
                    'kunye-',
                    REPLACE(formRecord.ApplicationNumber, ' ', '-'),
                    '-',
                    LEFT(CONVERT(varchar(36), formRecord.Id), 8)
                )
            ),
            formRecord.TheatreName,
            formRecord.Phone,
            COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName),
            COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone),
            NULL,
            formRecord.Email,
            0,
            0,
            0,
            formRecord.Id,
            1
        FROM dbo.Form AS formRecord
        INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
        WHERE formRecord.IsPublished = 1
          AND formRecord.IsActive = 1
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Plays AS play
              WHERE play.SourceFormId = formRecord.Id
          );

        UPDATE play
        SET
            PlayName = formRecord.RepertoireName,
            CreatedAt = formRecord.CreatedDate,
            UpdatedAt = COALESCE(formRecord.UpdatedDate, @Now),
            TheaterName = formRecord.TheatreName,
            Phone = formRecord.Phone,
            ContactPersonName =
                COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName),
            ContactPersonPhone =
                COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone),
            Email = formRecord.Email
        FROM dbo.Plays AS play
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
        WHERE play.RecordType = 0
          AND EXISTS
          (
              SELECT CONVERT(varbinary(max), play.PlayName), play.CreatedAt,
                  CONVERT(varbinary(max), play.TheaterName),
                  CONVERT(varbinary(max), play.Phone),
                  CONVERT(varbinary(max), play.ContactPersonName),
                  CONVERT(varbinary(max), play.ContactPersonPhone),
                  CONVERT(varbinary(max), play.Email)
              EXCEPT
              SELECT CONVERT(varbinary(max), formRecord.RepertoireName), formRecord.CreatedDate,
                  CONVERT(varbinary(max), formRecord.TheatreName),
                  CONVERT(varbinary(max), formRecord.Phone),
                  CONVERT(varbinary(max), COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName)),
                  CONVERT(varbinary(max), COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone)),
                  CONVERT(varbinary(max), formRecord.Email)
          );

        EXEC dbo.usp_SynchronizeFormCandidates @FormIdsJson = @FormIdsJson;

        CREATE TABLE #DeactivateForms
        (
            FormId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL
        );

        INSERT INTO #DeactivateForms (FormId, PlayId)
        SELECT formRecord.Id, play.Id
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
        WHERE play.IsActive = 1
          AND (formRecord.IsPublished = 0 OR formRecord.IsActive = 0);

        INSERT INTO dbo.FormLifecycleStates
        (
            Id, FormId, EntityName, EntityId, WasPublished, WasActive,
            WasJuriOylamaStatus, WasKunyeGirisStatus, WasStatusCode,
            DeactivatedAt, RestoredAt, IsPublished
        )
        SELECT
            NEWID(), affected.FormId, N'Play', play.Id,
            play.IsPublished, play.IsActive,
            play.JuriOylamaStatus, play.KunyeGirisStatus, play.StatusCode,
            @Now, NULL, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.Plays AS play ON play.Id = affected.PlayId
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.FormLifecycleStates AS state
            WHERE state.FormId = affected.FormId
              AND state.EntityName = N'Play'
              AND state.EntityId = play.Id
              AND state.IsPublished = 1
        );

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished, WasActive,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'PlayAwardCategory', candidate.Id,
               candidate.IsPublished, candidate.IsActive, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.PlayId = affected.PlayId
        WHERE candidate.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished, WasActive,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryVote', vote.Id,
               vote.IsPublished, vote.IsActive, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.PlayId = affected.PlayId
        INNER JOIN dbo.JuryVotes AS vote
            ON vote.PlayAwardCategoryId = candidate.Id
        WHERE vote.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryGameTicketFee', ticket.Id,
               ticket.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.JuryGameTicketFees AS ticket
            ON ticket.PlayId = affected.PlayId
        WHERE ticket.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryAssignedPlay', assignment.Id,
               assignment.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.JuryAssignedPlays AS assignment
            ON assignment.PlayId = affected.PlayId
        WHERE assignment.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'Blacklist', blacklist.Id,
               blacklist.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.Blacklist AS blacklist
            ON blacklist.PlayId = affected.PlayId
        WHERE blacklist.IsPublished = 1;

        UPDATE vote
        SET IsPublished = 0, IsActive = 0, UpdatedAt = @Now
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = candidate.PlayId
        WHERE vote.IsPublished = 1 OR vote.IsActive = 1;

        UPDATE candidate
        SET IsPublished = 0, IsActive = 0, UpdatedAt = @Now
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = candidate.PlayId
        WHERE candidate.IsPublished = 1 OR candidate.IsActive = 1;

        UPDATE ticket
        SET IsPublished = 0, UpdatedAt = @Now
        FROM dbo.JuryGameTicketFees AS ticket
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = ticket.PlayId
        WHERE ticket.IsPublished = 1;

        UPDATE assignment
        SET IsPublished = 0, UpdatedAt = @Now
        FROM dbo.JuryAssignedPlays AS assignment
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = assignment.PlayId
        WHERE assignment.IsPublished = 1;

        UPDATE blacklist
        SET IsPublished = 0
        FROM dbo.Blacklist AS blacklist
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = blacklist.PlayId
        WHERE blacklist.IsPublished = 1;

        UPDATE play
        SET IsActive = 0,
            JuriOylamaStatus = 0,
            KunyeGirisStatus = 0,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN #DeactivateForms AS affected ON affected.PlayId = play.Id;

        CREATE TABLE #ReactivateForms
        (
            FormId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL
        );

        INSERT INTO #ReactivateForms (FormId, PlayId)
        SELECT formRecord.Id, play.Id
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
        WHERE formRecord.IsPublished = 1
          AND formRecord.IsActive = 1
          AND play.IsActive = 0
          AND EXISTS
          (
              SELECT 1 FROM dbo.FormLifecycleStates AS state
              WHERE state.FormId = formRecord.Id
                AND state.EntityName = N'Play'
                AND state.EntityId = play.Id
                AND state.IsPublished = 1
          );

        UPDATE play
        SET IsActive = 1,
            JuriOylamaStatus = state.WasJuriOylamaStatus,
            KunyeGirisStatus = state.WasKunyeGirisStatus,
            StatusCode = state.WasStatusCode,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN #ReactivateForms AS affected ON affected.PlayId = play.Id
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.FormId = affected.FormId
           AND state.EntityName = N'Play'
           AND state.EntityId = play.Id
           AND state.IsPublished = 1;

        UPDATE candidate
        SET IsPublished = state.WasPublished,
            IsActive = state.WasActive,
            UpdatedAt = @Now
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'PlayAwardCategory'
           AND state.EntityId = candidate.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = affected.FormId
        WHERE NOT
        (
            (formRecord.previousProductionVersion = 1
             AND (candidate.AwardCategoryCode = 1002
                  OR candidate.AwardCategoryCode BETWEEN 1007 AND 1011))
            OR (candidate.AwardCategoryCode = 1002
                AND NULLIF(LTRIM(RTRIM(formRecord.Director)), N'') IS NULL)
        );

        UPDATE vote
        SET IsPublished = state.WasPublished,
            IsActive = state.WasActive,
            UpdatedAt = @Now
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryVote'
           AND state.EntityId = vote.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE ticket
        SET IsPublished = state.WasPublished,
            UpdatedAt = @Now
        FROM dbo.JuryGameTicketFees AS ticket
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryGameTicketFee'
           AND state.EntityId = ticket.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE assignment
        SET IsPublished = state.WasPublished,
            UpdatedAt = @Now
        FROM dbo.JuryAssignedPlays AS assignment
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryAssignedPlay'
           AND state.EntityId = assignment.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE blacklist
        SET IsPublished = state.WasPublished
        FROM dbo.Blacklist AS blacklist
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'Blacklist'
           AND state.EntityId = blacklist.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE state
        SET IsPublished = 0, RestoredAt = @Now
        FROM dbo.FormLifecycleStates AS state
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId
        WHERE state.IsPublished = 1;

        EXEC sys.sp_set_session_context
            @key = N'FormLifecycleSyncInProgress', @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
            @LockOwner = N'Session';
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'FormLifecycleSyncInProgress', @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
            @LockOwner = N'Session';
        THROW;
    END CATCH;
END;
GO

/*
    Keeps the editable admin projection and its source Form in sync.  The Form
    remains the import contract, while edits made through Plays or
    PlayAwardCategories are written back so a later Form synchronization cannot
    restore stale names or photos.
*/
CREATE OR ALTER PROCEDURE dbo.usp_SynchronizePlayDataToForms
    @PlayId uniqueidentifier = NULL,
    @PlayIdsJson nvarchar(max) = NULL,
    @SyncCandidateData bit = 1
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    /* Preserve the scalar and no-argument maintenance APIs. Trigger callers
       submit one set of affected Plays instead of invoking this proc per row. */
    CREATE TABLE #ReverseSyncPlays (PlayId uniqueidentifier NOT NULL PRIMARY KEY);
    IF @PlayIdsJson IS NULL
    BEGIN
        INSERT INTO #ReverseSyncPlays (PlayId)
        SELECT Id FROM dbo.Plays
        WHERE SourceFormId IS NOT NULL AND (@PlayId IS NULL OR Id = @PlayId);
    END
    ELSE
    BEGIN
        IF ISJSON(@PlayIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@PlayIdsJson,
               NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ')), 1) <> N'['
            THROW 52433, N'Play senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@PlayIdsJson) AS scopeItem
            WHERE scopeItem.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier, JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52433, N'Play senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        INSERT INTO #ReverseSyncPlays (PlayId)
        SELECT DISTINCT play.Id
        FROM OPENJSON(@PlayIdsJson) AS scopeItem
        INNER JOIN dbo.Plays AS play
            ON play.Id = CONVERT(uniqueidentifier, JSON_VALUE(scopeItem.[value], N'$.Id'))
        WHERE play.SourceFormId IS NOT NULL AND (@PlayId IS NULL OR play.Id = @PlayId);
    END;

    IF NOT EXISTS (SELECT 1 FROM #ReverseSyncPlays)
        RETURN;

    SET @SyncCandidateData = COALESCE(@SyncCandidateData, 1);
    EXEC sys.sp_set_session_context
        @key = N'PlayToFormSyncInProgress', @value = 1;

    BEGIN TRY
        DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

        /* A Play metadata edit must leave every imported JSON byte intact and
           must not read candidate image blobs or repair unrelated source slots. */
        IF @SyncCandidateData = 0
        BEGIN
            UPDATE formRecord
            SET RepertoireName = play.PlayName,
                TheatreName = play.TheaterName,
                Phone = COALESCE(play.Phone, formRecord.Phone),
                ContactName = play.ContactPersonName,
                ContactPhone = play.ContactPersonPhone,
                Email = COALESCE(play.Email, formRecord.Email),
                IsActive = play.IsActive,
                IsPublished = play.IsPublished,
                UpdatedDate = @Now
            FROM dbo.Form AS formRecord
            INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
            INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
            WHERE EXISTS
            (
                SELECT CONVERT(varbinary(max), play.PlayName),
                       CONVERT(varbinary(max), play.TheaterName),
                       CONVERT(varbinary(max), COALESCE(play.Phone, formRecord.Phone)),
                       CONVERT(varbinary(max), play.ContactPersonName),
                       CONVERT(varbinary(max), play.ContactPersonPhone),
                       CONVERT(varbinary(max), COALESCE(play.Email, formRecord.Email)),
                       play.IsActive, play.IsPublished
                EXCEPT
                SELECT CONVERT(varbinary(max), formRecord.RepertoireName),
                       CONVERT(varbinary(max), formRecord.TheatreName),
                       CONVERT(varbinary(max), formRecord.Phone),
                       CONVERT(varbinary(max), formRecord.ContactName),
                       CONVERT(varbinary(max), formRecord.ContactPhone),
                       CONVERT(varbinary(max), formRecord.Email),
                       formRecord.IsActive, formRecord.IsPublished
            );
        END
        ELSE
        BEGIN
        /* Admin-created candidates also need a stable Form array slot. */
        ;WITH MissingSlots AS
        (
            SELECT
                candidate.Id,
                COALESCE
                (
                    (
                        SELECT MAX(existing.SourceFormCandidateOrder)
                        FROM dbo.PlayAwardCategories AS existing
                        WHERE existing.PlayId = candidate.PlayId
                          AND existing.AwardCategoryCode = candidate.AwardCategoryCode
                    ),
                    0
                ) +
                ROW_NUMBER() OVER
                (
                    PARTITION BY candidate.PlayId, candidate.AwardCategoryCode
                    ORDER BY candidate.CreatedAt, candidate.RoleCode, candidate.Id
                ) AS NewSourceOrder
            FROM dbo.PlayAwardCategories AS candidate
            INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
            INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
            INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
            WHERE play.SourceFormId IS NOT NULL
              AND candidate.AwardCategoryCode BETWEEN 1003 AND 1011
              AND (formRecord.previousProductionVersion = 0
                   OR candidate.AwardCategoryCode BETWEEN 1003 AND 1006)
              AND candidate.SourceFormCandidateOrder IS NULL
              AND candidate.IsPublished = 1
              AND candidate.IsCurrent = 1
        )
        UPDATE candidate
        SET SourceFormCandidateOrder = missing.NewSourceOrder,
            UpdatedAt = COALESCE(candidate.UpdatedAt, @Now)
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN MissingSlots AS missing ON missing.Id = candidate.Id;

        CREATE TABLE #CandidatePayload
        (
            PlayId uniqueidentifier NOT NULL,
            AwardCategoryCode int NOT NULL,
            CandidateJson nvarchar(max) NOT NULL,
            PRIMARY KEY (PlayId, AwardCategoryCode)
        );

        INSERT INTO #CandidatePayload (PlayId, AwardCategoryCode, CandidateJson)
        SELECT play.Id,
               category.AwardCategoryCode,
               JSON_QUERY
               (
                   COALESCE
                   (
                       (
                           SELECT
                               candidate.Candidate AS [Name],
                               candidate.Role AS [Role],
                               candidateImage.FileName AS [ImageUrl],
                               /* FOR JSON serializes varbinary(max) as Base64. */
                               candidateImage.ImageData AS [Base64]
                           FROM dbo.PlayAwardCategories AS candidate
                           LEFT JOIN dbo.Images AS candidateImage
                               ON candidateImage.Id = candidate.PhotoImageId
                              AND candidateImage.IsPublished = 1
                           WHERE candidate.PlayId = play.Id
                             AND candidate.AwardCategoryCode = category.AwardCategoryCode
                             AND candidate.IsPublished = 1
                             AND candidate.IsCurrent = 1
                           ORDER BY
                               COALESCE(candidate.SourceFormCandidateOrder, 2147483647),
                               candidate.RoleCode,
                               candidate.CreatedAt,
                               candidate.Id
                           FOR JSON PATH
                       ),
                       N'[]'
                   )
               )
        FROM dbo.Plays AS play
        INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        CROSS JOIN
        (
            VALUES (1003), (1004), (1005), (1006), (1007),
                   (1008), (1009), (1010), (1011)
        ) AS category(AwardCategoryCode)
        WHERE play.SourceFormId IS NOT NULL
          AND (formRecord.previousProductionVersion = 0
               OR category.AwardCategoryCode BETWEEN 1003 AND 1006);

        UPDATE formRecord
        SET
            RepertoireName = play.PlayName,
            TheatreName = play.TheaterName,
            Phone = COALESCE(play.Phone, formRecord.Phone),
            ContactName = play.ContactPersonName,
            ContactPhone = play.ContactPersonPhone,
            Email = COALESCE(play.Email, formRecord.Email),
            Director = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL
                            ELSE COALESCE(director.Candidate, formRecord.Director) END,
            LeadActress = actress.CandidateJson,
            LeadActor = actor.CandidateJson,
            SupportActress = supportActress.CandidateJson,
            SupportActor = supportActor.CandidateJson,
            StageDesign = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageDesign.CandidateJson END,
            ClothesDesign = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE clothesDesign.CandidateJson END,
            StageMusic = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageMusic.CandidateJson END,
            LightDesign = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE lightDesign.CandidateJson END,
            Choreography = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE choreography.CandidateJson END,
            IsActive = play.IsActive,
            IsPublished = play.IsPublished,
            UpdatedDate = @Now
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
        OUTER APPLY
        (
            SELECT TOP (1) candidate.Candidate
            FROM dbo.PlayAwardCategories AS candidate
            WHERE candidate.PlayId = play.Id
              AND formRecord.previousProductionVersion = 0
              AND candidate.AwardCategoryCode = 1002
              AND candidate.IsPublished = 1
              AND candidate.IsCurrent = 1
            ORDER BY COALESCE(candidate.SourceFormCandidateOrder, 0), candidate.Id
        ) AS director
        INNER JOIN #CandidatePayload AS actress
            ON actress.PlayId = play.Id AND actress.AwardCategoryCode = 1003
        INNER JOIN #CandidatePayload AS actor
            ON actor.PlayId = play.Id AND actor.AwardCategoryCode = 1004
        INNER JOIN #CandidatePayload AS supportActress
            ON supportActress.PlayId = play.Id AND supportActress.AwardCategoryCode = 1005
        INNER JOIN #CandidatePayload AS supportActor
            ON supportActor.PlayId = play.Id AND supportActor.AwardCategoryCode = 1006
        LEFT JOIN #CandidatePayload AS stageDesign
            ON stageDesign.PlayId = play.Id AND stageDesign.AwardCategoryCode = 1007
        LEFT JOIN #CandidatePayload AS clothesDesign
            ON clothesDesign.PlayId = play.Id AND clothesDesign.AwardCategoryCode = 1008
        LEFT JOIN #CandidatePayload AS stageMusic
            ON stageMusic.PlayId = play.Id AND stageMusic.AwardCategoryCode = 1009
        LEFT JOIN #CandidatePayload AS lightDesign
            ON lightDesign.PlayId = play.Id AND lightDesign.AwardCategoryCode = 1010
        LEFT JOIN #CandidatePayload AS choreography
            ON choreography.PlayId = play.Id AND choreography.AwardCategoryCode = 1011
        WHERE EXISTS
        (
            SELECT CONVERT(varbinary(max), play.PlayName),
                   CONVERT(varbinary(max), play.TheaterName),
                   CONVERT(varbinary(max), COALESCE(play.Phone, formRecord.Phone)),
                   CONVERT(varbinary(max), play.ContactPersonName),
                   CONVERT(varbinary(max), play.ContactPersonPhone),
                   CONVERT(varbinary(max), COALESCE(play.Email, formRecord.Email)),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL
                       ELSE COALESCE(director.Candidate, formRecord.Director) END),
                   CONVERT(varbinary(max), actress.CandidateJson),
                   CONVERT(varbinary(max), actor.CandidateJson),
                   CONVERT(varbinary(max), supportActress.CandidateJson),
                   CONVERT(varbinary(max), supportActor.CandidateJson),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageDesign.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE clothesDesign.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageMusic.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE lightDesign.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE choreography.CandidateJson END),
                   play.IsActive, play.IsPublished
            EXCEPT
            SELECT CONVERT(varbinary(max), formRecord.RepertoireName),
                   CONVERT(varbinary(max), formRecord.TheatreName),
                   CONVERT(varbinary(max), formRecord.Phone),
                   CONVERT(varbinary(max), formRecord.ContactName),
                   CONVERT(varbinary(max), formRecord.ContactPhone),
                   CONVERT(varbinary(max), formRecord.Email),
                   CONVERT(varbinary(max), formRecord.Director),
                   CONVERT(varbinary(max), formRecord.LeadActress),
                   CONVERT(varbinary(max), formRecord.LeadActor),
                   CONVERT(varbinary(max), formRecord.SupportActress),
                   CONVERT(varbinary(max), formRecord.SupportActor),
                   CONVERT(varbinary(max), formRecord.StageDesign),
                   CONVERT(varbinary(max), formRecord.ClothesDesign),
                   CONVERT(varbinary(max), formRecord.StageMusic),
                   CONVERT(varbinary(max), formRecord.LightDesign),
                   CONVERT(varbinary(max), formRecord.Choreography),
                   formRecord.IsActive, formRecord.IsPublished
        );
        END;

        EXEC sys.sp_set_session_context
            @key = N'PlayToFormSyncInProgress', @value = NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'PlayToFormSyncInProgress', @value = NULL;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingJuries_SoftDelete ON dbo.AdditionalVotingJuries INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingPlays_SoftDelete ON dbo.AdditionalVotingPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotings_SoftDelete
ON dbo.AdditionalVotings INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now datetime2(7) = SYSDATETIME();
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotings target INNER JOIN deleted d ON d.Id = target.Id;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingUsages_SoftDelete ON dbo.AdditionalVotingUsages INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.Id; END;
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

/* Direct SQL deletes are also soft deletes. */
CREATE OR ALTER TRIGGER dbo.TR_Announcements_SoftDelete ON dbo.Announcements INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Announcements target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AwardCategories_SoftDelete ON dbo.AwardCategories INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.AwardCategories target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Blacklist_BlockAdminPlay]
ON [dbo].[Blacklist]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS blacklist
        INNER JOIN [dbo].[Plays] AS play
            ON play.[Id] = blacklist.[PlayId]
        WHERE play.[RecordType] = 1
    )
    BEGIN
        THROW 51213, N'RecordType 1 olan oyunlara blacklist kaydı eklenemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Blacklist_BlockInactiveSourceForm
ON dbo.Blacklist
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52414, N'Pasif Form kaynağı için yayımlanmış blacklist kaydı eklenemez.', 1;
END;
GO

/* A published blacklist entry immediately removes matching votes from circulation. */
CREATE OR ALTER TRIGGER [dbo].[TR_Blacklist_DeactivateJuryVotes]
ON [dbo].[Blacklist]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE vote
    SET vote.[IsPublished] = 0,
        vote.[IsActive] = 0,
        vote.[UpdatedAt] = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM [dbo].[JuryVotes] AS vote
    INNER JOIN [dbo].[PlayAwardCategories] AS candidate
        ON candidate.[Id] = vote.[PlayAwardCategoryId]
    INNER JOIN inserted AS blacklist
        ON blacklist.[JuryId] = vote.[JuryId]
       AND blacklist.[PlayId] = candidate.[PlayId]
       AND blacklist.[IsPublished] = 1
    WHERE vote.[IsPublished] = 1
       OR vote.[IsActive] = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Blacklist_SoftDelete ON dbo.Blacklist INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Blacklist target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Configs_ProtectJuryHomePageSettings
ON dbo.Configs
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Only ConfigValue/audit fields are editable for the four fixed keys.
       Ordinary Config rows retain their existing edit/soft-delete behavior. */
    IF EXISTS
    (
        SELECT 1
        FROM deleted AS previous
        LEFT JOIN inserted AS currentRow ON currentRow.id = previous.id
        WHERE previous.ConfigName IN
            (N'HomePageJuryTableEnabled', N'HomePageMissionTableEnabled',
             N'HomePageMostWatchedTableEnabled', N'HomePageLeastWatchedTableEnabled')
          AND (currentRow.id IS NULL OR
               DATALENGTH(currentRow.ConfigName) <> DATALENGTH(previous.ConfigName) OR
               currentRow.ConfigName COLLATE Latin1_General_100_BIN2 <>
               previous.ConfigName COLLATE Latin1_General_100_BIN2)
    )
        THROW 53213, N'Jüri ana ekran tablo ayarlarının sabit adı veya kimliği değiştirilemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Configs_SoftDelete ON dbo.Configs INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Configs target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Form_NormalizeSeasonAndSynchronize
ON dbo.Form
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* SQL fires statement triggers even when no rows match. An empty JSON
       scope can become NULL, which the maintenance procedure treats as all. */
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF TRY_CONVERT(bit, SESSION_CONTEXT(N'FormSeasonAssignmentSyncInProgress')) = 1
    BEGIN
        UPDATE target
        SET SeasonId = changed.SeasonId
        FROM dbo.Form AS target
        INNER JOIN inserted AS changed ON changed.Id = target.Id;
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        LEFT JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE previous.Id IS NOT NULL
          AND previous.Id <> changed.Id
    )
        THROW 52404, N'Form.Id oluşturulduktan sonra değiştirilemez.', 1;

    UPDATE target
    SET
        ApplicationNumber = changed.ApplicationNumber,
        SeasonId = season.Id,
        CreatedDate = changed.CreatedDate,
        UpdatedDate = changed.UpdatedDate,
        RepertoireName = changed.RepertoireName,
        TheatreName = changed.TheatreName,
        PremiereDate = changed.PremiereDate,
        Display = changed.Display,
        ApplicantName = changed.ApplicantName,
        ApplicantRole = changed.ApplicantRole,
        Phone = changed.Phone,
        Email = changed.Email,
        Director = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.Director END,
        ContactName = changed.ContactName,
        ContactPhone = changed.ContactPhone,
        LeadActress = changed.LeadActress,
        LeadActor = changed.LeadActor,
        SupportActress = changed.SupportActress,
        SupportActor = changed.SupportActor,
        StageDesign = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.StageDesign END,
        ClothesDesign = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.ClothesDesign END,
        LightDesign = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.LightDesign END,
        StageMusic = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.StageMusic END,
        Choreography = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.Choreography END,
        YoungGenerationArtist = changed.YoungGenerationArtist,
        previousProductionVersion = changed.previousProductionVersion,
        IsActive = changed.IsActive,
        IsPublished = changed.IsPublished
    FROM dbo.Form AS target
    INNER JOIN inserted AS changed ON changed.Id = target.Id
    OUTER APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
          AND changed.CreatedDate IS NOT NULL
          AND CAST(changed.CreatedDate AS date) >= season.SeasonStartDate
          AND CAST(changed.CreatedDate AS date) < season.SeasonEndDate
        ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
    ) AS season;

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, SeasonId, CreatedDate, UpdatedDate,
        RepertoireName, TheatreName, PremiereDate, Display, ApplicantName,
        ApplicantRole, Phone, Email, Director, ContactName, ContactPhone,
        LeadActress, LeadActor, SupportActress, SupportActor, StageDesign,
        ClothesDesign, LightDesign, StageMusic, Choreography,
        YoungGenerationArtist, previousProductionVersion,
        IsActive, IsPublished
    )
    SELECT
        changed.Id, changed.ApplicationNumber, season.Id,
        changed.CreatedDate, changed.UpdatedDate,
        changed.RepertoireName, changed.TheatreName, changed.PremiereDate,
        changed.Display, changed.ApplicantName, changed.ApplicantRole,
        changed.Phone, changed.Email,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.Director END,
        changed.ContactName, changed.ContactPhone,
        changed.LeadActress, changed.LeadActor,
        changed.SupportActress, changed.SupportActor,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.StageDesign END,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.ClothesDesign END,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.LightDesign END,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.StageMusic END,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.Choreography END,
        changed.YoungGenerationArtist, changed.previousProductionVersion,
        changed.IsActive, changed.IsPublished
    FROM inserted AS changed
    OUTER APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
          AND changed.CreatedDate IS NOT NULL
          AND CAST(changed.CreatedDate AS date) >= season.SeasonStartDate
          AND CAST(changed.CreatedDate AS date) < season.SeasonEndDate
        ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
    ) AS season
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Form AS target WHERE target.Id = changed.Id
    );

    /* A reverse synchronization has already made Form authoritative for this
       statement. Running the forward procedure here would re-enter the graph. */
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) <> 1
       OR SESSION_CONTEXT(N'PlayToFormSyncInProgress') IS NULL
    BEGIN
        DECLARE @FormIdsJson nvarchar(max) = (SELECT Id FROM inserted FOR JSON PATH);
        EXEC dbo.usp_SynchronizeFormsToPlays @FormIdsJson = @FormIdsJson;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Form_SoftDelete
ON dbo.Form
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    UPDATE target
    SET IsPublished = 0,
        IsActive = 0,
        UpdatedDate = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.Form AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;

    /* The UPDATE above already passes this statement's IDs through the Form
       INSERT/UPDATE trigger. Keep soft deletion within the same scope as well;
       never fall back to a full-history repair from a DELETE statement. */
    DECLARE @FormIdsJson nvarchar(max) = (SELECT Id FROM deleted FOR JSON PATH);
    EXEC dbo.usp_SynchronizeFormsToPlays @FormIdsJson = @FormIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Group_ProtectAssignments
ON dbo.[Group]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    /* Only non-deleted juries prevent removal. Inactive juries still count;
       deleted juries/admin users keep their historical GroupCode untouched.
       The indexed range lock covers concurrent membership state changes. */
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        INNER JOIN deleted AS previousGroup ON previousGroup.Id = changed.Id
        INNER JOIN dbo.Users AS member WITH (UPDLOCK, HOLDLOCK)
            ON member.GroupCode = changed.Code
        WHERE previousGroup.IsPublished = 1 AND changed.IsPublished = 0
          AND member.RoleCode = 2 AND member.IsPublished = 1
    )
        THROW 52820, N'Bu gruba bağlı jüriler bulunduğu için grup silinemez. Önce ilgili jürilerin grupla ilişiğini kesin.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Group_SoftDelete ON dbo.[Group] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Group] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Images_EnforceMaximumSize
ON dbo.Images
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Retiring an existing legacy image does not upload or change its content.
       INSERT and every write to the image payload still receive all checks. */
    IF NOT (UPDATE(FileName) OR UPDATE(ContentType) OR UPDATE(ImageData))
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE
            (ContentType = N'image/jpeg' AND
                (LOWER(FileName) NOT LIKE N'%.jpg' AND LOWER(FileName) NOT LIKE N'%.jpeg'))
            OR (ContentType = N'image/png' AND LOWER(FileName) NOT LIKE N'%.png')
            OR (ContentType = N'image/webp' AND LOWER(FileName) NOT LIKE N'%.webp')
            OR ContentType NOT IN (N'image/jpeg', N'image/png', N'image/webp')
            OR
            (
                ContentType = N'image/jpeg'
                AND (DATALENGTH(ImageData) < 3 OR SUBSTRING(ImageData, 1, 3) <> 0xFFD8FF)
            )
            OR
            (
                ContentType = N'image/png'
                AND
                (
                    DATALENGTH(ImageData) < 8
                    OR SUBSTRING(ImageData, 1, 8) <> 0x89504E470D0A1A0A
                )
            )
            OR
            (
                ContentType = N'image/webp'
                AND
                (
                    DATALENGTH(ImageData) < 12
                    OR SUBSTRING(ImageData, 1, 4) <> 0x52494646
                    OR SUBSTRING(ImageData, 9, 4) <> 0x57454250
                )
            )
    )
        THROW 52432,
            N'Yalnızca dosya uzantısı, içerik türü ve imzası doğrulanan JPEG, PNG veya WebP görseller yüklenebilir.',
            1;

    IF EXISTS
    (
        SELECT 1 FROM inserted
        WHERE DATALENGTH(ImageData) > 150 * 1024 * 1024
    )
        THROW 52431, N'Görsel boyutu 150 MB''dan büyük olamaz.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Images_SoftDelete ON dbo.Images INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Images target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_BlockInactiveSourceForm
ON dbo.JuryAssignedPlays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52413, N'Pasif Form kaynağı için yayımlanmış jüri ataması eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_SoftDelete ON dbo.JuryAssignedPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryAssignedPlays target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryGameTicketFees_BlockInactiveSourceForm
ON dbo.JuryGameTicketFees
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52412, N'Pasif Form kaynağı için yayımlanmış bilet ücreti eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryGameTicketFees_SoftDelete ON dbo.JuryGameTicketFees INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryGameTicketFees target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryLogs_SoftDelete
ON dbo.JuryLogs
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.JuryLogs AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;
END;
GO

/* Defense in depth: a blacklisted jury/play pair cannot publish a vote. */
CREATE OR ALTER TRIGGER [dbo].[TR_JuryVotes_BlockBlacklistedJuryPlay]
ON [dbo].[JuryVotes]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS vote
        INNER JOIN [dbo].[PlayAwardCategories] AS candidate
            ON candidate.[Id] = vote.[PlayAwardCategoryId]
        INNER JOIN [dbo].[Blacklist] AS blacklist
            ON blacklist.[JuryId] = vote.[JuryId]
           AND blacklist.[PlayId] = candidate.[PlayId]
           AND blacklist.[IsPublished] = 1
        WHERE vote.[IsPublished] = 1
           OR vote.[IsActive] = 1
    )
    BEGIN
        THROW 51214, N'Blacklist kaydı bulunan jüri bu oyun için oy veremez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_BlockInactiveSourceForm
ON dbo.JuryVotes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = changed.PlayAwardCategoryId
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52411, N'Pasif Form kaynağı için yayımlanmış jüri oyu eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshRankings
ON dbo.JuryVotes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @DirtyCandidates TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY);
    ;WITH ChangedVotes AS
    (
        SELECT currentVote.PlayAwardCategoryId AS NewCandidateId,
               previousVote.PlayAwardCategoryId AS OldCandidateId
        FROM inserted AS currentVote
        FULL OUTER JOIN deleted AS previousVote ON previousVote.Id = currentVote.Id
        WHERE currentVote.Id IS NULL OR previousVote.Id IS NULL OR EXISTS
        (
            SELECT currentVote.PlayAwardCategoryId, currentVote.Score, currentVote.IsPublished, currentVote.IsActive
            EXCEPT
            SELECT previousVote.PlayAwardCategoryId, previousVote.Score, previousVote.IsPublished, previousVote.IsActive
        )
    )
    INSERT INTO @DirtyCandidates (Id)
    SELECT NewCandidateId FROM ChangedVotes WHERE NewCandidateId IS NOT NULL
    UNION
    SELECT OldCandidateId FROM ChangedVotes WHERE OldCandidateId IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @DirtyCandidates) RETURN;
    DECLARE @CategoryCodesJson nvarchar(max) = COALESCE((
        SELECT DISTINCT candidate.AwardCategoryCode AS CategoryCode
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN @DirtyCandidates AS dirty ON dirty.Id = candidate.Id
        FOR JSON PATH
    ), N'[]');
    DECLARE @CandidateIdsJson nvarchar(max) = COALESCE((SELECT Id FROM @DirtyCandidates FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @CategoryCodesJson, @CandidateIdsJson = @CandidateIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshSeasonStatistics
ON dbo.JuryVotes AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Changed TABLE (Id uniqueidentifier PRIMARY KEY);
    INSERT @Changed
    SELECT COALESCE(i.Id, d.Id) FROM inserted i FULL JOIN deleted d ON d.Id = i.Id
    WHERE i.Id IS NULL OR d.Id IS NULL OR EXISTS
        (SELECT i.CreatedAt, i.IsPublished, i.IsActive, i.PlayAwardCategoryId
         EXCEPT SELECT d.CreatedAt, d.IsPublished, d.IsActive, d.PlayAwardCategoryId);
    IF NOT EXISTS (SELECT 1 FROM @Changed) RETURN;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT DISTINCT season.Id FROM dbo.Seasons season
        INNER JOIN
        (
            SELECT i.CreatedAt FROM inserted i INNER JOIN @Changed c ON c.Id = i.Id
            UNION SELECT d.CreatedAt FROM deleted d INNER JOIN @Changed c ON c.Id = d.Id
        ) changed ON changed.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
                 AND changed.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        WHERE season.IsPublished = 1 FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
GO

/* A new published vote soft-deletes every older vote in the same logical role. */
CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_SingleRecordPerPlayCategoryRole
ON dbo.JuryVotes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AffectedGroups TABLE
    (
        JuryId uniqueidentifier NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        RoleCode int NOT NULL,
        WinnerVoteId uniqueidentifier NOT NULL,
        PRIMARY KEY (JuryId, PlayId, AwardCategoryCode, RoleCode)
    );

    ;WITH ChangedVotes AS
    (
        SELECT
            changedVote.Id,
            changedVote.JuryId,
            candidate.PlayId,
            candidate.AwardCategoryCode,
            candidate.RoleCode,
            ROW_NUMBER() OVER
            (
                PARTITION BY changedVote.JuryId, candidate.PlayId,
                    candidate.AwardCategoryCode, candidate.RoleCode
                ORDER BY COALESCE(changedVote.UpdatedAt, changedVote.CreatedAt,
                    CONVERT(datetime2, '19000101')) DESC, changedVote.Id DESC
            ) AS VoteOrder
        FROM inserted AS changedVote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = changedVote.PlayAwardCategoryId
        WHERE changedVote.IsPublished = 1
    )
    INSERT INTO @AffectedGroups
        (JuryId, PlayId, AwardCategoryCode, RoleCode, WinnerVoteId)
    SELECT JuryId, PlayId, AwardCategoryCode, RoleCode, Id
    FROM ChangedVotes
    WHERE VoteOrder = 1;

    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    INNER JOIN @AffectedGroups AS affected
        ON affected.JuryId = vote.JuryId
       AND affected.PlayId = candidate.PlayId
       AND affected.AwardCategoryCode = candidate.AwardCategoryCode
       AND affected.RoleCode = candidate.RoleCode
    WHERE vote.Id <> affected.WinnerVoteId
      AND vote.IsPublished = 1;

    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN inserted AS changedVote ON changedVote.Id = vote.Id
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    WHERE (candidate.IsPublished = 0 AND vote.IsPublished = 1)
       OR (candidate.IsActive = 0 AND vote.IsActive = 1);
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_SoftDelete ON dbo.JuryVotes INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.JuryVotes target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Log_SoftDelete ON dbo.[Log] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Log] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Manager_SoftDelete ON dbo.[Manager] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Manager] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_PlayAwardCategories_BlockAdminPlay]
ON [dbo].[PlayAwardCategories]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN [dbo].[Plays] AS play
            ON play.[Id] = candidate.[PlayId]
        WHERE play.[RecordType] = 1
    )
    BEGIN
        THROW 51211, N'RecordType 1 olan oyunlara aday veya ödül kategorisi eklenemez.', 1;
    END;
END;
GO

/* Reject new visible relationships while their source Form is inactive. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_BlockInactiveSourceForm
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52410, N'Pasif Form kaynağına yayımlanmış aday/kategori eklenemez.', 1;
END;
GO

/* Previous productions cannot acquire director or technical-category candidates.
   Historical rows remain available when all three eligibility flags are off.
   Do not bypass this rule during lifecycle restoration: that must not resurrect
   a category excluded by the current Form contract. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_BlockPreviousProduction
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        WHERE formRecord.previousProductionVersion = 1
          AND (candidate.AwardCategoryCode = 1002
               OR candidate.AwardCategoryCode BETWEEN 1007 AND 1011)
          AND (candidate.IsPublished = 1 OR candidate.IsActive = 1 OR candidate.IsCurrent = 1)
    )
        THROW 52434, N'Önceki prodüksiyon başvurularına yönetmen veya teknik kategori adayı eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_EnforceMultiplicity
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* The Form synchronizer writes a complete snapshot inside one transaction.
       Permit it to normalize legacy intermediate values; normal application
       writes remain protected by every check below. */
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    IF EXISTS
    (
        SELECT 1 FROM inserted
        WHERE AwardCategoryCode = 1012
          AND (IsPublished = 1 OR IsActive = 1 OR IsCurrent = 1)
    )
        THROW 52430, N'1012 ödül kategorisi sistemden kaldırılmıştır.', 1;

    -- The 1001 row is a system-managed category slot, not a person candidate.
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE candidate.AwardCategoryCode = 1001
          AND
          (
              play.RecordType <> 0
              OR ISNULL(candidate.Role, N'') <> N'Tiyatro'
              OR candidate.Candidate <> play.TheaterName
              OR (candidate.RoleCode = 0 AND candidate.IsCurrent <> 1)
              OR
              (
                  candidate.RoleCode <> 0
                  AND
                  (
                      previousCandidate.Id IS NULL
                      OR previousCandidate.PlayId <> candidate.PlayId
                      OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                      OR previousCandidate.RoleCode <> candidate.RoleCode
                  )
              )
          )
    )
    BEGIN
        THROW 51302, N'1001 varsayilan oyun kategorisi sistem tarafindan yonetilir ve degistirilemez.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.Id IS NULL
           OR previousCandidate.PlayId <> candidate.PlayId
           OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
           OR previousCandidate.RoleCode <> candidate.RoleCode
           OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
    )
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 1
                AND (candidate.RoleCode <= 0 OR NULLIF(LTRIM(RTRIM(candidate.Role)), N'') IS NULL)
        )
        BEGIN
            THROW 51303, N'Cok adayli kategorilerde pozitif RoleCode ve dolu Role alani zorunludur.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            OUTER APPLY
            (
                SELECT TOP (1) existing.RoleCode
                FROM dbo.PlayAwardCategories AS existing
                WHERE existing.Id <> candidate.Id
                  AND existing.PlayId = candidate.PlayId
                  AND existing.AwardCategoryCode = candidate.AwardCategoryCode
                ORDER BY
                    existing.IsCurrent DESC,
                    COALESCE(existing.UpdatedAt, existing.CreatedAt, CONVERT(datetime2, '19000101')) DESC,
                    existing.Id
            ) AS canonicalSlot
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 0
                AND candidate.AwardCategoryCode <> 1001
                AND
                (
                    candidate.Role IS NOT NULL
                    OR candidate.RoleCode <> COALESCE(canonicalSlot.RoleCode, 0)
                )
        )
        BEGIN
            THROW 51304, N'Tek adayli kategoriler yalnizca tek mantiksal slot ve bos Role alani kullanabilir.', 1;
        END;

        /* RoleCode is the stable identity. Role is editable display data and
           distinct role slots may intentionally use the same display name. */
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        INNER JOIN dbo.AwardCategories AS category
            ON category.CategoryCode = candidate.AwardCategoryCode
        WHERE category.MultiCandidate = 0
          AND (previousCandidate.Id IS NULL OR previousCandidate.IsCurrent <> candidate.IsCurrent)
          AND
          (
              SELECT COUNT_BIG(*)
              FROM dbo.PlayAwardCategories AS currentCandidate
              WHERE currentCandidate.PlayId = candidate.PlayId
                AND currentCandidate.AwardCategoryCode = candidate.AwardCategoryCode
                AND currentCandidate.IsCurrent = 1
          ) > 1
    )
    BEGIN
        THROW 51306, N'Tek adayli kategorilerde ayni anda yalnizca bir guncel aday olabilir.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_ProtectDefaultCategory
ON dbo.PlayAwardCategories
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM deleted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE candidate.AwardCategoryCode = 1001
          AND candidate.RoleCode = 0
          AND play.RecordType = 0
    )
    BEGIN
        THROW 51307, N'Kunye oyunlarinin varsayilan 1001 kategori kaydi silinemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_RefreshRankings
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ChangedCandidates TABLE
    (
        Id uniqueidentifier NOT NULL PRIMARY KEY,
        OldCategoryCode int NULL,
        NewCategoryCode int NULL
    );
    INSERT INTO @ChangedCandidates (Id, OldCategoryCode, NewCategoryCode)
    SELECT COALESCE(currentCandidate.Id, previousCandidate.Id),
           previousCandidate.AwardCategoryCode, currentCandidate.AwardCategoryCode
    FROM inserted AS currentCandidate
    FULL OUTER JOIN deleted AS previousCandidate ON previousCandidate.Id = currentCandidate.Id
    WHERE currentCandidate.Id IS NULL OR previousCandidate.Id IS NULL OR EXISTS
    (
        SELECT currentCandidate.PlayId, currentCandidate.AwardCategoryCode,
               currentCandidate.IsPublished, currentCandidate.IsCurrent, currentCandidate.IsActive
        EXCEPT
        SELECT previousCandidate.PlayId, previousCandidate.AwardCategoryCode,
               previousCandidate.IsPublished, previousCandidate.IsCurrent, previousCandidate.IsActive
    );

    IF NOT EXISTS (SELECT 1 FROM @ChangedCandidates) RETURN;
    DECLARE @CategoryCodesJson nvarchar(max) = COALESCE((
        SELECT CategoryCode FROM
        (
            SELECT OldCategoryCode AS CategoryCode FROM @ChangedCandidates WHERE OldCategoryCode IS NOT NULL
            UNION
            SELECT NewCategoryCode FROM @ChangedCandidates WHERE NewCategoryCode IS NOT NULL
        ) AS affected
        FOR JSON PATH
    ), N'[]');
    DECLARE @CandidateIdsJson nvarchar(max) = COALESCE((SELECT Id FROM @ChangedCandidates FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @CategoryCodesJson, @CandidateIdsJson = @CandidateIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_RefreshSeasonStatistics
ON dbo.PlayAwardCategories AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT DISTINCT season.Id
        FROM inserted i INNER JOIN deleted d ON d.Id = i.Id
        INNER JOIN dbo.JuryVotes vote ON vote.PlayAwardCategoryId = i.Id
        INNER JOIN dbo.Seasons season
            ON vote.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
           AND vote.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        WHERE season.IsPublished = 1 AND vote.IsPublished = 1 AND vote.IsActive = 1
          AND EXISTS (SELECT i.PlayId, i.IsPublished, i.IsActive
                      EXCEPT SELECT d.PlayId, d.IsPublished, d.IsActive)
        FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SoftDelete
ON dbo.PlayAwardCategories
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted WHERE AwardCategoryCode IN (1001, 1002))
        THROW 51307, N'System-managed categories 1001 and 1002 cannot be deleted.', 1;

    UPDATE target
    SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories target
    INNER JOIN deleted source ON source.Id = target.Id;
END;
GO

/* Lifecycle sync restores votes explicitly from snapshots. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SynchronizeJuryVotes
ON dbo.PlayAwardCategories
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    IF UPDATE(IsActive)
    BEGIN
        UPDATE vote
        SET vote.IsActive = candidate.IsActive,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsActive <> candidate.IsActive
          AND vote.IsPublished = 1
          AND vote.IsActive <> candidate.IsActive;
    END;

    IF UPDATE(IsPublished)
    BEGIN
        UPDATE vote
        SET vote.IsPublished = candidate.IsPublished,
            vote.IsActive = CASE
                WHEN candidate.IsPublished = 1 THEN candidate.IsActive ELSE 0 END,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsPublished <> candidate.IsPublished
          AND
          (
              vote.IsPublished <> candidate.IsPublished
              OR vote.IsActive <> CASE
                    WHEN candidate.IsPublished = 1 THEN candidate.IsActive ELSE 0 END
          );
    END;

    IF NOT (UPDATE(PlayId) OR UPDATE(AwardCategoryCode) OR UPDATE(RoleCode))
        RETURN;

    ;WITH AffectedGroups AS
    (
        SELECT PlayId, AwardCategoryCode, RoleCode FROM inserted
        UNION
        SELECT PlayId, AwardCategoryCode, RoleCode FROM deleted
    ),
    RankedVotes AS
    (
        SELECT vote.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY vote.JuryId, candidate.PlayId,
                       candidate.AwardCategoryCode, candidate.RoleCode
                   ORDER BY COALESCE(vote.UpdatedAt, vote.CreatedAt,
                       CONVERT(datetime2, '19000101')) DESC, vote.Id DESC
               ) AS VoteOrder
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN AffectedGroups AS affected
            ON affected.PlayId = candidate.PlayId
           AND affected.AwardCategoryCode = candidate.AwardCategoryCode
           AND affected.RoleCode = candidate.RoleCode
        WHERE vote.IsPublished = 1
    )
    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN RankedVotes AS ranked ON ranked.Id = vote.Id
    WHERE ranked.VoteOrder > 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SynchronizeSourceForm
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    /* 1001 is generated automatically immediately after a Play insert. It has
       no Form candidate JSON field and must never clear the imported arrays. */
    IF NOT EXISTS
    (
        SELECT 1 FROM inserted WHERE AwardCategoryCode BETWEEN 1002 AND 1011
        UNION ALL
        SELECT 1 FROM deleted WHERE AwardCategoryCode BETWEEN 1002 AND 1011
    )
        RETURN;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT
       (
           UPDATE(PlayId) OR UPDATE(Candidate) OR UPDATE(Role)
           OR UPDATE(PhotoImageId) OR UPDATE(AwardCategoryCode)
           OR UPDATE(IsPublished) OR UPDATE(IsCurrent)
       )
        RETURN;

    DECLARE @AffectedPlayIdsJson nvarchar(max);
    ;WITH ChangedCandidates AS
    (
        SELECT changed.PlayId AS NewPlayId, previous.PlayId AS OldPlayId
        FROM inserted AS changed
        FULL OUTER JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE (changed.AwardCategoryCode BETWEEN 1002 AND 1011
               OR previous.AwardCategoryCode BETWEEN 1002 AND 1011)
          AND
          (
              changed.Id IS NULL OR previous.Id IS NULL
              OR EXISTS
              (
                  SELECT changed.PlayId, changed.AwardCategoryCode,
                         CONVERT(varbinary(max), changed.Candidate),
                         CONVERT(varbinary(max), changed.Role), changed.PhotoImageId,
                         changed.IsPublished, changed.IsCurrent
                  EXCEPT
                  SELECT previous.PlayId, previous.AwardCategoryCode,
                         CONVERT(varbinary(max), previous.Candidate),
                         CONVERT(varbinary(max), previous.Role), previous.PhotoImageId,
                         previous.IsPublished, previous.IsCurrent
              )
          )
    ), AffectedPlays AS
    (
        SELECT NewPlayId AS PlayId FROM ChangedCandidates WHERE NewPlayId IS NOT NULL
        UNION
        SELECT OldPlayId FROM ChangedCandidates WHERE OldPlayId IS NOT NULL
    )
    SELECT @AffectedPlayIdsJson =
    (
        SELECT play.Id
        FROM dbo.Plays AS play
        INNER JOIN AffectedPlays AS affected ON affected.PlayId = play.Id
        WHERE play.SourceFormId IS NOT NULL
        FOR JSON PATH
    );

    /* Empty FOR JSON assignments can be SQL NULL; never expand a no-op DML
       statement into the procedure's NULL/full-maintenance scope. */
    IF @AffectedPlayIdsJson IS NULL OR @AffectedPlayIdsJson = N'[]' RETURN;
    EXEC dbo.usp_SynchronizePlayDataToForms
        @PlayIdsJson = @AffectedPlayIdsJson, @SyncCandidateData = 1;
END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Plays_BlockAdminRecordTypeWithCandidates]
ON [dbo].[Plays]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- UPDATE(column) is true even when a SET clause writes the same value.
    -- Enforce the rule only when RecordType actually changes from Kunye (0)
    -- to Admin (1), leaving both status toggles editable for Kunye plays.
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS currentPlay
        INNER JOIN deleted AS previousPlay
            ON previousPlay.[Id] = currentPlay.[Id]
        WHERE previousPlay.[RecordType] = 0
          AND currentPlay.[RecordType] = 1
    )
       AND
       (
           EXISTS
           (
               SELECT 1
               FROM inserted AS play
               INNER JOIN [dbo].[PlayAwardCategories] AS candidate
                   ON candidate.[PlayId] = play.[Id]
               WHERE play.[RecordType] = 1
           )
           OR EXISTS
           (
               SELECT 1
               FROM inserted AS play
               INNER JOIN [dbo].[Blacklist] AS blacklist
                   ON blacklist.[PlayId] = play.[Id]
               WHERE play.[RecordType] = 1
           )
       )
    BEGIN
        THROW 51212, N'Aday veya blacklist kaydı bulunan bir oyun RecordType 1 olarak değiştirilemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_EnsureDefaultAwardCategory
ON dbo.Plays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE defaultCategory
    SET
        defaultCategory.Candidate = currentPlay.TheaterName,
        defaultCategory.Role = N'Tiyatro',
        defaultCategory.IsPublished = expected.IsPublished,
        defaultCategory.IsActive = CASE
            WHEN lifecycle.IsSynchronizing = 1 THEN defaultCategory.IsActive
            WHEN expected.IsPublished = 0 THEN 0
            WHEN defaultCategory.IsPublished = 0 THEN 1
            ELSE defaultCategory.IsActive END,
        defaultCategory.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME()),
        defaultCategory.UpdatedBy = currentPlay.UpdatedBy
    FROM dbo.PlayAwardCategories AS defaultCategory
    INNER JOIN inserted AS currentPlay ON currentPlay.Id = defaultCategory.PlayId
    INNER JOIN deleted AS previousPlay ON previousPlay.Id = currentPlay.Id
    LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = currentPlay.SourceFormId
    CROSS APPLY
    (
        SELECT CONVERT(bit, CASE
            WHEN TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
                THEN 1 ELSE 0 END) AS IsSynchronizing
    ) AS lifecycle
    CROSS APPLY
    (
        /* Form lifecycle captures the current flags before deactivation and
           restores them explicitly. Metadata updates must not overwrite that
           snapshot or a manually disabled default candidate. */
        SELECT CONVERT(bit, CASE
            WHEN lifecycle.IsSynchronizing = 1 THEN defaultCategory.IsPublished
            WHEN currentPlay.IsPublished = 1
             AND currentPlay.IsActive = 1
             AND
             (
                 currentPlay.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END) AS IsPublished
    ) AS expected
    WHERE currentPlay.RecordType = 0
      AND defaultCategory.AwardCategoryCode = 1001
      AND
      (
          currentPlay.TheaterName <> previousPlay.TheaterName
          OR defaultCategory.Candidate <> currentPlay.TheaterName
          OR ISNULL(defaultCategory.Role, N'') <> N'Tiyatro'
          OR defaultCategory.IsPublished <> expected.IsPublished
          OR defaultCategory.IsActive <> CASE
              WHEN lifecycle.IsSynchronizing = 1 THEN defaultCategory.IsActive
              WHEN expected.IsPublished = 0 THEN 0
              WHEN defaultCategory.IsPublished = 0 THEN 1
              ELSE defaultCategory.IsActive END
      );

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, IsActive,
        Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode, PhotoImageId
    )
    SELECT
        NEWID(),
        play.Id,
        COALESCE(play.CreatedAt, DATEADD(HOUR, 3, SYSUTCDATETIME())),
        play.CreatedBy,
        NULL,
        NULL,
        CASE
            WHEN play.IsPublished = 1
             AND play.IsActive = 1
             AND
             (
                 play.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END,
        CASE
            WHEN play.IsPublished = 1
             AND play.IsActive = 1
             AND
             (
                 play.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END,
        play.TheaterName,
        1001,
        1,
        N'Tiyatro',
        0,
        NULL
    FROM inserted AS play
    LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE play.RecordType = 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.PlayAwardCategories AS candidate WITH (UPDLOCK, HOLDLOCK)
          WHERE candidate.PlayId = play.Id
            AND candidate.AwardCategoryCode = 1001
            AND candidate.RoleCode = 0
      );
END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Plays_RecordTypeImmutable]
ON [dbo].[Plays]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS currentPlay
        INNER JOIN deleted AS previousPlay
            ON previousPlay.[Id] = currentPlay.[Id]
        WHERE currentPlay.[RecordType] <> previousPlay.[RecordType]
    )
    BEGIN
        THROW 51231, N'Mevcut bir oyunun RecordType degeri degistirilemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshRankings
ON dbo.Plays
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ChangedPlays TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY);
    INSERT INTO @ChangedPlays (Id)
    SELECT COALESCE(currentPlay.Id, previousPlay.Id)
    FROM inserted AS currentPlay
    FULL OUTER JOIN deleted AS previousPlay ON previousPlay.Id = currentPlay.Id
    WHERE currentPlay.Id IS NULL OR previousPlay.Id IS NULL OR EXISTS
    (
        SELECT currentPlay.RecordType, currentPlay.IsPublished, currentPlay.IsActive
        EXCEPT
        SELECT previousPlay.RecordType, previousPlay.IsPublished, previousPlay.IsActive
    );

    /* Eligibility changes affect every candidate on these plays, including a
       direct IsActive toggle. Pure metadata edits leave ranking metrics alone. */
    DECLARE @DirtyCandidates TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY, CategoryCode int NOT NULL);
    INSERT INTO @DirtyCandidates (Id, CategoryCode)
    SELECT candidate.Id, candidate.AwardCategoryCode
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN @ChangedPlays AS affected ON affected.Id = candidate.PlayId;

    IF NOT EXISTS (SELECT 1 FROM @DirtyCandidates) RETURN;
    DECLARE @CategoryCodesJson nvarchar(max) =
        COALESCE((SELECT DISTINCT CategoryCode FROM @DirtyCandidates FOR JSON PATH), N'[]');
    DECLARE @CandidateIdsJson nvarchar(max) = COALESCE((SELECT Id FROM @DirtyCandidates FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @CategoryCodesJson, @CandidateIdsJson = @CandidateIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshSeasonStatistics
ON dbo.Plays AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Changed TABLE (Id uniqueidentifier PRIMARY KEY, EligibilityChanged bit NOT NULL);
    INSERT @Changed
    SELECT COALESCE(i.Id, d.Id),
        CASE WHEN i.Id IS NULL OR d.Id IS NULL OR EXISTS
            (SELECT i.IsPublished, i.IsActive EXCEPT SELECT d.IsPublished, d.IsActive) THEN 1 ELSE 0 END
    FROM inserted i FULL JOIN deleted d ON d.Id = i.Id
    WHERE i.Id IS NULL OR d.Id IS NULL OR EXISTS
        (SELECT i.CreatedAt, i.IsPublished, i.IsActive, i.StatusCode
         EXCEPT SELECT d.CreatedAt, d.IsPublished, d.IsActive, d.StatusCode);
    IF NOT EXISTS (SELECT 1 FROM @Changed) RETURN;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT DISTINCT season.Id FROM dbo.Seasons season
        INNER JOIN
        (
            SELECT i.CreatedAt FROM inserted i INNER JOIN @Changed c ON c.Id = i.Id
            UNION SELECT d.CreatedAt FROM deleted d INNER JOIN @Changed c ON c.Id = d.Id
            /* A play and its votes may belong to different calendar seasons. */
            UNION SELECT vote.CreatedAt FROM @Changed c
            INNER JOIN dbo.PlayAwardCategories candidate ON candidate.PlayId = c.Id
            INNER JOIN dbo.JuryVotes vote ON vote.PlayAwardCategoryId = candidate.Id
            WHERE c.EligibilityChanged = 1 AND vote.IsPublished = 1 AND vote.IsActive = 1
        ) changed ON changed.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
                 AND changed.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        WHERE season.IsPublished = 1 FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDelete
ON dbo.Plays
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted WHERE RecordType = 0)
        THROW 51502, N'Kunye Giris Sistemi kaynakli oyunlar silinemez.', 1;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.Plays target
    INNER JOIN deleted source ON source.Id = target.Id
    WHERE source.RecordType = 1;
END;
GO

/* EF soft deletes are UPDATE operations, so dependent rows are soft-deleted here. */
CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDeleteDependents
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE candidate
    SET candidate.IsPublished = 0,
        candidate.IsActive = 0,
        candidate.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories candidate
    INNER JOIN inserted play ON play.Id = candidate.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND candidate.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted play ON play.Id = assignment.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted play ON play.Id = fee.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted play ON play.Id = blacklist.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_SynchronizeSlug
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(PlayName)
        RETURN;

    DECLARE @PlayId uniqueidentifier;
    DECLARE @PlayName nvarchar(255);
    DECLARE @BaseSlug varchar(255);
    DECLARE @Slug varchar(255);
    DECLARE @Suffix varchar(12);
    DECLARE @Counter int;

    DECLARE ChangedPlays CURSOR LOCAL FAST_FORWARD FOR
        SELECT insertedRecord.Id, insertedRecord.PlayName
        FROM inserted AS insertedRecord
        INNER JOIN deleted AS deletedRecord ON deletedRecord.Id = insertedRecord.Id
        WHERE ISNULL(insertedRecord.PlayName, N'') <> ISNULL(deletedRecord.PlayName, N'')
        ORDER BY insertedRecord.Id;

    OPEN ChangedPlays;
    FETCH NEXT FROM ChangedPlays INTO @PlayId, @PlayName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @BaseSlug = dbo.ufn_CreatePlaySlug(@PlayName);
        SET @Slug = @BaseSlug;
        SET @Counter = 2;

        WHILE EXISTS
        (
            SELECT 1
            FROM dbo.Plays WITH (UPDLOCK, HOLDLOCK)
            WHERE Id <> @PlayId
              AND Slug = @Slug
        )
        BEGIN
            SET @Suffix = '-' + CONVERT(varchar(10), @Counter);
            SET @Slug = LEFT(@BaseSlug, 255 - LEN(@Suffix)) + @Suffix;
            SET @Counter += 1;
        END;

        UPDATE dbo.Plays
        SET Slug = @Slug
        WHERE Id = @PlayId
          AND ISNULL(Slug, '') <> @Slug;

        FETCH NEXT FROM ChangedPlays INTO @PlayId, @PlayName;
    END;

    CLOSE ChangedPlays;
    DEALLOCATE ChangedPlays;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_SynchronizeSourceForm
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    IF NOT
       (
           UPDATE(PlayName) OR UPDATE(TheaterName) OR UPDATE(Phone)
           OR UPDATE(ContactPersonName) OR UPDATE(ContactPersonPhone)
           OR UPDATE(Email) OR UPDATE(IsActive) OR UPDATE(IsPublished)
       )
        RETURN;

    DECLARE @AffectedPlayIdsJson nvarchar(max) =
    (
        SELECT changed.Id
        FROM inserted AS changed
        INNER JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE changed.SourceFormId IS NOT NULL
          AND EXISTS
          (
              SELECT CONVERT(varbinary(max), changed.PlayName),
                     CONVERT(varbinary(max), changed.TheaterName),
                     CONVERT(varbinary(max), changed.Phone),
                     CONVERT(varbinary(max), changed.ContactPersonName),
                     CONVERT(varbinary(max), changed.ContactPersonPhone),
                     CONVERT(varbinary(max), changed.Email),
                     changed.IsActive, changed.IsPublished
              EXCEPT
              SELECT CONVERT(varbinary(max), previous.PlayName),
                     CONVERT(varbinary(max), previous.TheaterName),
                     CONVERT(varbinary(max), previous.Phone),
                     CONVERT(varbinary(max), previous.ContactPersonName),
                     CONVERT(varbinary(max), previous.ContactPersonPhone),
                     CONVERT(varbinary(max), previous.Email),
                     previous.IsActive, previous.IsPublished
          )
        FOR JSON PATH
    );

    /* Empty FOR JSON assignments can be SQL NULL; NULL is the procedure's
       explicit full-maintenance API and must never come from an empty trigger. */
    IF @AffectedPlayIdsJson IS NULL OR @AffectedPlayIdsJson = N'[]' RETURN;
    EXEC dbo.usp_SynchronizePlayDataToForms
        @PlayIdsJson = @AffectedPlayIdsJson, @SyncCandidateData = 0;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayStatuses_SoftDelete ON dbo.PlayStatuses INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.PlayStatuses target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Rankings_BlockManualDelete
ON dbo.Rankings
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52003,
        N'Rankings rows cannot be deleted manually.',
        1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Rankings_BlockManualWrite
ON dbo.Rankings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'RankingsRefreshAuthorized')) <> 1
       OR SESSION_CONTEXT(N'RankingsRefreshAuthorized') IS NULL
    BEGIN
        THROW 52002,
            N'Rankings can only be changed by dbo.usp_RefreshRankings.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Roles_SoftDelete ON dbo.Roles INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Roles target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_PreventPublishedDateOverlap
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        INNER JOIN dbo.Seasons AS existing
            ON existing.Id <> changed.Id
           AND existing.IsPublished = 1
           AND changed.SeasonStartDate <= existing.SeasonEndDate
           AND changed.SeasonEndDate >= existing.SeasonStartDate
        WHERE changed.IsPublished = 1
    )
        THROW 51912, N'Yayımlanmış sezonların tarih aralıkları çakışamaz veya ortak sınır tarihine sahip olamaz.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_ReassignForms
ON dbo.Seasons AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1 RETURN;
    DECLARE @Changed TABLE (Id uniqueidentifier PRIMARY KEY);
    INSERT @Changed
    SELECT i.Id FROM inserted i LEFT JOIN deleted d ON d.Id = i.Id
    WHERE d.Id IS NULL OR EXISTS
        (SELECT i.SeasonStartDate, i.SeasonEndDate, i.IsPublished
         EXCEPT SELECT d.SeasonStartDate, d.SeasonEndDate, d.IsPublished);
    IF NOT EXISTS (SELECT 1 FROM @Changed) RETURN;
    DECLARE @ChangedSeasonsJson nvarchar(max) =
    (
        SELECT ranges.Id, ranges.SeasonStartDate AS StartDate, ranges.SeasonEndDate AS EndDate
        FROM
        (
            SELECT i.Id, i.SeasonStartDate, i.SeasonEndDate FROM inserted i INNER JOIN @Changed c ON c.Id = i.Id
            UNION SELECT d.Id, d.SeasonStartDate, d.SeasonEndDate FROM deleted d INNER JOIN @Changed c ON c.Id = d.Id
        ) ranges FOR JSON PATH
    );
    EXEC dbo.usp_ReassignFormSeasons @ChangedSeasonsJson = @ChangedSeasonsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_RefreshStatistics
ON dbo.Seasons AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT i.Id FROM inserted i LEFT JOIN deleted d ON d.Id = i.Id
        WHERE d.Id IS NULL OR EXISTS
            (SELECT i.SeasonStartDate, i.SeasonEndDate, i.IsPublished
             EXCEPT SELECT d.SeasonStartDate, d.SeasonEndDate, d.IsPublished)
        FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_SoftDelete
ON dbo.Seasons
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE season
    SET IsPublished = 0
    FROM dbo.Seasons AS season
    INNER JOIN deleted AS removed ON removed.Id = season.Id;

    /* The UPDATE trigger reassigns only these seasons' old/new ranges. */
END;
GO

/* Security metadata is append-only. Rotation/revocation append framework XML;
   old keys remain available for already issued cookies and antiforgery tokens.
   Never serialize this table's secret XML into the generic full-row audit. */
CREATE OR ALTER TRIGGER dbo.TR_SharedAdminDataProtectionKeys_AppendOnly
ON dbo.SharedAdminDataProtectionKeys
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) OR EXISTS (SELECT 1 FROM deleted)
        THROW 52750, N'Shared admin Data Protection keys are append-only.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDelete ON dbo.Users INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.Users target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDeleteDependents
ON dbo.Users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE vote SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes vote
    INNER JOIN inserted jury ON jury.Id = vote.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND vote.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted jury ON jury.Id = assignment.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted jury ON jury.Id = fee.UserId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted jury ON jury.Id = blacklist.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Users_ValidateGroupAssignment
ON dbo.Users
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(GroupCode) AND NOT UPDATE(IsPublished) AND NOT UPDATE(RoleCode) RETURN;

    /* Old relationships to an unpublished group remain editable. An old Code
       disappearing while its FK changes proves a parent-key cascade (the
       enabled FK forbids an orphan before this update), not a new membership.
       Restoring a deleted jury or promoting an admin to a published jury must
       also validate the group, even when the stored GroupCode stays the same. */
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS member
        LEFT JOIN deleted AS previousMember ON previousMember.Id = member.Id
        INNER JOIN dbo.[Group] AS selectedGroup WITH (HOLDLOCK)
            ON selectedGroup.Code = member.GroupCode
        WHERE member.GroupCode IS NOT NULL
          AND
          (
              previousMember.Id IS NULL OR previousMember.GroupCode IS NULL
              OR (previousMember.GroupCode <> member.GroupCode AND EXISTS
                  (SELECT 1 FROM dbo.[Group] AS previousGroup WITH (HOLDLOCK)
                   WHERE previousGroup.Code = previousMember.GroupCode))
              OR (member.RoleCode = 2 AND member.IsPublished = 1
                  AND (previousMember.IsPublished = 0 OR previousMember.RoleCode <> 2))
          )
          AND selectedGroup.IsPublished = 0
    )
        THROW 52821, N'Yalnızca yayındaki jüri grupları seçilebilir. Grup listesini yenileyip tekrar deneyin.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_UsersLog_SoftDelete ON dbo.UsersLog INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.UsersLog target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

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
  /* Crypto XML is secret framework metadata, not a business-row audit payload. */
  AND NOT (schemaInfo.name = N'dbo' AND tableInfo.name IN (N'AdminLogs', N'JuryLogs', N'UsersLog', N'JuryPasswordResetTokens', N'SharedAdminDataProtectionKeys', N'__EFMigrationsHistory'))
  AND NOT (schemaInfo.name = N'dbo' AND tableInfo.name LIKE N'\_\_Archived\_SharedAdminDataProtectionKeys\_%' ESCAPE N'\')
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

SET XACT_ABORT ON;

/*
   Bootstrap immutable integration rows before foreign keys, procedures and
   Form-to-Play synchronization are installed. Existing code rows are never
   renumbered or replaced; schema validation checks their canonical values.
*/
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleCode = 1)
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Id = '10000000-0000-0000-0000-000000000001')
        THROW 51030, 'Reference bootstrap blocked: canonical coordinator role Id is already used.', 1;
    INSERT INTO dbo.Roles (Id, RoleName, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode)
    VALUES ('10000000-0000-0000-0000-000000000001', N'Koordinatör', '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1, 1);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleCode = 2)
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Id = '10000000-0000-0000-0000-000000000002')
        THROW 51031, 'Reference bootstrap blocked: canonical jury role Id is already used.', 1;
    INSERT INTO dbo.Roles (Id, RoleName, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode)
    VALUES ('10000000-0000-0000-0000-000000000002', N'Jüri', '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1, 2);
END;
UPDATE dbo.Roles
SET RoleName = CASE RoleCode WHEN 1 THEN N'Koordinatör' WHEN 2 THEN N'Jüri' END,
    IsPublished = 1
WHERE RoleCode IN (1, 2);

DECLARE @PlayStatuses TABLE
(
    Id uniqueidentifier NOT NULL,
    StatusCode int NOT NULL,
    StatusName nvarchar(100) NOT NULL,
    StatusColor nvarchar(50) NOT NULL
);

INSERT INTO @PlayStatuses (Id, StatusCode, StatusName, StatusColor)
VALUES
    ('30000000-0000-0000-0000-000000000001', 1, N'Oylama Aktif', N'#27ae60'),
    ('30000000-0000-0000-0000-000000000002', 2, N'Değerlendirmeyecek Oyun', N'#d9322d'),
    ('30000000-0000-0000-0000-000000000003', 3, N'Başvuru Yapmayacak Oyun', N'#2CA9E8'),
    ('30000000-0000-0000-0000-000000000004', 4, N'Sahnelenmeyecek Oyun', N'#ac48ed'),
    ('30000000-0000-0000-0000-000000000005', 5, N'Başvurusu Olmayan Oyun', N'#ffffff'),
    ('30000000-0000-0000-0000-000000000006', 6, N'Sistemde Aktif Değil', N'#ffc400');

IF EXISTS
(
    SELECT 1
    FROM @PlayStatuses AS source
    INNER JOIN dbo.PlayStatuses AS target ON target.Id = source.Id
    WHERE target.StatusCode <> source.StatusCode
)
    THROW 51032, 'Reference bootstrap blocked: a canonical PlayStatuses Id is assigned to another code.', 1;

INSERT INTO dbo.PlayStatuses
    (Id, StatusName, StatusCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, StatusColor)
SELECT source.Id, source.StatusName, source.StatusCode,
       '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1, source.StatusColor
FROM @PlayStatuses AS source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.PlayStatuses AS target
    WHERE target.StatusCode = source.StatusCode
);
UPDATE target
SET StatusName = source.StatusName,
    StatusColor = source.StatusColor,
    IsPublished = 1
FROM dbo.PlayStatuses AS target
INNER JOIN @PlayStatuses AS source ON source.StatusCode = target.StatusCode;

DECLARE @AwardCategories TABLE
(
    Id uniqueidentifier NOT NULL,
    CategoryCode int NOT NULL,
    CategoryName nvarchar(255) NOT NULL,
    MultiCandidate bit NOT NULL,
    HasRoleAndPhoto bit NOT NULL
);

INSERT INTO @AwardCategories (Id, CategoryCode, CategoryName, MultiCandidate, HasRoleAndPhoto)
VALUES
    ('40000000-0000-0000-0000-000000000001', 1001, N'Yılın En Başarılı Oyunu', 0, 0),
    ('40000000-0000-0000-0000-000000000002', 1002, N'Yılın En Başarılı Yönetmeni', 0, 1),
    ('40000000-0000-0000-0000-000000000003', 1003, N'Yılın En Başarılı Kadın Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000004', 1004, N'Yılın En Başarılı Erkek Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000005', 1005, N'Yardımcı Rolde Yılın En Başarılı Kadın Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000006', 1006, N'Yardımcı Rolde Yılın En Başarılı Erkek Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000007', 1007, N'Yılın En Başarılı Sahne Tasarımı', 1, 1),
    ('40000000-0000-0000-0000-000000000008', 1008, N'Yılın En Başarılı Giysi Tasarımı', 1, 1),
    ('40000000-0000-0000-0000-000000000010', 1009, N'Yılın En Başarılı Sahne Müziği', 1, 1),
    ('40000000-0000-0000-0000-000000000009', 1010, N'Yılın En Başarılı Işık Tasarımı', 1, 1),
    ('40000000-0000-0000-0000-000000000012', 1011, N'Yılın En Başarılı Hareket Tasarımı (Kareografisi)', 1, 1);

IF EXISTS
(
    SELECT 1
    FROM @AwardCategories AS source
    INNER JOIN dbo.AwardCategories AS target ON target.Id = source.Id
    WHERE target.CategoryCode <> source.CategoryCode
)
    THROW 51033, 'Reference bootstrap blocked: a canonical AwardCategories Id is assigned to another code.', 1;

INSERT INTO dbo.AwardCategories
    (Id, CategoryName, CategoryCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
     IsPublished, MultiCandidate, HasRoleAndPhoto)
SELECT source.Id, source.CategoryName, source.CategoryCode,
       '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1,
       source.MultiCandidate, source.HasRoleAndPhoto
FROM @AwardCategories AS source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.AwardCategories AS target
    WHERE target.CategoryCode = source.CategoryCode
);
UPDATE target
SET CategoryName = source.CategoryName,
    IsPublished = 1
FROM dbo.AwardCategories AS target
INNER JOIN @AwardCategories AS source ON source.CategoryCode = target.CategoryCode;

/* Category 1012 is retired. Retain the FK target as unpublished history so
   existing candidate/vote/audit rows remain referentially valid. */
UPDATE dbo.AwardCategories
SET IsPublished = 0,
    UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
WHERE CategoryCode = 1012
  AND IsPublished = 1;

IF COL_LENGTH(N'dbo.AwardCategories', N'MultiCandidate') IS NOT NULL
   AND COL_LENGTH(N'dbo.AwardCategories', N'HasRoleAndPhoto') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
    UPDATE dbo.AwardCategories
    SET MultiCandidate = CASE WHEN CategoryCode BETWEEN 1003 AND 1011 THEN 1 ELSE 0 END,
        HasRoleAndPhoto = CASE WHEN CategoryCode BETWEEN 1002 AND 1011 THEN 1 ELSE 0 END
    WHERE CategoryCode BETWEEN 1001 AND 1011;';
END;
GO

SET XACT_ABORT ON;

/* Fixed integration keys. Insert missing rows only; never reset an administrator's
   true/false choice, timestamps or existing Id on deployment or migration replay. */
DECLARE @HomePageTables TABLE
(
    Id uniqueidentifier NOT NULL,
    ConfigName nvarchar(255) NOT NULL
);
INSERT INTO @HomePageTables (Id, ConfigName)
VALUES
    ('60000000-0000-0000-0000-000000000001', N'HomePageJuryTableEnabled'),
    ('60000000-0000-0000-0000-000000000002', N'HomePageMissionTableEnabled'),
    ('60000000-0000-0000-0000-000000000003', N'HomePageMostWatchedTableEnabled'),
    ('60000000-0000-0000-0000-000000000004', N'HomePageLeastWatchedTableEnabled');

IF EXISTS
(
    SELECT target.ConfigName
    FROM dbo.Configs AS target
    INNER JOIN @HomePageTables AS source ON source.ConfigName = target.ConfigName
    GROUP BY target.ConfigName
    HAVING COUNT_BIG(*) > 1
)
    THROW 53210, N'Jüri ana ekran tablo ayarı birden fazla kayda sahip. Veriler korunarak migration durduruldu.', 1;

IF EXISTS
(
    SELECT 1 FROM dbo.Configs AS target
    INNER JOIN @HomePageTables AS source ON source.ConfigName = target.ConfigName
    WHERE target.ConfigName COLLATE Latin1_General_100_BIN2 <> source.ConfigName
       OR DATALENGTH(target.ConfigName) <> DATALENGTH(source.ConfigName)
       OR target.ConfigValue COLLATE Latin1_General_100_BIN2 NOT IN (N'true', N'false')
       OR DATALENGTH(target.ConfigValue) <> CASE WHEN target.ConfigValue COLLATE Latin1_General_100_BIN2 = N'true' THEN 8 ELSE 10 END
)
    THROW 53211, N'Jüri ana ekran tablo ayarının adı veya true/false değeri geçersiz. Mevcut değer değiştirilmedi.', 1;

IF EXISTS
(
    SELECT 1 FROM @HomePageTables AS source
    INNER JOIN dbo.Configs AS target ON target.id = source.Id
    WHERE target.ConfigName <> source.ConfigName
      AND NOT EXISTS (SELECT 1 FROM dbo.Configs AS existing WHERE existing.ConfigName = source.ConfigName)
)
    THROW 53212, N'Jüri ana ekran tablo ayarı için başlangıç ID değeri başka bir kayıtta kullanılıyor.', 1;

DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
INSERT INTO dbo.Configs
    (id, ConfigName, ConfigValue, created_at, created_by, updated_at, updated_by, IsPublished)
SELECT source.Id, source.ConfigName, N'true', @Now, NULL, @Now, NULL, 1
FROM @HomePageTables AS source
WHERE NOT EXISTS (SELECT 1 FROM dbo.Configs AS target WHERE target.ConfigName = source.ConfigName);

/* Repair a historical soft-delete without changing the saved visibility choice. */
UPDATE target SET IsPublished = 1
FROM dbo.Configs AS target
INNER JOIN @HomePageTables AS source ON source.ConfigName = target.ConfigName
WHERE target.IsPublished = 0;
GO

-- </AFIFE:CANONICAL>
-- <AFIFE:SHA256:REFERENCES=7F5F7A17B7098C170D18B258FF321EE716EA3CA4C817115CD2B1BE0CFB018B2A>
-- <AFIFE:SHA256-LF:REFERENCES=7F5F7A17B7098C170D18B258FF321EE716EA3CA4C817115CD2B1BE0CFB018B2A:BA12094AB3E96C919980C27300659BC2A067DA5AA13F9A323E9BC0880252ABB7>
-- <AFIFE:BATCHES:REFERENCES=2>
-- <AFIFE:REFERENCES>
SET XACT_ABORT ON;

/*
   Bootstrap immutable integration rows before foreign keys, procedures and
   Form-to-Play synchronization are installed. Existing code rows are never
   renumbered or replaced; schema validation checks their canonical values.
*/
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleCode = 1)
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Id = '10000000-0000-0000-0000-000000000001')
        THROW 51030, 'Reference bootstrap blocked: canonical coordinator role Id is already used.', 1;
    INSERT INTO dbo.Roles (Id, RoleName, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode)
    VALUES ('10000000-0000-0000-0000-000000000001', N'Koordinatör', '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1, 1);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleCode = 2)
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Roles WHERE Id = '10000000-0000-0000-0000-000000000002')
        THROW 51031, 'Reference bootstrap blocked: canonical jury role Id is already used.', 1;
    INSERT INTO dbo.Roles (Id, RoleName, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, RoleCode)
    VALUES ('10000000-0000-0000-0000-000000000002', N'Jüri', '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1, 2);
END;
UPDATE dbo.Roles
SET RoleName = CASE RoleCode WHEN 1 THEN N'Koordinatör' WHEN 2 THEN N'Jüri' END,
    IsPublished = 1
WHERE RoleCode IN (1, 2);

DECLARE @PlayStatuses TABLE
(
    Id uniqueidentifier NOT NULL,
    StatusCode int NOT NULL,
    StatusName nvarchar(100) NOT NULL,
    StatusColor nvarchar(50) NOT NULL
);

INSERT INTO @PlayStatuses (Id, StatusCode, StatusName, StatusColor)
VALUES
    ('30000000-0000-0000-0000-000000000001', 1, N'Oylama Aktif', N'#27ae60'),
    ('30000000-0000-0000-0000-000000000002', 2, N'Değerlendirmeyecek Oyun', N'#d9322d'),
    ('30000000-0000-0000-0000-000000000003', 3, N'Başvuru Yapmayacak Oyun', N'#2CA9E8'),
    ('30000000-0000-0000-0000-000000000004', 4, N'Sahnelenmeyecek Oyun', N'#ac48ed'),
    ('30000000-0000-0000-0000-000000000005', 5, N'Başvurusu Olmayan Oyun', N'#ffffff'),
    ('30000000-0000-0000-0000-000000000006', 6, N'Sistemde Aktif Değil', N'#ffc400');

IF EXISTS
(
    SELECT 1
    FROM @PlayStatuses AS source
    INNER JOIN dbo.PlayStatuses AS target ON target.Id = source.Id
    WHERE target.StatusCode <> source.StatusCode
)
    THROW 51032, 'Reference bootstrap blocked: a canonical PlayStatuses Id is assigned to another code.', 1;

INSERT INTO dbo.PlayStatuses
    (Id, StatusName, StatusCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, StatusColor)
SELECT source.Id, source.StatusName, source.StatusCode,
       '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1, source.StatusColor
FROM @PlayStatuses AS source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.PlayStatuses AS target
    WHERE target.StatusCode = source.StatusCode
);
UPDATE target
SET StatusName = source.StatusName,
    StatusColor = source.StatusColor,
    IsPublished = 1
FROM dbo.PlayStatuses AS target
INNER JOIN @PlayStatuses AS source ON source.StatusCode = target.StatusCode;

DECLARE @AwardCategories TABLE
(
    Id uniqueidentifier NOT NULL,
    CategoryCode int NOT NULL,
    CategoryName nvarchar(255) NOT NULL,
    MultiCandidate bit NOT NULL,
    HasRoleAndPhoto bit NOT NULL
);

INSERT INTO @AwardCategories (Id, CategoryCode, CategoryName, MultiCandidate, HasRoleAndPhoto)
VALUES
    ('40000000-0000-0000-0000-000000000001', 1001, N'Yılın En Başarılı Oyunu', 0, 0),
    ('40000000-0000-0000-0000-000000000002', 1002, N'Yılın En Başarılı Yönetmeni', 0, 1),
    ('40000000-0000-0000-0000-000000000003', 1003, N'Yılın En Başarılı Kadın Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000004', 1004, N'Yılın En Başarılı Erkek Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000005', 1005, N'Yardımcı Rolde Yılın En Başarılı Kadın Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000006', 1006, N'Yardımcı Rolde Yılın En Başarılı Erkek Oyuncusu', 1, 1),
    ('40000000-0000-0000-0000-000000000007', 1007, N'Yılın En Başarılı Sahne Tasarımı', 1, 1),
    ('40000000-0000-0000-0000-000000000008', 1008, N'Yılın En Başarılı Giysi Tasarımı', 1, 1),
    ('40000000-0000-0000-0000-000000000010', 1009, N'Yılın En Başarılı Sahne Müziği', 1, 1),
    ('40000000-0000-0000-0000-000000000009', 1010, N'Yılın En Başarılı Işık Tasarımı', 1, 1),
    ('40000000-0000-0000-0000-000000000012', 1011, N'Yılın En Başarılı Hareket Tasarımı (Kareografisi)', 1, 1);

IF EXISTS
(
    SELECT 1
    FROM @AwardCategories AS source
    INNER JOIN dbo.AwardCategories AS target ON target.Id = source.Id
    WHERE target.CategoryCode <> source.CategoryCode
)
    THROW 51033, 'Reference bootstrap blocked: a canonical AwardCategories Id is assigned to another code.', 1;

INSERT INTO dbo.AwardCategories
    (Id, CategoryName, CategoryCode, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
     IsPublished, MultiCandidate, HasRoleAndPhoto)
SELECT source.Id, source.CategoryName, source.CategoryCode,
       '2026-07-16T15:39:19.4137221', NULL, NULL, NULL, 1,
       source.MultiCandidate, source.HasRoleAndPhoto
FROM @AwardCategories AS source
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.AwardCategories AS target
    WHERE target.CategoryCode = source.CategoryCode
);
UPDATE target
SET CategoryName = source.CategoryName,
    IsPublished = 1
FROM dbo.AwardCategories AS target
INNER JOIN @AwardCategories AS source ON source.CategoryCode = target.CategoryCode;

/* Category 1012 is retired. Retain the FK target as unpublished history so
   existing candidate/vote/audit rows remain referentially valid. */
UPDATE dbo.AwardCategories
SET IsPublished = 0,
    UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
WHERE CategoryCode = 1012
  AND IsPublished = 1;

IF COL_LENGTH(N'dbo.AwardCategories', N'MultiCandidate') IS NOT NULL
   AND COL_LENGTH(N'dbo.AwardCategories', N'HasRoleAndPhoto') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
    UPDATE dbo.AwardCategories
    SET MultiCandidate = CASE WHEN CategoryCode BETWEEN 1003 AND 1011 THEN 1 ELSE 0 END,
        HasRoleAndPhoto = CASE WHEN CategoryCode BETWEEN 1002 AND 1011 THEN 1 ELSE 0 END
    WHERE CategoryCode BETWEEN 1001 AND 1011;';
END;
GO

SET XACT_ABORT ON;

/* Fixed integration keys. Insert missing rows only; never reset an administrator's
   true/false choice, timestamps or existing Id on deployment or migration replay. */
DECLARE @HomePageTables TABLE
(
    Id uniqueidentifier NOT NULL,
    ConfigName nvarchar(255) NOT NULL
);
INSERT INTO @HomePageTables (Id, ConfigName)
VALUES
    ('60000000-0000-0000-0000-000000000001', N'HomePageJuryTableEnabled'),
    ('60000000-0000-0000-0000-000000000002', N'HomePageMissionTableEnabled'),
    ('60000000-0000-0000-0000-000000000003', N'HomePageMostWatchedTableEnabled'),
    ('60000000-0000-0000-0000-000000000004', N'HomePageLeastWatchedTableEnabled');

IF EXISTS
(
    SELECT target.ConfigName
    FROM dbo.Configs AS target
    INNER JOIN @HomePageTables AS source ON source.ConfigName = target.ConfigName
    GROUP BY target.ConfigName
    HAVING COUNT_BIG(*) > 1
)
    THROW 53210, N'Jüri ana ekran tablo ayarı birden fazla kayda sahip. Veriler korunarak migration durduruldu.', 1;

IF EXISTS
(
    SELECT 1 FROM dbo.Configs AS target
    INNER JOIN @HomePageTables AS source ON source.ConfigName = target.ConfigName
    WHERE target.ConfigName COLLATE Latin1_General_100_BIN2 <> source.ConfigName
       OR DATALENGTH(target.ConfigName) <> DATALENGTH(source.ConfigName)
       OR target.ConfigValue COLLATE Latin1_General_100_BIN2 NOT IN (N'true', N'false')
       OR DATALENGTH(target.ConfigValue) <> CASE WHEN target.ConfigValue COLLATE Latin1_General_100_BIN2 = N'true' THEN 8 ELSE 10 END
)
    THROW 53211, N'Jüri ana ekran tablo ayarının adı veya true/false değeri geçersiz. Mevcut değer değiştirilmedi.', 1;

IF EXISTS
(
    SELECT 1 FROM @HomePageTables AS source
    INNER JOIN dbo.Configs AS target ON target.id = source.Id
    WHERE target.ConfigName <> source.ConfigName
      AND NOT EXISTS (SELECT 1 FROM dbo.Configs AS existing WHERE existing.ConfigName = source.ConfigName)
)
    THROW 53212, N'Jüri ana ekran tablo ayarı için başlangıç ID değeri başka bir kayıtta kullanılıyor.', 1;

DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
INSERT INTO dbo.Configs
    (id, ConfigName, ConfigValue, created_at, created_by, updated_at, updated_by, IsPublished)
SELECT source.Id, source.ConfigName, N'true', @Now, NULL, @Now, NULL, 1
FROM @HomePageTables AS source
WHERE NOT EXISTS (SELECT 1 FROM dbo.Configs AS target WHERE target.ConfigName = source.ConfigName);

/* Repair a historical soft-delete without changing the saved visibility choice. */
UPDATE target SET IsPublished = 1
FROM dbo.Configs AS target
INNER JOIN @HomePageTables AS source ON source.ConfigName = target.ConfigName
WHERE target.IsPublished = 0;
GO

-- </AFIFE:REFERENCES>
-- <AFIFE:SHA256:UP=6E6B8E64CBF94669D73450AE2EB83121BC5072FDCA1AD1F29A784D2AB5B5D301>
-- <AFIFE:SHA256-LF:UP=6E6B8E64CBF94669D73450AE2EB83121BC5072FDCA1AD1F29A784D2AB5B5D301:76EDCD8891A264C9E4D8CF0B55A15E3313D69358FBDCBC9DA752FB5CF6EE5A64>
-- <AFIFE:BATCHES:UP=75>
-- <AFIFE:UP>
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
GO

SET XACT_ABORT ON;

/* Legacy releases enforced one current row per play/category and therefore
   blocked the RoleCode-based multi-candidate contract introduced for 1003-1012.
   Remove only the known obsolete index before any historical migration invokes
   the current Form synchronization procedure. Rows are not changed. */
IF EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
      AND name = N'UX_PlayAwardCategories_PlayId_IsCurrent_AwardCategoryCode'
)
    DROP INDEX [UX_PlayAwardCategories_PlayId_IsCurrent_AwardCategoryCode]
        ON [dbo].[PlayAwardCategories];

/* Some company databases use a different name for the same obsolete filtered
   index. Detect its shape as well: unique PlayId+AwardCategoryCode keys, filtered
   to current rows, without RoleCode. Canonical indexes all include RoleCode or
   have a different key shape. */
DECLARE @ObsoleteCurrentCategoryIndex sysname;
SELECT TOP (1) @ObsoleteCurrentCategoryIndex = candidateIndex.name
FROM sys.indexes AS candidateIndex
WHERE candidateIndex.object_id = OBJECT_ID(N'dbo.PlayAwardCategories')
  AND candidateIndex.is_unique = 1
  AND candidateIndex.has_filter = 1
  AND candidateIndex.filter_definition LIKE N'%IsCurrent%'
  AND
  (
      SELECT COUNT(*)
      FROM sys.index_columns AS indexColumn
      WHERE indexColumn.object_id = candidateIndex.object_id
        AND indexColumn.index_id = candidateIndex.index_id
        AND indexColumn.key_ordinal > 0
  ) = 2
  AND EXISTS
  (
      SELECT 1
      FROM sys.index_columns AS indexColumn
      INNER JOIN sys.columns AS columnRecord
          ON columnRecord.object_id = indexColumn.object_id
         AND columnRecord.column_id = indexColumn.column_id
      WHERE indexColumn.object_id = candidateIndex.object_id
        AND indexColumn.index_id = candidateIndex.index_id
        AND indexColumn.key_ordinal > 0
        AND columnRecord.name = N'PlayId'
  )
  AND EXISTS
  (
      SELECT 1
      FROM sys.index_columns AS indexColumn
      INNER JOIN sys.columns AS columnRecord
          ON columnRecord.object_id = indexColumn.object_id
         AND columnRecord.column_id = indexColumn.column_id
      WHERE indexColumn.object_id = candidateIndex.object_id
        AND indexColumn.index_id = candidateIndex.index_id
        AND indexColumn.key_ordinal > 0
        AND columnRecord.name = N'AwardCategoryCode'
  );

IF @ObsoleteCurrentCategoryIndex IS NOT NULL
BEGIN
    DECLARE @DropObsoleteCurrentCategoryIndexSql nvarchar(max) =
        N'DROP INDEX ' + QUOTENAME(@ObsoleteCurrentCategoryIndex) +
        N' ON dbo.PlayAwardCategories;';
    EXEC sys.sp_executesql @DropObsoleteCurrentCategoryIndexSql;
END;

/*
   CREATE OR ALTER still validates referenced columns while compiling modules.
   Keep every additive column required by Programmability.sql here so historical
   migrations that execute the current resource can safely upgrade legacy tables.
*/
IF OBJECT_ID(N'dbo.Form', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
BEGIN
    EXEC sys.sp_executesql
        N'ALTER TABLE dbo.Form ADD YoungGenerationArtist nvarchar(max) NULL;';
END;

IF OBJECT_ID(N'dbo.Form', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
    THROW 52421, N'Programmability ön koşulu başarısız: dbo.Form.YoungGenerationArtist oluşturulamadı.', 1;

IF OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.PlayAwardCategories', N'SourceFormCandidateOrder') IS NULL
BEGIN
    EXEC sys.sp_executesql
        N'ALTER TABLE dbo.PlayAwardCategories ADD SourceFormCandidateOrder int NULL;';
END;

IF OBJECT_ID(N'dbo.PlayAwardCategories', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.PlayAwardCategories', N'SourceFormCandidateOrder') IS NULL
    THROW 52422, N'Programmability ön koşulu başarısız: dbo.PlayAwardCategories.SourceFormCandidateOrder oluşturulamadı.', 1;
GO

CREATE OR ALTER FUNCTION dbo.ufn_CreatePlaySlug(@Value nvarchar(255))
RETURNS varchar(255)
AS
BEGIN
    DECLARE @Input nvarchar(255) = ISNULL(@Value, N'');
    DECLARE @Result varchar(255) = '';
    DECLARE @Position int = 1;
    DECLARE @PendingSeparator bit = 0;
    DECLARE @Character nchar(1);
    DECLARE @CodePoint int;

    WHILE @Position <= LEN(@Input) AND LEN(@Result) < 255
    BEGIN
        SET @Character = SUBSTRING(@Input, @Position, 1);
        SET @Character = CASE @Character COLLATE Latin1_General_100_BIN2
            WHEN N'ç' THEN N'c' WHEN N'Ç' THEN N'c'
            WHEN N'ğ' THEN N'g' WHEN N'Ğ' THEN N'g'
            WHEN N'ı' THEN N'i' WHEN N'İ' THEN N'i'
            WHEN N'ö' THEN N'o' WHEN N'Ö' THEN N'o'
            WHEN N'ş' THEN N's' WHEN N'Ş' THEN N's'
            WHEN N'ü' THEN N'u' WHEN N'Ü' THEN N'u'
            ELSE LOWER(@Character COLLATE Latin1_General_100_CI_AS)
        END;
        SET @CodePoint = UNICODE(@Character);

        IF @CodePoint BETWEEN 48 AND 57 OR @CodePoint BETWEEN 97 AND 122
        BEGIN
            IF @PendingSeparator = 1 AND LEN(@Result) > 0
            BEGIN
                IF LEN(@Result) >= 254
                    BREAK;

                SET @Result += '-';
            END;

            IF LEN(@Result) < 255
                SET @Result += CONVERT(varchar(1), @Character);

            SET @PendingSeparator = 0;
        END
        ELSE IF LEN(@Result) > 0
            SET @PendingSeparator = 1;

        SET @Position += 1;
    END;

    RETURN CASE WHEN LEN(@Result) = 0 THEN 'oyun' ELSE @Result END;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_ReassignFormSeasons]
    @ChangedSeasonsJson nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    CREATE TABLE #ChangedSeasonRanges
    (Id uniqueidentifier NOT NULL, StartDate date NOT NULL, EndDate date NOT NULL);
    IF @ChangedSeasonsJson IS NOT NULL
    BEGIN
        IF ISJSON(@ChangedSeasonsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@ChangedSeasonsJson, CHAR(9), N' '), CHAR(10), N' '), CHAR(13), N' ')), 1) <> N'['
            THROW 52742, N'Changed seasons must be an array.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@ChangedSeasonsJson) AS item
            OUTER APPLY OPENJSON(CASE WHEN item.type = 5 THEN item.value ELSE N'{}' END)
                WITH (Id nvarchar(max), StartDate nvarchar(max), EndDate nvarchar(max)) AS scope
            WHERE item.type <> 5 OR scope.Id IS NULL OR DATALENGTH(scope.Id) <> 72
               OR TRY_CONVERT(uniqueidentifier, scope.Id) IS NULL
               OR scope.StartDate IS NULL OR scope.EndDate IS NULL
               OR TRY_CONVERT(date, scope.StartDate, 23) IS NULL
               OR TRY_CONVERT(date, scope.EndDate, 23) IS NULL
               OR TRY_CONVERT(date, scope.StartDate, 23) >= TRY_CONVERT(date, scope.EndDate, 23)
        ) THROW 52742, N'Changed season range is invalid.', 1;
        INSERT #ChangedSeasonRanges
        SELECT DISTINCT CONVERT(uniqueidentifier, Id), CONVERT(date, StartDate, 23), CONVERT(date, EndDate, 23)
        FROM OPENJSON(@ChangedSeasonsJson) WITH (Id nvarchar(36), StartDate nvarchar(10), EndDate nvarchar(10));
    END;

    CREATE TABLE #SeasonForms (Id uniqueidentifier NOT NULL PRIMARY KEY);
    IF @ChangedSeasonsJson IS NULL
        INSERT #SeasonForms SELECT Id FROM dbo.Form;
    ELSE
        INSERT #SeasonForms
        SELECT formRecord.Id FROM #ChangedSeasonRanges AS changed
        INNER JOIN dbo.Form AS formRecord
            ON formRecord.CreatedDate >= CONVERT(datetime, changed.StartDate)
           AND formRecord.CreatedDate < CONVERT(datetime, changed.EndDate)
        UNION
        SELECT formRecord.Id FROM #ChangedSeasonRanges AS changed
        INNER JOIN dbo.Form AS formRecord ON formRecord.SeasonId = changed.Id;

    BEGIN TRY
        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = 1;

        UPDATE formRecord
        SET SeasonId = selectedSeason.Id
        FROM dbo.Form AS formRecord
        INNER JOIN #SeasonForms AS affected ON affected.Id = formRecord.Id
        OUTER APPLY
        (
            SELECT TOP (1) season.Id
            FROM dbo.Seasons AS season
            WHERE season.IsPublished = 1
              AND formRecord.CreatedDate IS NOT NULL
              AND formRecord.CreatedDate >= CONVERT(datetime, season.SeasonStartDate)
              AND formRecord.CreatedDate < CONVERT(datetime, season.SeasonEndDate)
            ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
        ) AS selectedSeason
        WHERE formRecord.SeasonId <> selectedSeason.Id
           OR (formRecord.SeasonId IS NULL AND selectedSeason.Id IS NOT NULL)
           OR (formRecord.SeasonId IS NOT NULL AND selectedSeason.Id IS NULL);

        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'FormSeasonAssignmentSyncInProgress', @value = NULL;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_RefreshRankings]
    @CategoryCodesJson nvarchar(max) = NULL,
    @CandidateIdsJson nvarchar(max) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'RankingsRefreshInProgress')) = 1
        RETURN;

    /* Explicit maintenance keeps the historical full-rebuild contract. Normal
       DML supplies old/new categories and dirty candidate IDs. Rankings depend
       on peers in the same category, but their unchanged votes need no reread. */
    DECLARE @FullRefresh bit = CASE WHEN @CategoryCodesJson IS NULL THEN 1 ELSE 0 END;
    CREATE TABLE #RankingAffectedCategories (CategoryCode int NOT NULL PRIMARY KEY);
    CREATE TABLE #RankingDirtyCandidates (CandidateId uniqueidentifier NOT NULL PRIMARY KEY);
    CREATE TABLE #RankingCategoryLocks
    (
        CategoryCode int NOT NULL PRIMARY KEY,
        IsAcquired bit NOT NULL DEFAULT (0)
    );

    IF @CategoryCodesJson IS NULL AND @CandidateIdsJson IS NOT NULL
        THROW 52740, N'Aday kapsamı için ödül kategorisi kapsamı da gereklidir.', 1;

    IF @CategoryCodesJson IS NOT NULL
    BEGIN
        IF ISJSON(@CategoryCodesJson) <> 1 OR LEFT(LTRIM(@CategoryCodesJson), 1) <> N'['
            THROW 52740, N'Sıralama kapsamı geçerli bir CategoryCode dizisi olmalıdır.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@CategoryCodesJson) AS item
            WHERE item.[type] <> 5 OR TRY_CONVERT(int,
                JSON_VALUE(CASE WHEN item.[type] = 5 THEN item.[value] ELSE N'{}' END, N'$.CategoryCode')) IS NULL
        )
            THROW 52740, N'Sıralama kapsamı geçerli bir CategoryCode dizisi olmalıdır.', 1;
        INSERT INTO #RankingAffectedCategories (CategoryCode)
        SELECT DISTINCT CONVERT(int, JSON_VALUE(item.[value], N'$.CategoryCode'))
        FROM OPENJSON(@CategoryCodesJson) AS item;
    END;

    IF @CandidateIdsJson IS NOT NULL
    BEGIN
        IF ISJSON(@CandidateIdsJson) <> 1 OR LEFT(LTRIM(@CandidateIdsJson), 1) <> N'['
            THROW 52740, N'Sıralama aday kapsamı geçerli bir Id dizisi olmalıdır.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@CandidateIdsJson) AS item
            WHERE item.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN item.[type] = 5 THEN item.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier,
                   JSON_VALUE(CASE WHEN item.[type] = 5 THEN item.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52740, N'Sıralama aday kapsamı geçerli bir Id dizisi olmalıdır.', 1;
        INSERT INTO #RankingDirtyCandidates (CandidateId)
        SELECT DISTINCT CONVERT(uniqueidentifier, JSON_VALUE(item.[value], N'$.Id'))
        FROM OPENJSON(@CandidateIdsJson) AS item;
    END;

    IF @FullRefresh = 0
       AND NOT EXISTS (SELECT 1 FROM #RankingAffectedCategories)
       AND NOT EXISTS (SELECT 1 FROM #RankingDirtyCandidates)
        RETURN;

    DECLARE @ApplicationLockResult int;
    DECLARE @GlobalLockMode nvarchar(32) = CASE WHEN @FullRefresh = 1 THEN N'Exclusive' ELSE N'Shared' END;
    DECLARE @LockedCategory int;
    DECLARE @CategoryLockResource nvarchar(255);
    /* Scalar variables survive a deadlock victim's transaction rollback. A
       temp-table acquisition log does not, while session-owned locks survive. */
    DECLARE @AcquiredCategoryLocks nvarchar(max) = N'';
    DECLARE @CategoryLockDelimiter int;
    EXEC @ApplicationLockResult = sys.sp_getapplock
        @Resource = N'AfifeAdmin.Rankings.Refresh',
        @LockMode = @GlobalLockMode,
        @LockOwner = N'Session',
        @LockTimeout = 30000;

    IF @ApplicationLockResult < 0
        THROW 52001, N'Rankings refresh lock could not be acquired.', 1;

    EXEC sys.sp_set_session_context
        @key = N'RankingsRefreshInProgress',
        @value = 1;
    EXEC sys.sp_set_session_context
        @key = N'RankingsRefreshAuthorized',
        @value = 1;

    BEGIN TRY
        IF @FullRefresh = 1
            INSERT INTO #RankingAffectedCategories (CategoryCode)
            SELECT DISTINCT AwardCategoryCode FROM dbo.PlayAwardCategories;
        ELSE
            /* A moved dirty candidate brings its new category even if a caller
               only supplied its previous category. */
            INSERT INTO #RankingAffectedCategories (CategoryCode)
            SELECT DISTINCT candidate.AwardCategoryCode
            FROM dbo.PlayAwardCategories AS candidate
            INNER JOIN #RankingDirtyCandidates AS dirty ON dirty.CandidateId = candidate.Id
            WHERE NOT EXISTS
            (
                SELECT 1 FROM #RankingAffectedCategories AS affected
                WHERE affected.CategoryCode = candidate.AwardCategoryCode
            );

        /* Different categories can refresh concurrently. Full maintenance takes
           the global lock exclusively; scoped callers share it and acquire all
           their category locks in numeric order, including both sides of moves. */
        IF @FullRefresh = 0
        BEGIN
            INSERT INTO #RankingCategoryLocks (CategoryCode)
            SELECT CategoryCode FROM #RankingAffectedCategories;
            WHILE EXISTS (SELECT 1 FROM #RankingCategoryLocks WHERE IsAcquired = 0)
            BEGIN
                SELECT TOP (1) @LockedCategory = CategoryCode
                FROM #RankingCategoryLocks WHERE IsAcquired = 0 ORDER BY CategoryCode;
                SET @CategoryLockResource = N'AfifeAdmin.Rankings.Category.' + CONVERT(nvarchar(12), @LockedCategory);
                EXEC @ApplicationLockResult = sys.sp_getapplock
                    @Resource = @CategoryLockResource, @LockMode = N'Exclusive',
                    @LockOwner = N'Session', @LockTimeout = 30000;
                IF @ApplicationLockResult < 0
                    THROW 52001, N'Rankings category refresh lock could not be acquired.', 1;
                SET @AcquiredCategoryLocks += CONVERT(nvarchar(12), @LockedCategory) + N';';
                UPDATE #RankingCategoryLocks SET IsAcquired = 1 WHERE CategoryCode = @LockedCategory;
            END;
        END;

        CREATE TABLE #RankingTargetScope (CandidateId uniqueidentifier NOT NULL PRIMARY KEY);
        INSERT INTO #RankingTargetScope (CandidateId)
        SELECT candidate.Id
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #RankingAffectedCategories AS affected ON affected.CategoryCode = candidate.AwardCategoryCode
        UNION
        SELECT CandidateId FROM #RankingDirtyCandidates
        UNION
        SELECT PlayAwardCategoryId FROM dbo.Rankings WHERE @FullRefresh = 1;

        CREATE TABLE #RankingEligibleCandidates
        (
            PlayAwardCategoryId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL,
            AwardCategoryCode int NOT NULL
        );
        INSERT INTO #RankingEligibleCandidates (PlayAwardCategoryId, PlayId, AwardCategoryCode)
        SELECT candidate.Id, candidate.PlayId, candidate.AwardCategoryCode
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #RankingAffectedCategories AS affected ON affected.CategoryCode = candidate.AwardCategoryCode
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE play.RecordType = 0 AND play.IsPublished = 1 AND play.IsActive = 1
          AND candidate.IsPublished = 1 AND candidate.IsCurrent = 1 AND candidate.IsActive = 1;

        CREATE TABLE #RankingRecalculate (CandidateId uniqueidentifier NOT NULL PRIMARY KEY);
        INSERT INTO #RankingRecalculate (CandidateId)
        SELECT eligible.PlayAwardCategoryId
        FROM #RankingEligibleCandidates AS eligible
        LEFT JOIN dbo.Rankings AS previous ON previous.PlayAwardCategoryId = eligible.PlayAwardCategoryId
        LEFT JOIN #RankingDirtyCandidates AS dirty ON dirty.CandidateId = eligible.PlayAwardCategoryId
        WHERE @CandidateIdsJson IS NULL OR dirty.CandidateId IS NOT NULL
           OR previous.Id IS NULL OR previous.IsPublished = 0;

        ;WITH OrderedActiveVotes AS
        (
            SELECT
                dirty.CandidateId AS PlayAwardCategoryId,
                vote.Score,
                ROW_NUMBER() OVER
                (
                    PARTITION BY dirty.CandidateId
                    ORDER BY vote.Score, vote.Id
                ) AS ScoreOrder,
                COUNT_BIG(*) OVER
                (
                    PARTITION BY dirty.CandidateId
                ) AS VoteCount
            FROM #RankingRecalculate AS dirty
            INNER JOIN dbo.JuryVotes AS vote
                ON vote.PlayAwardCategoryId = dirty.CandidateId
            WHERE vote.IsPublished = 1
              AND vote.IsActive = 1
        ),
        VoteStatistics AS
        (
            SELECT
                PlayAwardCategoryId,
                COUNT_BIG(*) AS NumberOfActiveVote,
                AVG(CONVERT(float, Score)) AS ArithmeticMean,
                VAR(CONVERT(float, Score)) AS ArithmeticVariance
            FROM OrderedActiveVotes
            GROUP BY PlayAwardCategoryId
        ),
        TrimmedStatistics AS
        (
            SELECT
                PlayAwardCategoryId,
                AVG(CONVERT(float, Score)) AS TrimmedMean
            FROM OrderedActiveVotes
            WHERE VoteCount >= 3
              AND ScoreOrder > 1
              AND ScoreOrder < VoteCount
            GROUP BY PlayAwardCategoryId
        ),
        CandidateStatistics AS
        (
            SELECT
                eligible.PlayAwardCategoryId,
                eligible.PlayId,
                eligible.AwardCategoryCode,
                CASE WHEN dirty.CandidateId IS NOT NULL
                    THEN CONVERT(int, COALESCE(voteStats.NumberOfActiveVote, 0))
                    ELSE previous.NumberOfActiveVote END
                    AS NumberOfActiveVote,
                CASE WHEN dirty.CandidateId IS NOT NULL THEN voteStats.ArithmeticMean ELSE previous.ArithmeticMean END AS ArithmeticMean,
                CASE WHEN dirty.CandidateId IS NOT NULL THEN trimmed.TrimmedMean ELSE previous.TrimmedMean END AS TrimmedMean,
                CASE WHEN dirty.CandidateId IS NOT NULL THEN voteStats.ArithmeticVariance ELSE previous.ArithmeticVariance END AS ArithmeticVariance
            FROM #RankingEligibleCandidates AS eligible
            LEFT JOIN #RankingRecalculate AS dirty ON dirty.CandidateId = eligible.PlayAwardCategoryId
            LEFT JOIN dbo.Rankings AS previous ON previous.PlayAwardCategoryId = eligible.PlayAwardCategoryId
            LEFT JOIN VoteStatistics AS voteStats
                ON voteStats.PlayAwardCategoryId =
                    eligible.PlayAwardCategoryId
            LEFT JOIN TrimmedStatistics AS trimmed
                ON trimmed.PlayAwardCategoryId =
                    eligible.PlayAwardCategoryId
        ),
        RankedStatistics AS
        (
            SELECT
                PlayAwardCategoryId,
                PlayId,
                NumberOfActiveVote,
                ArithmeticMean,
                TrimmedMean,
                CASE
                    WHEN ArithmeticMean IS NULL THEN NULL
                    ELSE CONVERT
                    (
                        int,
                        RANK() OVER
                        (
                            PARTITION BY AwardCategoryCode
                            ORDER BY
                                CASE WHEN ArithmeticMean IS NULL THEN 1 ELSE 0 END,
                                ArithmeticMean DESC
                        )
                    )
                END AS ArithmeticRank,
                CASE
                    WHEN TrimmedMean IS NULL THEN NULL
                    ELSE CONVERT
                    (
                        int,
                        RANK() OVER
                        (
                            PARTITION BY AwardCategoryCode
                            ORDER BY
                                CASE WHEN TrimmedMean IS NULL THEN 1 ELSE 0 END,
                                TrimmedMean DESC
                        )
                    )
                END AS TrimmedRank,
                ArithmeticVariance,
                CASE
                    WHEN ArithmeticVariance IS NULL THEN NULL
                    WHEN ArithmeticVariance >= 6.064 THEN 1
                    WHEN ArithmeticVariance >= 4.987 THEN 2
                    WHEN ArithmeticVariance >= 4.141 THEN 3
                    ELSE 4
                END AS ConfidenceValue
            FROM CandidateStatistics
        )
        MERGE dbo.Rankings WITH (HOLDLOCK) AS target
        USING RankedStatistics AS source
            ON source.PlayAwardCategoryId = target.PlayAwardCategoryId
        WHEN MATCHED AND
        (
            target.PlayId <> source.PlayId
            OR target.NumberOfActiveVote <> source.NumberOfActiveVote
            OR target.IsPublished = 0
            OR target.ArithmeticMean <> source.ArithmeticMean
            OR (target.ArithmeticMean IS NULL AND source.ArithmeticMean IS NOT NULL)
            OR (target.ArithmeticMean IS NOT NULL AND source.ArithmeticMean IS NULL)
            OR target.TrimmedMean <> source.TrimmedMean
            OR (target.TrimmedMean IS NULL AND source.TrimmedMean IS NOT NULL)
            OR (target.TrimmedMean IS NOT NULL AND source.TrimmedMean IS NULL)
            OR target.ArithmeticRank <> source.ArithmeticRank
            OR (target.ArithmeticRank IS NULL AND source.ArithmeticRank IS NOT NULL)
            OR (target.ArithmeticRank IS NOT NULL AND source.ArithmeticRank IS NULL)
            OR target.TrimmedRank <> source.TrimmedRank
            OR (target.TrimmedRank IS NULL AND source.TrimmedRank IS NOT NULL)
            OR (target.TrimmedRank IS NOT NULL AND source.TrimmedRank IS NULL)
            OR target.ArithmeticVariance <> source.ArithmeticVariance
            OR
            (
                target.ArithmeticVariance IS NULL
                AND source.ArithmeticVariance IS NOT NULL
            )
            OR
            (
                target.ArithmeticVariance IS NOT NULL
                AND source.ArithmeticVariance IS NULL
            )
            OR target.ConfidenceValue <> source.ConfidenceValue
            OR (target.ConfidenceValue IS NULL AND source.ConfidenceValue IS NOT NULL)
            OR (target.ConfidenceValue IS NOT NULL AND source.ConfidenceValue IS NULL)
        )
            THEN UPDATE SET
                PlayId = source.PlayId,
                NumberOfActiveVote = source.NumberOfActiveVote,
                ArithmeticMean = source.ArithmeticMean,
                TrimmedMean = source.TrimmedMean,
                ArithmeticRank = source.ArithmeticRank,
                TrimmedRank = source.TrimmedRank,
                ArithmeticVariance = source.ArithmeticVariance,
                ConfidenceValue = source.ConfidenceValue,
                IsPublished = 1
        WHEN NOT MATCHED BY TARGET
            THEN INSERT
            (
                Id,
                PlayId,
                PlayAwardCategoryId,
                NumberOfActiveVote,
                ArithmeticMean,
                TrimmedMean,
                ArithmeticRank,
                TrimmedRank,
                ArithmeticVariance,
                ConfidenceValue,
                IsPublished
            )
            VALUES
            (
                NEWID(),
                source.PlayId,
                source.PlayAwardCategoryId,
                source.NumberOfActiveVote,
                source.ArithmeticMean,
                source.TrimmedMean,
                source.ArithmeticRank,
                source.TrimmedRank,
                source.ArithmeticVariance,
                source.ConfidenceValue,
                1
            );

        /* Restrict retirement separately: a partial source must never unpublish
           rankings from other categories. Dirty IDs also cover removed rows. */
        UPDATE target
        SET IsPublished = 0
        FROM dbo.Rankings AS target
        INNER JOIN #RankingTargetScope AS affected ON affected.CandidateId = target.PlayAwardCategoryId
        LEFT JOIN #RankingEligibleCandidates AS eligible ON eligible.PlayAwardCategoryId = target.PlayAwardCategoryId
        WHERE target.IsPublished = 1 AND eligible.PlayAwardCategoryId IS NULL;

        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshAuthorized',
            @value = NULL;
        EXEC sys.sp_set_session_context
            @key = N'RankingsRefreshInProgress',
            @value = NULL;
        WHILE LEN(@AcquiredCategoryLocks) > 0
        BEGIN
            SET @CategoryLockDelimiter = CHARINDEX(N';', @AcquiredCategoryLocks);
            SET @LockedCategory = CONVERT(int, LEFT(@AcquiredCategoryLocks, @CategoryLockDelimiter - 1));
            SET @CategoryLockResource = N'AfifeAdmin.Rankings.Category.' + CONVERT(nvarchar(12), @LockedCategory);
            EXEC sys.sp_releaseapplock @Resource = @CategoryLockResource, @LockOwner = N'Session';
            SET @AcquiredCategoryLocks = SUBSTRING(@AcquiredCategoryLocks, @CategoryLockDelimiter + 1, LEN(@AcquiredCategoryLocks));
        END;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Rankings.Refresh',
            @LockOwner = N'Session';
    END TRY
    BEGIN CATCH
        BEGIN TRY
            EXEC sys.sp_set_session_context @key = N'RankingsRefreshAuthorized', @value = NULL;
            EXEC sys.sp_set_session_context @key = N'RankingsRefreshInProgress', @value = NULL;
        END TRY
        BEGIN CATCH
            PRINT N'Rankings session-context cleanup failed.';
        END CATCH;
        /* No temp-table access here: SQL 1205 can remove those tables. Cleanup
           failures must not prevent release of other locks or mask the error. */
        WHILE LEN(@AcquiredCategoryLocks) > 0
        BEGIN
            SET @CategoryLockDelimiter = CHARINDEX(N';', @AcquiredCategoryLocks);
            SET @LockedCategory = CONVERT(int, LEFT(@AcquiredCategoryLocks, @CategoryLockDelimiter - 1));
            SET @AcquiredCategoryLocks = SUBSTRING(@AcquiredCategoryLocks, @CategoryLockDelimiter + 1, LEN(@AcquiredCategoryLocks));
            SET @CategoryLockResource = N'AfifeAdmin.Rankings.Category.' + CONVERT(nvarchar(12), @LockedCategory);
            BEGIN TRY
                EXEC sys.sp_releaseapplock @Resource = @CategoryLockResource, @LockOwner = N'Session';
            END TRY
            BEGIN CATCH
                PRINT N'Rankings category-lock cleanup failed.';
            END CATCH;
        END;
        BEGIN TRY
            EXEC sys.sp_releaseapplock @Resource = N'AfifeAdmin.Rankings.Refresh', @LockOwner = N'Session';
        END TRY
        BEGIN CATCH
            PRINT N'Rankings global-lock cleanup failed.';
        END CATCH;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_RefreshSeasonStatistics]
    @FromDate datetime2(7) = NULL,
    @ToDate datetime2(7) = NULL,
    @SeasonIdsJson nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @FromDate IS NOT NULL AND @ToDate IS NULL SET @ToDate = @FromDate;
    IF @ToDate IS NOT NULL AND @FromDate IS NULL SET @FromDate = @ToDate;
    CREATE TABLE #StatisticSeasons (Id uniqueidentifier NOT NULL PRIMARY KEY);
    IF @SeasonIdsJson IS NOT NULL
    BEGIN
        IF ISJSON(@SeasonIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@SeasonIdsJson, CHAR(9), N' '), CHAR(10), N' '), CHAR(13), N' ')), 1) <> N'['
            THROW 52741, N'Season scope must be an array of Id objects.', 1;
        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@SeasonIdsJson) AS item
            OUTER APPLY OPENJSON(CASE WHEN item.type = 5 THEN item.value ELSE N'{}' END)
                WITH (Id nvarchar(max) '$.Id') AS scope
            WHERE item.type <> 5 OR scope.Id IS NULL OR DATALENGTH(scope.Id) <> 72
               OR TRY_CONVERT(uniqueidentifier, scope.Id) IS NULL
        ) THROW 52741, N'Season scope contains an invalid Id.', 1;
        INSERT #StatisticSeasons SELECT DISTINCT CONVERT(uniqueidentifier, Id)
        FROM OPENJSON(@SeasonIdsJson) WITH (Id nvarchar(36) '$.Id');
    END
    ELSE
        INSERT #StatisticSeasons
        SELECT Id FROM dbo.Seasons
        WHERE IsPublished = 1 AND (@FromDate IS NULL OR
            (@FromDate < CONVERT(datetime2(7), SeasonEndDate)
             AND @ToDate >= CONVERT(datetime2(7), SeasonStartDate)));

    /* Trigger callers pass exact identities, not a min/max interval spanning
       unrelated seasons. Date covering indexes serve the range aggregates. */
    UPDATE season
    SET PlayCount = plays.PlayCount, ActivePlayCount = plays.ActivePlayCount,
        VoteCount = votes.VoteCount
    FROM dbo.Seasons AS season
    INNER JOIN #StatisticSeasons AS affected ON affected.Id = season.Id
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS PlayCount,
               COALESCE(SUM(CONVERT(bigint, CASE WHEN play.StatusCode = 1 THEN 1 ELSE 0 END)), 0) AS ActivePlayCount
        FROM dbo.Plays AS play
        WHERE play.IsPublished = 1 AND play.IsActive = 1
          AND play.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
          AND play.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
    ) AS plays
    CROSS APPLY
    (
        SELECT COUNT_BIG(*) AS VoteCount
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE vote.IsPublished = 1 AND vote.IsActive = 1
          AND candidate.IsPublished = 1 AND candidate.IsActive = 1
          AND play.IsPublished = 1 AND play.IsActive = 1
          AND vote.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
          AND vote.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
    ) AS votes
    WHERE season.IsPublished = 1
      AND (season.PlayCount <> plays.PlayCount OR season.ActivePlayCount <> plays.ActivePlayCount
           OR season.VoteCount <> votes.VoteCount);
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_SynchronizeFormCandidates]
    @FormIdsJson nvarchar(max) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());
    DECLARE @MaximumImageBytes bigint = 150 * 1024 * 1024;

    /* NULL retains the explicit full-maintenance contract. Trigger callers pass
       [{"Id":"guid"}] so a single Form never repairs or decodes unrelated plays. */
    CREATE TABLE #CandidateAffectedForms
    (
        FormId uniqueidentifier NOT NULL PRIMARY KEY
    );
    CREATE TABLE #CandidateAffectedPlays
    (
        PlayId uniqueidentifier NOT NULL PRIMARY KEY
    );

    IF @FormIdsJson IS NULL
    BEGIN
        INSERT INTO #CandidateAffectedForms (FormId)
        SELECT Id FROM dbo.Form;

        /* Historical full repairs also cover mapped legacy slots on plays that
           no longer have a Form link. Scoped calls must never touch them. */
        INSERT INTO #CandidateAffectedPlays (PlayId)
        SELECT Id FROM dbo.Plays;
    END
    ELSE
    BEGIN
        IF ISJSON(@FormIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@FormIdsJson,
               NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ')), 1) <> N'['
            THROW 52433, N'Form senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM OPENJSON(@FormIdsJson) AS scopeItem
            WHERE scopeItem.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier,
                   JSON_VALUE(CASE WHEN scopeItem.[type] = 5 THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52433, N'Form senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        INSERT INTO #CandidateAffectedForms (FormId)
        SELECT DISTINCT CONVERT(uniqueidentifier, JSON_VALUE(scopeItem.[value], N'$.Id'))
        FROM OPENJSON(@FormIdsJson) AS scopeItem;

        /* Include inactive/unpublished Forms: only source creation is filtered
           by active flags; legacy slot repair keeps its previous semantics. */
        INSERT INTO #CandidateAffectedPlays (PlayId)
        SELECT play.Id
        FROM dbo.Plays AS play
        INNER JOIN #CandidateAffectedForms AS affected ON affected.FormId = play.SourceFormId;
    END;

    IF NOT EXISTS (SELECT 1 FROM #CandidateAffectedPlays)
        RETURN;

    /* A previous production has only acting categories. Retire every forbidden
       row on the affected plays, including manually created/unmapped slots.
       A normal Form without a director likewise has no category 1002 candidate.
       Keep identities and past votes; lifecycle/ranking triggers retain their
       existing history rules while the flags exclude these rows from voting. */
    UPDATE candidate
    SET IsPublished = 0,
        IsActive = 0,
        IsCurrent = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE
        (
            (formRecord.previousProductionVersion = 1
             AND (candidate.AwardCategoryCode = 1002
                  OR candidate.AwardCategoryCode BETWEEN 1007 AND 1011))
            OR (candidate.AwardCategoryCode = 1002
                AND NULLIF(LTRIM(RTRIM(formRecord.Director)), N'') IS NULL)
        )
      AND (candidate.IsPublished = 1 OR candidate.IsActive = 1 OR candidate.IsCurrent = 1);

    CREATE TABLE #CandidateSource
    (
        SourceOrder int NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        Role nvarchar(200) NULL,
        RoleCode int NULL,
        ImageUrl nvarchar(255) NULL,
        Base64 nvarchar(max) NULL
    );

    /* A non-empty director on a normal production is the category 1002 slot. */
    INSERT INTO #CandidateSource
        (SourceOrder, PlayId, AwardCategoryCode, Candidate, Role, RoleCode, ImageUrl, Base64)
    SELECT 0, play.Id, 1002, LEFT(LTRIM(RTRIM(formRecord.Director)), 250),
           NULL, 0, NULL, NULL
    FROM dbo.Form AS formRecord
    INNER JOIN #CandidateAffectedForms AS affectedForm ON affectedForm.FormId = formRecord.Id
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    INNER JOIN #CandidateAffectedPlays AS affectedPlay ON affectedPlay.PlayId = play.Id
    WHERE formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.RecordType = 0
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND formRecord.previousProductionVersion = 0
      AND NULLIF(LTRIM(RTRIM(formRecord.Director)), N'') IS NOT NULL;

    /* Every category except 1001/1002 creates one role-scoped row per JSON item. */
    INSERT INTO #CandidateSource
        (SourceOrder, PlayId, AwardCategoryCode, Candidate, Role, RoleCode, ImageUrl, Base64)
    SELECT CONVERT(int, jsonItem.[key]) + 1,
           play.Id,
           category.AwardCategoryCode,
           LEFT(LTRIM(RTRIM(candidateValue.[Name])), 250),
           LEFT(COALESCE
           (
               NULLIF(LTRIM(RTRIM(candidateValue.[Role])), N''),
               NULLIF(LTRIM(RTRIM(candidateValue.[Name])), N'')
           ), 200),
           NULL,
           LEFT(NULLIF(LTRIM(RTRIM(candidateValue.ImageUrl)), N''), 255),
           NULLIF(LTRIM(RTRIM(candidateValue.Base64)), N'')
    FROM dbo.Form AS formRecord
    INNER JOIN #CandidateAffectedForms AS affectedForm ON affectedForm.FormId = formRecord.Id
    INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
    INNER JOIN #CandidateAffectedPlays AS affectedPlay ON affectedPlay.PlayId = play.Id
    CROSS APPLY
    (
        VALUES
            (1003, formRecord.LeadActress),
            (1004, formRecord.LeadActor),
            (1005, formRecord.SupportActress),
            (1006, formRecord.SupportActor),
            (1007, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.StageDesign END),
            (1008, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.ClothesDesign END),
            (1009, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.StageMusic END),
            (1010, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.LightDesign END),
            (1011, CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE formRecord.Choreography END)
    ) AS category(AwardCategoryCode, CandidateJson)
    CROSS APPLY OPENJSON
    (
        CASE
            WHEN ISJSON(category.CandidateJson) <> 1 THEN N'[]'
            WHEN LEFT(LTRIM(category.CandidateJson), 1) = N'[' THEN category.CandidateJson
            ELSE N'[' + category.CandidateJson + N']'
        END
    ) AS jsonItem
    /* Legacy payloads can mix objects with scalar array items. Only objects
       carry named candidate fields; leave the original Form JSON untouched. */
    CROSS APPLY OPENJSON(CASE WHEN jsonItem.[type] = 5 THEN jsonItem.value ELSE N'{}' END)
    WITH
    (
        [Name] nvarchar(250) N'$.Name',
        [Role] nvarchar(200) N'$.Role',
        ImageUrl nvarchar(255) N'$.ImageUrl',
        /* JSON_VALUE silently returns NULL above 4000 characters. Candidate
           photos are intentionally read as nvarchar(max) instead. */
        Base64 nvarchar(max) N'$.Base64'
    ) AS candidateValue
    WHERE formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.RecordType = 0
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND NULLIF(LTRIM(RTRIM(candidateValue.[Name])), N'') IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #CandidateSource
        WHERE AwardCategoryCode BETWEEN 1003 AND 1011
          AND NULLIF(LTRIM(RTRIM(Role)), N'') IS NULL
    )
        THROW 52410, N'Çok adaylı kategorilerde Role alanı zorunludur.', 1;

    /* Repair legacy rows that point to the same Form array slot. Keep the most
       relevant row on the slot; release later rows so the remaining-source
       backfill below can map them to slot 2, 3, ... without deleting history. */
    ;WITH RankedMappedSlots AS
    (
        SELECT candidate.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode,
                                candidate.SourceFormCandidateOrder
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC,
                            candidate.Id
               ) AS SlotOccurrence
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
        WHERE candidate.SourceFormCandidateOrder IS NOT NULL
          AND candidate.AwardCategoryCode BETWEEN 1002 AND 1011
    )
    UPDATE candidate
    SET SourceFormCandidateOrder = NULL,
        IsCurrent = 0,
        IsActive = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN RankedMappedSlots AS mappedSlot ON mappedSlot.Id = candidate.Id
    WHERE mappedSlot.SlotOccurrence > 1;

    /* SourceOrder is the stable Form slot identity. Candidate and Role are
       editable descriptions; duplicate role names are valid distinct slots. */
    ;WITH SourceMatches AS
    (
        SELECT source.*,
               ROW_NUMBER() OVER
               (
                   PARTITION BY source.PlayId, source.AwardCategoryCode,
                                LOWER(LTRIM(RTRIM(source.Candidate))),
                                LOWER(LTRIM(RTRIM(COALESCE(source.Role, N''))))
                   ORDER BY source.SourceOrder
               ) AS MatchOrder
        FROM #CandidateSource AS source
    ),
    ExistingMatches AS
    (
        SELECT candidate.Id, candidate.PlayId, candidate.AwardCategoryCode,
               candidate.Candidate, candidate.Role,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode,
                                LOWER(LTRIM(RTRIM(candidate.Candidate))),
                                LOWER(LTRIM(RTRIM(COALESCE(candidate.Role, N''))))
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            candidate.RoleCode, candidate.Id
               ) AS MatchOrder
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
        WHERE candidate.SourceFormCandidateOrder IS NULL
          AND candidate.CreatedBy IS NULL
          AND candidate.AwardCategoryCode BETWEEN 1002 AND 1011
    )
    UPDATE candidate
    SET SourceFormCandidateOrder = source.SourceOrder,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN ExistingMatches AS existing ON existing.Id = candidate.Id
    INNER JOIN SourceMatches AS source
        ON source.PlayId = existing.PlayId
       AND source.AwardCategoryCode = existing.AwardCategoryCode
       AND LOWER(LTRIM(RTRIM(source.Candidate))) = LOWER(LTRIM(RTRIM(existing.Candidate)))
       AND LOWER(LTRIM(RTRIM(COALESCE(source.Role, N'')))) =
           LOWER(LTRIM(RTRIM(COALESCE(existing.Role, N''))))
       AND source.MatchOrder = existing.MatchOrder
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories AS mapped
        WHERE mapped.PlayId = source.PlayId
          AND mapped.AwardCategoryCode = source.AwardCategoryCode
          AND mapped.SourceFormCandidateOrder = source.SourceOrder
    );

    /* Backfill old procedure-created rows which predate source-slot tracking. */
    ;WITH RemainingSources AS
    (
        SELECT source.*,
               ROW_NUMBER() OVER
               (
                   PARTITION BY source.PlayId, source.AwardCategoryCode
                   ORDER BY source.SourceOrder
               ) AS SlotOrder
        FROM #CandidateSource AS source
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.PlayAwardCategories AS mapped
            WHERE mapped.PlayId = source.PlayId
              AND mapped.AwardCategoryCode = source.AwardCategoryCode
              AND mapped.SourceFormCandidateOrder = source.SourceOrder
        )
    ),
    RemainingCandidates AS
    (
        SELECT candidate.Id, candidate.PlayId, candidate.AwardCategoryCode,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            candidate.RoleCode, candidate.Id
               ) AS SlotOrder
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
        WHERE candidate.SourceFormCandidateOrder IS NULL
          AND candidate.CreatedBy IS NULL
          AND candidate.AwardCategoryCode BETWEEN 1002 AND 1011
    )
    UPDATE candidate
    SET SourceFormCandidateOrder = source.SourceOrder,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN RemainingCandidates AS existing ON existing.Id = candidate.Id
    INNER JOIN RemainingSources AS source
        ON source.PlayId = existing.PlayId
       AND source.AwardCategoryCode = existing.AwardCategoryCode
       AND source.SlotOrder = existing.SlotOrder;

    UPDATE source
    SET RoleCode = existing.RoleCode
    FROM #CandidateSource AS source
    CROSS APPLY
    (
        SELECT TOP (1) candidate.RoleCode
        FROM dbo.PlayAwardCategories AS candidate
        WHERE candidate.PlayId = source.PlayId
          AND candidate.AwardCategoryCode = source.AwardCategoryCode
          AND candidate.SourceFormCandidateOrder = source.SourceOrder
        ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                 COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC, candidate.Id
    ) AS existing
    WHERE source.AwardCategoryCode <> 1002;

    /* Only an exact (play, category, RoleCode, candidate) repetition is
       forbidden. Different candidates may intentionally share a RoleCode.
       Repair only legacy slots that would become an exact duplicate. */
    ;WITH DuplicateSourceRoles AS
    (
        SELECT source.PlayId, source.AwardCategoryCode, source.SourceOrder,
               ROW_NUMBER() OVER
               (
                   PARTITION BY source.PlayId, source.AwardCategoryCode, source.RoleCode,
                                LOWER(LTRIM(RTRIM(source.Candidate)))
                   ORDER BY source.SourceOrder
               ) AS RoleOccurrence
        FROM #CandidateSource AS source
        WHERE source.AwardCategoryCode BETWEEN 1003 AND 1011
          AND source.RoleCode > 0
    )
    UPDATE source
    SET RoleCode = NULL
    FROM #CandidateSource AS source
    INNER JOIN DuplicateSourceRoles AS duplicateRole
        ON duplicateRole.PlayId = source.PlayId
       AND duplicateRole.AwardCategoryCode = source.AwardCategoryCode
       AND duplicateRole.SourceOrder = source.SourceOrder
    WHERE duplicateRole.RoleOccurrence > 1;

    ;WITH MissingRoles AS
    (
        SELECT source.PlayId, source.AwardCategoryCode, source.SourceOrder,
               COALESCE
               (
                   (SELECT MAX(candidate.RoleCode)
                    FROM dbo.PlayAwardCategories AS candidate
                    WHERE candidate.PlayId = source.PlayId AND candidate.RoleCode > 0),
                   0
               ) + ROW_NUMBER() OVER
                   (PARTITION BY source.PlayId ORDER BY source.AwardCategoryCode, source.SourceOrder) AS NewRoleCode
        FROM #CandidateSource AS source
        WHERE source.Role IS NOT NULL AND source.RoleCode IS NULL
    )
    UPDATE source
    SET RoleCode = missing.NewRoleCode
    FROM #CandidateSource AS source
    INNER JOIN MissingRoles AS missing
        ON missing.PlayId = source.PlayId
       AND missing.AwardCategoryCode = source.AwardCategoryCode
       AND missing.SourceOrder = source.SourceOrder;

    /* Form changes update only the mapped slot. Existing published/current
       candidates retain their manually selected status. A retired source slot
       becoming current again starts active, just like a newly created slot. */
    ;WITH CurrentTargets AS
    (
        SELECT candidate.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY candidate.PlayId, candidate.AwardCategoryCode,
                                candidate.SourceFormCandidateOrder
                   ORDER BY candidate.IsCurrent DESC, candidate.IsPublished DESC,
                            COALESCE(candidate.UpdatedAt, candidate.CreatedAt) DESC,
                            candidate.Id
               ) AS TargetOrder
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
        WHERE candidate.SourceFormCandidateOrder IS NOT NULL
    )
    UPDATE candidate
    SET Candidate = source.Candidate,
        Role = source.Role,
        RoleCode = source.RoleCode,
        IsPublished = 1,
        IsActive = CASE
            WHEN candidate.IsPublished = 1 AND candidate.IsCurrent = 1
                THEN candidate.IsActive
            ELSE 1 END,
        IsCurrent = 1,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN CurrentTargets AS target
        ON target.Id = candidate.Id AND target.TargetOrder = 1
    INNER JOIN #CandidateSource AS source
        ON source.PlayId = candidate.PlayId
       AND source.AwardCategoryCode = candidate.AwardCategoryCode
       AND source.SourceOrder = candidate.SourceFormCandidateOrder
    /* Avoid audit/ranking work for unchanged slots. Binary text comparisons
       preserve case and trailing-space edits, and EXCEPT treats NULLs equally.
       Published/current candidates retain their manual IsActive value above. */
    WHERE EXISTS
    (
        SELECT CONVERT(varbinary(max), candidate.Candidate),
               CONVERT(varbinary(max), candidate.Role),
               candidate.RoleCode, candidate.IsPublished, candidate.IsCurrent
        EXCEPT
        SELECT CONVERT(varbinary(max), source.Candidate),
               CONVERT(varbinary(max), source.Role),
               source.RoleCode, CONVERT(bit, 1), CONVERT(bit, 1)
    );

    /* A non-empty valid Base64 value replaces the mapped candidate photo.
       Empty/invalid legacy values preserve the existing image. */
    CREATE TABLE #UpdatedCandidateImages
    (
        CandidateId uniqueidentifier NOT NULL PRIMARY KEY,
        OldImageId uniqueidentifier NULL,
        NewImageId uniqueidentifier NOT NULL,
        ImageUrl nvarchar(255) NULL,
        CleanBase64 nvarchar(max) NOT NULL,
        ImageData varbinary(max) NULL,
        ContentType nvarchar(100) NULL
    );

    INSERT INTO #UpdatedCandidateImages
        (CandidateId, OldImageId, NewImageId, ImageUrl, CleanBase64)
    SELECT candidate.Id, candidate.PhotoImageId, NEWID(), source.ImageUrl,
           CASE
               WHEN source.Base64 LIKE N'data:%;base64,%'
                   THEN REPLACE(REPLACE(REPLACE(SUBSTRING(source.Base64,
                        CHARINDEX(N',', source.Base64) + 1, LEN(source.Base64)), CHAR(13), N''), CHAR(10), N''), N' ', N'')
               ELSE REPLACE(REPLACE(REPLACE(source.Base64, CHAR(13), N''), CHAR(10), N''), N' ', N'')
           END
    FROM #CandidateSource AS source
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.PlayId = source.PlayId
       AND candidate.AwardCategoryCode = source.AwardCategoryCode
       AND candidate.SourceFormCandidateOrder = source.SourceOrder
       AND candidate.IsCurrent = 1
    WHERE source.Base64 IS NOT NULL;

    UPDATE image
    SET ImageData = CAST(N'' AS xml).value(
            'xs:base64Binary(sql:column("image.CleanBase64"))', 'varbinary(max)')
    FROM #UpdatedCandidateImages AS image
    WHERE LEN(image.CleanBase64) % 4 = 0
      AND image.CleanBase64 COLLATE Latin1_General_100_BIN2 NOT LIKE N'%[^A-Za-z0-9+/=]%';

    UPDATE image
    SET ContentType = CASE
        WHEN SUBSTRING(image.ImageData, 1, 3) = 0xFFD8FF THEN N'image/jpeg'
        WHEN SUBSTRING(image.ImageData, 1, 8) = 0x89504E470D0A1A0A THEN N'image/png'
        WHEN SUBSTRING(image.ImageData, 1, 4) = 0x52494646
         AND SUBSTRING(image.ImageData, 9, 4) = 0x57454250 THEN N'image/webp'
        ELSE NULL END
    FROM #UpdatedCandidateImages AS image
    WHERE image.ImageData IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #UpdatedCandidateImages
        WHERE DATALENGTH(ImageData) > @MaximumImageBytes
    )
        THROW 52431, N'Görsel boyutu 150 MB''dan büyük olamaz.', 1;

    INSERT INTO dbo.Images
        (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
    SELECT image.NewImageId,
           /* Legacy ImageUrl may have an unrelated extension or URL suffix.
              Keep the Form source; name the projected image for its bytes. */
           COALESCE(CASE
                        WHEN image.ContentType = N'image/jpeg'
                         AND (LOWER(image.ImageUrl) LIKE N'%.jpg' OR LOWER(image.ImageUrl) LIKE N'%.jpeg')
                            THEN image.ImageUrl
                        WHEN image.ContentType = N'image/png' AND LOWER(image.ImageUrl) LIKE N'%.png'
                            THEN image.ImageUrl
                        WHEN image.ContentType = N'image/webp' AND LOWER(image.ImageUrl) LIKE N'%.webp'
                            THEN image.ImageUrl
                    END,
                    CONCAT(N'form-candidate-', CONVERT(nvarchar(36), image.CandidateId),
                           CASE image.ContentType WHEN N'image/png' THEN N'.png'
                                WHEN N'image/webp' THEN N'.webp' ELSE N'.jpg' END)),
           image.ContentType, image.ImageData, @Now, image.CandidateId, 1
    FROM #UpdatedCandidateImages AS image
    LEFT JOIN dbo.Images AS currentImage ON currentImage.Id = image.OldImageId
    WHERE image.ContentType IS NOT NULL
      AND DATALENGTH(image.ImageData) BETWEEN 1 AND @MaximumImageBytes
      AND
      (
          currentImage.Id IS NULL
          OR currentImage.IsPublished = 0
          OR currentImage.ContentType <> image.ContentType
          OR DATALENGTH(currentImage.ImageData) <> DATALENGTH(image.ImageData)
          OR currentImage.ImageData <> image.ImageData
      );

    UPDATE candidate
    SET PhotoImageId = image.NewImageId,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN #UpdatedCandidateImages AS image ON image.CandidateId = candidate.Id
    INNER JOIN dbo.Images AS newImage ON newImage.Id = image.NewImageId;

    UPDATE oldImage
    SET IsPublished = 0,
        UpdatedAt = @Now
    FROM dbo.Images AS oldImage
    INNER JOIN #UpdatedCandidateImages AS replacement
        ON replacement.OldImageId = oldImage.Id
    INNER JOIN dbo.Images AS newImage ON newImage.Id = replacement.NewImageId
    WHERE oldImage.IsPublished = 1
      /* Reference checks intentionally span all plays: a photo shared with an
         unscoped published candidate must remain published. */
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.PlayAwardCategories AS candidate
          WHERE candidate.PhotoImageId = oldImage.Id
            AND candidate.IsPublished = 1
      );

    UPDATE candidate
    SET IsPublished = 0,
        IsActive = 0,
        IsCurrent = 0,
        UpdatedAt = @Now
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN #CandidateAffectedPlays AS affected ON affected.PlayId = candidate.PlayId
    INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
    INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE candidate.SourceFormCandidateOrder IS NOT NULL
      AND formRecord.IsPublished = 1
      AND formRecord.IsActive = 1
      AND play.IsPublished = 1
      AND play.IsActive = 1
      AND NOT EXISTS
      (
          SELECT 1 FROM #CandidateSource AS source
          WHERE source.PlayId = candidate.PlayId
            AND source.AwardCategoryCode = candidate.AwardCategoryCode
            AND source.SourceOrder = candidate.SourceFormCandidateOrder
      )
      AND (candidate.IsPublished = 1 OR candidate.IsActive = 1 OR candidate.IsCurrent = 1);

    CREATE TABLE #NewCandidates
    (
        CandidateId uniqueidentifier NOT NULL PRIMARY KEY,
        ImageId uniqueidentifier NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        Candidate nvarchar(250) NOT NULL,
        Role nvarchar(200) NULL,
        RoleCode int NOT NULL,
        SourceOrder int NOT NULL,
        ImageUrl nvarchar(255) NULL,
        CleanBase64 nvarchar(max) NULL,
        ImageData varbinary(max) NULL,
        ContentType nvarchar(100) NULL
    );

    INSERT INTO #NewCandidates
        (CandidateId, ImageId, PlayId, AwardCategoryCode, Candidate, Role,
         RoleCode, SourceOrder, ImageUrl, CleanBase64)
    SELECT NEWID(), CASE WHEN source.Base64 IS NULL THEN NULL ELSE NEWID() END,
           source.PlayId, source.AwardCategoryCode, source.Candidate, source.Role,
           COALESCE(source.RoleCode, 0), source.SourceOrder, source.ImageUrl,
           CASE
               WHEN source.Base64 LIKE N'data:%;base64,%'
                   THEN REPLACE(REPLACE(REPLACE(SUBSTRING(source.Base64,
                        CHARINDEX(N',', source.Base64) + 1, LEN(source.Base64)), CHAR(13), N''), CHAR(10), N''), N' ', N'')
               ELSE REPLACE(REPLACE(REPLACE(source.Base64, CHAR(13), N''), CHAR(10), N''), N' ', N'')
           END
    FROM #CandidateSource AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.PlayAwardCategories AS existing
        WHERE existing.PlayId = source.PlayId
          AND existing.AwardCategoryCode = source.AwardCategoryCode
          AND existing.RoleCode = COALESCE(source.RoleCode, 0)
          AND LOWER(LTRIM(RTRIM(existing.Candidate))) =
              LOWER(LTRIM(RTRIM(source.Candidate)))
          AND existing.IsPublished = 1
    );

    /* Legacy/test Forms can contain placeholder strings in Base64. They must not
       block candidate backfill and must never be persisted as image bytes. */
    UPDATE candidate
    SET ImageId = NULL, CleanBase64 = NULL
    FROM #NewCandidates AS candidate
    WHERE candidate.CleanBase64 IS NOT NULL
      AND
      (
          LEN(candidate.CleanBase64) % 4 <> 0
          OR candidate.CleanBase64 COLLATE Latin1_General_100_BIN2 LIKE N'%[^A-Za-z0-9+/=]%'
      );

    UPDATE candidate
    SET ImageData = CAST(N'' AS xml).value(
            'xs:base64Binary(sql:column("candidate.CleanBase64"))', 'varbinary(max)')
    FROM #NewCandidates AS candidate
    WHERE candidate.CleanBase64 IS NOT NULL;

    UPDATE candidate
    SET ContentType = CASE
        WHEN SUBSTRING(candidate.ImageData, 1, 3) = 0xFFD8FF THEN N'image/jpeg'
        WHEN SUBSTRING(candidate.ImageData, 1, 8) = 0x89504E470D0A1A0A THEN N'image/png'
        WHEN SUBSTRING(candidate.ImageData, 1, 4) = 0x52494646
         AND SUBSTRING(candidate.ImageData, 9, 4) = 0x57454250 THEN N'image/webp'
        ELSE NULL END
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageData IS NOT NULL;

    IF EXISTS
    (
        SELECT 1 FROM #NewCandidates
        WHERE DATALENGTH(ImageData) > @MaximumImageBytes
    )
        THROW 52431, N'Görsel boyutu 150 MB''dan büyük olamaz.', 1;

    UPDATE candidate
    SET ImageId = NULL, ImageData = NULL, CleanBase64 = NULL
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageData IS NOT NULL
      AND
      (
          DATALENGTH(candidate.ImageData) = 0
          OR DATALENGTH(candidate.ImageData) > @MaximumImageBytes
          OR candidate.ContentType IS NULL
      );

    INSERT INTO dbo.Images
        (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
    SELECT candidate.ImageId,
           COALESCE(CASE
                        WHEN candidate.ContentType = N'image/jpeg'
                         AND (LOWER(candidate.ImageUrl) LIKE N'%.jpg' OR LOWER(candidate.ImageUrl) LIKE N'%.jpeg')
                            THEN candidate.ImageUrl
                        WHEN candidate.ContentType = N'image/png' AND LOWER(candidate.ImageUrl) LIKE N'%.png'
                            THEN candidate.ImageUrl
                        WHEN candidate.ContentType = N'image/webp' AND LOWER(candidate.ImageUrl) LIKE N'%.webp'
                            THEN candidate.ImageUrl
                    END,
                    CONCAT(N'form-candidate-', CONVERT(nvarchar(36), candidate.CandidateId),
                           CASE candidate.ContentType WHEN N'image/png' THEN N'.png'
                                WHEN N'image/webp' THEN N'.webp' ELSE N'.jpg' END)),
           candidate.ContentType, candidate.ImageData, @Now, candidate.CandidateId, 1
    FROM #NewCandidates AS candidate
    WHERE candidate.ImageId IS NOT NULL;

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy,
        IsPublished, IsActive, Candidate, AwardCategoryCode,
        IsCurrent, Role, RoleCode, PhotoImageId, SourceFormCandidateOrder
    )
    SELECT candidate.CandidateId, candidate.PlayId, @Now, NULL, NULL, NULL,
           1, 1, candidate.Candidate, candidate.AwardCategoryCode,
           1, candidate.Role, candidate.RoleCode, candidate.ImageId, candidate.SourceOrder
    FROM #NewCandidates AS candidate;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_SynchronizeFormsToPlays]
    @FormIdsJson nvarchar(max) = NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    /* Trigger calls carry the complete statement's Form IDs. NULL is reserved
       for the existing explicit full-repair/migration entry point. */
    CREATE TABLE #SyncForms (FormId uniqueidentifier NOT NULL PRIMARY KEY);

    IF @FormIdsJson IS NULL
        INSERT INTO #SyncForms (FormId) SELECT Id FROM dbo.Form;
    ELSE
    BEGIN
        IF ISJSON(@FormIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@FormIdsJson,
               NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ')), 1) <> N'['
            THROW 52433, N'Form senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@FormIdsJson) AS scopeItem
            WHERE scopeItem.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier,
                   JSON_VALUE(CASE WHEN scopeItem.[type] = 5 THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52433, N'Form senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        INSERT INTO #SyncForms (FormId)
        SELECT DISTINCT CONVERT(uniqueidentifier, JSON_VALUE(scopeItem.[value], N'$.Id'))
        FROM OPENJSON(@FormIdsJson) AS scopeItem;
    END;

    IF @FormIdsJson IS NOT NULL AND NOT EXISTS (SELECT 1 FROM #SyncForms)
        RETURN;

    DECLARE @LockResult int;
    EXEC @LockResult = sys.sp_getapplock
        @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
        @LockMode = N'Exclusive',
        @LockOwner = N'Session',
        @LockTimeout = 30000;

    IF @LockResult < 0
        THROW 52403, N'Form senkronizasyon kilidi alınamadı.', 1;

    EXEC sys.sp_set_session_context
        @key = N'FormLifecycleSyncInProgress', @value = 1;

    BEGIN TRY
        DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

        /* Search only affected Forms for legacy matches. Ambiguity must still
           be checked against ALL Forms: a scoped call must not steal a legacy
           play that also matches an unrelated (even inactive) Form. */
        ;WITH ExactMatches AS
        (
            SELECT
                formRecord.Id AS FormId,
                play.Id AS PlayId,
                COUNT_BIG(*) OVER (PARTITION BY formRecord.Id) AS PlayMatchCount
            FROM dbo.Form AS formRecord
            INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
            INNER JOIN dbo.Plays AS play
                ON play.RecordType = 0
               AND play.SourceFormId IS NULL
               AND LOWER(LTRIM(RTRIM(play.PlayName))) =
                   LOWER(LTRIM(RTRIM(formRecord.RepertoireName)))
               AND LOWER(LTRIM(RTRIM(play.TheaterName))) =
                   LOWER(LTRIM(RTRIM(formRecord.TheatreName)))
        )
        UPDATE play
        SET SourceFormId = exact.FormId,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN ExactMatches AS exact ON exact.PlayId = play.Id
        WHERE exact.PlayMatchCount = 1
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Form AS otherForm
              WHERE otherForm.Id <> exact.FormId
                AND LOWER(LTRIM(RTRIM(otherForm.RepertoireName))) =
                    LOWER(LTRIM(RTRIM(play.PlayName)))
                AND LOWER(LTRIM(RTRIM(otherForm.TheatreName))) =
                    LOWER(LTRIM(RTRIM(play.TheaterName)))
          );

        INSERT INTO dbo.Plays
        (
            Id, PlayName, StatusCode, CreatedAt, CreatedBy, UpdatedAt,
            UpdatedBy, IsPublished, Slug, TheaterName, Phone,
            ContactPersonName, ContactPersonPhone, Address, Email,
            JuriOylamaStatus, KunyeGirisStatus, RecordType,
            SourceFormId, IsActive
        )
        SELECT
            NEWID(),
            formRecord.RepertoireName,
            1,
            formRecord.CreatedDate,
            NULL,
            formRecord.UpdatedDate,
            NULL,
            1,
            LOWER
            (
                CONCAT
                (
                    'kunye-',
                    REPLACE(formRecord.ApplicationNumber, ' ', '-'),
                    '-',
                    LEFT(CONVERT(varchar(36), formRecord.Id), 8)
                )
            ),
            formRecord.TheatreName,
            formRecord.Phone,
            COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName),
            COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone),
            NULL,
            formRecord.Email,
            0,
            0,
            0,
            formRecord.Id,
            1
        FROM dbo.Form AS formRecord
        INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
        WHERE formRecord.IsPublished = 1
          AND formRecord.IsActive = 1
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.Plays AS play
              WHERE play.SourceFormId = formRecord.Id
          );

        UPDATE play
        SET
            PlayName = formRecord.RepertoireName,
            CreatedAt = formRecord.CreatedDate,
            UpdatedAt = COALESCE(formRecord.UpdatedDate, @Now),
            TheaterName = formRecord.TheatreName,
            Phone = formRecord.Phone,
            ContactPersonName =
                COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName),
            ContactPersonPhone =
                COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone),
            Email = formRecord.Email
        FROM dbo.Plays AS play
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
        WHERE play.RecordType = 0
          AND EXISTS
          (
              SELECT CONVERT(varbinary(max), play.PlayName), play.CreatedAt,
                  CONVERT(varbinary(max), play.TheaterName),
                  CONVERT(varbinary(max), play.Phone),
                  CONVERT(varbinary(max), play.ContactPersonName),
                  CONVERT(varbinary(max), play.ContactPersonPhone),
                  CONVERT(varbinary(max), play.Email)
              EXCEPT
              SELECT CONVERT(varbinary(max), formRecord.RepertoireName), formRecord.CreatedDate,
                  CONVERT(varbinary(max), formRecord.TheatreName),
                  CONVERT(varbinary(max), formRecord.Phone),
                  CONVERT(varbinary(max), COALESCE(NULLIF(formRecord.ContactName, N''), formRecord.ApplicantName)),
                  CONVERT(varbinary(max), COALESCE(NULLIF(formRecord.ContactPhone, N''), formRecord.Phone)),
                  CONVERT(varbinary(max), formRecord.Email)
          );

        EXEC dbo.usp_SynchronizeFormCandidates @FormIdsJson = @FormIdsJson;

        CREATE TABLE #DeactivateForms
        (
            FormId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL
        );

        INSERT INTO #DeactivateForms (FormId, PlayId)
        SELECT formRecord.Id, play.Id
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
        WHERE play.IsActive = 1
          AND (formRecord.IsPublished = 0 OR formRecord.IsActive = 0);

        INSERT INTO dbo.FormLifecycleStates
        (
            Id, FormId, EntityName, EntityId, WasPublished, WasActive,
            WasJuriOylamaStatus, WasKunyeGirisStatus, WasStatusCode,
            DeactivatedAt, RestoredAt, IsPublished
        )
        SELECT
            NEWID(), affected.FormId, N'Play', play.Id,
            play.IsPublished, play.IsActive,
            play.JuriOylamaStatus, play.KunyeGirisStatus, play.StatusCode,
            @Now, NULL, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.Plays AS play ON play.Id = affected.PlayId
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.FormLifecycleStates AS state
            WHERE state.FormId = affected.FormId
              AND state.EntityName = N'Play'
              AND state.EntityId = play.Id
              AND state.IsPublished = 1
        );

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished, WasActive,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'PlayAwardCategory', candidate.Id,
               candidate.IsPublished, candidate.IsActive, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.PlayId = affected.PlayId
        WHERE candidate.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished, WasActive,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryVote', vote.Id,
               vote.IsPublished, vote.IsActive, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.PlayId = affected.PlayId
        INNER JOIN dbo.JuryVotes AS vote
            ON vote.PlayAwardCategoryId = candidate.Id
        WHERE vote.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryGameTicketFee', ticket.Id,
               ticket.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.JuryGameTicketFees AS ticket
            ON ticket.PlayId = affected.PlayId
        WHERE ticket.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'JuryAssignedPlay', assignment.Id,
               assignment.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.JuryAssignedPlays AS assignment
            ON assignment.PlayId = affected.PlayId
        WHERE assignment.IsPublished = 1;

        INSERT INTO dbo.FormLifecycleStates
            (Id, FormId, EntityName, EntityId, WasPublished,
             DeactivatedAt, IsPublished)
        SELECT NEWID(), affected.FormId, N'Blacklist', blacklist.Id,
               blacklist.IsPublished, @Now, 1
        FROM #DeactivateForms AS affected
        INNER JOIN dbo.Blacklist AS blacklist
            ON blacklist.PlayId = affected.PlayId
        WHERE blacklist.IsPublished = 1;

        UPDATE vote
        SET IsPublished = 0, IsActive = 0, UpdatedAt = @Now
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = candidate.PlayId
        WHERE vote.IsPublished = 1 OR vote.IsActive = 1;

        UPDATE candidate
        SET IsPublished = 0, IsActive = 0, UpdatedAt = @Now
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = candidate.PlayId
        WHERE candidate.IsPublished = 1 OR candidate.IsActive = 1;

        UPDATE ticket
        SET IsPublished = 0, UpdatedAt = @Now
        FROM dbo.JuryGameTicketFees AS ticket
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = ticket.PlayId
        WHERE ticket.IsPublished = 1;

        UPDATE assignment
        SET IsPublished = 0, UpdatedAt = @Now
        FROM dbo.JuryAssignedPlays AS assignment
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = assignment.PlayId
        WHERE assignment.IsPublished = 1;

        UPDATE blacklist
        SET IsPublished = 0
        FROM dbo.Blacklist AS blacklist
        INNER JOIN #DeactivateForms AS affected
            ON affected.PlayId = blacklist.PlayId
        WHERE blacklist.IsPublished = 1;

        UPDATE play
        SET IsActive = 0,
            JuriOylamaStatus = 0,
            KunyeGirisStatus = 0,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN #DeactivateForms AS affected ON affected.PlayId = play.Id;

        CREATE TABLE #ReactivateForms
        (
            FormId uniqueidentifier NOT NULL PRIMARY KEY,
            PlayId uniqueidentifier NOT NULL
        );

        INSERT INTO #ReactivateForms (FormId, PlayId)
        SELECT formRecord.Id, play.Id
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        INNER JOIN #SyncForms AS affected ON affected.FormId = formRecord.Id
        WHERE formRecord.IsPublished = 1
          AND formRecord.IsActive = 1
          AND play.IsActive = 0
          AND EXISTS
          (
              SELECT 1 FROM dbo.FormLifecycleStates AS state
              WHERE state.FormId = formRecord.Id
                AND state.EntityName = N'Play'
                AND state.EntityId = play.Id
                AND state.IsPublished = 1
          );

        UPDATE play
        SET IsActive = 1,
            JuriOylamaStatus = state.WasJuriOylamaStatus,
            KunyeGirisStatus = state.WasKunyeGirisStatus,
            StatusCode = state.WasStatusCode,
            UpdatedAt = @Now
        FROM dbo.Plays AS play
        INNER JOIN #ReactivateForms AS affected ON affected.PlayId = play.Id
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.FormId = affected.FormId
           AND state.EntityName = N'Play'
           AND state.EntityId = play.Id
           AND state.IsPublished = 1;

        UPDATE candidate
        SET IsPublished = state.WasPublished,
            IsActive = state.WasActive,
            UpdatedAt = @Now
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'PlayAwardCategory'
           AND state.EntityId = candidate.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = affected.FormId
        WHERE NOT
        (
            (formRecord.previousProductionVersion = 1
             AND (candidate.AwardCategoryCode = 1002
                  OR candidate.AwardCategoryCode BETWEEN 1007 AND 1011))
            OR (candidate.AwardCategoryCode = 1002
                AND NULLIF(LTRIM(RTRIM(formRecord.Director)), N'') IS NULL)
        );

        UPDATE vote
        SET IsPublished = state.WasPublished,
            IsActive = state.WasActive,
            UpdatedAt = @Now
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryVote'
           AND state.EntityId = vote.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE ticket
        SET IsPublished = state.WasPublished,
            UpdatedAt = @Now
        FROM dbo.JuryGameTicketFees AS ticket
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryGameTicketFee'
           AND state.EntityId = ticket.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE assignment
        SET IsPublished = state.WasPublished,
            UpdatedAt = @Now
        FROM dbo.JuryAssignedPlays AS assignment
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'JuryAssignedPlay'
           AND state.EntityId = assignment.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE blacklist
        SET IsPublished = state.WasPublished
        FROM dbo.Blacklist AS blacklist
        INNER JOIN dbo.FormLifecycleStates AS state
            ON state.EntityName = N'Blacklist'
           AND state.EntityId = blacklist.Id
           AND state.IsPublished = 1
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId;

        UPDATE state
        SET IsPublished = 0, RestoredAt = @Now
        FROM dbo.FormLifecycleStates AS state
        INNER JOIN #ReactivateForms AS affected
            ON affected.FormId = state.FormId
        WHERE state.IsPublished = 1;

        EXEC sys.sp_set_session_context
            @key = N'FormLifecycleSyncInProgress', @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
            @LockOwner = N'Session';
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'FormLifecycleSyncInProgress', @value = NULL;
        EXEC sys.sp_releaseapplock
            @Resource = N'AfifeAdmin.Forms.KunyePlaySync',
            @LockOwner = N'Session';
        THROW;
    END CATCH;
END;
GO

/*
    Keeps the editable admin projection and its source Form in sync.  The Form
    remains the import contract, while edits made through Plays or
    PlayAwardCategories are written back so a later Form synchronization cannot
    restore stale names or photos.
*/
CREATE OR ALTER PROCEDURE dbo.usp_SynchronizePlayDataToForms
    @PlayId uniqueidentifier = NULL,
    @PlayIdsJson nvarchar(max) = NULL,
    @SyncCandidateData bit = 1
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    /* Preserve the scalar and no-argument maintenance APIs. Trigger callers
       submit one set of affected Plays instead of invoking this proc per row. */
    CREATE TABLE #ReverseSyncPlays (PlayId uniqueidentifier NOT NULL PRIMARY KEY);
    IF @PlayIdsJson IS NULL
    BEGIN
        INSERT INTO #ReverseSyncPlays (PlayId)
        SELECT Id FROM dbo.Plays
        WHERE SourceFormId IS NOT NULL AND (@PlayId IS NULL OR Id = @PlayId);
    END
    ELSE
    BEGIN
        IF ISJSON(@PlayIdsJson) <> 1
           OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@PlayIdsJson,
               NCHAR(9), N' '), NCHAR(10), N' '), NCHAR(13), N' ')), 1) <> N'['
            THROW 52433, N'Play senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        IF EXISTS
        (
            SELECT 1 FROM OPENJSON(@PlayIdsJson) AS scopeItem
            WHERE scopeItem.[type] <> 5
               OR DATALENGTH(JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) <> 72
               OR TRY_CONVERT(uniqueidentifier, JSON_VALUE(CASE WHEN scopeItem.[type] = 5
                   THEN scopeItem.[value] ELSE N'{}' END, N'$.Id')) IS NULL
        )
            THROW 52433, N'Play senkronizasyon kapsamı geçerli bir Id dizisi olmalıdır.', 1;

        INSERT INTO #ReverseSyncPlays (PlayId)
        SELECT DISTINCT play.Id
        FROM OPENJSON(@PlayIdsJson) AS scopeItem
        INNER JOIN dbo.Plays AS play
            ON play.Id = CONVERT(uniqueidentifier, JSON_VALUE(scopeItem.[value], N'$.Id'))
        WHERE play.SourceFormId IS NOT NULL AND (@PlayId IS NULL OR play.Id = @PlayId);
    END;

    IF NOT EXISTS (SELECT 1 FROM #ReverseSyncPlays)
        RETURN;

    SET @SyncCandidateData = COALESCE(@SyncCandidateData, 1);
    EXEC sys.sp_set_session_context
        @key = N'PlayToFormSyncInProgress', @value = 1;

    BEGIN TRY
        DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

        /* A Play metadata edit must leave every imported JSON byte intact and
           must not read candidate image blobs or repair unrelated source slots. */
        IF @SyncCandidateData = 0
        BEGIN
            UPDATE formRecord
            SET RepertoireName = play.PlayName,
                TheatreName = play.TheaterName,
                Phone = COALESCE(play.Phone, formRecord.Phone),
                ContactName = play.ContactPersonName,
                ContactPhone = play.ContactPersonPhone,
                Email = COALESCE(play.Email, formRecord.Email),
                IsActive = play.IsActive,
                IsPublished = play.IsPublished,
                UpdatedDate = @Now
            FROM dbo.Form AS formRecord
            INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
            INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
            WHERE EXISTS
            (
                SELECT CONVERT(varbinary(max), play.PlayName),
                       CONVERT(varbinary(max), play.TheaterName),
                       CONVERT(varbinary(max), COALESCE(play.Phone, formRecord.Phone)),
                       CONVERT(varbinary(max), play.ContactPersonName),
                       CONVERT(varbinary(max), play.ContactPersonPhone),
                       CONVERT(varbinary(max), COALESCE(play.Email, formRecord.Email)),
                       play.IsActive, play.IsPublished
                EXCEPT
                SELECT CONVERT(varbinary(max), formRecord.RepertoireName),
                       CONVERT(varbinary(max), formRecord.TheatreName),
                       CONVERT(varbinary(max), formRecord.Phone),
                       CONVERT(varbinary(max), formRecord.ContactName),
                       CONVERT(varbinary(max), formRecord.ContactPhone),
                       CONVERT(varbinary(max), formRecord.Email),
                       formRecord.IsActive, formRecord.IsPublished
            );
        END
        ELSE
        BEGIN
        /* Admin-created candidates also need a stable Form array slot. */
        ;WITH MissingSlots AS
        (
            SELECT
                candidate.Id,
                COALESCE
                (
                    (
                        SELECT MAX(existing.SourceFormCandidateOrder)
                        FROM dbo.PlayAwardCategories AS existing
                        WHERE existing.PlayId = candidate.PlayId
                          AND existing.AwardCategoryCode = candidate.AwardCategoryCode
                    ),
                    0
                ) +
                ROW_NUMBER() OVER
                (
                    PARTITION BY candidate.PlayId, candidate.AwardCategoryCode
                    ORDER BY candidate.CreatedAt, candidate.RoleCode, candidate.Id
                ) AS NewSourceOrder
            FROM dbo.PlayAwardCategories AS candidate
            INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
            INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
            INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
            WHERE play.SourceFormId IS NOT NULL
              AND candidate.AwardCategoryCode BETWEEN 1003 AND 1011
              AND (formRecord.previousProductionVersion = 0
                   OR candidate.AwardCategoryCode BETWEEN 1003 AND 1006)
              AND candidate.SourceFormCandidateOrder IS NULL
              AND candidate.IsPublished = 1
              AND candidate.IsCurrent = 1
        )
        UPDATE candidate
        SET SourceFormCandidateOrder = missing.NewSourceOrder,
            UpdatedAt = COALESCE(candidate.UpdatedAt, @Now)
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN MissingSlots AS missing ON missing.Id = candidate.Id;

        CREATE TABLE #CandidatePayload
        (
            PlayId uniqueidentifier NOT NULL,
            AwardCategoryCode int NOT NULL,
            CandidateJson nvarchar(max) NOT NULL,
            PRIMARY KEY (PlayId, AwardCategoryCode)
        );

        INSERT INTO #CandidatePayload (PlayId, AwardCategoryCode, CandidateJson)
        SELECT play.Id,
               category.AwardCategoryCode,
               JSON_QUERY
               (
                   COALESCE
                   (
                       (
                           SELECT
                               candidate.Candidate AS [Name],
                               candidate.Role AS [Role],
                               candidateImage.FileName AS [ImageUrl],
                               /* FOR JSON serializes varbinary(max) as Base64. */
                               candidateImage.ImageData AS [Base64]
                           FROM dbo.PlayAwardCategories AS candidate
                           LEFT JOIN dbo.Images AS candidateImage
                               ON candidateImage.Id = candidate.PhotoImageId
                              AND candidateImage.IsPublished = 1
                           WHERE candidate.PlayId = play.Id
                             AND candidate.AwardCategoryCode = category.AwardCategoryCode
                             AND candidate.IsPublished = 1
                             AND candidate.IsCurrent = 1
                           ORDER BY
                               COALESCE(candidate.SourceFormCandidateOrder, 2147483647),
                               candidate.RoleCode,
                               candidate.CreatedAt,
                               candidate.Id
                           FOR JSON PATH
                       ),
                       N'[]'
                   )
               )
        FROM dbo.Plays AS play
        INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        CROSS JOIN
        (
            VALUES (1003), (1004), (1005), (1006), (1007),
                   (1008), (1009), (1010), (1011)
        ) AS category(AwardCategoryCode)
        WHERE play.SourceFormId IS NOT NULL
          AND (formRecord.previousProductionVersion = 0
               OR category.AwardCategoryCode BETWEEN 1003 AND 1006);

        UPDATE formRecord
        SET
            RepertoireName = play.PlayName,
            TheatreName = play.TheaterName,
            Phone = COALESCE(play.Phone, formRecord.Phone),
            ContactName = play.ContactPersonName,
            ContactPhone = play.ContactPersonPhone,
            Email = COALESCE(play.Email, formRecord.Email),
            Director = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL
                            ELSE COALESCE(director.Candidate, formRecord.Director) END,
            LeadActress = actress.CandidateJson,
            LeadActor = actor.CandidateJson,
            SupportActress = supportActress.CandidateJson,
            SupportActor = supportActor.CandidateJson,
            StageDesign = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageDesign.CandidateJson END,
            ClothesDesign = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE clothesDesign.CandidateJson END,
            StageMusic = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageMusic.CandidateJson END,
            LightDesign = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE lightDesign.CandidateJson END,
            Choreography = CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE choreography.CandidateJson END,
            IsActive = play.IsActive,
            IsPublished = play.IsPublished,
            UpdatedDate = @Now
        FROM dbo.Form AS formRecord
        INNER JOIN dbo.Plays AS play ON play.SourceFormId = formRecord.Id
        INNER JOIN #ReverseSyncPlays AS affected ON affected.PlayId = play.Id
        OUTER APPLY
        (
            SELECT TOP (1) candidate.Candidate
            FROM dbo.PlayAwardCategories AS candidate
            WHERE candidate.PlayId = play.Id
              AND formRecord.previousProductionVersion = 0
              AND candidate.AwardCategoryCode = 1002
              AND candidate.IsPublished = 1
              AND candidate.IsCurrent = 1
            ORDER BY COALESCE(candidate.SourceFormCandidateOrder, 0), candidate.Id
        ) AS director
        INNER JOIN #CandidatePayload AS actress
            ON actress.PlayId = play.Id AND actress.AwardCategoryCode = 1003
        INNER JOIN #CandidatePayload AS actor
            ON actor.PlayId = play.Id AND actor.AwardCategoryCode = 1004
        INNER JOIN #CandidatePayload AS supportActress
            ON supportActress.PlayId = play.Id AND supportActress.AwardCategoryCode = 1005
        INNER JOIN #CandidatePayload AS supportActor
            ON supportActor.PlayId = play.Id AND supportActor.AwardCategoryCode = 1006
        LEFT JOIN #CandidatePayload AS stageDesign
            ON stageDesign.PlayId = play.Id AND stageDesign.AwardCategoryCode = 1007
        LEFT JOIN #CandidatePayload AS clothesDesign
            ON clothesDesign.PlayId = play.Id AND clothesDesign.AwardCategoryCode = 1008
        LEFT JOIN #CandidatePayload AS stageMusic
            ON stageMusic.PlayId = play.Id AND stageMusic.AwardCategoryCode = 1009
        LEFT JOIN #CandidatePayload AS lightDesign
            ON lightDesign.PlayId = play.Id AND lightDesign.AwardCategoryCode = 1010
        LEFT JOIN #CandidatePayload AS choreography
            ON choreography.PlayId = play.Id AND choreography.AwardCategoryCode = 1011
        WHERE EXISTS
        (
            SELECT CONVERT(varbinary(max), play.PlayName),
                   CONVERT(varbinary(max), play.TheaterName),
                   CONVERT(varbinary(max), COALESCE(play.Phone, formRecord.Phone)),
                   CONVERT(varbinary(max), play.ContactPersonName),
                   CONVERT(varbinary(max), play.ContactPersonPhone),
                   CONVERT(varbinary(max), COALESCE(play.Email, formRecord.Email)),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL
                       ELSE COALESCE(director.Candidate, formRecord.Director) END),
                   CONVERT(varbinary(max), actress.CandidateJson),
                   CONVERT(varbinary(max), actor.CandidateJson),
                   CONVERT(varbinary(max), supportActress.CandidateJson),
                   CONVERT(varbinary(max), supportActor.CandidateJson),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageDesign.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE clothesDesign.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE stageMusic.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE lightDesign.CandidateJson END),
                   CONVERT(varbinary(max), CASE WHEN formRecord.previousProductionVersion = 1 THEN NULL ELSE choreography.CandidateJson END),
                   play.IsActive, play.IsPublished
            EXCEPT
            SELECT CONVERT(varbinary(max), formRecord.RepertoireName),
                   CONVERT(varbinary(max), formRecord.TheatreName),
                   CONVERT(varbinary(max), formRecord.Phone),
                   CONVERT(varbinary(max), formRecord.ContactName),
                   CONVERT(varbinary(max), formRecord.ContactPhone),
                   CONVERT(varbinary(max), formRecord.Email),
                   CONVERT(varbinary(max), formRecord.Director),
                   CONVERT(varbinary(max), formRecord.LeadActress),
                   CONVERT(varbinary(max), formRecord.LeadActor),
                   CONVERT(varbinary(max), formRecord.SupportActress),
                   CONVERT(varbinary(max), formRecord.SupportActor),
                   CONVERT(varbinary(max), formRecord.StageDesign),
                   CONVERT(varbinary(max), formRecord.ClothesDesign),
                   CONVERT(varbinary(max), formRecord.StageMusic),
                   CONVERT(varbinary(max), formRecord.LightDesign),
                   CONVERT(varbinary(max), formRecord.Choreography),
                   formRecord.IsActive, formRecord.IsPublished
        );
        END;

        EXEC sys.sp_set_session_context
            @key = N'PlayToFormSyncInProgress', @value = NULL;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context
            @key = N'PlayToFormSyncInProgress', @value = NULL;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingJuries_SoftDelete ON dbo.AdditionalVotingJuries INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingPlays_SoftDelete ON dbo.AdditionalVotingPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotings_SoftDelete
ON dbo.AdditionalVotings INSTEAD OF DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Now datetime2(7) = SYSDATETIME();
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotings target INNER JOIN deleted d ON d.Id = target.Id;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingJuries target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingPlays target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
    UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = @Now FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.AdditionalVotingId WHERE target.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AdditionalVotingUsages_SoftDelete ON dbo.AdditionalVotingUsages INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsActive = 0, IsPublished = 0, UpdatedAt = SYSDATETIME() FROM dbo.AdditionalVotingUsages target INNER JOIN deleted d ON d.Id = target.Id; END;
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

/* Direct SQL deletes are also soft deletes. */
CREATE OR ALTER TRIGGER dbo.TR_Announcements_SoftDelete ON dbo.Announcements INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Announcements target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_AwardCategories_SoftDelete ON dbo.AwardCategories INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.AwardCategories target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Blacklist_BlockAdminPlay]
ON [dbo].[Blacklist]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS blacklist
        INNER JOIN [dbo].[Plays] AS play
            ON play.[Id] = blacklist.[PlayId]
        WHERE play.[RecordType] = 1
    )
    BEGIN
        THROW 51213, N'RecordType 1 olan oyunlara blacklist kaydı eklenemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Blacklist_BlockInactiveSourceForm
ON dbo.Blacklist
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52414, N'Pasif Form kaynağı için yayımlanmış blacklist kaydı eklenemez.', 1;
END;
GO

/* A published blacklist entry immediately removes matching votes from circulation. */
CREATE OR ALTER TRIGGER [dbo].[TR_Blacklist_DeactivateJuryVotes]
ON [dbo].[Blacklist]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE vote
    SET vote.[IsPublished] = 0,
        vote.[IsActive] = 0,
        vote.[UpdatedAt] = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM [dbo].[JuryVotes] AS vote
    INNER JOIN [dbo].[PlayAwardCategories] AS candidate
        ON candidate.[Id] = vote.[PlayAwardCategoryId]
    INNER JOIN inserted AS blacklist
        ON blacklist.[JuryId] = vote.[JuryId]
       AND blacklist.[PlayId] = candidate.[PlayId]
       AND blacklist.[IsPublished] = 1
    WHERE vote.[IsPublished] = 1
       OR vote.[IsActive] = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Blacklist_SoftDelete ON dbo.Blacklist INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Blacklist target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Configs_ProtectJuryHomePageSettings
ON dbo.Configs
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Only ConfigValue/audit fields are editable for the four fixed keys.
       Ordinary Config rows retain their existing edit/soft-delete behavior. */
    IF EXISTS
    (
        SELECT 1
        FROM deleted AS previous
        LEFT JOIN inserted AS currentRow ON currentRow.id = previous.id
        WHERE previous.ConfigName IN
            (N'HomePageJuryTableEnabled', N'HomePageMissionTableEnabled',
             N'HomePageMostWatchedTableEnabled', N'HomePageLeastWatchedTableEnabled')
          AND (currentRow.id IS NULL OR
               DATALENGTH(currentRow.ConfigName) <> DATALENGTH(previous.ConfigName) OR
               currentRow.ConfigName COLLATE Latin1_General_100_BIN2 <>
               previous.ConfigName COLLATE Latin1_General_100_BIN2)
    )
        THROW 53213, N'Jüri ana ekran tablo ayarlarının sabit adı veya kimliği değiştirilemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Configs_SoftDelete ON dbo.Configs INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Configs target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Form_NormalizeSeasonAndSynchronize
ON dbo.Form
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* SQL fires statement triggers even when no rows match. An empty JSON
       scope can become NULL, which the maintenance procedure treats as all. */
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF TRY_CONVERT(bit, SESSION_CONTEXT(N'FormSeasonAssignmentSyncInProgress')) = 1
    BEGIN
        UPDATE target
        SET SeasonId = changed.SeasonId
        FROM dbo.Form AS target
        INNER JOIN inserted AS changed ON changed.Id = target.Id;
        RETURN;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        LEFT JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE previous.Id IS NOT NULL
          AND previous.Id <> changed.Id
    )
        THROW 52404, N'Form.Id oluşturulduktan sonra değiştirilemez.', 1;

    UPDATE target
    SET
        ApplicationNumber = changed.ApplicationNumber,
        SeasonId = season.Id,
        CreatedDate = changed.CreatedDate,
        UpdatedDate = changed.UpdatedDate,
        RepertoireName = changed.RepertoireName,
        TheatreName = changed.TheatreName,
        PremiereDate = changed.PremiereDate,
        Display = changed.Display,
        ApplicantName = changed.ApplicantName,
        ApplicantRole = changed.ApplicantRole,
        Phone = changed.Phone,
        Email = changed.Email,
        Director = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.Director END,
        ContactName = changed.ContactName,
        ContactPhone = changed.ContactPhone,
        LeadActress = changed.LeadActress,
        LeadActor = changed.LeadActor,
        SupportActress = changed.SupportActress,
        SupportActor = changed.SupportActor,
        StageDesign = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.StageDesign END,
        ClothesDesign = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.ClothesDesign END,
        LightDesign = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.LightDesign END,
        StageMusic = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.StageMusic END,
        Choreography = CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.Choreography END,
        YoungGenerationArtist = changed.YoungGenerationArtist,
        previousProductionVersion = changed.previousProductionVersion,
        IsActive = changed.IsActive,
        IsPublished = changed.IsPublished
    FROM dbo.Form AS target
    INNER JOIN inserted AS changed ON changed.Id = target.Id
    OUTER APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
          AND changed.CreatedDate IS NOT NULL
          AND CAST(changed.CreatedDate AS date) >= season.SeasonStartDate
          AND CAST(changed.CreatedDate AS date) < season.SeasonEndDate
        ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
    ) AS season;

    INSERT INTO dbo.Form
    (
        Id, ApplicationNumber, SeasonId, CreatedDate, UpdatedDate,
        RepertoireName, TheatreName, PremiereDate, Display, ApplicantName,
        ApplicantRole, Phone, Email, Director, ContactName, ContactPhone,
        LeadActress, LeadActor, SupportActress, SupportActor, StageDesign,
        ClothesDesign, LightDesign, StageMusic, Choreography,
        YoungGenerationArtist, previousProductionVersion,
        IsActive, IsPublished
    )
    SELECT
        changed.Id, changed.ApplicationNumber, season.Id,
        changed.CreatedDate, changed.UpdatedDate,
        changed.RepertoireName, changed.TheatreName, changed.PremiereDate,
        changed.Display, changed.ApplicantName, changed.ApplicantRole,
        changed.Phone, changed.Email,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.Director END,
        changed.ContactName, changed.ContactPhone,
        changed.LeadActress, changed.LeadActor,
        changed.SupportActress, changed.SupportActor,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.StageDesign END,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.ClothesDesign END,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.LightDesign END,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.StageMusic END,
        CASE WHEN changed.previousProductionVersion = 1 THEN NULL ELSE changed.Choreography END,
        changed.YoungGenerationArtist, changed.previousProductionVersion,
        changed.IsActive, changed.IsPublished
    FROM inserted AS changed
    OUTER APPLY
    (
        SELECT TOP (1) season.Id
        FROM dbo.Seasons AS season
        WHERE season.IsPublished = 1
          AND changed.CreatedDate IS NOT NULL
          AND CAST(changed.CreatedDate AS date) >= season.SeasonStartDate
          AND CAST(changed.CreatedDate AS date) < season.SeasonEndDate
        ORDER BY season.SeasonEndDate, season.SeasonStartDate DESC, season.Id
    ) AS season
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.Form AS target WHERE target.Id = changed.Id
    );

    /* A reverse synchronization has already made Form authoritative for this
       statement. Running the forward procedure here would re-enter the graph. */
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) <> 1
       OR SESSION_CONTEXT(N'PlayToFormSyncInProgress') IS NULL
    BEGIN
        DECLARE @FormIdsJson nvarchar(max) = (SELECT Id FROM inserted FOR JSON PATH);
        EXEC dbo.usp_SynchronizeFormsToPlays @FormIdsJson = @FormIdsJson;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Form_SoftDelete
ON dbo.Form
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;

    UPDATE target
    SET IsPublished = 0,
        IsActive = 0,
        UpdatedDate = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.Form AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;

    /* The UPDATE above already passes this statement's IDs through the Form
       INSERT/UPDATE trigger. Keep soft deletion within the same scope as well;
       never fall back to a full-history repair from a DELETE statement. */
    DECLARE @FormIdsJson nvarchar(max) = (SELECT Id FROM deleted FOR JSON PATH);
    EXEC dbo.usp_SynchronizeFormsToPlays @FormIdsJson = @FormIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Group_ProtectAssignments
ON dbo.[Group]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    /* Only non-deleted juries prevent removal. Inactive juries still count;
       deleted juries/admin users keep their historical GroupCode untouched.
       The indexed range lock covers concurrent membership state changes. */
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        INNER JOIN deleted AS previousGroup ON previousGroup.Id = changed.Id
        INNER JOIN dbo.Users AS member WITH (UPDLOCK, HOLDLOCK)
            ON member.GroupCode = changed.Code
        WHERE previousGroup.IsPublished = 1 AND changed.IsPublished = 0
          AND member.RoleCode = 2 AND member.IsPublished = 1
    )
        THROW 52820, N'Bu gruba bağlı jüriler bulunduğu için grup silinemez. Önce ilgili jürilerin grupla ilişiğini kesin.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Group_SoftDelete ON dbo.[Group] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Group] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Images_EnforceMaximumSize
ON dbo.Images
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* Retiring an existing legacy image does not upload or change its content.
       INSERT and every write to the image payload still receive all checks. */
    IF NOT (UPDATE(FileName) OR UPDATE(ContentType) OR UPDATE(ImageData))
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        WHERE
            (ContentType = N'image/jpeg' AND
                (LOWER(FileName) NOT LIKE N'%.jpg' AND LOWER(FileName) NOT LIKE N'%.jpeg'))
            OR (ContentType = N'image/png' AND LOWER(FileName) NOT LIKE N'%.png')
            OR (ContentType = N'image/webp' AND LOWER(FileName) NOT LIKE N'%.webp')
            OR ContentType NOT IN (N'image/jpeg', N'image/png', N'image/webp')
            OR
            (
                ContentType = N'image/jpeg'
                AND (DATALENGTH(ImageData) < 3 OR SUBSTRING(ImageData, 1, 3) <> 0xFFD8FF)
            )
            OR
            (
                ContentType = N'image/png'
                AND
                (
                    DATALENGTH(ImageData) < 8
                    OR SUBSTRING(ImageData, 1, 8) <> 0x89504E470D0A1A0A
                )
            )
            OR
            (
                ContentType = N'image/webp'
                AND
                (
                    DATALENGTH(ImageData) < 12
                    OR SUBSTRING(ImageData, 1, 4) <> 0x52494646
                    OR SUBSTRING(ImageData, 9, 4) <> 0x57454250
                )
            )
    )
        THROW 52432,
            N'Yalnızca dosya uzantısı, içerik türü ve imzası doğrulanan JPEG, PNG veya WebP görseller yüklenebilir.',
            1;

    IF EXISTS
    (
        SELECT 1 FROM inserted
        WHERE DATALENGTH(ImageData) > 150 * 1024 * 1024
    )
        THROW 52431, N'Görsel boyutu 150 MB''dan büyük olamaz.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Images_SoftDelete ON dbo.Images INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Images target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_BlockInactiveSourceForm
ON dbo.JuryAssignedPlays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52413, N'Pasif Form kaynağı için yayımlanmış jüri ataması eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryAssignedPlays_SoftDelete ON dbo.JuryAssignedPlays INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryAssignedPlays target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryGameTicketFees_BlockInactiveSourceForm
ON dbo.JuryGameTicketFees
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52412, N'Pasif Form kaynağı için yayımlanmış bilet ücreti eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryGameTicketFees_SoftDelete ON dbo.JuryGameTicketFees INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryGameTicketFees target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryLogs_SoftDelete
ON dbo.JuryLogs
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.JuryLogs AS target
    INNER JOIN deleted AS source ON source.Id = target.Id;
END;
GO

/* Defense in depth: a blacklisted jury/play pair cannot publish a vote. */
CREATE OR ALTER TRIGGER [dbo].[TR_JuryVotes_BlockBlacklistedJuryPlay]
ON [dbo].[JuryVotes]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS vote
        INNER JOIN [dbo].[PlayAwardCategories] AS candidate
            ON candidate.[Id] = vote.[PlayAwardCategoryId]
        INNER JOIN [dbo].[Blacklist] AS blacklist
            ON blacklist.[JuryId] = vote.[JuryId]
           AND blacklist.[PlayId] = candidate.[PlayId]
           AND blacklist.[IsPublished] = 1
        WHERE vote.[IsPublished] = 1
           OR vote.[IsActive] = 1
    )
    BEGIN
        THROW 51214, N'Blacklist kaydı bulunan jüri bu oyun için oy veremez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_BlockInactiveSourceForm
ON dbo.JuryVotes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = changed.PlayAwardCategoryId
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52411, N'Pasif Form kaynağı için yayımlanmış jüri oyu eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshRankings
ON dbo.JuryVotes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @DirtyCandidates TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY);
    ;WITH ChangedVotes AS
    (
        SELECT currentVote.PlayAwardCategoryId AS NewCandidateId,
               previousVote.PlayAwardCategoryId AS OldCandidateId
        FROM inserted AS currentVote
        FULL OUTER JOIN deleted AS previousVote ON previousVote.Id = currentVote.Id
        WHERE currentVote.Id IS NULL OR previousVote.Id IS NULL OR EXISTS
        (
            SELECT currentVote.PlayAwardCategoryId, currentVote.Score, currentVote.IsPublished, currentVote.IsActive
            EXCEPT
            SELECT previousVote.PlayAwardCategoryId, previousVote.Score, previousVote.IsPublished, previousVote.IsActive
        )
    )
    INSERT INTO @DirtyCandidates (Id)
    SELECT NewCandidateId FROM ChangedVotes WHERE NewCandidateId IS NOT NULL
    UNION
    SELECT OldCandidateId FROM ChangedVotes WHERE OldCandidateId IS NOT NULL;

    IF NOT EXISTS (SELECT 1 FROM @DirtyCandidates) RETURN;
    DECLARE @CategoryCodesJson nvarchar(max) = COALESCE((
        SELECT DISTINCT candidate.AwardCategoryCode AS CategoryCode
        FROM dbo.PlayAwardCategories AS candidate
        INNER JOIN @DirtyCandidates AS dirty ON dirty.Id = candidate.Id
        FOR JSON PATH
    ), N'[]');
    DECLARE @CandidateIdsJson nvarchar(max) = COALESCE((SELECT Id FROM @DirtyCandidates FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @CategoryCodesJson, @CandidateIdsJson = @CandidateIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_RefreshSeasonStatistics
ON dbo.JuryVotes AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Changed TABLE (Id uniqueidentifier PRIMARY KEY);
    INSERT @Changed
    SELECT COALESCE(i.Id, d.Id) FROM inserted i FULL JOIN deleted d ON d.Id = i.Id
    WHERE i.Id IS NULL OR d.Id IS NULL OR EXISTS
        (SELECT i.CreatedAt, i.IsPublished, i.IsActive, i.PlayAwardCategoryId
         EXCEPT SELECT d.CreatedAt, d.IsPublished, d.IsActive, d.PlayAwardCategoryId);
    IF NOT EXISTS (SELECT 1 FROM @Changed) RETURN;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT DISTINCT season.Id FROM dbo.Seasons season
        INNER JOIN
        (
            SELECT i.CreatedAt FROM inserted i INNER JOIN @Changed c ON c.Id = i.Id
            UNION SELECT d.CreatedAt FROM deleted d INNER JOIN @Changed c ON c.Id = d.Id
        ) changed ON changed.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
                 AND changed.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        WHERE season.IsPublished = 1 FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
GO

/* A new published vote soft-deletes every older vote in the same logical role. */
CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_SingleRecordPerPlayCategoryRole
ON dbo.JuryVotes
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AffectedGroups TABLE
    (
        JuryId uniqueidentifier NOT NULL,
        PlayId uniqueidentifier NOT NULL,
        AwardCategoryCode int NOT NULL,
        RoleCode int NOT NULL,
        WinnerVoteId uniqueidentifier NOT NULL,
        PRIMARY KEY (JuryId, PlayId, AwardCategoryCode, RoleCode)
    );

    ;WITH ChangedVotes AS
    (
        SELECT
            changedVote.Id,
            changedVote.JuryId,
            candidate.PlayId,
            candidate.AwardCategoryCode,
            candidate.RoleCode,
            ROW_NUMBER() OVER
            (
                PARTITION BY changedVote.JuryId, candidate.PlayId,
                    candidate.AwardCategoryCode, candidate.RoleCode
                ORDER BY COALESCE(changedVote.UpdatedAt, changedVote.CreatedAt,
                    CONVERT(datetime2, '19000101')) DESC, changedVote.Id DESC
            ) AS VoteOrder
        FROM inserted AS changedVote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = changedVote.PlayAwardCategoryId
        WHERE changedVote.IsPublished = 1
    )
    INSERT INTO @AffectedGroups
        (JuryId, PlayId, AwardCategoryCode, RoleCode, WinnerVoteId)
    SELECT JuryId, PlayId, AwardCategoryCode, RoleCode, Id
    FROM ChangedVotes
    WHERE VoteOrder = 1;

    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    INNER JOIN @AffectedGroups AS affected
        ON affected.JuryId = vote.JuryId
       AND affected.PlayId = candidate.PlayId
       AND affected.AwardCategoryCode = candidate.AwardCategoryCode
       AND affected.RoleCode = candidate.RoleCode
    WHERE vote.Id <> affected.WinnerVoteId
      AND vote.IsPublished = 1;

    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN inserted AS changedVote ON changedVote.Id = vote.Id
    INNER JOIN dbo.PlayAwardCategories AS candidate
        ON candidate.Id = vote.PlayAwardCategoryId
    WHERE (candidate.IsPublished = 0 AND vote.IsPublished = 1)
       OR (candidate.IsActive = 0 AND vote.IsActive = 1);
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_JuryVotes_SoftDelete ON dbo.JuryVotes INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.JuryVotes target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Log_SoftDelete ON dbo.[Log] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Log] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Manager_SoftDelete ON dbo.[Manager] INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.[Manager] target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_PlayAwardCategories_BlockAdminPlay]
ON [dbo].[PlayAwardCategories]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN [dbo].[Plays] AS play
            ON play.[Id] = candidate.[PlayId]
        WHERE play.[RecordType] = 1
    )
    BEGIN
        THROW 51211, N'RecordType 1 olan oyunlara aday veya ödül kategorisi eklenemez.', 1;
    END;
END;
GO

/* Reject new visible relationships while their source Form is inactive. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_BlockInactiveSourceForm
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1 RETURN;
    IF EXISTS
    (
        SELECT 1 FROM inserted AS changed
        INNER JOIN dbo.Plays AS play ON play.Id = changed.PlayId
        WHERE changed.IsPublished = 1 AND play.SourceFormId IS NOT NULL AND play.IsActive = 0
    )
        THROW 52410, N'Pasif Form kaynağına yayımlanmış aday/kategori eklenemez.', 1;
END;
GO

/* Previous productions cannot acquire director or technical-category candidates.
   Historical rows remain available when all three eligibility flags are off.
   Do not bypass this rule during lifecycle restoration: that must not resurrect
   a category excluded by the current Form contract. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_BlockPreviousProduction
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        INNER JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
        WHERE formRecord.previousProductionVersion = 1
          AND (candidate.AwardCategoryCode = 1002
               OR candidate.AwardCategoryCode BETWEEN 1007 AND 1011)
          AND (candidate.IsPublished = 1 OR candidate.IsActive = 1 OR candidate.IsCurrent = 1)
    )
        THROW 52434, N'Önceki prodüksiyon başvurularına yönetmen veya teknik kategori adayı eklenemez.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_EnforceMultiplicity
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    /* The Form synchronizer writes a complete snapshot inside one transaction.
       Permit it to normalize legacy intermediate values; normal application
       writes remain protected by every check below. */
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    IF EXISTS
    (
        SELECT 1 FROM inserted
        WHERE AwardCategoryCode = 1012
          AND (IsPublished = 1 OR IsActive = 1 OR IsCurrent = 1)
    )
        THROW 52430, N'1012 ödül kategorisi sistemden kaldırılmıştır.', 1;

    -- The 1001 row is a system-managed category slot, not a person candidate.
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE candidate.AwardCategoryCode = 1001
          AND
          (
              play.RecordType <> 0
              OR ISNULL(candidate.Role, N'') <> N'Tiyatro'
              OR candidate.Candidate <> play.TheaterName
              OR (candidate.RoleCode = 0 AND candidate.IsCurrent <> 1)
              OR
              (
                  candidate.RoleCode <> 0
                  AND
                  (
                      previousCandidate.Id IS NULL
                      OR previousCandidate.PlayId <> candidate.PlayId
                      OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                      OR previousCandidate.RoleCode <> candidate.RoleCode
                  )
              )
          )
    )
    BEGIN
        THROW 51302, N'1001 varsayilan oyun kategorisi sistem tarafindan yonetilir ve degistirilemez.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.Id IS NULL
           OR previousCandidate.PlayId <> candidate.PlayId
           OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
           OR previousCandidate.RoleCode <> candidate.RoleCode
           OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
    )
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 1
                AND (candidate.RoleCode <= 0 OR NULLIF(LTRIM(RTRIM(candidate.Role)), N'') IS NULL)
        )
        BEGIN
            THROW 51303, N'Cok adayli kategorilerde pozitif RoleCode ve dolu Role alani zorunludur.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM inserted AS candidate
            LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
            INNER JOIN dbo.AwardCategories AS category
                ON category.CategoryCode = candidate.AwardCategoryCode
            OUTER APPLY
            (
                SELECT TOP (1) existing.RoleCode
                FROM dbo.PlayAwardCategories AS existing
                WHERE existing.Id <> candidate.Id
                  AND existing.PlayId = candidate.PlayId
                  AND existing.AwardCategoryCode = candidate.AwardCategoryCode
                ORDER BY
                    existing.IsCurrent DESC,
                    COALESCE(existing.UpdatedAt, existing.CreatedAt, CONVERT(datetime2, '19000101')) DESC,
                    existing.Id
            ) AS canonicalSlot
            WHERE
                (
                    previousCandidate.Id IS NULL
                    OR previousCandidate.PlayId <> candidate.PlayId
                    OR previousCandidate.AwardCategoryCode <> candidate.AwardCategoryCode
                    OR previousCandidate.RoleCode <> candidate.RoleCode
                    OR ISNULL(previousCandidate.Role, N'') <> ISNULL(candidate.Role, N'')
                )
                AND category.MultiCandidate = 0
                AND candidate.AwardCategoryCode <> 1001
                AND
                (
                    candidate.Role IS NOT NULL
                    OR candidate.RoleCode <> COALESCE(canonicalSlot.RoleCode, 0)
                )
        )
        BEGIN
            THROW 51304, N'Tek adayli kategoriler yalnizca tek mantiksal slot ve bos Role alani kullanabilir.', 1;
        END;

        /* RoleCode is the stable identity. Role is editable display data and
           distinct role slots may intentionally use the same display name. */
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS candidate
        LEFT JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        INNER JOIN dbo.AwardCategories AS category
            ON category.CategoryCode = candidate.AwardCategoryCode
        WHERE category.MultiCandidate = 0
          AND (previousCandidate.Id IS NULL OR previousCandidate.IsCurrent <> candidate.IsCurrent)
          AND
          (
              SELECT COUNT_BIG(*)
              FROM dbo.PlayAwardCategories AS currentCandidate
              WHERE currentCandidate.PlayId = candidate.PlayId
                AND currentCandidate.AwardCategoryCode = candidate.AwardCategoryCode
                AND currentCandidate.IsCurrent = 1
          ) > 1
    )
    BEGIN
        THROW 51306, N'Tek adayli kategorilerde ayni anda yalnizca bir guncel aday olabilir.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_ProtectDefaultCategory
ON dbo.PlayAwardCategories
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM deleted AS candidate
        INNER JOIN dbo.Plays AS play ON play.Id = candidate.PlayId
        WHERE candidate.AwardCategoryCode = 1001
          AND candidate.RoleCode = 0
          AND play.RecordType = 0
    )
    BEGIN
        THROW 51307, N'Kunye oyunlarinin varsayilan 1001 kategori kaydi silinemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_RefreshRankings
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ChangedCandidates TABLE
    (
        Id uniqueidentifier NOT NULL PRIMARY KEY,
        OldCategoryCode int NULL,
        NewCategoryCode int NULL
    );
    INSERT INTO @ChangedCandidates (Id, OldCategoryCode, NewCategoryCode)
    SELECT COALESCE(currentCandidate.Id, previousCandidate.Id),
           previousCandidate.AwardCategoryCode, currentCandidate.AwardCategoryCode
    FROM inserted AS currentCandidate
    FULL OUTER JOIN deleted AS previousCandidate ON previousCandidate.Id = currentCandidate.Id
    WHERE currentCandidate.Id IS NULL OR previousCandidate.Id IS NULL OR EXISTS
    (
        SELECT currentCandidate.PlayId, currentCandidate.AwardCategoryCode,
               currentCandidate.IsPublished, currentCandidate.IsCurrent, currentCandidate.IsActive
        EXCEPT
        SELECT previousCandidate.PlayId, previousCandidate.AwardCategoryCode,
               previousCandidate.IsPublished, previousCandidate.IsCurrent, previousCandidate.IsActive
    );

    IF NOT EXISTS (SELECT 1 FROM @ChangedCandidates) RETURN;
    DECLARE @CategoryCodesJson nvarchar(max) = COALESCE((
        SELECT CategoryCode FROM
        (
            SELECT OldCategoryCode AS CategoryCode FROM @ChangedCandidates WHERE OldCategoryCode IS NOT NULL
            UNION
            SELECT NewCategoryCode FROM @ChangedCandidates WHERE NewCategoryCode IS NOT NULL
        ) AS affected
        FOR JSON PATH
    ), N'[]');
    DECLARE @CandidateIdsJson nvarchar(max) = COALESCE((SELECT Id FROM @ChangedCandidates FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @CategoryCodesJson, @CandidateIdsJson = @CandidateIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_RefreshSeasonStatistics
ON dbo.PlayAwardCategories AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT DISTINCT season.Id
        FROM inserted i INNER JOIN deleted d ON d.Id = i.Id
        INNER JOIN dbo.JuryVotes vote ON vote.PlayAwardCategoryId = i.Id
        INNER JOIN dbo.Seasons season
            ON vote.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
           AND vote.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        WHERE season.IsPublished = 1 AND vote.IsPublished = 1 AND vote.IsActive = 1
          AND EXISTS (SELECT i.PlayId, i.IsPublished, i.IsActive
                      EXCEPT SELECT d.PlayId, d.IsPublished, d.IsActive)
        FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SoftDelete
ON dbo.PlayAwardCategories
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted WHERE AwardCategoryCode IN (1001, 1002))
        THROW 51307, N'System-managed categories 1001 and 1002 cannot be deleted.', 1;

    UPDATE target
    SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories target
    INNER JOIN deleted source ON source.Id = target.Id;
END;
GO

/* Lifecycle sync restores votes explicitly from snapshots. */
CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SynchronizeJuryVotes
ON dbo.PlayAwardCategories
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
        RETURN;

    IF UPDATE(IsActive)
    BEGIN
        UPDATE vote
        SET vote.IsActive = candidate.IsActive,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsActive <> candidate.IsActive
          AND vote.IsPublished = 1
          AND vote.IsActive <> candidate.IsActive;
    END;

    IF UPDATE(IsPublished)
    BEGIN
        UPDATE vote
        SET vote.IsPublished = candidate.IsPublished,
            vote.IsActive = CASE
                WHEN candidate.IsPublished = 1 THEN candidate.IsActive ELSE 0 END,
            vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
        FROM dbo.JuryVotes AS vote
        INNER JOIN inserted AS candidate ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN deleted AS previousCandidate ON previousCandidate.Id = candidate.Id
        WHERE previousCandidate.IsPublished <> candidate.IsPublished
          AND
          (
              vote.IsPublished <> candidate.IsPublished
              OR vote.IsActive <> CASE
                    WHEN candidate.IsPublished = 1 THEN candidate.IsActive ELSE 0 END
          );
    END;

    IF NOT (UPDATE(PlayId) OR UPDATE(AwardCategoryCode) OR UPDATE(RoleCode))
        RETURN;

    ;WITH AffectedGroups AS
    (
        SELECT PlayId, AwardCategoryCode, RoleCode FROM inserted
        UNION
        SELECT PlayId, AwardCategoryCode, RoleCode FROM deleted
    ),
    RankedVotes AS
    (
        SELECT vote.Id,
               ROW_NUMBER() OVER
               (
                   PARTITION BY vote.JuryId, candidate.PlayId,
                       candidate.AwardCategoryCode, candidate.RoleCode
                   ORDER BY COALESCE(vote.UpdatedAt, vote.CreatedAt,
                       CONVERT(datetime2, '19000101')) DESC, vote.Id DESC
               ) AS VoteOrder
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        INNER JOIN AffectedGroups AS affected
            ON affected.PlayId = candidate.PlayId
           AND affected.AwardCategoryCode = candidate.AwardCategoryCode
           AND affected.RoleCode = candidate.RoleCode
        WHERE vote.IsPublished = 1
    )
    UPDATE vote
    SET vote.IsPublished = 0,
        vote.IsActive = 0,
        vote.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes AS vote
    INNER JOIN RankedVotes AS ranked ON ranked.Id = vote.Id
    WHERE ranked.VoteOrder > 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayAwardCategories_SynchronizeSourceForm
ON dbo.PlayAwardCategories
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    /* 1001 is generated automatically immediately after a Play insert. It has
       no Form candidate JSON field and must never clear the imported arrays. */
    IF NOT EXISTS
    (
        SELECT 1 FROM inserted WHERE AwardCategoryCode BETWEEN 1002 AND 1011
        UNION ALL
        SELECT 1 FROM deleted WHERE AwardCategoryCode BETWEEN 1002 AND 1011
    )
        RETURN;

    IF EXISTS (SELECT 1 FROM inserted)
       AND EXISTS (SELECT 1 FROM deleted)
       AND NOT
       (
           UPDATE(PlayId) OR UPDATE(Candidate) OR UPDATE(Role)
           OR UPDATE(PhotoImageId) OR UPDATE(AwardCategoryCode)
           OR UPDATE(IsPublished) OR UPDATE(IsCurrent)
       )
        RETURN;

    DECLARE @AffectedPlayIdsJson nvarchar(max);
    ;WITH ChangedCandidates AS
    (
        SELECT changed.PlayId AS NewPlayId, previous.PlayId AS OldPlayId
        FROM inserted AS changed
        FULL OUTER JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE (changed.AwardCategoryCode BETWEEN 1002 AND 1011
               OR previous.AwardCategoryCode BETWEEN 1002 AND 1011)
          AND
          (
              changed.Id IS NULL OR previous.Id IS NULL
              OR EXISTS
              (
                  SELECT changed.PlayId, changed.AwardCategoryCode,
                         CONVERT(varbinary(max), changed.Candidate),
                         CONVERT(varbinary(max), changed.Role), changed.PhotoImageId,
                         changed.IsPublished, changed.IsCurrent
                  EXCEPT
                  SELECT previous.PlayId, previous.AwardCategoryCode,
                         CONVERT(varbinary(max), previous.Candidate),
                         CONVERT(varbinary(max), previous.Role), previous.PhotoImageId,
                         previous.IsPublished, previous.IsCurrent
              )
          )
    ), AffectedPlays AS
    (
        SELECT NewPlayId AS PlayId FROM ChangedCandidates WHERE NewPlayId IS NOT NULL
        UNION
        SELECT OldPlayId FROM ChangedCandidates WHERE OldPlayId IS NOT NULL
    )
    SELECT @AffectedPlayIdsJson =
    (
        SELECT play.Id
        FROM dbo.Plays AS play
        INNER JOIN AffectedPlays AS affected ON affected.PlayId = play.Id
        WHERE play.SourceFormId IS NOT NULL
        FOR JSON PATH
    );

    /* Empty FOR JSON assignments can be SQL NULL; never expand a no-op DML
       statement into the procedure's NULL/full-maintenance scope. */
    IF @AffectedPlayIdsJson IS NULL OR @AffectedPlayIdsJson = N'[]' RETURN;
    EXEC dbo.usp_SynchronizePlayDataToForms
        @PlayIdsJson = @AffectedPlayIdsJson, @SyncCandidateData = 1;
END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Plays_BlockAdminRecordTypeWithCandidates]
ON [dbo].[Plays]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- UPDATE(column) is true even when a SET clause writes the same value.
    -- Enforce the rule only when RecordType actually changes from Kunye (0)
    -- to Admin (1), leaving both status toggles editable for Kunye plays.
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS currentPlay
        INNER JOIN deleted AS previousPlay
            ON previousPlay.[Id] = currentPlay.[Id]
        WHERE previousPlay.[RecordType] = 0
          AND currentPlay.[RecordType] = 1
    )
       AND
       (
           EXISTS
           (
               SELECT 1
               FROM inserted AS play
               INNER JOIN [dbo].[PlayAwardCategories] AS candidate
                   ON candidate.[PlayId] = play.[Id]
               WHERE play.[RecordType] = 1
           )
           OR EXISTS
           (
               SELECT 1
               FROM inserted AS play
               INNER JOIN [dbo].[Blacklist] AS blacklist
                   ON blacklist.[PlayId] = play.[Id]
               WHERE play.[RecordType] = 1
           )
       )
    BEGIN
        THROW 51212, N'Aday veya blacklist kaydı bulunan bir oyun RecordType 1 olarak değiştirilemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_EnsureDefaultAwardCategory
ON dbo.Plays
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE defaultCategory
    SET
        defaultCategory.Candidate = currentPlay.TheaterName,
        defaultCategory.Role = N'Tiyatro',
        defaultCategory.IsPublished = expected.IsPublished,
        defaultCategory.IsActive = CASE
            WHEN lifecycle.IsSynchronizing = 1 THEN defaultCategory.IsActive
            WHEN expected.IsPublished = 0 THEN 0
            WHEN defaultCategory.IsPublished = 0 THEN 1
            ELSE defaultCategory.IsActive END,
        defaultCategory.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME()),
        defaultCategory.UpdatedBy = currentPlay.UpdatedBy
    FROM dbo.PlayAwardCategories AS defaultCategory
    INNER JOIN inserted AS currentPlay ON currentPlay.Id = defaultCategory.PlayId
    INNER JOIN deleted AS previousPlay ON previousPlay.Id = currentPlay.Id
    LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = currentPlay.SourceFormId
    CROSS APPLY
    (
        SELECT CONVERT(bit, CASE
            WHEN TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
                THEN 1 ELSE 0 END) AS IsSynchronizing
    ) AS lifecycle
    CROSS APPLY
    (
        /* Form lifecycle captures the current flags before deactivation and
           restores them explicitly. Metadata updates must not overwrite that
           snapshot or a manually disabled default candidate. */
        SELECT CONVERT(bit, CASE
            WHEN lifecycle.IsSynchronizing = 1 THEN defaultCategory.IsPublished
            WHEN currentPlay.IsPublished = 1
             AND currentPlay.IsActive = 1
             AND
             (
                 currentPlay.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END) AS IsPublished
    ) AS expected
    WHERE currentPlay.RecordType = 0
      AND defaultCategory.AwardCategoryCode = 1001
      AND
      (
          currentPlay.TheaterName <> previousPlay.TheaterName
          OR defaultCategory.Candidate <> currentPlay.TheaterName
          OR ISNULL(defaultCategory.Role, N'') <> N'Tiyatro'
          OR defaultCategory.IsPublished <> expected.IsPublished
          OR defaultCategory.IsActive <> CASE
              WHEN lifecycle.IsSynchronizing = 1 THEN defaultCategory.IsActive
              WHEN expected.IsPublished = 0 THEN 0
              WHEN defaultCategory.IsPublished = 0 THEN 1
              ELSE defaultCategory.IsActive END
      );

    INSERT INTO dbo.PlayAwardCategories
    (
        Id, PlayId, CreatedAt, CreatedBy, UpdatedAt, UpdatedBy, IsPublished, IsActive,
        Candidate, AwardCategoryCode, IsCurrent, Role, RoleCode, PhotoImageId
    )
    SELECT
        NEWID(),
        play.Id,
        COALESCE(play.CreatedAt, DATEADD(HOUR, 3, SYSUTCDATETIME())),
        play.CreatedBy,
        NULL,
        NULL,
        CASE
            WHEN play.IsPublished = 1
             AND play.IsActive = 1
             AND
             (
                 play.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END,
        CASE
            WHEN play.IsPublished = 1
             AND play.IsActive = 1
             AND
             (
                 play.SourceFormId IS NULL
                 OR (formRecord.IsPublished = 1 AND formRecord.IsActive = 1)
             ) THEN 1 ELSE 0 END,
        play.TheaterName,
        1001,
        1,
        N'Tiyatro',
        0,
        NULL
    FROM inserted AS play
    LEFT JOIN dbo.Form AS formRecord ON formRecord.Id = play.SourceFormId
    WHERE play.RecordType = 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.PlayAwardCategories AS candidate WITH (UPDLOCK, HOLDLOCK)
          WHERE candidate.PlayId = play.Id
            AND candidate.AwardCategoryCode = 1001
            AND candidate.RoleCode = 0
      );
END;
GO

CREATE OR ALTER TRIGGER [dbo].[TR_Plays_RecordTypeImmutable]
ON [dbo].[Plays]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS currentPlay
        INNER JOIN deleted AS previousPlay
            ON previousPlay.[Id] = currentPlay.[Id]
        WHERE currentPlay.[RecordType] <> previousPlay.[RecordType]
    )
    BEGIN
        THROW 51231, N'Mevcut bir oyunun RecordType degeri degistirilemez.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshRankings
ON dbo.Plays
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ChangedPlays TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY);
    INSERT INTO @ChangedPlays (Id)
    SELECT COALESCE(currentPlay.Id, previousPlay.Id)
    FROM inserted AS currentPlay
    FULL OUTER JOIN deleted AS previousPlay ON previousPlay.Id = currentPlay.Id
    WHERE currentPlay.Id IS NULL OR previousPlay.Id IS NULL OR EXISTS
    (
        SELECT currentPlay.RecordType, currentPlay.IsPublished, currentPlay.IsActive
        EXCEPT
        SELECT previousPlay.RecordType, previousPlay.IsPublished, previousPlay.IsActive
    );

    /* Eligibility changes affect every candidate on these plays, including a
       direct IsActive toggle. Pure metadata edits leave ranking metrics alone. */
    DECLARE @DirtyCandidates TABLE (Id uniqueidentifier NOT NULL PRIMARY KEY, CategoryCode int NOT NULL);
    INSERT INTO @DirtyCandidates (Id, CategoryCode)
    SELECT candidate.Id, candidate.AwardCategoryCode
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN @ChangedPlays AS affected ON affected.Id = candidate.PlayId;

    IF NOT EXISTS (SELECT 1 FROM @DirtyCandidates) RETURN;
    DECLARE @CategoryCodesJson nvarchar(max) =
        COALESCE((SELECT DISTINCT CategoryCode FROM @DirtyCandidates FOR JSON PATH), N'[]');
    DECLARE @CandidateIdsJson nvarchar(max) = COALESCE((SELECT Id FROM @DirtyCandidates FOR JSON PATH), N'[]');
    EXEC dbo.usp_RefreshRankings @CategoryCodesJson = @CategoryCodesJson, @CandidateIdsJson = @CandidateIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_RefreshSeasonStatistics
ON dbo.Plays AFTER INSERT, UPDATE, DELETE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Changed TABLE (Id uniqueidentifier PRIMARY KEY, EligibilityChanged bit NOT NULL);
    INSERT @Changed
    SELECT COALESCE(i.Id, d.Id),
        CASE WHEN i.Id IS NULL OR d.Id IS NULL OR EXISTS
            (SELECT i.IsPublished, i.IsActive EXCEPT SELECT d.IsPublished, d.IsActive) THEN 1 ELSE 0 END
    FROM inserted i FULL JOIN deleted d ON d.Id = i.Id
    WHERE i.Id IS NULL OR d.Id IS NULL OR EXISTS
        (SELECT i.CreatedAt, i.IsPublished, i.IsActive, i.StatusCode
         EXCEPT SELECT d.CreatedAt, d.IsPublished, d.IsActive, d.StatusCode);
    IF NOT EXISTS (SELECT 1 FROM @Changed) RETURN;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT DISTINCT season.Id FROM dbo.Seasons season
        INNER JOIN
        (
            SELECT i.CreatedAt FROM inserted i INNER JOIN @Changed c ON c.Id = i.Id
            UNION SELECT d.CreatedAt FROM deleted d INNER JOIN @Changed c ON c.Id = d.Id
            /* A play and its votes may belong to different calendar seasons. */
            UNION SELECT vote.CreatedAt FROM @Changed c
            INNER JOIN dbo.PlayAwardCategories candidate ON candidate.PlayId = c.Id
            INNER JOIN dbo.JuryVotes vote ON vote.PlayAwardCategoryId = candidate.Id
            WHERE c.EligibilityChanged = 1 AND vote.IsPublished = 1 AND vote.IsActive = 1
        ) changed ON changed.CreatedAt >= CONVERT(datetime2(7), season.SeasonStartDate)
                 AND changed.CreatedAt < CONVERT(datetime2(7), season.SeasonEndDate)
        WHERE season.IsPublished = 1 FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDelete
ON dbo.Plays
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted WHERE RecordType = 0)
        THROW 51502, N'Kunye Giris Sistemi kaynakli oyunlar silinemez.', 1;

    UPDATE target
    SET IsPublished = 0
    FROM dbo.Plays target
    INNER JOIN deleted source ON source.Id = target.Id
    WHERE source.RecordType = 1;
END;
GO

/* EF soft deletes are UPDATE operations, so dependent rows are soft-deleted here. */
CREATE OR ALTER TRIGGER dbo.TR_Plays_SoftDeleteDependents
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE candidate
    SET candidate.IsPublished = 0,
        candidate.IsActive = 0,
        candidate.UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.PlayAwardCategories candidate
    INNER JOIN inserted play ON play.Id = candidate.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND candidate.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted play ON play.Id = assignment.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted play ON play.Id = fee.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted play ON play.Id = blacklist.PlayId
    INNER JOIN deleted previousPlay ON previousPlay.Id = play.Id
    WHERE previousPlay.IsPublished = 1 AND play.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_SynchronizeSlug
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(PlayName)
        RETURN;

    DECLARE @PlayId uniqueidentifier;
    DECLARE @PlayName nvarchar(255);
    DECLARE @BaseSlug varchar(255);
    DECLARE @Slug varchar(255);
    DECLARE @Suffix varchar(12);
    DECLARE @Counter int;

    DECLARE ChangedPlays CURSOR LOCAL FAST_FORWARD FOR
        SELECT insertedRecord.Id, insertedRecord.PlayName
        FROM inserted AS insertedRecord
        INNER JOIN deleted AS deletedRecord ON deletedRecord.Id = insertedRecord.Id
        WHERE ISNULL(insertedRecord.PlayName, N'') <> ISNULL(deletedRecord.PlayName, N'')
        ORDER BY insertedRecord.Id;

    OPEN ChangedPlays;
    FETCH NEXT FROM ChangedPlays INTO @PlayId, @PlayName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @BaseSlug = dbo.ufn_CreatePlaySlug(@PlayName);
        SET @Slug = @BaseSlug;
        SET @Counter = 2;

        WHILE EXISTS
        (
            SELECT 1
            FROM dbo.Plays WITH (UPDLOCK, HOLDLOCK)
            WHERE Id <> @PlayId
              AND Slug = @Slug
        )
        BEGIN
            SET @Suffix = '-' + CONVERT(varchar(10), @Counter);
            SET @Slug = LEFT(@BaseSlug, 255 - LEN(@Suffix)) + @Suffix;
            SET @Counter += 1;
        END;

        UPDATE dbo.Plays
        SET Slug = @Slug
        WHERE Id = @PlayId
          AND ISNULL(Slug, '') <> @Slug;

        FETCH NEXT FROM ChangedPlays INTO @PlayId, @PlayName;
    END;

    CLOSE ChangedPlays;
    DEALLOCATE ChangedPlays;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Plays_SynchronizeSourceForm
ON dbo.Plays
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1
        RETURN;

    IF NOT
       (
           UPDATE(PlayName) OR UPDATE(TheaterName) OR UPDATE(Phone)
           OR UPDATE(ContactPersonName) OR UPDATE(ContactPersonPhone)
           OR UPDATE(Email) OR UPDATE(IsActive) OR UPDATE(IsPublished)
       )
        RETURN;

    DECLARE @AffectedPlayIdsJson nvarchar(max) =
    (
        SELECT changed.Id
        FROM inserted AS changed
        INNER JOIN deleted AS previous ON previous.Id = changed.Id
        WHERE changed.SourceFormId IS NOT NULL
          AND EXISTS
          (
              SELECT CONVERT(varbinary(max), changed.PlayName),
                     CONVERT(varbinary(max), changed.TheaterName),
                     CONVERT(varbinary(max), changed.Phone),
                     CONVERT(varbinary(max), changed.ContactPersonName),
                     CONVERT(varbinary(max), changed.ContactPersonPhone),
                     CONVERT(varbinary(max), changed.Email),
                     changed.IsActive, changed.IsPublished
              EXCEPT
              SELECT CONVERT(varbinary(max), previous.PlayName),
                     CONVERT(varbinary(max), previous.TheaterName),
                     CONVERT(varbinary(max), previous.Phone),
                     CONVERT(varbinary(max), previous.ContactPersonName),
                     CONVERT(varbinary(max), previous.ContactPersonPhone),
                     CONVERT(varbinary(max), previous.Email),
                     previous.IsActive, previous.IsPublished
          )
        FOR JSON PATH
    );

    /* Empty FOR JSON assignments can be SQL NULL; NULL is the procedure's
       explicit full-maintenance API and must never come from an empty trigger. */
    IF @AffectedPlayIdsJson IS NULL OR @AffectedPlayIdsJson = N'[]' RETURN;
    EXEC dbo.usp_SynchronizePlayDataToForms
        @PlayIdsJson = @AffectedPlayIdsJson, @SyncCandidateData = 0;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_PlayStatuses_SoftDelete ON dbo.PlayStatuses INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.PlayStatuses target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Rankings_BlockManualDelete
ON dbo.Rankings
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 52003,
        N'Rankings rows cannot be deleted manually.',
        1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Rankings_BlockManualWrite
ON dbo.Rankings
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRY_CONVERT(int, SESSION_CONTEXT(N'RankingsRefreshAuthorized')) <> 1
       OR SESSION_CONTEXT(N'RankingsRefreshAuthorized') IS NULL
    BEGIN
        THROW 52002,
            N'Rankings can only be changed by dbo.usp_RefreshRankings.',
            1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Roles_SoftDelete ON dbo.Roles INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Roles target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_PreventPublishedDateOverlap
ON dbo.Seasons
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SeasonStartDate) OR UPDATE(SeasonEndDate) OR UPDATE(IsPublished))
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS changed
        INNER JOIN dbo.Seasons AS existing
            ON existing.Id <> changed.Id
           AND existing.IsPublished = 1
           AND changed.SeasonStartDate <= existing.SeasonEndDate
           AND changed.SeasonEndDate >= existing.SeasonStartDate
        WHERE changed.IsPublished = 1
    )
        THROW 51912, N'Yayımlanmış sezonların tarih aralıkları çakışamaz veya ortak sınır tarihine sahip olamaz.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_ReassignForms
ON dbo.Seasons AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(int, SESSION_CONTEXT(N'FormLifecycleSyncInProgress')) = 1
       OR TRY_CONVERT(int, SESSION_CONTEXT(N'PlayToFormSyncInProgress')) = 1 RETURN;
    DECLARE @Changed TABLE (Id uniqueidentifier PRIMARY KEY);
    INSERT @Changed
    SELECT i.Id FROM inserted i LEFT JOIN deleted d ON d.Id = i.Id
    WHERE d.Id IS NULL OR EXISTS
        (SELECT i.SeasonStartDate, i.SeasonEndDate, i.IsPublished
         EXCEPT SELECT d.SeasonStartDate, d.SeasonEndDate, d.IsPublished);
    IF NOT EXISTS (SELECT 1 FROM @Changed) RETURN;
    DECLARE @ChangedSeasonsJson nvarchar(max) =
    (
        SELECT ranges.Id, ranges.SeasonStartDate AS StartDate, ranges.SeasonEndDate AS EndDate
        FROM
        (
            SELECT i.Id, i.SeasonStartDate, i.SeasonEndDate FROM inserted i INNER JOIN @Changed c ON c.Id = i.Id
            UNION SELECT d.Id, d.SeasonStartDate, d.SeasonEndDate FROM deleted d INNER JOIN @Changed c ON c.Id = d.Id
        ) ranges FOR JSON PATH
    );
    EXEC dbo.usp_ReassignFormSeasons @ChangedSeasonsJson = @ChangedSeasonsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_RefreshStatistics
ON dbo.Seasons AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SeasonIdsJson nvarchar(max) =
    (
        SELECT i.Id FROM inserted i LEFT JOIN deleted d ON d.Id = i.Id
        WHERE d.Id IS NULL OR EXISTS
            (SELECT i.SeasonStartDate, i.SeasonEndDate, i.IsPublished
             EXCEPT SELECT d.SeasonStartDate, d.SeasonEndDate, d.IsPublished)
        FOR JSON PATH
    );
    IF @SeasonIdsJson IS NULL OR @SeasonIdsJson = N'[]' RETURN;
    EXEC dbo.usp_RefreshSeasonStatistics @SeasonIdsJson = @SeasonIdsJson;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Seasons_SoftDelete
ON dbo.Seasons
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE season
    SET IsPublished = 0
    FROM dbo.Seasons AS season
    INNER JOIN deleted AS removed ON removed.Id = season.Id;

    /* The UPDATE trigger reassigns only these seasons' old/new ranges. */
END;
GO

/* Security metadata is append-only. Rotation/revocation append framework XML;
   old keys remain available for already issued cookies and antiforgery tokens.
   Never serialize this table's secret XML into the generic full-row audit. */
CREATE OR ALTER TRIGGER dbo.TR_SharedAdminDataProtectionKeys_AppendOnly
ON dbo.SharedAdminDataProtectionKeys
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) OR EXISTS (SELECT 1 FROM deleted)
        THROW 52750, N'Shared admin Data Protection keys are append-only.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDelete ON dbo.Users INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0, IsActive = 0 FROM dbo.Users target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Users_SoftDeleteDependents
ON dbo.Users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(IsPublished) RETURN;

    UPDATE vote SET IsPublished = 0, IsActive = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryVotes vote
    INNER JOIN inserted jury ON jury.Id = vote.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND vote.IsPublished = 1;

    UPDATE assignment SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryAssignedPlays assignment
    INNER JOIN inserted jury ON jury.Id = assignment.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND assignment.IsPublished = 1;

    UPDATE fee SET IsPublished = 0,
        UpdatedAt = DATEADD(HOUR, 3, SYSUTCDATETIME())
    FROM dbo.JuryGameTicketFees fee
    INNER JOIN inserted jury ON jury.Id = fee.UserId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND fee.IsPublished = 1;

    UPDATE blacklist SET IsPublished = 0
    FROM dbo.Blacklist blacklist
    INNER JOIN inserted jury ON jury.Id = blacklist.JuryId
    INNER JOIN deleted previousJury ON previousJury.Id = jury.Id
    WHERE previousJury.IsPublished = 1 AND jury.IsPublished = 0
      AND blacklist.IsPublished = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_Users_ValidateGroupAssignment
ON dbo.Users
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(GroupCode) AND NOT UPDATE(IsPublished) AND NOT UPDATE(RoleCode) RETURN;

    /* Old relationships to an unpublished group remain editable. An old Code
       disappearing while its FK changes proves a parent-key cascade (the
       enabled FK forbids an orphan before this update), not a new membership.
       Restoring a deleted jury or promoting an admin to a published jury must
       also validate the group, even when the stored GroupCode stays the same. */
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS member
        LEFT JOIN deleted AS previousMember ON previousMember.Id = member.Id
        INNER JOIN dbo.[Group] AS selectedGroup WITH (HOLDLOCK)
            ON selectedGroup.Code = member.GroupCode
        WHERE member.GroupCode IS NOT NULL
          AND
          (
              previousMember.Id IS NULL OR previousMember.GroupCode IS NULL
              OR (previousMember.GroupCode <> member.GroupCode AND EXISTS
                  (SELECT 1 FROM dbo.[Group] AS previousGroup WITH (HOLDLOCK)
                   WHERE previousGroup.Code = previousMember.GroupCode))
              OR (member.RoleCode = 2 AND member.IsPublished = 1
                  AND (previousMember.IsPublished = 0 OR previousMember.RoleCode <> 2))
          )
          AND selectedGroup.IsPublished = 0
    )
        THROW 52821, N'Yalnızca yayındaki jüri grupları seçilebilir. Grup listesini yenileyip tekrar deneyin.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.TR_UsersLog_SoftDelete ON dbo.UsersLog INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.UsersLog target INNER JOIN deleted source ON source.Id = target.Id; END;
GO

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
  /* Crypto XML is secret framework metadata, not a business-row audit payload. */
  AND NOT (schemaInfo.name = N'dbo' AND tableInfo.name IN (N'AdminLogs', N'JuryLogs', N'UsersLog', N'JuryPasswordResetTokens', N'SharedAdminDataProtectionKeys', N'__EFMigrationsHistory'))
  AND NOT (schemaInfo.name = N'dbo' AND tableInfo.name LIKE N'\_\_Archived\_SharedAdminDataProtectionKeys\_%' ESCAPE N'\')
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

-- </AFIFE:UP>
-- <AFIFE:SHA256:DOWN=90B3F4BD2C298D243E5786778C4ED9D353D5E2DAF07F68AE52B3B4C060078EA0>
-- <AFIFE:SHA256-LF:DOWN=90B3F4BD2C298D243E5786778C4ED9D353D5E2DAF07F68AE52B3B4C060078EA0:BC8D7427DD7E6EA31DA06A5D82F286444DBC67846ADDF5C8719A4041D139487E>
-- <AFIFE:BATCHES:DOWN=75>
-- <AFIFE:DOWN:REFERENCE=GroupDeletionRules_v_20261027114234:UP>
