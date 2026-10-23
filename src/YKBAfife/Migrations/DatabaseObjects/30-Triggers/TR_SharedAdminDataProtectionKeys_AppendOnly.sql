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
