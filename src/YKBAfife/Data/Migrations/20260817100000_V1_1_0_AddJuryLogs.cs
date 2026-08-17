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
        migrationBuilder.CreateTable(
            name: "JuryLogs",
            schema: "dbo",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false,
                    defaultValueSql: "newsequentialid()"),
                CorrelationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false,
                    defaultValueSql: "newid()"),
                JuryId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                JuryUsername = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                PlayId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                PlayName = table.Column<string>(type: "nvarchar(250)", maxLength: 250, nullable: true),
                AdditionalVotingId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                AdditionalVotingUsageId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                AdditionalVotingUsageType = table.Column<byte>(type: "tinyint", nullable: true),
                IsAdditionalVoting = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                OperationName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false),
                OperationType = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                SubmittedVotesJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                OldVotesJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                NewVotesJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                SubmittedTicketFee = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: true),
                OldTicketFee = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: true),
                NewTicketFee = table.Column<decimal>(type: "decimal(10,2)", precision: 10, scale: 2, nullable: true),
                RequestPayloadJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                StateSnapshotJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                AffectedVoteCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                OccurredAt = table.Column<DateTime>(type: "datetime2(7)", nullable: false,
                    defaultValueSql: "DATEADD(HOUR, 3, SYSUTCDATETIME())"),
                DurationMilliseconds = table.Column<long>(type: "bigint", nullable: true),
                IpAddress = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true),
                UserAgent = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                HttpMethod = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: true),
                RequestPath = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: true),
                ControllerName = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                ActionName = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: true),
                Application = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false,
                    defaultValue: "AfifeJury"),
                Source = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false,
                    defaultValue: "JuryPanel"),
                IsSuccessful = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                ResultCode = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                Details = table.Column<string>(type: "nvarchar(max)", nullable: true),
                FailureReason = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                IsPublished = table.Column<bool>(type: "bit", nullable: false, defaultValue: true)
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_JuryLogs", x => x.Id);
                table.ForeignKey(
                    name: "FK_JuryLogs_AdditionalVotings_AdditionalVotingId",
                    column: x => x.AdditionalVotingId,
                    principalSchema: "dbo",
                    principalTable: "AdditionalVotings",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_JuryLogs_Plays_PlayId",
                    column: x => x.PlayId,
                    principalSchema: "dbo",
                    principalTable: "Plays",
                    principalColumn: "Id");
                table.ForeignKey(
                    name: "FK_JuryLogs_Users_JuryId",
                    column: x => x.JuryId,
                    principalSchema: "dbo",
                    principalTable: "Users",
                    principalColumn: "Id");
            });

        migrationBuilder.CreateIndex(
            name: "IX_JuryLogs_CorrelationId",
            schema: "dbo",
            table: "JuryLogs",
            column: "CorrelationId");
        migrationBuilder.CreateIndex(
            name: "IX_JuryLogs_JuryId_OccurredAt",
            schema: "dbo",
            table: "JuryLogs",
            columns: new[] { "JuryId", "OccurredAt" });
        migrationBuilder.CreateIndex(
            name: "IX_JuryLogs_PlayId_OccurredAt",
            schema: "dbo",
            table: "JuryLogs",
            columns: new[] { "PlayId", "OccurredAt" });
        migrationBuilder.CreateIndex(
            name: "IX_JuryLogs_OperationType_IsSuccessful_OccurredAt",
            schema: "dbo",
            table: "JuryLogs",
            columns: new[] { "OperationType", "IsSuccessful", "OccurredAt" });

        MigrationSqlResources.Execute(migrationBuilder, "AuditTriggers.sql");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        // Audit history is intentionally retained during compatibility rollback.
    }
}
