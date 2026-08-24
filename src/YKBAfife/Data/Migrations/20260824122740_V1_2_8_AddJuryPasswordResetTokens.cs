using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class V1_2_8_AddJuryPasswordResetTokens : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "JuryPasswordResetTokens",
                schema: "dbo",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, defaultValueSql: "newsequentialid()"),
                    UserId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TokenHash = table.Column<byte[]>(type: "binary(32)", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "datetime2(7)", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "datetime2(7)", nullable: false),
                    UsedAtUtc = table.Column<DateTime>(type: "datetime2(7)", nullable: true),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_JuryPasswordResetTokens", x => x.Id);
                    table.CheckConstraint("CK_JuryPasswordResetTokens_Expiry", "[ExpiresAtUtc] > [CreatedAtUtc] AND [ExpiresAtUtc] <= DATEADD(MINUTE, 5, [CreatedAtUtc])");
                    table.CheckConstraint("CK_JuryPasswordResetTokens_UsedAt", "[UsedAtUtc] IS NULL OR [UsedAtUtc] >= [CreatedAtUtc]");
                    table.ForeignKey(
                        name: "FK_JuryPasswordResetTokens_Users_UserId",
                        column: x => x.UserId,
                        principalSchema: "dbo",
                        principalTable: "Users",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_JuryPasswordResetTokens_UserId_CreatedAtUtc",
                schema: "dbo",
                table: "JuryPasswordResetTokens",
                columns: new[] { "UserId", "CreatedAtUtc" },
                descending: new[] { false, true });

            migrationBuilder.CreateIndex(
                name: "UX_JuryPasswordResetTokens_TokenHash",
                schema: "dbo",
                table: "JuryPasswordResetTokens",
                column: "TokenHash",
                unique: true);

        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "JuryPasswordResetTokens",
                schema: "dbo");
        }
    }
}
