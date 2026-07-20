using Microsoft.EntityFrameworkCore;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data;

public sealed class AfifeContext(DbContextOptions<AfifeContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
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

        modelBuilder.Entity<Play>(entity =>
        {
            entity.ToTable("Plays", "dbo");
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
            entity.ToTable("PlayAwardCategories", "dbo");
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
            entity.ToTable("JuryVotes", "dbo");
            entity.Ignore(x => x.Jury);
        });

        modelBuilder.Entity<JuryGameTicketFee>(entity =>
        {
            entity.ToTable("JuryGameTicketFees", "dbo");
            entity.Ignore(x => x.User);
            entity.Property(x => x.TicketFee).HasPrecision(10, 2);
        });
    }
}