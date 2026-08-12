SET XACT_ABORT ON;

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'AfifeBaselineAlreadyExists')) <> 1
    RETURN;

/* Fail before mutation when canonical uniqueness cannot be established safely. */
IF EXISTS (SELECT CategoryCode FROM dbo.AwardCategories GROUP BY CategoryCode HAVING COUNT(*) > 1)
    THROW 51010, 'Legacy upgrade blocked: duplicate AwardCategories.CategoryCode values exist.', 1;
IF EXISTS (SELECT Code FROM dbo.[Group] GROUP BY Code HAVING COUNT(*) > 1)
    THROW 51011, 'Legacy upgrade blocked: duplicate Group.Code values exist.', 1;
IF EXISTS (SELECT StatusCode FROM dbo.PlayStatuses GROUP BY StatusCode HAVING COUNT(*) > 1)
    THROW 51012, 'Legacy upgrade blocked: duplicate PlayStatuses.StatusCode values exist.', 1;
IF EXISTS (SELECT RoleCode FROM dbo.Roles GROUP BY RoleCode HAVING COUNT(*) > 1)
    THROW 51013, 'Legacy upgrade blocked: duplicate Roles.RoleCode values exist.', 1;
IF EXISTS (SELECT RoleCode, Username FROM dbo.Users WHERE IsPublished = 1 GROUP BY RoleCode, Username HAVING COUNT(*) > 1)
    THROW 51014, 'Legacy upgrade blocked: duplicate published Users RoleCode/Username values exist.', 1;
IF EXISTS (SELECT RoleCode, Email FROM dbo.Users WHERE IsPublished = 1 GROUP BY RoleCode, Email HAVING COUNT(*) > 1)
    THROW 51015, 'Legacy upgrade blocked: duplicate published Users RoleCode/Email values exist.', 1;
IF EXISTS (SELECT PlayId, JuryId FROM dbo.JuryAssignedPlays WHERE IsPublished = 1 GROUP BY PlayId, JuryId HAVING COUNT(*) > 1)
    THROW 51016, 'Legacy upgrade blocked: duplicate published JuryAssignedPlays pairs exist.', 1;
IF EXISTS (SELECT UserId, PlayId FROM dbo.JuryGameTicketFees WHERE IsPublished = 1 GROUP BY UserId, PlayId HAVING COUNT(*) > 1)
    THROW 51017, 'Legacy upgrade blocked: duplicate published JuryGameTicketFees pairs exist.', 1;
IF EXISTS (SELECT PlayAwardCategoryId, JuryId FROM dbo.JuryVotes WHERE IsPublished = 1 GROUP BY PlayAwardCategoryId, JuryId HAVING COUNT(*) > 1)
    THROW 51018, 'Legacy upgrade blocked: duplicate published JuryVotes pairs exist.', 1;
IF EXISTS (SELECT PlayId, AwardCategoryCode, RoleCode, Candidate FROM dbo.PlayAwardCategories WHERE IsPublished = 1 GROUP BY PlayId, AwardCategoryCode, RoleCode, Candidate HAVING COUNT(*) > 1)
    THROW 51019, 'Legacy upgrade blocked: duplicate published candidate identities exist.', 1;
IF EXISTS (SELECT PlayId, AwardCategoryCode, RoleCode FROM dbo.PlayAwardCategories WHERE IsPublished = 1 AND IsCurrent = 1 GROUP BY PlayId, AwardCategoryCode, RoleCode HAVING COUNT(*) > 1)
    THROW 51020, 'Legacy upgrade blocked: multiple current candidates exist in one role slot.', 1;
/* Additive columns retain every legacy column and row. */
IF COL_LENGTH(N'dbo.AwardCategories', N'MultiCandidate') IS NULL
    ALTER TABLE dbo.AwardCategories ADD MultiCandidate bit NOT NULL CONSTRAINT DF_AwardCategories_MultiCandidate DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.AwardCategories', N'HasRoleAndPhoto') IS NULL
    ALTER TABLE dbo.AwardCategories ADD HasRoleAndPhoto bit NOT NULL CONSTRAINT DF_AwardCategories_HasRoleAndPhoto DEFAULT (0) WITH VALUES;

