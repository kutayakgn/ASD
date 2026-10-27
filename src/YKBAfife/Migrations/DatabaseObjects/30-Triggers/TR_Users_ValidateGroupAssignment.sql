CREATE OR ALTER TRIGGER dbo.TR_Users_ValidateGroupAssignment
ON dbo.Users
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(GroupCode) AND NOT UPDATE(IsPublished) AND NOT UPDATE(RoleCode) RETURN;

    /* Old relationships to an unpublished group remain editable. An old Code
       disappearing while its FK changes proves a parent-key cascade (the
       enabled FK forbids an orphan before this update), not a new membership.
       Restoring a deleted jury or promoting an admin to a published jury must
       also validate the group, even when the stored GroupCode stays the same. */
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS member
        LEFT JOIN deleted AS previousMember ON previousMember.Id = member.Id
        INNER JOIN dbo.[Group] AS selectedGroup WITH (HOLDLOCK)
            ON selectedGroup.Code = member.GroupCode
        WHERE member.GroupCode IS NOT NULL
          AND
          (
              previousMember.Id IS NULL OR previousMember.GroupCode IS NULL
              OR (previousMember.GroupCode <> member.GroupCode AND EXISTS
                  (SELECT 1 FROM dbo.[Group] AS previousGroup WITH (HOLDLOCK)
                   WHERE previousGroup.Code = previousMember.GroupCode))
              OR (member.RoleCode = 2 AND member.IsPublished = 1
                  AND (previousMember.IsPublished = 0 OR previousMember.RoleCode <> 2))
          )
          AND selectedGroup.IsPublished = 0
    )
        THROW 52821, N'Yalnızca yayındaki jüri grupları seçilebilir. Grup listesini yenileyip tekrar deneyin.', 1;
END;
