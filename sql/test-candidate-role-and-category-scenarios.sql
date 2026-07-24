USE [AfifeAdmin];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF COL_LENGTH(N'dbo.AwardCategories', N'MultiCandidate') IS NULL
    THROW 51400, N'Run add-award-category-multiplicity-and-default-play-category.sql first.', 1;

DECLARE @JuryId uniqueidentifier =
(
    SELECT TOP (1) Id
    FROM dbo.Users
    WHERE RoleCode = 2
    ORDER BY Id
);

IF @JuryId IS NULL
    THROW 51401, N'Vote scenarios require at least one RoleCode=2 user.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @KunyePlayId uniqueidentifier = NEWID();
    DECLARE @AdminPlayId uniqueidentifier = NEWID();
    DECLARE @MaleOldId uniqueidentifier = NEWID();
    DECLARE @MaleNewId uniqueidentifier = NEWID();
    DECLARE @SecondRoleId uniqueidentifier = NEWID();
    DECLARE @CostumeOldId uniqueidentifier = NEWID();
    DECLARE @CostumeNewId uniqueidentifier = NEWID();
    DECLARE @Now datetime2(7) = DATEADD(HOUR, 3, SYSUTCDATETIME());

    INSERT dbo.Plays
        (Id, PlayName, TheaterName, StatusCode, CreatedAt, IsPublished, Slug,
         JuriOylamaStatus, KunyeGirisStatus, RecordType)
    VALUES
        (@KunyePlayId, N'Senaryo Oyunu', N'Ilk Tiyatro', 1, @Now, 1,
         CONVERT(varchar(36), @KunyePlayId), 1, 1, 0),
        (@AdminPlayId, N'Admin Senaryo Oyunu', N'Admin Tiyatro', 2, @Now, 1,
         CONVERT(varchar(36), @AdminPlayId), 0, 0, 1);

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories
        WHERE PlayId = @KunyePlayId AND AwardCategoryCode = 1001
          AND Candidate = N'Ilk Tiyatro' AND Role IS NULL
          AND RoleCode = 0 AND IsCurrent = 1
    )
        THROW 51402, N'FAIL: Category 1001 was not created from TheaterName.', 1;

    IF EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE PlayId = @AdminPlayId)
        THROW 51403, N'FAIL: RecordType 1 play received a category row.', 1;

    INSERT dbo.PlayAwardCategories
        (Id, PlayId, CreatedAt, IsPublished, Candidate, AwardCategoryCode,
         IsCurrent, Role, RoleCode)
    VALUES
        (@MaleOldId, @KunyePlayId, @Now, 1, N'Ahmet Kaya', 1004, 1, N'Shrek', 1),
        (@SecondRoleId, @KunyePlayId, @Now, 1, N'Emre Yilmaz', 1004, 1, N'Esek', 2);

    UPDATE dbo.PlayAwardCategories
    SET IsCurrent = 0, UpdatedAt = DATEADD(SECOND, 1, @Now)
    WHERE Id = @MaleOldId;

    INSERT dbo.PlayAwardCategories
        (Id, PlayId, CreatedAt, IsPublished, Candidate, AwardCategoryCode,
         IsCurrent, Role, RoleCode)
    VALUES
        (@MaleNewId, @KunyePlayId, DATEADD(SECOND, 2, @Now), 1,
         N'Huseyin Demir', 1004, 1, N'Shrek', 1);

    IF (SELECT COUNT_BIG(*) FROM dbo.PlayAwardCategories
        WHERE PlayId = @KunyePlayId AND AwardCategoryCode = 1004
          AND RoleCode = 1 AND IsCurrent = 1) <> 1
        THROW 51404, N'FAIL: A multi-candidate role has an invalid current count.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.PlayAwardCategories
                   WHERE Id = @MaleOldId AND IsCurrent = 0 AND IsPublished = 1)
        THROW 51405, N'FAIL: Replaced candidate was not preserved as published history.', 1;

    INSERT dbo.PlayAwardCategories
        (Id, PlayId, CreatedAt, IsPublished, Candidate, AwardCategoryCode,
         IsCurrent, Role, RoleCode)
    VALUES
        (@CostumeOldId, @KunyePlayId, @Now, 1, N'Ilk Tasarimci', 1008, 1, NULL, 0);

    UPDATE dbo.PlayAwardCategories SET IsCurrent = 0 WHERE Id = @CostumeOldId;

    INSERT dbo.PlayAwardCategories
        (Id, PlayId, CreatedAt, IsPublished, Candidate, AwardCategoryCode,
         IsCurrent, Role, RoleCode)
    VALUES
        (@CostumeNewId, @KunyePlayId, DATEADD(SECOND, 1, @Now), 1,
         N'Yeni Tasarimci', 1008, 1, NULL, 0);

    UPDATE dbo.Plays SET TheaterName = N'Yeni Tiyatro' WHERE Id = @KunyePlayId;
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.PlayAwardCategories
        WHERE PlayId = @KunyePlayId AND AwardCategoryCode = 1001
          AND RoleCode = 0 AND Candidate = N'Yeni Tiyatro'
    )
        THROW 51406, N'FAIL: TheaterName change did not synchronize category 1001.', 1;

    INSERT dbo.JuryVotes
        (Id, PlayAwardCategoryId, CreatedAt, IsPublished, Score, JuryId)
    VALUES
        (NEWID(), @MaleOldId, @Now, 1, 1, @JuryId),
        (NEWID(), @MaleNewId, DATEADD(SECOND, 1, @Now), 1, 1, @JuryId),
        (NEWID(), @SecondRoleId, DATEADD(SECOND, 2, @Now), 1, 1, @JuryId);

    IF (SELECT COUNT_BIG(*)
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        WHERE vote.JuryId = @JuryId AND candidate.PlayId = @KunyePlayId
          AND candidate.AwardCategoryCode = 1004 AND candidate.RoleCode = 1) <> 1
        THROW 51407, N'FAIL: Old/current candidates retained two physical votes.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.JuryVotes
                   WHERE JuryId = @JuryId AND PlayAwardCategoryId = @MaleNewId)
        THROW 51408, N'FAIL: The newest vote did not replace the old-candidate vote.', 1;

    IF (SELECT COUNT_BIG(*)
        FROM dbo.JuryVotes AS vote
        INNER JOIN dbo.PlayAwardCategories AS candidate
            ON candidate.Id = vote.PlayAwardCategoryId
        WHERE vote.JuryId = @JuryId AND candidate.PlayId = @KunyePlayId
          AND candidate.AwardCategoryCode = 1004) <> 2
        THROW 51409, N'FAIL: Votes in distinct roles did not coexist.', 1;

    UPDATE dbo.PlayAwardCategories SET IsPublished = 0 WHERE Id = @MaleNewId;
    IF EXISTS (SELECT 1 FROM dbo.JuryVotes
               WHERE PlayAwardCategoryId = @MaleNewId AND IsPublished = 1)
        THROW 51410, N'FAIL: Candidate unpublish did not deactivate its vote.', 1;

    UPDATE dbo.PlayAwardCategories SET IsPublished = 1 WHERE Id = @MaleNewId;
    IF EXISTS (SELECT 1 FROM dbo.JuryVotes
               WHERE PlayAwardCategoryId = @MaleNewId AND IsPublished = 0)
        THROW 51411, N'FAIL: Candidate republish did not reactivate its vote.', 1;

    DELETE dbo.PlayAwardCategories WHERE Id = @SecondRoleId;
    IF EXISTS (SELECT 1 FROM dbo.JuryVotes WHERE PlayAwardCategoryId = @SecondRoleId)
        THROW 51412, N'FAIL: Hard-deleted candidate retained vote rows.', 1;

    ROLLBACK TRANSACTION;
    PRINT N'PASS: Positive candidate, role, default-category, and vote scenarios.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @PlayId uniqueidentifier = NEWID();
    INSERT dbo.Plays
        (Id, PlayName, TheaterName, StatusCode, CreatedAt, IsPublished, Slug,
         JuriOylamaStatus, KunyeGirisStatus, RecordType)
    VALUES
        (@PlayId, N'Gecersiz Rol Testi', N'Test Tiyatrosu', 1,
         DATEADD(HOUR, 3, SYSUTCDATETIME()), 1, CONVERT(varchar(36), @PlayId), 1, 1, 0);

    INSERT dbo.PlayAwardCategories
        (Id, PlayId, CreatedAt, IsPublished, Candidate, AwardCategoryCode,
         IsCurrent, Role, RoleCode)
    VALUES
        (NEWID(), @PlayId, DATEADD(HOUR, 3, SYSUTCDATETIME()), 1,
         N'Gecersiz Aday', 1004, 1, NULL, 0);

    THROW 51420, N'FAIL: Multi-candidate category accepted an empty role.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 51303
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'PASS: Multi-candidate category rejects empty Role/RoleCode.';
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @PlayId uniqueidentifier = NEWID();
    INSERT dbo.Plays
        (Id, PlayName, TheaterName, StatusCode, CreatedAt, IsPublished, Slug,
         JuriOylamaStatus, KunyeGirisStatus, RecordType)
    VALUES
        (@PlayId, N'Varsayilan Silme Testi', N'Silinemez Tiyatro', 1,
         DATEADD(HOUR, 3, SYSUTCDATETIME()), 1, CONVERT(varchar(36), @PlayId), 1, 1, 0);

    DELETE dbo.PlayAwardCategories
    WHERE PlayId = @PlayId AND AwardCategoryCode = 1001 AND RoleCode = 0;

    THROW 51421, N'FAIL: System-managed category 1001 was deleted.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 51307
    BEGIN
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT N'PASS: System-managed category 1001 rejects direct deletion.';
END CATCH;
GO