/* Compile after additive columns exist; SQL Server binds static column names per batch. */
EXEC sys.sp_executesql N'
UPDATE dbo.AwardCategories
SET MultiCandidate = CASE WHEN CategoryCode BETWEEN 1003 AND 1012 THEN 1 ELSE 0 END,
    HasRoleAndPhoto = CASE WHEN CategoryCode BETWEEN 1002 AND 1012 THEN 1 ELSE 0 END
WHERE CategoryCode BETWEEN 1001 AND 1012;';

IF COL_LENGTH(N'dbo.Configs', N'IsPublished') IS NULL
    ALTER TABLE dbo.Configs ADD IsPublished bit NOT NULL CONSTRAINT DF_Configs_IsPublished DEFAULT (1) WITH VALUES;
IF COL_LENGTH(N'dbo.JuryVotes', N'IsActive') IS NULL
BEGIN
    ALTER TABLE dbo.JuryVotes ADD IsActive bit NULL;
    EXEC(N'UPDATE dbo.JuryVotes SET IsActive = IsPublished; ALTER TABLE dbo.JuryVotes ALTER COLUMN IsActive bit NOT NULL;');
END;
IF COL_LENGTH(N'dbo.[Log]', N'IsPublished') IS NULL
    ALTER TABLE dbo.[Log] ADD IsPublished bit NOT NULL CONSTRAINT DF_Log_IsPublished DEFAULT (1) WITH VALUES;
IF COL_LENGTH(N'dbo.Manager', N'IsPublished') IS NULL
    ALTER TABLE dbo.Manager ADD IsPublished bit NOT NULL CONSTRAINT DF_Manager_IsPublished DEFAULT (1) WITH VALUES;
IF COL_LENGTH(N'dbo.PlayAwardCategories', N'PhotoImageId') IS NULL
    ALTER TABLE dbo.PlayAwardCategories ADD PhotoImageId uniqueidentifier NULL;
IF COL_LENGTH(N'dbo.PlayAwardCategories', N'IsActive') IS NULL
BEGIN
    ALTER TABLE dbo.PlayAwardCategories ADD IsActive bit NULL;
    EXEC(N'UPDATE dbo.PlayAwardCategories SET IsActive = IsPublished; ALTER TABLE dbo.PlayAwardCategories ALTER COLUMN IsActive bit NOT NULL;');
END;
IF COL_LENGTH(N'dbo.Users', N'PhotoImageId') IS NULL
    ALTER TABLE dbo.Users ADD PhotoImageId uniqueidentifier NULL;
IF COL_LENGTH(N'dbo.Users', N'IsActive') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD IsActive bit NULL;
    EXEC(N'UPDATE dbo.Users SET IsActive = IsPublished; ALTER TABLE dbo.Users ALTER COLUMN IsActive bit NOT NULL;');
END;
IF COL_LENGTH(N'dbo.Users', N'IsJuryPresident') IS NULL
    ALTER TABLE dbo.Users ADD IsJuryPresident bit NOT NULL
        CONSTRAINT DF_Users_IsJuryPresident DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.Form', N'YoungGenerationArtist') IS NULL
    EXEC sys.sp_executesql
        N'ALTER TABLE dbo.Form ADD YoungGenerationArtist nvarchar(max) NULL;';
GO
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Users')
      AND name = N'UX_Users_OnePublishedJuryPresident'
)
    CREATE UNIQUE INDEX UX_Users_OnePublishedJuryPresident
        ON dbo.Users(IsJuryPresident)
        WHERE IsPublished = 1 AND IsJuryPresident = 1;
GO
IF OBJECT_ID(N'dbo.CK_Users_JuryPresident', N'C') IS NULL
    ALTER TABLE dbo.Users WITH CHECK ADD CONSTRAINT CK_Users_JuryPresident
        CHECK (IsJuryPresident = 0 OR (RoleCode = 2 AND IsActive = 1));
IF COL_LENGTH(N'dbo.Announcements', N'ImageId') IS NULL
    ALTER TABLE dbo.Announcements ADD ImageId uniqueidentifier NULL;
IF COL_LENGTH(N'dbo.Announcements', N'BackgroundImageId') IS NULL
    ALTER TABLE dbo.Announcements ADD BackgroundImageId uniqueidentifier NULL;

