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

IF COL_LENGTH(N'dbo.PlayAwardCategories', N'IsActive') IS NULL
   OR COL_LENGTH(N'dbo.JuryVotes', N'IsActive') IS NULL
    THROW 51600, N'Run migrate-candidate-vote-active-soft-delete.sql first.', 1;

DECLARE @CandidateId uniqueidentifier =
(
    SELECT TOP (1) candidate.Id
    FROM dbo.PlayAwardCategories AS candidate
    INNER JOIN dbo.JuryVotes AS vote ON vote.PlayAwardCategoryId = candidate.Id
    WHERE candidate.AwardCategoryCode <> 1001
      AND candidate.IsPublished = 1
      AND vote.IsPublished = 1
    ORDER BY candidate.Id
);

IF @CandidateId IS NULL
    THROW 51601, N'Tests require one non-system candidate with a non-deleted vote.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE dbo.PlayAwardCategories SET IsActive = 0 WHERE Id = @CandidateId;
    IF EXISTS
    (
        SELECT 1 FROM dbo.JuryVotes
        WHERE PlayAwardCategoryId = @CandidateId AND IsPublished = 1 AND IsActive = 1
    )
        THROW 51602, N'FAIL: Candidate deactivation did not deactivate votes.', 1;

    UPDATE dbo.PlayAwardCategories SET IsActive = 1 WHERE Id = @CandidateId;
    IF EXISTS
    (
        SELECT 1 FROM dbo.JuryVotes
        WHERE PlayAwardCategoryId = @CandidateId AND IsPublished = 1 AND IsActive = 0
    )
        THROW 51603, N'FAIL: Candidate reactivation did not reactivate votes.', 1;

    UPDATE dbo.PlayAwardCategories SET IsPublished = 0 WHERE Id = @CandidateId;
    IF NOT EXISTS (SELECT 1 FROM dbo.PlayAwardCategories WHERE Id = @CandidateId)
        THROW 51604, N'FAIL: Candidate soft-delete removed the physical row.', 1;
    IF EXISTS
    (
        SELECT 1 FROM dbo.JuryVotes
        WHERE PlayAwardCategoryId = @CandidateId AND IsPublished = 1
    )
        THROW 51605, N'FAIL: Candidate soft-delete did not soft-delete votes.', 1;

    UPDATE dbo.PlayAwardCategories SET IsPublished = 1 WHERE Id = @CandidateId;
    IF EXISTS
    (
        SELECT 1 FROM dbo.JuryVotes
        WHERE PlayAwardCategoryId = @CandidateId
          AND (IsPublished = 0 OR IsActive = 0)
    )
        THROW 51607, N'FAIL: Candidate republish did not restore active votes.', 1;

    ROLLBACK TRANSACTION;
    PRINT N'PASS: Candidate activity and soft-delete synchronization.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @CandidateId uniqueidentifier =
    (
        SELECT TOP (1) candidate.Id
        FROM dbo.PlayAwardCategories AS candidate
        WHERE candidate.AwardCategoryCode <> 1001 AND candidate.IsPublished = 1
          AND EXISTS (SELECT 1 FROM dbo.JuryVotes AS vote WHERE vote.PlayAwardCategoryId = candidate.Id)
        ORDER BY candidate.Id
    );

    DELETE dbo.PlayAwardCategories WHERE Id = @CandidateId;
    IF EXISTS (SELECT 1 FROM dbo.JuryVotes WHERE PlayAwardCategoryId = @CandidateId)
        THROW 51606, N'FAIL: Candidate hard-delete retained vote rows.', 1;

    ROLLBACK TRANSACTION;
    PRINT N'PASS: Physical candidate delete cascades physical vote deletion.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO