using System.Reflection;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;
using YKBAfife.Data;

// These checks exercise the runtime compatibility boundary without opening a
// database, editing a released package, or duplicating the installer algorithm.
internal static class GroupCascadeCompatibilityRegression
{
    internal static void Run(Action<bool, string> assert)
    {
        var type = typeof(AfifeContext).Assembly.GetType(
            "YKBAfife.Data.Migrations.MigrationSqlResources", throwOnError: true)!;
        var read = type.GetMethod("Read", BindingFlags.Static | BindingFlags.Public)!;
        var map = type.GetMethod("ApplyHistoricalGroupCascadeCompatibility",
            BindingFlags.Static | BindingFlags.NonPublic, binder: null,
            [typeof(string), typeof(Func<string, string>)], modifiers: null)!;
        string Read(string name) => (string)read.Invoke(null, [name])!;
        string Map(string sql, Func<string, string>? reader = null) =>
            (string)map.Invoke(null, [sql, reader ?? Read])!;
        static string Normalize(string sql) => sql.Replace("\r\n", "\n", StringComparison.Ordinal).Trim();

        const string version = "GroupManagement_v_20261027112722";
        var released = Read(version + ".Up.sql"); // Full package integrity is verified first.
        var original = Regex.Split(released, @"^\s*GO\s*(?:--.*)?$",
                RegexOptions.Multiline | RegexOptions.IgnoreCase)
            .Single(sql => sql.Contains("/* Code is editable business data.", StringComparison.Ordinal)).Trim();
        var compatible = Read("GroupCodeCascadeCompatibility.sql").Trim();
        assert(Normalize(original) != Normalize(compatible),
            "The reviewed duplicate-cascade compatibility batch differs from the frozen installer.");
        foreach (var sql in new[] { original, Normalize(original), Normalize(original).Replace("\n", "\r\n", StringComparison.Ordinal) })
            assert(Normalize(Map(sql)) == Normalize(compatible),
                "Only the exact frozen installer maps to the reviewed compatible batch across LF/CRLF transport.");

        foreach (var sql in new[] { "SELECT 1;", original.Replace("ON UPDATE CASCADE", "ON UPDATE NO ACTION", StringComparison.Ordinal),
                     original.Replace("@UpdateAction", "@OtherAction", StringComparison.Ordinal) })
            assert(Map(sql) == sql, "Unrelated or changed SQL never gains a historical compatibility rewrite.");

        var readCount = 0;
        assert(Map("SELECT 2;", _ => { readCount++; throw new InvalidOperationException(); }) == "SELECT 2;" && readCount == 0,
            "Unrelated batches do not consult the compatibility resource.");
        var rejected = false;
        try { Map(original, _ => compatible + "\nSELECT 999;"); }
        catch (TargetInvocationException exception) when (exception.InnerException is InvalidOperationException failure &&
            failure.Message.Contains("compatibility resource failed its integrity check", StringComparison.Ordinal))
        {
            rejected = true;
        }
        assert(rejected, "A changed compatibility resource fails closed instead of bypassing package integrity.");

        var builder = new MigrationBuilder("Microsoft.EntityFrameworkCore.SqlServer");
        type.GetMethod("ExecuteVersionedDatabaseObjects", BindingFlags.Static | BindingFlags.Public)!
            .Invoke(null, [builder, version, "Up.sql"]);
        assert(builder.Operations.OfType<SqlOperation>().Any(operation => Normalize(operation.Sql) == Normalize(compatible)) &&
               !builder.Operations.OfType<SqlOperation>().Any(operation => Normalize(operation.Sql) == Normalize(original)),
            "The real pending historical migration emits the compatible installer after reading its unchanged verified package.");

        var ordinary = new MigrationBuilder("Microsoft.EntityFrameworkCore.SqlServer");
        type.GetMethod("ExecuteSql", BindingFlags.Static | BindingFlags.NonPublic)!
            .Invoke(null, [ordinary, original, false, false, false]);
        assert(ordinary.Operations.OfType<SqlOperation>().Single().Sql == original,
            "Non-versioned migration SQL keeps its original behavior and does not opt into the narrow historical rewrite.");
    }
}