IF COL_LENGTH(N'dbo.Plays', N'JuriOylamaStatus') IS NULL
    ALTER TABLE dbo.Plays ADD JuriOylamaStatus bit NOT NULL CONSTRAINT DF_Plays_JuriOylamaStatus DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.Plays', N'KunyeGirisStatus') IS NULL
    ALTER TABLE dbo.Plays ADD KunyeGirisStatus bit NOT NULL CONSTRAINT DF_Plays_KunyeGirisStatus DEFAULT (0) WITH VALUES;
IF COL_LENGTH(N'dbo.Plays', N'RecordType') IS NULL
BEGIN
    ALTER TABLE dbo.Plays ADD RecordType bit NULL;
    IF COL_LENGTH(N'dbo.Plays', N'FromKunye') IS NOT NULL
        EXEC(N'UPDATE dbo.Plays SET RecordType = CASE WHEN FromKunye = 1 THEN 0 ELSE 1 END;');
    ELSE
        EXEC(N'UPDATE dbo.Plays SET RecordType = CASE WHEN IsPublished = 0 THEN 1 ELSE 0 END;');
    EXEC(N'ALTER TABLE dbo.Plays ALTER COLUMN RecordType bit NOT NULL;');
END;
IF COL_LENGTH(N'dbo.Plays', N'SourceFormId') IS NULL
    ALTER TABLE dbo.Plays ADD SourceFormId uniqueidentifier NULL;
IF COL_LENGTH(N'dbo.Plays', N'IsActive') IS NULL
    ALTER TABLE dbo.Plays ADD IsActive bit NOT NULL CONSTRAINT DF_Plays_IsActive DEFAULT (1) WITH VALUES;

/*
   Legacy unpublished plays without source metadata are retained as soft-deleted
   Admin records. This is the only provenance compatible with an unpublished
   play because Kunye records must remain published.
*/
EXEC sys.sp_executesql N'
UPDATE dbo.Plays
SET JuriOylamaStatus = 0,
    KunyeGirisStatus = 0,
    StatusCode = CASE WHEN StatusCode = 1 THEN 2 ELSE StatusCode END,
    IsActive = CASE WHEN IsPublished = 0 THEN 0 ELSE IsActive END
WHERE RecordType = 1;';

/* Legacy string columns may be wider. Keep them to prevent truncation/data loss. */

GO

/* Copy the preserved int-key Form archive into the canonical GUID table. */
IF OBJECT_ID(N'dbo.FormLegacy_PreEf', N'U') IS NOT NULL
BEGIN
    IF OBJECT_ID(N'dbo.Form', N'U') IS NULL
        THROW 51026, 'Legacy upgrade blocked: canonical dbo.Form was not created.', 1;

    IF COL_LENGTH(N'dbo.Form', N'LegacyId') IS NULL
        ALTER TABLE dbo.Form ADD LegacyId int NULL;

    IF EXISTS (SELECT 1 FROM dbo.FormLegacy_PreEf WHERE Id < 0)
        THROW 51027, 'Legacy upgrade blocked: negative legacy Form IDs cannot be converted deterministically.', 1;

    DECLARE @legacyPublishedExpression nvarchar(200) =
        CASE
            WHEN COL_LENGTH(N'dbo.FormLegacy_PreEf', N'Deleted') IS NOT NULL
                THEN N'CASE WHEN ISNULL(legacy.Deleted, 0) = 1 THEN 0 ELSE 1 END'
            WHEN COL_LENGTH(N'dbo.FormLegacy_PreEf', N'IsPublished') IS NOT NULL
                THEN N'legacy.IsPublished'
            ELSE N'CONVERT(bit, 1)'
        END;
    DECLARE @legacyActiveExpression nvarchar(200) =
        CASE
            WHEN COL_LENGTH(N'dbo.FormLegacy_PreEf', N'Active') IS NOT NULL
                THEN N'COALESCE(legacy.Active, 1)'
            WHEN COL_LENGTH(N'dbo.FormLegacy_PreEf', N'IsActive') IS NOT NULL
                THEN N'legacy.IsActive'
            ELSE N'CONVERT(bit, 1)'
        END;
    DECLARE @copyLegacyFormsSql nvarchar(max) = N'
      INSERT dbo.Form
      (
          ApplicationNumber, CreatedDate, UpdatedDate, RepertoireName, TheatreName,
          PremiereDate, Display, ApplicantName, ApplicantRole, Phone, Email, Director,
          ContactName, ContactPhone, LeadActress, LeadActor, SupportActress, SupportActor,
          StageDesign, ClothesDesign, LightDesign, StageMusic, Choreography,
          IsPublished, Id, LegacyId, SeasonId, IsActive
      )
      SELECT
          legacy.ApplicationNumber, legacy.CreatedDate, legacy.UpdatedDate,
          legacy.RepertoireName, legacy.TheatreName, legacy.PremiereDate,
          legacy.Display, legacy.ApplicantName, legacy.ApplicantRole, legacy.Phone,
          legacy.Email, legacy.Director, legacy.ContactName, legacy.ContactPhone,
          legacy.LeadActress, legacy.LeadActor, legacy.SupportActress, legacy.SupportActor,
          legacy.StageDesign, legacy.ClothesDesign, legacy.LightDesign,
          legacy.StageMusic, legacy.Choreography,
          ' + @legacyPublishedExpression + N',
          CONVERT(uniqueidentifier,
              N''f0000000-0000-0000-0000-'' +
              RIGHT(REPLICATE(N''0'', 12) + CONVERT(nvarchar(12), legacy.Id), 12)),
          legacy.Id, NULL, ' + @legacyActiveExpression + N'
      FROM dbo.FormLegacy_PreEf AS legacy
      WHERE NOT EXISTS
      (
          SELECT 1 FROM dbo.Form AS currentForm WHERE currentForm.LegacyId = legacy.Id
      );';
    EXEC sys.sp_executesql @copyLegacyFormsSql;
