using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace YKBAfife.Data.Migrations
{
    /// <inheritdoc />
    public partial class FormPreviousProductionVersion_v_20261023143319 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<string>(
                name: "Director",
                schema: "dbo",
                table: "Form",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true,
                oldClrType: typeof(string),
                oldType: "nvarchar(100)",
                oldMaxLength: 100);

            migrationBuilder.AddColumn<bool>(
                name: "previousProductionVersion",
                schema: "dbo",
                table: "Form",
                type: "bit",
                nullable: false,
                defaultValue: false)
                .Annotation(NoDataLossSqlServerMigrationsSqlGenerator.PreserveExistingColumnAnnotation, true);
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "FormPreviousProductionVersion_v_20261023143319", "Up.sql");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Never invent a director to satisfy the old required schema.
            migrationBuilder.Sql("""
                IF EXISTS (SELECT 1 FROM dbo.Form WHERE Director IS NULL)
                    THROW 52761, N'Director NULL kayıtları varken önceki zorunlu şemaya dönülemez. Veriler değiştirilmedi.', 1;
                """);
            // Introduced in this version; remove before schema rollback.
            migrationBuilder.Sql("DROP TRIGGER IF EXISTS [dbo].[TR_PlayAwardCategories_BlockPreviousProduction];");

            // Remove the Form trigger's dependency before archiving the flag.
            MigrationSqlResources.ExecuteVersionedDatabaseObjects(
                migrationBuilder, "FormPreviousProductionVersion_v_20261023143319", "Down.sql");
            migrationBuilder.DropColumn(
                name: "previousProductionVersion",
                schema: "dbo",
                table: "Form");

            migrationBuilder.AlterColumn<string>(
                name: "Director",
                schema: "dbo",
                table: "Form",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(100)",
                oldMaxLength: 100,
                oldNullable: true)
                .Annotation(MigrationSqlResources.ReviewedDataSafeSqlAnnotation, true);
        }
    }
}
