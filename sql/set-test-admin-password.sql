USE [AfifeAdmin];
GO

SET XACT_ABORT ON;

BEGIN TRANSACTION;

UPDATE [dbo].[Users]
SET [PasswordHash] = N'AQIDBAUGBwgJCgsMDQ4PENgFvbWLFMGV+RkEc72b5x3SjymL',
    [UpdatedAt] = DATEADD(HOUR, 3, SYSUTCDATETIME()),
    [UpdatedBy] = [Id]
WHERE [Username] = N'coordinator.test'
  AND [RoleCode] = 1
  AND [IsPublished] = 1;

IF @@ROWCOUNT = 0
BEGIN
    ROLLBACK TRANSACTION;
    THROW 50001, 'Aktif coordinator.test kullanicisi bulunamadi.', 1;
END;

COMMIT TRANSACTION;
GO

-- Test credentials:
-- Username: coordinator.test
-- Password: Test123!