END
ELSE IF COL_LENGTH(N'dbo.Form', N'LegacyId') IS NULL
    ALTER TABLE dbo.Form ADD LegacyId int NULL;

GO
/* Create deterministic season ranges for migrated forms; June-August stays unassigned. */
;WITH SeasonYears AS
(
    SELECT DISTINCT CASE
        WHEN MONTH(CreatedDate) >= 9 THEN YEAR(CreatedDate)
        WHEN MONTH(CreatedDate) <= 5 THEN YEAR(CreatedDate) - 1
        ELSE NULL END AS StartYear
    FROM dbo.Form
    WHERE CreatedDate IS NOT NULL
), Missing AS
(
    SELECT StartYear FROM SeasonYears sy
    WHERE StartYear IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.Seasons s
          WHERE s.SeasonStartDate = DATEFROMPARTS(sy.StartYear, 9, 1)
            AND s.SeasonEndDate = DATEFROMPARTS(sy.StartYear + 1, 5, 1)
            AND s.IsPublished = 1
      )
)
INSERT dbo.Seasons
(
    Id, SeasonStartDate, SeasonEndDate, KunyeRegistrationStartDate,
    KunyeRegistrationEndDate, VotingStartDate, VotingEndDate,
    PlayCount, ActivePlayCount, VoteCount, IsPublished
)
SELECT NEWID(), DATEFROMPARTS(StartYear, 9, 1), DATEFROMPARTS(StartYear + 1, 5, 1),
       DATEFROMPARTS(StartYear, 9, 1), DATEFROMPARTS(StartYear + 1, 4, 30),
       DATEFROMPARTS(StartYear, 9, 1), DATEFROMPARTS(StartYear + 1, 4, 30),
       0, 0, 0, 1
FROM Missing;

UPDATE f
SET SeasonId = s.Id
FROM dbo.Form f
INNER JOIN dbo.Seasons s
    ON f.CreatedDate >= s.SeasonStartDate
   AND f.CreatedDate < DATEADD(day, 1, s.SeasonEndDate)
   AND s.IsPublished = 1
WHERE f.SeasonId IS NULL;

GO

