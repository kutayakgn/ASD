SET XACT_ABORT ON;

IF TRY_CONVERT(bit, SESSION_CONTEXT(N'AfifeBaselineAlreadyExists')) <> 1
    RETURN;

/*
   Move the legacy int-key Form out of the canonical name before missing tables
   are created. The original table and every row remain physically available.
*/
IF OBJECT_ID(N'dbo.Form', N'U') IS NOT NULL
   AND EXISTS
   (
       SELECT 1
       FROM sys.columns
       WHERE object_id = OBJECT_ID(N'dbo.Form')
         AND name = N'Id'
         AND system_type_id = TYPE_ID(N'int')
   )
BEGIN
    IF OBJECT_ID(N'dbo.FormLegacy_PreEf', N'U') IS NOT NULL
        THROW 51022, 'Legacy upgrade blocked: FormLegacy_PreEf already exists while dbo.Form is still legacy.', 1;

    IF COL_LENGTH(N'dbo.Form', N'ApplicationNumber') IS NULL
        THROW 51023, 'Legacy upgrade blocked: dbo.Form.ApplicationNumber is missing.', 1;

    DECLARE @duplicatePublishedForms bit = 0;
    DECLARE @duplicateSql nvarchar(max) =
        CASE
            WHEN COL_LENGTH(N'dbo.Form', N'Deleted') IS NOT NULL THEN
                N'SELECT @result = CASE WHEN EXISTS
                  (SELECT ApplicationNumber FROM dbo.Form WHERE ISNULL(Deleted, 0) = 0
                   GROUP BY ApplicationNumber HAVING COUNT(*) > 1) THEN 1 ELSE 0 END;'
            WHEN COL_LENGTH(N'dbo.Form', N'IsPublished') IS NOT NULL THEN
                N'SELECT @result = CASE WHEN EXISTS
                  (SELECT ApplicationNumber FROM dbo.Form WHERE IsPublished = 1
                   GROUP BY ApplicationNumber HAVING COUNT(*) > 1) THEN 1 ELSE 0 END;'
            ELSE
                N'SELECT @result = CASE WHEN EXISTS
                  (SELECT ApplicationNumber FROM dbo.Form
                   GROUP BY ApplicationNumber HAVING COUNT(*) > 1) THEN 1 ELSE 0 END;'
        END;
    EXEC sys.sp_executesql @duplicateSql,
        N'@result bit OUTPUT', @result = @duplicatePublishedForms OUTPUT;
    IF @duplicatePublishedForms = 1
        THROW 51024, 'Legacy upgrade blocked: duplicate published Form.ApplicationNumber values exist.', 1;

    IF EXISTS (SELECT 1 FROM dbo.Form WHERE LEN(ApplicationNumber) > 6)
        THROW 51025, 'Legacy upgrade blocked: Form.ApplicationNumber exceeds 6 characters.', 1;

    IF OBJECT_ID(N'dbo.PK_Form', N'PK') IS NOT NULL
        EXEC sys.sp_rename N'dbo.PK_Form', N'PK_FormLegacy_PreEf', N'OBJECT';

    EXEC sys.sp_rename N'dbo.Form', N'FormLegacy_PreEf';
END;
