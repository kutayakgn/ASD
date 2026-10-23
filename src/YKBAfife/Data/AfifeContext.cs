using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using System.Linq.Expressions;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data;

public sealed class AfifeContext(DbContextOptions<AfifeContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<UserLog> UserLogs => Set<UserLog>();
    public DbSet<AdminLog> AdminLogs => Set<AdminLog>();
    public DbSet<JuryLog> JuryLogs => Set<JuryLog>();
    public DbSet<JuryPasswordResetToken> JuryPasswordResetTokens => Set<JuryPasswordResetToken>();
    public DbSet<SharedAdminDataProtectionKey> SharedAdminDataProtectionKeys => Set<SharedAdminDataProtectionKey>();
    public DbSet<Play> Plays => Set<Play>();
    public DbSet<Season> Seasons => Set<Season>();
    public DbSet<AdditionalVoting> AdditionalVotings => Set<AdditionalVoting>();
    public DbSet<AdditionalVotingJury> AdditionalVotingJuries => Set<AdditionalVotingJury>();
    public DbSet<AdditionalVotingPlay> AdditionalVotingPlays => Set<AdditionalVotingPlay>();
    public DbSet<AdditionalVotingUsage> AdditionalVotingUsages => Set<AdditionalVotingUsage>();
    public DbSet<Ranking> Rankings => Set<Ranking>();
    public DbSet<PlayAwardCategory> PlayAwardCategories => Set<PlayAwardCategory>();
    public DbSet<JuryVote> JuryVotes => Set<JuryVote>();
    public DbSet<JuryGameTicketFee> JuryGameTicketFees => Set<JuryGameTicketFee>();
    public DbSet<Image> Images => Set<Image>();
    public DbSet<Announcement> Announcements => Set<Announcement>();
    public DbSet<Form> Forms => Set<Form>();
    public DbSet<FormLifecycleState> FormLifecycleStates => Set<FormLifecycleState>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<PlayStatus> PlayStatuses => Set<PlayStatus>();
    public DbSet<JuryAssignedPlay> JuryAssignedPlays => Set<JuryAssignedPlay>();
    public DbSet<AwardCategory> AwardCategories => Set<AwardCategory>();
    public DbSet<Blacklist> Blacklists => Set<Blacklist>();
    public DbSet<Config> Configs => Set<Config>();
    public DbSet<Log> Logs => Set<Log>();
    public DbSet<Manager> Managers => Set<Manager>();
    public DbSet<Role> Roles => Set<Role>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AfifeContext).Assembly);
        Configurations.AfifeModelConventions.RemoveLegacyConventionIndexes(modelBuilder);

        DisableSqlOutputClauseForAuditedTables(modelBuilder);
        ApplyPublishedQueryFilters(modelBuilder);
        modelBuilder.Entity<JuryPasswordResetToken>()
            .HasQueryFilter(token => token.User.IsPublished);
        modelBuilder.Entity<Form>()
            .HasQueryFilter(form => form.IsPublished);
        modelBuilder.Entity<Play>()
            .HasQueryFilter(play => play.IsPublished && play.IsActive);
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        ApplyPersistenceRules();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(
        bool acceptAllChangesOnSuccess,
        CancellationToken cancellationToken = default)
    {
        ApplyPersistenceRules();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    private static void DisableSqlOutputClauseForAuditedTables(ModelBuilder modelBuilder)
    {
        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            entityType.UseSqlOutputClause(false);
        }
    }

    private static void ApplyPublishedQueryFilters(ModelBuilder modelBuilder)
    {
        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            var isPublishedProperty = entityType.FindProperty("IsPublished");
            if (isPublishedProperty?.ClrType != typeof(bool))
            {
                continue;
            }

            isPublishedProperty.SetDefaultValue(true);

            var parameter = Expression.Parameter(entityType.ClrType, "entity");
            var body = Expression.Equal(
                Expression.Property(parameter, "IsPublished"),
                Expression.Constant(true));

            entityType.SetQueryFilter(Expression.Lambda(body, parameter));
        }
    }

    private void ApplyPersistenceRules()
    {
        foreach (var entry in ChangeTracker.Entries()
                     .Where(entry => entry.State == EntityState.Added)
                     .ToArray())
        {
            var isPublishedProperty = entry.Metadata.FindProperty("IsPublished");
            if (isPublishedProperty?.ClrType == typeof(bool))
            {
                entry.Property("IsPublished").CurrentValue = true;
            }
        }

        foreach (var entry in ChangeTracker.Entries()
                     .Where(entry => entry.State == EntityState.Deleted)
                     .ToArray())
        {
            var isPublishedProperty = entry.Metadata.FindProperty("IsPublished");
            if (isPublishedProperty?.ClrType != typeof(bool))
            {
                throw new InvalidOperationException(
                    $"{entry.Metadata.ClrType.Name} cannot be deleted because it has no IsPublished soft-delete property.");
            }

            entry.State = EntityState.Modified;
            entry.Property("IsPublished").CurrentValue = false;

            var isActiveProperty = entry.Metadata.FindProperty("IsActive");
            if (isActiveProperty?.ClrType == typeof(bool))
            {
                entry.Property("IsActive").CurrentValue = false;
            }
        }
    }
}
