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
