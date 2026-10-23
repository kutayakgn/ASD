/* Disposable LocalDB only. No trigger or business rule is disabled. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
IF LEN(DB_NAME())<>LEN(N'YkbAfifePreviousProductionTest_')+32
 OR LEFT(DB_NAME(),LEN(N'YkbAfifePreviousProductionTest_'))<>N'YkbAfifePreviousProductionTest_'
 OR RIGHT(DB_NAME(),32) COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%'
 THROW 53590,N'Refusing a database outside the disposable prefix.',1;
IF NOT EXISTS(SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id
 WHERE c.object_id=OBJECT_ID(N'dbo.Form') AND c.name COLLATE Latin1_General_100_BIN2=N'previousProductionVersion'
 AND t.name=N'bit' AND c.is_nullable=0) THROW 53591,N'Exact nonnullable bit flag is missing.',1;
IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.Form') AND name=N'Director' AND is_nullable=1)
 THROW 53592,N'Director must accept SQL NULL.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @True uniqueidentifier=NEWID(),@Normal uniqueidentifier=NEWID(),@Null uniqueidentifier=NEWID(),
 @Blank uniqueidentifier=NEWID(),@Default uniqueidentifier=NEWID(),@Jury uniqueidentifier=NEWID();
 DECLARE @Json nvarchar(max)=N'[{"Name":"Previous production person","Role":"Original role"}]';
 INSERT dbo.Form(Id,ApplicationNumber,CreatedDate,RepertoireName,TheatreName,PremiereDate,Display,
 ApplicantName,ApplicantRole,Phone,Email,Director,LeadActress,LeadActor,SupportActress,SupportActor,
 StageDesign,ClothesDesign,LightDesign,StageMusic,Choreography,previousProductionVersion,IsPublished,IsActive)
 SELECT f.Id,f.Number,'2099-04-01',N'Previous fixture '+CONVERT(nvarchar(36),f.Id),N'Previous theatre',
 '2099-04-01',N'[]',N'Applicant',N'Contact',N'5550000000',N'previous@example.invalid',f.Director,
 @Json,@Json,@Json,@Json,f.Technical,f.Technical,f.Technical,f.Technical,f.Technical,f.Flag,1,1
 FROM(VALUES(@True,N'PP0001',CONVERT(bit,1),N'Must be cleared',@Json),
 (@Normal,N'PP0002',CONVERT(bit,0),N'Normal director',@Json),
 (@Null,N'PP0003',CONVERT(bit,0),CONVERT(nvarchar(max),NULL),CONVERT(nvarchar(max),NULL)),
 (@Blank,N'PP0004',CONVERT(bit,0),N'   ',CONVERT(nvarchar(max),NULL)))f(Id,Number,Flag,Director,Technical);
 IF NOT EXISTS(SELECT 1 FROM dbo.Form WHERE Id=@True AND previousProductionVersion=1 AND Director IS NULL
 AND StageDesign IS NULL AND ClothesDesign IS NULL AND LightDesign IS NULL AND StageMusic IS NULL AND Choreography IS NULL)
 THROW 53593,N'True insert must clear all six excluded fields to SQL NULL.',1;
 IF(SELECT COUNT(*) FROM dbo.Plays WHERE SourceFormId IN(@True,@Normal,@Null,@Blank))<>4
 THROW 53594,N'Mixed insert did not create four linked Plays.',1;
 IF(SELECT COUNT(*) FROM dbo.PlayAwardCategories c JOIN dbo.Plays p ON p.Id=c.PlayId WHERE p.SourceFormId=@Normal
 AND c.AwardCategoryCode=1002 AND c.Candidate=N'Normal director' AND c.IsPublished=1 AND c.IsCurrent=1)<>1
 THROW 53595,N'Normal filled director must create exactly one 1002 candidate.',1;
 IF EXISTS(SELECT 1 FROM dbo.PlayAwardCategories c JOIN dbo.Plays p ON p.Id=c.PlayId
 WHERE p.SourceFormId IN(@True,@Null,@Blank) AND c.AwardCategoryCode=1002 AND(c.IsPublished=1 OR c.IsActive=1 OR c.IsCurrent=1))
 THROW 53596,N'NULL/blank or true director produced a usable 1002 candidate.',1;
 IF(SELECT COUNT(*) FROM dbo.PlayAwardCategories c JOIN dbo.Plays p ON p.Id=c.PlayId WHERE p.SourceFormId=@True
 AND c.AwardCategoryCode BETWEEN 1003 AND 1006 AND c.IsPublished=1 AND c.IsActive=1 AND c.IsCurrent=1)<>4
 THROW 53597,N'True Forms must retain all four allowed performer categories.',1;
 IF EXISTS(SELECT 1 FROM dbo.PlayAwardCategories c JOIN dbo.Plays p ON p.Id=c.PlayId WHERE p.SourceFormId=@True
 AND(c.AwardCategoryCode=1002 OR c.AwardCategoryCode BETWEEN 1007 AND 1011) AND(c.IsPublished=1 OR c.IsActive=1 OR c.IsCurrent=1))
 THROW 53598,N'True technical payload produced a forbidden candidate.',1;
 DECLARE @Play uniqueidentifier=(SELECT Id FROM dbo.Plays WHERE SourceFormId=@Normal),@Manual uniqueidentifier=NEWID();
 INSERT dbo.Users(Id,FirstName,LastName,Username,Email,PasswordHash,RoleCode,IsPublished,IsActive,CreatedAt)
 VALUES(@Jury,N'Previous',N'Production',N'pp.'+LEFT(REPLACE(CONVERT(nvarchar(36),@Jury),N'-',N''),20),
 CONVERT(nvarchar(36),@Jury)+N'@example.invalid',N'opaque-test-only',2,1,1,'2099-04-01');
 INSERT dbo.PlayAwardCategories(Id,PlayId,Candidate,AwardCategoryCode,Role,RoleCode,CreatedAt,CreatedBy,IsPublished,IsActive,IsCurrent)
 VALUES(@Manual,@Play,N'Manual stage person',1007,N'Manual stage role',901,'2099-04-01',@Jury,1,1,1);
 DECLARE @Retiring TABLE(Id uniqueidentifier PRIMARY KEY,CreatedBy uniqueidentifier NULL);
 INSERT @Retiring SELECT Id,CreatedBy FROM dbo.PlayAwardCategories WHERE PlayId=@Play
 AND(AwardCategoryCode=1002 OR AwardCategoryCode BETWEEN 1007 AND 1011) AND IsPublished=1 AND IsCurrent=1;
 IF NOT EXISTS(SELECT 1 FROM @Retiring WHERE Id=@Manual AND CreatedBy=@Jury)
 OR(SELECT COUNT(*) FROM @Retiring WHERE CreatedBy IS NULL)<>6
 THROW 53599,N'Fixture must contain six source rows and one manually created candidate.',1;
 INSERT dbo.JuryVotes(Id,PlayAwardCategoryId,JuryId,Score,CreatedAt,IsPublished,IsActive)
 SELECT NEWID(),Id,@Jury,6,'2099-04-01',1,1 FROM @Retiring;
 DECLARE @Votes nvarchar(max)=(SELECT * FROM dbo.JuryVotes WHERE JuryId=@Jury ORDER BY Id FOR JSON PATH,INCLUDE_NULL_VALUES);
 DECLARE @Allowed nvarchar(max)=(SELECT Id,Candidate,Role,RoleCode,IsPublished,IsActive,IsCurrent
 FROM dbo.PlayAwardCategories WHERE PlayId=@Play AND AwardCategoryCode BETWEEN 1003 AND 1006 ORDER BY Id FOR JSON PATH,INCLUDE_NULL_VALUES);
 UPDATE dbo.Form SET previousProductionVersion=1 WHERE Id=@Normal;
 IF EXISTS(SELECT 1 FROM @Retiring r LEFT JOIN dbo.PlayAwardCategories c ON c.Id=r.Id
 WHERE c.Id IS NULL OR c.IsPublished<>0 OR c.IsActive<>0 OR c.IsCurrent<>0)
 THROW 53600,N'False-to-true must retire mapped/manual rows without deleting their identities.',1;
 IF CONVERT(varbinary(max),@Votes)<>CONVERT(varbinary(max),(SELECT * FROM dbo.JuryVotes WHERE JuryId=@Jury ORDER BY Id FOR JSON PATH,INCLUDE_NULL_VALUES))
 THROW 53601,N'False-to-true changed existing vote history.',1;
 IF CONVERT(varbinary(max),@Allowed)<>CONVERT(varbinary(max),(SELECT Id,Candidate,Role,RoleCode,IsPublished,IsActive,IsCurrent
 FROM dbo.PlayAwardCategories WHERE PlayId=@Play AND AwardCategoryCode BETWEEN 1003 AND 1006 ORDER BY Id FOR JSON PATH,INCLUDE_NULL_VALUES))
 THROW 53602,N'False-to-true changed allowed performer candidates.',1;
 UPDATE dbo.PlayAwardCategories SET Candidate=N'Edited allowed performer' WHERE PlayId=@Play AND AwardCategoryCode=1003 AND IsCurrent=1;
 UPDATE dbo.Plays SET Phone=N'5550000001' WHERE Id=@Play;
 EXEC dbo.usp_SynchronizePlayDataToForms @PlayId=@Play;
 IF NOT EXISTS(SELECT 1 FROM dbo.Form WHERE Id=@Normal AND previousProductionVersion=1 AND Director IS NULL
 AND StageDesign IS NULL AND ClothesDesign IS NULL AND LightDesign IS NULL AND StageMusic IS NULL AND Choreography IS NULL
 AND LeadActress LIKE N'%Edited allowed performer%' AND Phone=N'5550000001')
 THROW 53603,N'Reverse sync repopulated excluded fields or lost allowed edits.',1;
 UPDATE dbo.Form SET previousProductionVersion=0 WHERE Id=@True;
 IF EXISTS(SELECT 1 FROM dbo.PlayAwardCategories c JOIN dbo.Plays p ON p.Id=c.PlayId WHERE p.SourceFormId=@True
 AND c.AwardCategoryCode=1002 AND(c.IsPublished=1 OR c.IsActive=1 OR c.IsCurrent=1))
 THROW 53604,N'False flag must not invent an absent director.',1;
 UPDATE dbo.Form SET Director=N'New normal director' WHERE Id=@True;
 IF(SELECT COUNT(*) FROM dbo.PlayAwardCategories c JOIN dbo.Plays p ON p.Id=c.PlayId WHERE p.SourceFormId=@True
 AND c.AwardCategoryCode=1002 AND c.IsPublished=1 AND c.IsCurrent=1 AND c.Candidate=N'New normal director')<>1
 THROW 53605,N'Filling a normal director did not produce exactly one mapped 1002 slot.',1;
 UPDATE dbo.Form SET Director=NULL WHERE Id=@True;
 IF EXISTS(SELECT 1 FROM dbo.PlayAwardCategories c JOIN dbo.Plays p ON p.Id=c.PlayId WHERE p.SourceFormId=@True
 AND c.AwardCategoryCode=1002 AND(c.IsPublished=1 OR c.IsActive=1 OR c.IsCurrent=1))
 THROW 53606,N'Removing a normal director must retire its 1002 slot.',1;
 UPDATE dbo.Form SET IsActive=0 WHERE Id=@Normal;
 UPDATE dbo.Form SET IsActive=1 WHERE Id=@Normal;
 IF EXISTS(SELECT 1 FROM dbo.PlayAwardCategories WHERE PlayId=@Play
 AND(AwardCategoryCode=1002 OR AwardCategoryCode BETWEEN 1007 AND 1011) AND(IsPublished=1 OR IsActive=1 OR IsCurrent=1))
 THROW 53607,N'Lifecycle reactivation revived forbidden candidate history.',1;
 INSERT dbo.Form(Id,ApplicationNumber,CreatedDate,RepertoireName,TheatreName,PremiereDate,Display,
 ApplicantName,ApplicantRole,Phone,Email,Director,IsPublished,IsActive)
 VALUES(@Default,N'PP0005','2099-04-01',N'Omitted flag '+CONVERT(nvarchar(36),@Default),N'Previous theatre',
 '2099-04-01',N'[]',N'Applicant',N'Contact',N'5550000000',N'previous@example.invalid',NULL,1,1);
 IF NOT EXISTS(SELECT 1 FROM dbo.Form WHERE Id=@Default AND previousProductionVersion=0 AND Director IS NULL)
 THROW 53608,N'Omitted flag must default false and preserve NULL Director.',1;
 UPDATE dbo.Form SET ApplicantName=N'Edited applicant' WHERE Id IN(@True,@Normal);
 IF NOT EXISTS(SELECT 1 FROM dbo.Form WHERE Id=@True AND previousProductionVersion=0)
 OR NOT EXISTS(SELECT 1 FROM dbo.Form WHERE Id=@Normal AND previousProductionVersion=1)
 THROW 53609,N'An unrelated edit reset the flag.',1;
 ROLLBACK TRANSACTION;
 PRINT N'PASS: NULL Director, mixed flags, allowed categories, six NULLs, mapped/manual retirement, exact vote history and reverse/lifecycle sync.';
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
/* Each expected trigger error is isolated because XACT_ABORT can doom it. */
DECLARE @Codes TABLE(Code int PRIMARY KEY);
INSERT @Codes VALUES(1002),(1007),(1008),(1009),(1010),(1011);
DECLARE @Code int=(SELECT MIN(Code) FROM @Codes),@Attempt int;
WHILE @Code IS NOT NULL
BEGIN
 SET @Attempt=0;
 WHILE @Attempt<5
 BEGIN
 DECLARE @Guard uniqueidentifier=NEWID(),@Other uniqueidentifier=NEWID(),@Candidate uniqueidentifier=NEWID(),
 @GuardPlay uniqueidentifier,@OtherPlay uniqueidentifier;
 BEGIN TRY
  BEGIN TRANSACTION;
  INSERT dbo.Form(Id,ApplicationNumber,CreatedDate,RepertoireName,TheatreName,PremiereDate,Display,
  ApplicantName,ApplicantRole,Phone,Email,Director,previousProductionVersion,IsPublished,IsActive)
  SELECT f.Id,CASE WHEN f.Flag=1 THEN N'PPG001' ELSE N'PPG002' END,'2099-04-01',N'Guard '+CONVERT(nvarchar(36),f.Id),N'Guard theatre',
  '2099-04-01',N'[]',N'Applicant',N'Contact',N'5550000000',N'guard@example.invalid',NULL,f.Flag,1,1
  FROM(VALUES(@Guard,CONVERT(bit,1)),(@Other,CONVERT(bit,0)))f(Id,Flag);
  SELECT @GuardPlay=Id FROM dbo.Plays WHERE SourceFormId=@Guard;
  SELECT @OtherPlay=Id FROM dbo.Plays WHERE SourceFormId=@Other;
  INSERT dbo.PlayAwardCategories(Id,PlayId,Candidate,AwardCategoryCode,Role,RoleCode,CreatedAt,IsPublished,IsActive,IsCurrent)
  VALUES(@Candidate,CASE WHEN @Attempt=1 THEN @OtherPlay ELSE @GuardPlay END,N'Guard candidate',@Code,
  CASE WHEN @Code=1002 THEN NULL ELSE N'Guard role' END,CASE WHEN @Code=1002 THEN 0 ELSE 777 END,'2099-04-01',
  CASE WHEN @Attempt<2 THEN 1 ELSE 0 END,CASE WHEN @Attempt<2 THEN 1 ELSE 0 END,CASE WHEN @Attempt<2 THEN 1 ELSE 0 END);
  IF @Attempt=1 UPDATE dbo.PlayAwardCategories SET PlayId=@GuardPlay WHERE Id=@Candidate;
  IF @Attempt=2 UPDATE dbo.PlayAwardCategories SET IsPublished=1 WHERE Id=@Candidate;
  IF @Attempt=3 UPDATE dbo.PlayAwardCategories SET IsActive=1 WHERE Id=@Candidate;
  IF @Attempt=4 UPDATE dbo.PlayAwardCategories SET IsCurrent=1 WHERE Id=@Candidate;
  THROW 53610,N'Forbidden insert/move/state reactivation bypassed the guard.',1;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  IF ERROR_NUMBER()<>52434 THROW;
 END CATCH;
 IF EXISTS(SELECT 1 FROM dbo.Form WHERE Id IN(@Guard,@Other)) OR EXISTS(SELECT 1 FROM dbo.PlayAwardCategories WHERE Id=@Candidate)
 THROW 53611,N'Rejected operation left partial fixture data.',1;
 SET @Attempt+=1;
 END;
 SELECT @Code=MIN(Code) FROM @Codes WHERE Code>@Code;
END;
PRINT N'PASS: all six excluded codes reject insert, cross-play move and each state reactivation with SQL 52434.';
