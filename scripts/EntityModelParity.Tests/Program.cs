using System.Reflection;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using YKBAfife.Data;
using YKBAfife.Data.Migrations;
using YKBAfife.Helpers;
using YKBAfife.Models.Entities;

// No connection is opened: this checks the actual EF model and shared save rules.
using var context = new AfifeContextDesignTimeFactory().CreateDbContext([]);
var model = context.GetService<IDesignTimeModel>().Model;
var snapshot = context.GetService<IMigrationsAssembly>().ModelSnapshot
    ?? throw new InvalidOperationException("The EF migration snapshot is missing.");
var initializedSnapshot = context.GetService<IModelRuntimeInitializer>()
    .Initialize(snapshot.Model, designTime: true);
var differences = context.GetService<IMigrationsModelDiffer>().GetDifferences(
    initializedSnapshot.GetRelationalModel(), model.GetRelationalModel());
var assertions = 0;
Assert(differences.Count == 0,
    "The organization-only refactor must produce zero relational changes. Found: " +
    string.Join(", ", differences.Select(operation => operation.GetType().Name)));

foreach (var entity in model.GetEntityTypes())
{
    Assert(entity.GetSchema() == "dbo", $"{entity.Name}: dbo schema preserved");
    Assert(entity.IsSqlOutputClauseUsed() == false, $"{entity.Name}: trigger-compatible saves preserved");
    foreach (var foreignKey in entity.GetForeignKeys())
    {
        Assert(foreignKey.DeleteBehavior == DeleteBehavior.NoAction,
            $"{entity.Name}: {foreignKey.GetConstraintName()} must not cascade-delete data");
    }

    var published = entity.FindProperty("IsPublished");
    if (published?.ClrType == typeof(bool))
    {
        Assert(Equals(published.GetDefaultValue(), true), $"{entity.Name}: published default is true");
        Assert(entity.GetQueryFilter() is not null, $"{entity.Name}: soft-delete filter preserved");
    }
}

var play = model.FindEntityType(typeof(Play))!;
Assert(play.FindProperty(nameof(Play.RecordType))!.GetAfterSaveBehavior() == PropertySaveBehavior.Throw,
    "A play's record type remains immutable after first save.");
Assert(play.GetQueryFilter()!.ToString().Contains("IsActive", StringComparison.Ordinal),
    "Play queries still hide inactive records.");
Assert(model.FindEntityType(typeof(JuryPasswordResetToken))!.GetQueryFilter()!.ToString()
        .Contains("User.IsPublished", StringComparison.Ordinal),
    "Password reset tokens still require a published user.");

var users = model.FindEntityType(typeof(User))!;
foreach (var property in new[] { nameof(User.Username), nameof(User.Email) })
{
    var index = users.GetIndexes().Single(item => item.Properties.Select(p => p.Name)
        .SequenceEqual(new[] { nameof(User.RoleCode), property }));
    Assert(index.IsUnique && index.GetFilter() == "[IsPublished] = 1",
        $"Role-specific published-user uniqueness is preserved for {property}.");
}
var usages = model.FindEntityType(typeof(AdditionalVotingUsage))!;
Assert(!usages.GetIndexes().Single(index => index.GetDatabaseName() ==
    "IX_AdditionalVotingUsages_Jury_Play").IsUnique, "Additional voting remains unlimited.");
var fees = model.FindEntityType(typeof(JuryGameTicketFee))!;
Assert(fees.GetIndexes().Single(index => index.GetDatabaseName() ==
    "UX_JuryGameTicketFees_UserId_PlayId").IsUnique, "Published ticket fees remain one per jury/play.");
var configs = model.FindEntityType(typeof(Config))!;
var configValueCheck = configs.GetCheckConstraints().Single(check => check.Name ==
    "CK_Configs_JuryHomePageTableValue").Sql;
var expectedValueCheck = typeof(JuryHomePageTableSettings)
    .GetField("ValueCheck", BindingFlags.Static | BindingFlags.NonPublic)!.GetRawConstantValue();
Assert(Equals(configValueCheck, expectedValueCheck),
    "Fixed homepage config-value rules are unchanged.");

var applyRules = typeof(AfifeContext).GetMethod("ApplyPersistenceRules", BindingFlags.Instance | BindingFlags.NonPublic)!;
var user = new User { Id = Guid.NewGuid(), IsPublished = false, IsActive = false };
context.Add(user);
applyRules.Invoke(context, null);
Assert(user.IsPublished && !user.IsActive, "Insert forces publication without enabling an inactive user.");
context.ChangeTracker.Clear();

CheckSoftDelete(new User { Id = Guid.NewGuid(), IsPublished = true, IsActive = true },
    entity => !entity.IsPublished && !entity.IsActive);
CheckSoftDelete(new Form { Id = Guid.NewGuid(), IsPublished = true, IsActive = true },
    entity => !entity.IsPublished && !entity.IsActive);
CheckSoftDelete(new JuryVote { Id = Guid.NewGuid(), IsPublished = true, IsActive = true, Score = 8 },
    entity => !entity.IsPublished && !entity.IsActive && entity.Score == 8);
CheckSoftDelete(new Config { Id = Guid.NewGuid(), IsPublished = true, ConfigValue = "false" },
    entity => !entity.IsPublished && entity.ConfigValue == "false");

MigrationPayloadRuntimeRegression.Run(Assert);

Console.WriteLine($"Entity model parity: {assertions} assertions passed; no DB connection required.");

void CheckSoftDelete<TEntity>(TEntity entity, Func<TEntity, bool> stateIsCorrect) where TEntity : class
{
    context.Attach(entity);
    context.Remove(entity);
    applyRules.Invoke(context, null);
    Assert(context.Entry(entity).State == EntityState.Modified && stateIsCorrect(entity),
        $"{typeof(TEntity).Name}: physical deletion is converted to state-only soft deletion.");
    context.ChangeTracker.Clear();
}

void Assert(bool condition, string message)
{
    assertions++;
    if (!condition) throw new InvalidOperationException(message);
}
