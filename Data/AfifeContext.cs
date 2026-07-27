using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using System.Linq.Expressions;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data;

public sealed class AfifeContext(DbContextOptions<AfifeContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<UserLog> UserLogs => Set<UserLog>();
    public DbSet<Play> Plays => Set<Play>();
    public DbSet<PlayAwardCategory> PlayAwardCategories => Set<PlayAwardCategory>();
    public DbSet<JuryVote> JuryVotes => Set<JuryVote>();
    public DbSet<JuryGameTicketFee> JuryGameTicketFees => Set<JuryGameTicketFee>();
    public DbSet<Image> Images => Set<Image>();
    public DbSet<Announcement> Announcements => Set<Announcement>();
    public DbSet<Form> Forms => Set<Form>();
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
            entity.ToTable("Users", "dbo");
            entity.Ignore(x => x.Role);
            entity.Ignore(x => x.Group);
            entity.Ignore(x => x.AssignedPlays);
            entity.Ignore(x => x.JuryGameTicketFees);
            entity.Ignore(x => x.JuryVotes);
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
        modelBuilder.Entity<Play>(entity =>
        {
            entity.ToTable("Plays", "dbo", table => table.UseSqlOutputClause(false));
            entity.Property(x => x.RecordType)
                .Metadata.SetAfterSaveBehavior(PropertySaveBehavior.Throw);
            entity.Ignore(x => x.Status);
            entity.Ignore(x => x.JuryAssignments);
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
            entity.Ignore(x => x.AwardCategory);
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
            entity.Ignore(x => x.Users);
        });
        modelBuilder.Entity<Group>(entity =>
        {
            entity.ToTable("Group", "dbo");
            entity.Ignore(x => x.Users);
        });

        modelBuilder.Entity<PlayStatus>(entity =>
        {
            entity.ToTable("PlayStatuses", "dbo");
            entity.Ignore(x => x.Plays);
        });

        modelBuilder.Entity<AwardCategory>(entity =>
        {
            entity.ToTable("AwardCategories", "dbo");
            entity.Ignore(x => x.PlayAwardCategories);
        });

        modelBuilder.Entity<JuryAssignedPlay>(entity =>
        {
            entity.ToTable("JuryAssignedPlays", "dbo");
            entity.Ignore(x => x.Play);
            entity.Ignore(x => x.Jury);
        });
        modelBuilder.Entity<JuryVote>(entity =>
        {
            entity.ToTable("JuryVotes", "dbo", table => table.UseSqlOutputClause(false));
            entity.Ignore(x => x.Jury);
        });

        modelBuilder.Entity<JuryGameTicketFee>(entity =>
        {
            entity.ToTable("JuryGameTicketFees", "dbo");
            entity.Ignore(x => x.User);
            entity.Property(x => x.TicketFee).HasPrecision(10, 2);
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
        ApplyPublishedQueryFilters(modelBuilder);
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        ConvertDeletesToSoftDeletes();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(
        bool acceptAllChangesOnSuccess,
        CancellationToken cancellationToken = default)
    {
        ConvertDeletesToSoftDeletes();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
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

            var parameter = Expression.Parameter(entityType.ClrType, "entity");
            var body = Expression.Equal(
                Expression.Property(parameter, "IsPublished"),
                Expression.Constant(true));

            entityType.SetQueryFilter(Expression.Lambda(body, parameter));
        }
    }

    private void ConvertDeletesToSoftDeletes()
    {
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
