CREATE OR ALTER TRIGGER dbo.TR_JuryGameTicketFees_SoftDelete ON dbo.JuryGameTicketFees INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.JuryGameTicketFees target INNER JOIN deleted source ON source.Id = target.Id; END;
