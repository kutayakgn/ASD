using Microsoft.EntityFrameworkCore;
using YkbAfife.Domain.Model.Entity.Announcement;
using YkbAfife.Domain.Model.Entity.Form;
using YkbAfife.Domain.Model.Entity.JuryVoting;
using YkbAfife.Domain.Model.Entity.User;

public sealed class AfifeContext : DbContext
{
    public DbSet<Announcement> Announcements => Set<Announcement>();
    public DbSet<Form> Form => Set<Form>();
    public DbSet<AwardCategory> AwardCategories => Set<AwardCategory>();
    public DbSet<JuryAssignedPlays> JuryAssignedPlays => Set<JuryAssignedPlays>();
    public DbSet<Group> Groups => Set<Group>();
    public DbSet<Image> Images => Set<Image>();
    public DbSet<JuryGameTicketFee> JuryGameTicketFees => Set<JuryGameTicketFee>();
    public DbSet<JuryVotes> JuryVotes => Set<JuryVotes>();
    public DbSet<Log> Log => Set<Log>();
    public DbSet<PlayAwardCategory> PlayAwardCategories => Set<PlayAwardCategory>();
    public DbSet<Play> Plays => Set<Play>();
    public DbSet<PlayStatus> PlayStatuses => Set<PlayStatus>();
    public DbSet<Season> Seasons => Set<Season>();
    public DbSet<AdditionalVoting> AdditionalVotings => Set<AdditionalVoting>();
    public DbSet<AdditionalVotingJury> AdditionalVotingJuries => Set<AdditionalVotingJury>();
    public DbSet<AdditionalVotingPlay> AdditionalVotingPlays => Set<AdditionalVotingPlay>();
    public DbSet<AdditionalVotingUsage> AdditionalVotingUsages => Set<AdditionalVotingUsage>();
    public DbSet<Blacklist> Blacklists => Set<Blacklist>();
    public DbSet<JuryLog> JuryLogs => Set<JuryLog>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<User> Users => Set<User>();

    public AfifeContext(DbContextOptions<AfifeContext> options) : base(options)
    {
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            entityType.UseSqlOutputClause(false);
        }

        modelBuilder.Entity<Blacklist>(entity =>
        {
            entity.ToTable("Blacklist", "dbo");
            entity.HasIndex(x => new { x.JuryId, x.PlayId })
                .HasDatabaseName("UX_Blacklist_JuryId_PlayId_Published")
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
        });

        modelBuilder.Entity<Play>(entity =>
        {
            entity.Property(x => x.RecordType)
                .HasConversion(
                    modelValue => modelValue != 0,
                    providerValue => providerValue ? 1 : 0)
                .HasColumnType("bit");
        });

        modelBuilder.Entity<JuryLog>(entity =>
        {
            entity.ToTable("JuryLogs", "dbo");
            entity.Property(x => x.SubmittedTicketFee).HasPrecision(10, 2);
            entity.Property(x => x.OldTicketFee).HasPrecision(10, 2);
            entity.Property(x => x.NewTicketFee).HasPrecision(10, 2);
            entity.HasIndex(x => x.CorrelationId)
                .HasDatabaseName("IX_JuryLogs_CorrelationId");
            entity.HasIndex(x => new { x.JuryId, x.OccurredAt })
                .HasDatabaseName("IX_JuryLogs_JuryId_OccurredAt");
            entity.HasIndex(x => new { x.PlayId, x.OccurredAt })
                .HasDatabaseName("IX_JuryLogs_PlayId_OccurredAt");
            entity.HasIndex(x => new { x.OperationType, x.IsSuccessful, x.OccurredAt })
                .HasDatabaseName("IX_JuryLogs_OperationType_IsSuccessful_OccurredAt");
        });

        modelBuilder.Entity<AdditionalVotingUsage>()
            .HasIndex(x => new { x.AdditionalVotingId, x.JuryId, x.PlayId })
            .HasDatabaseName("UX_AdditionalVotingUsages_OneTime")
            .IsUnique()
            .HasFilter("[IsPublished] = 1");
    }
}
