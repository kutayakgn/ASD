using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations;

[DbContext(typeof(AfifeContext))]
[Migration("20260817100000_V1_1_0_AddJuryLogs")]
public sealed class V1_1_0_AddJuryLogs : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.Sql(
            """
            IF OBJECT_ID(N'dbo.JuryLogs', N'U') IS NULL
            BEGIN
                CREATE TABLE dbo.JuryLogs
                (
                    Id uniqueidentifier NOT NULL
                        CONSTRAINT DF_JuryLogs_Id DEFAULT (newsequentialid()),
                    CorrelationId uniqueidentifier NOT NULL
                        CONSTRAINT DF_JuryLogs_CorrelationId DEFAULT (newid()),
                    JuryId uniqueidentifier NULL,
                    JuryUsername nvarchar(100) NULL,
                    PlayId uniqueidentifier NULL,
                    PlayName nvarchar(250) NULL,
                    AdditionalVotingId uniqueidentifier NULL,
                    AdditionalVotingUsageId uniqueidentifier NULL,
                    AdditionalVotingUsageType tinyint NULL,
                    IsAdditionalVoting bit NOT NULL
                        CONSTRAINT DF_JuryLogs_IsAdditionalVoting DEFAULT ((0)),
                    OperationName nvarchar(256) NOT NULL,
                    OperationType nvarchar(50) NOT NULL,
                    SubmittedVotesJson nvarchar(max) NULL,
                    OldVotesJson nvarchar(max) NULL,
                    NewVotesJson nvarchar(max) NULL,
                    SubmittedTicketFee decimal(10,2) NULL,
                    OldTicketFee decimal(10,2) NULL,
                    NewTicketFee decimal(10,2) NULL,
                    RequestPayloadJson nvarchar(max) NULL,
                    StateSnapshotJson nvarchar(max) NULL,
                    AffectedVoteCount int NOT NULL
                        CONSTRAINT DF_JuryLogs_AffectedVoteCount DEFAULT ((0)),
                    OccurredAt datetime2(7) NOT NULL
                        CONSTRAINT DF_JuryLogs_OccurredAt
                        DEFAULT (DATEADD(HOUR, (3), SYSUTCDATETIME())),
                    DurationMilliseconds bigint NULL,
                    IpAddress nvarchar(64) NULL,
                    UserAgent nvarchar(1000) NULL,
                    HttpMethod nvarchar(16) NULL,
                    RequestPath nvarchar(2048) NULL,
                    ControllerName nvarchar(128) NULL,
                    ActionName nvarchar(128) NULL,
                    Application nvarchar(100) NOT NULL
                        CONSTRAINT DF_JuryLogs_Application DEFAULT (N'AfifeJury'),
                    Source nvarchar(50) NOT NULL
                        CONSTRAINT DF_JuryLogs_Source DEFAULT (N'JuryPanel'),
                    IsSuccessful bit NOT NULL
                        CONSTRAINT DF_JuryLogs_IsSuccessful DEFAULT ((0)),
                    ResultCode nvarchar(100) NULL,
                    Details nvarchar(max) NULL,
                    FailureReason nvarchar(2000) NULL,
                    IsPublished bit NOT NULL
                        CONSTRAINT DF_JuryLogs_IsPublished DEFAULT ((1)),
                    CONSTRAINT PK_JuryLogs PRIMARY KEY (Id),
                    CONSTRAINT FK_JuryLogs_AdditionalVotings_AdditionalVotingId
                        FOREIGN KEY (AdditionalVotingId) REFERENCES dbo.AdditionalVotings(Id),
                    CONSTRAINT FK_JuryLogs_Plays_PlayId
                        FOREIGN KEY (PlayId) REFERENCES dbo.Plays(Id),
                    CONSTRAINT FK_JuryLogs_Users_JuryId
                        FOREIGN KEY (JuryId) REFERENCES dbo.Users(Id)
                );
            END;

            IF NOT EXISTS
            (
                SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID(N'dbo.JuryLogs')
                  AND name = N'IX_JuryLogs_CorrelationId'
            )
                CREATE INDEX IX_JuryLogs_CorrelationId
                    ON dbo.JuryLogs(CorrelationId);

            IF NOT EXISTS
            (
                SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID(N'dbo.JuryLogs')
                  AND name = N'IX_JuryLogs_JuryId_OccurredAt'
            )
                CREATE INDEX IX_JuryLogs_JuryId_OccurredAt
                    ON dbo.JuryLogs(JuryId, OccurredAt);

            IF NOT EXISTS
            (
                SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID(N'dbo.JuryLogs')
                  AND name = N'IX_JuryLogs_PlayId_OccurredAt'
            )
                CREATE INDEX IX_JuryLogs_PlayId_OccurredAt
                    ON dbo.JuryLogs(PlayId, OccurredAt);

            IF NOT EXISTS
            (
                SELECT 1 FROM sys.indexes
                WHERE object_id = OBJECT_ID(N'dbo.JuryLogs')
                  AND name = N'IX_JuryLogs_OperationType_IsSuccessful_OccurredAt'
            )
                CREATE INDEX IX_JuryLogs_OperationType_IsSuccessful_OccurredAt
                    ON dbo.JuryLogs(OperationType, IsSuccessful, OccurredAt);
            """)
            .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);

        MigrationSqlResources.Execute(migrationBuilder, "AuditTriggers.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Audit history is intentionally retained during compatibility rollback.
    }
}
