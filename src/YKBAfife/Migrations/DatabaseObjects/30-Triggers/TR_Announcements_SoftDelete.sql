/* Direct SQL deletes are also soft deletes. */
CREATE OR ALTER TRIGGER dbo.TR_Announcements_SoftDelete ON dbo.Announcements INSTEAD OF DELETE AS
BEGIN SET NOCOUNT ON; UPDATE target SET IsPublished = 0 FROM dbo.Announcements target INNER JOIN deleted source ON source.Id = target.Id; END;