/* Normalize legacy image references without dropping their original string columns. */
IF COL_LENGTH(N'dbo.Users', N'Photo') IS NOT NULL
    EXEC sys.sp_executesql N'
      INSERT dbo.Images (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
      SELECT NEWID(), LEFT(u.Photo, 255), N''application/x-afife-legacy-reference'', 0x,
             COALESCE(u.CreatedAt, SYSDATETIME()), u.Id, u.IsPublished
      FROM dbo.Users u
      WHERE NULLIF(LTRIM(RTRIM(u.Photo)), N'''') IS NOT NULL AND u.PhotoImageId IS NULL;
      UPDATE u SET PhotoImageId = i.Id
      FROM dbo.Users u
      CROSS APPLY (SELECT TOP (1) Id FROM dbo.Images WHERE FileName = LEFT(u.Photo, 255)
        AND ContentType = N''application/x-afife-legacy-reference'' AND CreatedBy = u.Id ORDER BY CreatedAt DESC) i
      WHERE u.PhotoImageId IS NULL AND NULLIF(LTRIM(RTRIM(u.Photo)), N'''') IS NOT NULL;';

IF COL_LENGTH(N'dbo.PlayAwardCategories', N'Photo') IS NOT NULL
    EXEC sys.sp_executesql N'
      INSERT dbo.Images (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
      SELECT NEWID(), LEFT(p.Photo, 255), N''application/x-afife-legacy-reference'', 0x,
             COALESCE(p.CreatedAt, SYSDATETIME()), p.Id, p.IsPublished
      FROM dbo.PlayAwardCategories p
      WHERE NULLIF(LTRIM(RTRIM(p.Photo)), N'''') IS NOT NULL AND p.PhotoImageId IS NULL;
      UPDATE p SET PhotoImageId = i.Id
      FROM dbo.PlayAwardCategories p
      CROSS APPLY (SELECT TOP (1) Id FROM dbo.Images WHERE FileName = LEFT(p.Photo, 255)
        AND ContentType = N''application/x-afife-legacy-reference'' AND CreatedBy = p.Id ORDER BY CreatedAt DESC) i
      WHERE p.PhotoImageId IS NULL AND NULLIF(LTRIM(RTRIM(p.Photo)), N'''') IS NOT NULL;';
GO

IF COL_LENGTH(N'dbo.Announcements', N'Image') IS NOT NULL
    EXEC sys.sp_executesql N'
      INSERT dbo.Images (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
      SELECT NEWID(), LEFT(a.Image, 255), N''application/x-afife-legacy-reference'', 0x,
             COALESCE(a.CreatedAt, SYSDATETIME()), a.Id, a.IsPublished
      FROM dbo.Announcements a
      WHERE NULLIF(LTRIM(RTRIM(a.Image)), N'''') IS NOT NULL AND a.ImageId IS NULL;
      UPDATE a SET ImageId = i.Id
      FROM dbo.Announcements a
      CROSS APPLY (SELECT TOP (1) Id FROM dbo.Images WHERE FileName = LEFT(a.Image, 255)
        AND ContentType = N''application/x-afife-legacy-reference'' AND CreatedBy = a.Id ORDER BY CreatedAt DESC) i
      WHERE a.ImageId IS NULL AND NULLIF(LTRIM(RTRIM(a.Image)), N'''') IS NOT NULL;';

IF COL_LENGTH(N'dbo.Announcements', N'BackgroundImage') IS NOT NULL
    EXEC sys.sp_executesql N'
      INSERT dbo.Images (Id, FileName, ContentType, ImageData, CreatedAt, CreatedBy, IsPublished)
      SELECT NEWID(), LEFT(a.BackgroundImage, 255), N''application/x-afife-legacy-reference'', 0x,
             COALESCE(a.CreatedAt, SYSDATETIME()), a.Id, a.IsPublished
      FROM dbo.Announcements a
      WHERE NULLIF(LTRIM(RTRIM(a.BackgroundImage)), N'''') IS NOT NULL AND a.BackgroundImageId IS NULL;
      UPDATE a SET BackgroundImageId = i.Id
      FROM dbo.Announcements a
      CROSS APPLY (SELECT TOP (1) Id FROM dbo.Images WHERE FileName = LEFT(a.BackgroundImage, 255)
        AND ContentType = N''application/x-afife-legacy-reference'' AND CreatedBy = a.Id ORDER BY CreatedAt DESC) i
      WHERE a.BackgroundImageId IS NULL AND NULLIF(LTRIM(RTRIM(a.BackgroundImage)), N'''') IS NOT NULL;';
/* Preserve every FK relationship while replacing cascading actions with NO ACTION. */
DECLARE @ForeignKeyObjectId int;
DECLARE @ConstraintName sysname;
DECLARE @ParentTable nvarchar(520);
DECLARE @ReferencedTable nvarchar(520);
DECLARE @ParentColumns nvarchar(max);
DECLARE @ReferencedColumns nvarchar(max);
DECLARE @NormalizeForeignKeySql nvarchar(max);

DECLARE cascading_fk_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT foreignKey.object_id
FROM sys.foreign_keys AS foreignKey
INNER JOIN sys.tables AS parentTable
    ON parentTable.object_id = foreignKey.parent_object_id
INNER JOIN sys.schemas AS parentSchema
    ON parentSchema.schema_id = parentTable.schema_id
WHERE parentSchema.name = N'dbo'
  AND
  (
      foreignKey.delete_referential_action <> 0
      OR foreignKey.update_referential_action <> 0
  );

OPEN cascading_fk_cursor;
FETCH NEXT FROM cascading_fk_cursor INTO @ForeignKeyObjectId;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT
        @ConstraintName = foreignKey.name,
        @ParentTable = QUOTENAME(parentSchema.name) + N'.' + QUOTENAME(parentTable.name),
        @ReferencedTable = QUOTENAME(referencedSchema.name) + N'.' + QUOTENAME(referencedTable.name)
    FROM sys.foreign_keys AS foreignKey
    INNER JOIN sys.tables AS parentTable
        ON parentTable.object_id = foreignKey.parent_object_id
    INNER JOIN sys.schemas AS parentSchema
        ON parentSchema.schema_id = parentTable.schema_id
    INNER JOIN sys.tables AS referencedTable
        ON referencedTable.object_id = foreignKey.referenced_object_id
    INNER JOIN sys.schemas AS referencedSchema
        ON referencedSchema.schema_id = referencedTable.schema_id
    WHERE foreignKey.object_id = @ForeignKeyObjectId;

    SELECT
        @ParentColumns = STRING_AGG(QUOTENAME(parentColumn.name), N', ')
            WITHIN GROUP (ORDER BY foreignKeyColumn.constraint_column_id),
        @ReferencedColumns = STRING_AGG(QUOTENAME(referencedColumn.name), N', ')
            WITHIN GROUP (ORDER BY foreignKeyColumn.constraint_column_id)
    FROM sys.foreign_key_columns AS foreignKeyColumn
    INNER JOIN sys.columns AS parentColumn
        ON parentColumn.object_id = foreignKeyColumn.parent_object_id
       AND parentColumn.column_id = foreignKeyColumn.parent_column_id
    INNER JOIN sys.columns AS referencedColumn
        ON referencedColumn.object_id = foreignKeyColumn.referenced_object_id
       AND referencedColumn.column_id = foreignKeyColumn.referenced_column_id
    WHERE foreignKeyColumn.constraint_object_id = @ForeignKeyObjectId;

    SET @NormalizeForeignKeySql =
        N'ALTER TABLE ' + @ParentTable + N' DROP CONSTRAINT ' + QUOTENAME(@ConstraintName) + N'; ' +
        N'ALTER TABLE ' + @ParentTable + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@ConstraintName) +
        N' FOREIGN KEY (' + @ParentColumns + N') REFERENCES ' + @ReferencedTable +
        N' (' + @ReferencedColumns + N') ON UPDATE NO ACTION ON DELETE NO ACTION; ' +
        N'ALTER TABLE ' + @ParentTable + N' CHECK CONSTRAINT ' + QUOTENAME(@ConstraintName) + N';';

    EXEC sys.sp_executesql @NormalizeForeignKeySql;
    FETCH NEXT FROM cascading_fk_cursor INTO @ForeignKeyObjectId;
END;
CLOSE cascading_fk_cursor;
DEALLOCATE cascading_fk_cursor;
/* Alternate keys are required FK targets and remain globally unique contracts. */
IF OBJECT_ID(N'dbo.UQ_AwardCategories_CategoryCode', N'UQ') IS NULL
    ALTER TABLE dbo.AwardCategories ADD CONSTRAINT UQ_AwardCategories_CategoryCode UNIQUE (CategoryCode);
IF OBJECT_ID(N'dbo.UQ_Group_Code', N'UQ') IS NULL
    ALTER TABLE dbo.[Group] ADD CONSTRAINT UQ_Group_Code UNIQUE (Code);
IF OBJECT_ID(N'dbo.UQ_PlayStatuses_StatusCode', N'UQ') IS NULL
    ALTER TABLE dbo.PlayStatuses ADD CONSTRAINT UQ_PlayStatuses_StatusCode UNIQUE (StatusCode);
IF OBJECT_ID(N'dbo.UQ_Roles_RoleCode', N'UQ') IS NULL
    ALTER TABLE dbo.Roles ADD CONSTRAINT UQ_Roles_RoleCode UNIQUE (RoleCode);
