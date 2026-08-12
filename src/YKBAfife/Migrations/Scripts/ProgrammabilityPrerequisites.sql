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
