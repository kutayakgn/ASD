SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

/* Reproduces the oldest preprod shape: only a legacy AwardCategories table
   exists and the two candidate flags are mandatory without default values. */
CREATE TABLE dbo.AwardCategories
(
    Id uniqueidentifier NOT NULL,
    CategoryName nvarchar(255) NOT NULL,
    CategoryCode int NOT NULL,
    CreatedAt datetime2(7) NOT NULL,
    CreatedBy uniqueidentifier NULL,
    UpdatedAt datetime2(7) NULL,
    UpdatedBy uniqueidentifier NULL,
    IsPublished bit NOT NULL,
    MultiCandidate bit NOT NULL,
    HasRoleAndPhoto bit NOT NULL,
    CONSTRAINT PK_AwardCategories PRIMARY KEY (Id)
);

INSERT INTO dbo.AwardCategories
(
    Id, CategoryName, CategoryCode, CreatedAt, CreatedBy,
    UpdatedAt, UpdatedBy, IsPublished, MultiCandidate, HasRoleAndPhoto
)
VALUES
(
    '40000000-0000-0000-0000-000000000001',
    N'Eski Oyun Kategorisi', 1001, SYSDATETIME(), NULL,
    NULL, NULL, 1, 0, 0
);
