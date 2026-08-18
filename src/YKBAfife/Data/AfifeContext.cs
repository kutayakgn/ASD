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
        modelBuilder.Entity<Image>(entity =>
        {
            entity.ToTable("Images", "dbo");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("Users", "dbo", table =>
                table.HasCheckConstraint(
                    "CK_Users_JuryPresident",
                    "[IsJuryPresident] = 0 OR ([RoleCode] = 2 AND [IsActive] = 1)"));
            entity.HasIndex(x => new { x.RoleCode, x.Username })
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
            entity.HasIndex(x => new { x.RoleCode, x.Email })
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
            entity.HasIndex(x => x.IsJuryPresident)
                .IsUnique()
                .HasFilter("[IsPublished] = 1 AND [IsJuryPresident] = 1");
            entity.HasOne(x => x.PhotoImage)
                .WithMany(x => x.UserPhotos)
                .HasForeignKey(x => x.PhotoImageId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<UserLog>(entity =>
        {
            entity.ToTable("UsersLog", "dbo");
            entity.Property(x => x.Username).HasMaxLength(100);
            entity.Property(x => x.EventType).HasMaxLength(50);
            entity.Property(x => x.IpAddress).HasMaxLength(64);
            entity.Property(x => x.UserAgent).HasMaxLength(1000);
            entity.Property(x => x.Application).HasMaxLength(100);
            entity.Property(x => x.Details).HasMaxLength(2000);
            entity.Property(x => x.FailureReason).HasMaxLength(500);
            entity.HasIndex(x => new { x.UserId, x.EventType, x.OccurredAt });
            entity.HasIndex(x => new { x.Username, x.OccurredAt });
        });
        modelBuilder.Entity<AdminLog>(entity =>
        {
            entity.ToTable("AdminLogs", "dbo");
            entity.Property(x => x.Username).HasMaxLength(100);
            entity.Property(x => x.OperationName).HasMaxLength(256);
            entity.Property(x => x.OperationType).HasMaxLength(30);
            entity.Property(x => x.SchemaName).HasMaxLength(128);
            entity.Property(x => x.TableName).HasMaxLength(128);
            entity.Property(x => x.IpAddress).HasMaxLength(64);
            entity.Property(x => x.UserAgent).HasMaxLength(1000);
            entity.Property(x => x.Application).HasMaxLength(100);
            entity.Property(x => x.HttpMethod).HasMaxLength(16);
            entity.Property(x => x.RequestPath).HasMaxLength(2048);
            entity.Property(x => x.ControllerName).HasMaxLength(128);
            entity.Property(x => x.ActionName).HasMaxLength(128);
            entity.Property(x => x.Source).HasMaxLength(50);
            entity.Property(x => x.FailureReason).HasMaxLength(2000);
            entity.HasIndex(x => new { x.UserId, x.OccurredAt });
            entity.HasIndex(x => new { x.TableName, x.OccurredAt });
            entity.HasIndex(x => x.CorrelationId);
        });
        modelBuilder.Entity<JuryLog>(entity =>
        {
            entity.ToTable("JuryLogs", "dbo");
            entity.Property(x => x.Id).HasDefaultValueSql("newsequentialid()");
            entity.Property(x => x.CorrelationId).HasDefaultValueSql("newid()");
            entity.Property(x => x.JuryUsername).HasMaxLength(100);
            entity.Property(x => x.PlayName).HasMaxLength(250);
            entity.Property(x => x.OperationName).HasMaxLength(256);
            entity.Property(x => x.OperationType).HasMaxLength(50);
            entity.Property(x => x.SubmittedTicketFee).HasPrecision(10, 2);
            entity.Property(x => x.OldTicketFee).HasPrecision(10, 2);
            entity.Property(x => x.NewTicketFee).HasPrecision(10, 2);
            entity.Property(x => x.IpAddress).HasMaxLength(64);
            entity.Property(x => x.UserAgent).HasMaxLength(1000);
            entity.Property(x => x.HttpMethod).HasMaxLength(16);
            entity.Property(x => x.RequestPath).HasMaxLength(2048);
            entity.Property(x => x.ControllerName).HasMaxLength(128);
            entity.Property(x => x.ActionName).HasMaxLength(128);
            entity.Property(x => x.Application).HasMaxLength(100);
            entity.Property(x => x.Source).HasMaxLength(50);
            entity.Property(x => x.ResultCode).HasMaxLength(100);
            entity.Property(x => x.FailureReason).HasMaxLength(2000);
            entity.Property(x => x.IsAdditionalVoting).HasDefaultValue(false);
            entity.Property(x => x.AffectedVoteCount).HasDefaultValue(0);
            entity.Property(x => x.OccurredAt)
                .HasColumnType("datetime2(7)")
                .HasDefaultValueSql("DATEADD(HOUR, 3, SYSUTCDATETIME())");
            entity.Property(x => x.Application).HasDefaultValue("AfifeJury");
            entity.Property(x => x.Source).HasDefaultValue("JuryPanel");
            entity.Property(x => x.IsSuccessful).HasDefaultValue(false);
            entity.Property(x => x.IsPublished).HasDefaultValue(true);
            entity.HasIndex(x => x.CorrelationId);
            entity.HasIndex(x => new { x.JuryId, x.OccurredAt });
            entity.HasIndex(x => new { x.PlayId, x.OccurredAt });
            entity.HasIndex(x => new { x.OperationType, x.IsSuccessful, x.OccurredAt });
            entity.HasOne(x => x.Jury).WithMany().HasForeignKey(x => x.JuryId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne(x => x.Play).WithMany().HasForeignKey(x => x.PlayId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne(x => x.AdditionalVoting).WithMany().HasForeignKey(x => x.AdditionalVotingId)
                .OnDelete(DeleteBehavior.NoAction);
        });
        modelBuilder.Entity<Season>(entity =>
        {
            entity.ToTable("Seasons", "dbo");
            entity.HasIndex(season => new { season.SeasonStartDate, season.SeasonEndDate })
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
        });
        modelBuilder.Entity<AdditionalVoting>(entity =>
        {
            entity.ToTable("AdditionalVotings", "dbo", table =>
                table.HasCheckConstraint("CK_AdditionalVotings_DateRange", "[StartDate] < [EndDate]"));
            entity.HasMany(x => x.EligibleJuries).WithOne(x => x.AdditionalVoting)
                .HasForeignKey(x => x.AdditionalVotingId).OnDelete(DeleteBehavior.NoAction);
            entity.HasMany(x => x.EligiblePlays).WithOne(x => x.AdditionalVoting)
                .HasForeignKey(x => x.AdditionalVotingId).OnDelete(DeleteBehavior.NoAction);
            entity.HasMany(x => x.Usages).WithOne(x => x.AdditionalVoting)
                .HasForeignKey(x => x.AdditionalVotingId).OnDelete(DeleteBehavior.NoAction);
        });
        modelBuilder.Entity<AdditionalVotingJury>(entity =>
        {
            entity.ToTable("AdditionalVotingJuries", "dbo");
            entity.HasIndex(x => new { x.AdditionalVotingId, x.JuryId }).IsUnique()
                .HasFilter("[IsPublished] = 1");
            entity.HasOne(x => x.Jury).WithMany().HasForeignKey(x => x.JuryId)
                .OnDelete(DeleteBehavior.NoAction);
        });
        modelBuilder.Entity<AdditionalVotingPlay>(entity =>
        {
            entity.ToTable("AdditionalVotingPlays", "dbo");
            entity.HasIndex(x => new { x.AdditionalVotingId, x.PlayId }).IsUnique()
                .HasFilter("[IsPublished] = 1");
            entity.HasOne(x => x.Play).WithMany().HasForeignKey(x => x.PlayId)
                .OnDelete(DeleteBehavior.NoAction);
        });
        modelBuilder.Entity<AdditionalVotingUsage>(entity =>
        {
            entity.ToTable("AdditionalVotingUsages", "dbo", table =>
                table.HasCheckConstraint("CK_AdditionalVotingUsages_UsageType", "[UsageType] IN (0, 1)"));
            entity.HasIndex(x => new { x.AdditionalVotingId, x.JuryId, x.PlayId })
                .IsUnique().HasFilter("[IsPublished] = 1");
            entity.HasOne(x => x.Jury).WithMany().HasForeignKey(x => x.JuryId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne(x => x.Play).WithMany().HasForeignKey(x => x.PlayId)
                .OnDelete(DeleteBehavior.NoAction);
        });
        modelBuilder.Entity<Ranking>(entity =>
        {
            entity.ToTable("Rankings", "dbo");
            entity.Property(x => x.ArithmeticMean).HasColumnType("float");
            entity.Property(x => x.TrimmedMean).HasColumnType("float");
            entity.Property(x => x.ArithmeticVariance).HasColumnType("float");
            entity.HasIndex(x => x.PlayAwardCategoryId)
                .IsUnique();
            entity.HasIndex(x => new { x.PlayId, x.IsPublished });
            entity.HasOne(x => x.Play)
                .WithMany()
                .HasForeignKey(x => x.PlayId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne(x => x.PlayAwardCategory)
                .WithMany()
                .HasForeignKey(x => x.PlayAwardCategoryId)
                .OnDelete(DeleteBehavior.NoAction);
        });
        modelBuilder.Entity<Play>(entity =>
        {
            entity.ToTable("Plays", "dbo", table =>
            {
                table.UseSqlOutputClause(false);
                table.HasCheckConstraint(
                    "CK_Plays_KunyeMustRemainPublished",
                    "[RecordType] = 1 OR [IsPublished] = 1");
                table.HasCheckConstraint(
                    "CK_Plays_AdminRecord_StatusCode",
                    "[RecordType] = 0 OR [StatusCode] <> 1");
            });
            entity.Property(x => x.RecordType)
                .Metadata.SetAfterSaveBehavior(PropertySaveBehavior.Throw);
            entity.HasOne(x => x.SourceForm)
                .WithOne(x => x.Play)
                .HasForeignKey<Play>(x => x.SourceFormId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasMany(x => x.PlayAwardCategories)
                .WithOne(x => x.Play)
                .HasForeignKey(x => x.PlayId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasMany(x => x.JuryGameTicketFees)
                .WithOne(x => x.Play)
                .HasForeignKey(x => x.PlayId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<PlayAwardCategory>(entity =>
        {
            entity.ToTable("PlayAwardCategories", "dbo", table => table.UseSqlOutputClause(false));
            entity.HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.RoleCode, x.Candidate })
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
            entity.HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.RoleCode, x.IsCurrent })
                .HasFilter("[IsCurrent] = 1 AND [IsPublished] = 1");
            entity.HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.SourceFormCandidateOrder })
                .HasFilter("[SourceFormCandidateOrder] IS NOT NULL AND [IsCurrent] = 1")
                .HasDatabaseName("IX_PlayAwardCategories_FormSourceSlot");
            entity.HasOne(x => x.PhotoImage)
                .WithMany(x => x.CandidatePhotos)
                .HasForeignKey(x => x.PhotoImageId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasMany(x => x.JuryVotes)
                .WithOne(x => x.PlayAwardCategory)
                .HasForeignKey(x => x.PlayAwardCategoryId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Announcement>(entity =>
        {
            entity.ToTable("Announcements", "dbo");
            entity.HasOne(x => x.ImageAsset)
                .WithMany(x => x.AnnouncementImages)
                .HasForeignKey(x => x.ImageId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne(x => x.BackgroundImageAsset)
                .WithMany(x => x.AnnouncementBackgroundImages)
                .HasForeignKey(x => x.BackgroundImageId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Form>(entity =>
        {
            entity.ToTable("Form", "dbo");
            entity.HasIndex(x => x.ApplicationNumber)
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
            entity.HasOne(x => x.Season)
                .WithMany()
                .HasForeignKey(x => x.SeasonId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<FormLifecycleState>(entity =>
        {
            entity.ToTable("FormLifecycleStates", "dbo");
            entity.Property(x => x.EntityName).HasMaxLength(64);
            entity.HasIndex(x => new { x.FormId, x.EntityName, x.EntityId })
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
            entity.HasOne(x => x.Form)
                .WithMany()
                .HasForeignKey(x => x.FormId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        modelBuilder.Entity<Config>(entity =>
        {
            entity.ToTable("Configs", "dbo");
        });

        modelBuilder.Entity<Log>(entity =>
        {
            entity.ToTable("Log", "dbo");
        });

        modelBuilder.Entity<Manager>(entity =>
        {
            entity.ToTable("Manager", "dbo");
        });

        modelBuilder.Entity<Role>(entity =>
        {
            entity.ToTable("Roles", "dbo");
        });
        modelBuilder.Entity<Group>(entity =>
        {
            entity.ToTable("Group", "dbo");
        });

        modelBuilder.Entity<PlayStatus>(entity =>
        {
            entity.ToTable("PlayStatuses", "dbo");
        });

        modelBuilder.Entity<AwardCategory>(entity =>
        {
            entity.ToTable("AwardCategories", "dbo");
        });

        modelBuilder.Entity<JuryAssignedPlay>(entity =>
        {
            entity.ToTable("JuryAssignedPlays", "dbo");
            entity.HasIndex(x => new { x.PlayId, x.JuryId })
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
        });
        modelBuilder.Entity<JuryVote>(entity =>
        {
            entity.ToTable("JuryVotes", "dbo", table =>
            {
                table.UseSqlOutputClause(false);
                table.HasCheckConstraint("CK_JuryVotes_Score", "[Score] >= 1 AND [Score] <= 10");
            });
            entity.HasIndex(x => new { x.PlayAwardCategoryId, x.JuryId })
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
        });

        modelBuilder.Entity<JuryGameTicketFee>(entity =>
        {
            entity.ToTable("JuryGameTicketFees", "dbo");
            entity.Property(x => x.TicketFee).HasPrecision(10, 2);
            entity.HasIndex(x => new { x.UserId, x.PlayId })
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
        });

        modelBuilder.Entity<Blacklist>(entity =>
        {
            entity.ToTable("Blacklist", "dbo", table => table.UseSqlOutputClause(false));
            entity.HasIndex(x => new { x.JuryId, x.PlayId })
                .IsUnique()
                .HasFilter("[IsPublished] = 1");
            entity.HasOne(x => x.Jury)
                .WithMany()
                .HasForeignKey(x => x.JuryId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne(x => x.Play)
                .WithMany()
                .HasForeignKey(x => x.PlayId)
                .OnDelete(DeleteBehavior.NoAction);
            entity.HasOne(x => x.Creator)
                .WithMany()
                .HasForeignKey(x => x.CreatedBy)
                .OnDelete(DeleteBehavior.NoAction);
        });
        AfifeRelationalModelConfiguration.Configure(modelBuilder);
        DisableSqlOutputClauseForAuditedTables(modelBuilder);
        ApplyPublishedQueryFilters(modelBuilder);
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
