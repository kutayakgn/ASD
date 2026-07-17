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

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(entity =>
        {
            entity.ToTable("Users", "dbo");
            entity.Ignore(x => x.Role);
            entity.Ignore(x => x.Group);
            entity.Ignore(x => x.AssignedPlays);
            entity.Ignore(x => x.JuryGameTicketFees);
            entity.Ignore(x => x.JuryVotes);
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
            entity.HasMany(x => x.JuryVotes)
                .WithOne(x => x.PlayAwardCategory)
                .HasForeignKey(x => x.PlayAwardCategoryId)
                .OnDelete(DeleteBehavior.NoAction);
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