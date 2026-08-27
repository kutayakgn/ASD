using Microsoft.EntityFrameworkCore;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data;

internal static partial class AfifeRelationalModelConfiguration
{
    private static void ConfigureRelationships(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AdditionalVotingJury>().HasOne(x => x.AdditionalVoting)
            .WithMany(x => x.EligibleJuries).HasForeignKey(x => x.AdditionalVotingId)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_AdditionalVotingJuries_AdditionalVotings");
        modelBuilder.Entity<AdditionalVotingJury>().HasOne(x => x.Jury).WithMany()
            .HasForeignKey(x => x.JuryId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingJuries_Users_Jury");
        modelBuilder.Entity<AdditionalVotingPlay>().HasOne(x => x.AdditionalVoting)
            .WithMany(x => x.EligiblePlays).HasForeignKey(x => x.AdditionalVotingId)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_AdditionalVotingPlays_AdditionalVotings");
        modelBuilder.Entity<AdditionalVotingPlay>().HasOne(x => x.Play).WithMany()
            .HasForeignKey(x => x.PlayId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingPlays_Plays");
        modelBuilder.Entity<AdditionalVotingUsage>().HasOne(x => x.AdditionalVoting)
            .WithMany(x => x.Usages).HasForeignKey(x => x.AdditionalVotingId)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_AdditionalVotingUsages_AdditionalVotings");
        modelBuilder.Entity<AdditionalVotingUsage>().HasOne(x => x.Jury).WithMany()
            .HasForeignKey(x => x.JuryId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingUsages_Users_Jury");
        modelBuilder.Entity<AdditionalVotingUsage>().HasOne(x => x.Play).WithMany()
            .HasForeignKey(x => x.PlayId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingUsages_Plays");
        modelBuilder.Entity<User>().HasOne(x => x.Role).WithMany(x => x.Users)
            .HasForeignKey(x => x.RoleCode).HasPrincipalKey(x => x.RoleCode)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_Users_Roles");
        modelBuilder.Entity<User>().HasOne(x => x.Group).WithMany(x => x.Users)
            .HasForeignKey(x => x.GroupCode).HasPrincipalKey(x => x.Code)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_Users_Group");
        modelBuilder.Entity<User>().HasOne(x => x.PhotoImage).WithMany(x => x.UserPhotos)
            .HasForeignKey(x => x.PhotoImageId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Users_Images_PhotoImageId");

        modelBuilder.Entity<Play>().HasOne(x => x.Status).WithMany(x => x.Plays)
            .HasForeignKey(x => x.StatusCode).HasPrincipalKey(x => x.StatusCode)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_Plays_PlayStatuses");
        modelBuilder.Entity<Play>().HasMany(x => x.JuryAssignments).WithOne(x => x.Play)
            .HasForeignKey(x => x.PlayId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryAssignedPlays_Plays");
        modelBuilder.Entity<JuryAssignedPlay>().HasOne(x => x.Jury).WithMany(x => x.AssignedPlays)
            .HasForeignKey(x => x.JuryId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryAssignedPlays_Users");
        modelBuilder.Entity<JuryGameTicketFee>().HasOne(x => x.User).WithMany(x => x.JuryGameTicketFees)
            .HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryGameTicketFees_Users");
        modelBuilder.Entity<JuryGameTicketFee>().HasOne(x => x.Play).WithMany(x => x.JuryGameTicketFees)
            .HasForeignKey(x => x.PlayId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryGameTicketFees_Plays");
        modelBuilder.Entity<JuryVote>().HasOne(x => x.Jury).WithMany(x => x.JuryVotes)
            .HasForeignKey(x => x.JuryId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryVotes_Users");
        modelBuilder.Entity<PlayAwardCategory>().HasOne(x => x.AwardCategory)
            .WithMany(x => x.PlayAwardCategories).HasForeignKey(x => x.AwardCategoryCode)
            .HasPrincipalKey(x => x.CategoryCode).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_PlayAwardCategories_AwardCategories");

        modelBuilder.Entity<UserLog>().HasOne<User>().WithMany().HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_UsersLog_Users_UserId");
        modelBuilder.Entity<JuryLog>().HasOne(x => x.Jury).WithMany()
            .HasForeignKey(x => x.JuryId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryLogs_Users_JuryId");
        modelBuilder.Entity<JuryLog>().HasOne(x => x.Play).WithMany()
            .HasForeignKey(x => x.PlayId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryLogs_Plays_PlayId");
        modelBuilder.Entity<JuryLog>().HasOne(x => x.AdditionalVoting).WithMany()
            .HasForeignKey(x => x.AdditionalVotingId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryLogs_AdditionalVotings_AdditionalVotingId");

        modelBuilder.Entity<Announcement>().HasOne(x => x.ImageAsset)
            .WithMany(x => x.AnnouncementImages).HasForeignKey(x => x.ImageId)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_Announcements_Images_ImageId");
        modelBuilder.Entity<Announcement>().HasOne(x => x.BackgroundImageAsset)
            .WithMany(x => x.AnnouncementBackgroundImages).HasForeignKey(x => x.BackgroundImageId)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_Announcements_Images_BackgroundImageId");
        modelBuilder.Entity<Blacklist>().HasOne(x => x.Jury).WithMany()
            .HasForeignKey(x => x.JuryId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Blacklist_Users_JuryId");
        modelBuilder.Entity<Blacklist>().HasOne(x => x.Play).WithMany()
            .HasForeignKey(x => x.PlayId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Blacklist_Plays_PlayId");
        modelBuilder.Entity<Blacklist>().HasOne(x => x.Creator).WithMany()
            .HasForeignKey(x => x.CreatedBy).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Blacklist_Users_CreatedBy");
        modelBuilder.Entity<Form>().HasOne(x => x.Season).WithMany()
            .HasForeignKey(x => x.SeasonId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Form_Seasons");
        modelBuilder.Entity<FormLifecycleState>().HasOne(x => x.Form).WithMany()
            .HasForeignKey(x => x.FormId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_FormLifecycleStates_Form");
        modelBuilder.Entity<Play>().HasOne(x => x.SourceForm).WithOne(x => x.Play)
            .HasForeignKey<Play>(x => x.SourceFormId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Plays_Form_SourceFormId");
        modelBuilder.Entity<PlayAwardCategory>().HasOne(x => x.Play)
            .WithMany(x => x.PlayAwardCategories).HasForeignKey(x => x.PlayId)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_PlayAwardCategories_Plays");
        modelBuilder.Entity<PlayAwardCategory>().HasOne(x => x.PhotoImage)
            .WithMany(x => x.CandidatePhotos).HasForeignKey(x => x.PhotoImageId)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_PlayAwardCategories_Images_PhotoImageId");
        modelBuilder.Entity<JuryVote>().HasOne(x => x.PlayAwardCategory)
            .WithMany(x => x.JuryVotes).HasForeignKey(x => x.PlayAwardCategoryId)
            .OnDelete(DeleteBehavior.NoAction).HasConstraintName("FK_JuryVotes_PlayAwardCategories");
        modelBuilder.Entity<Ranking>().HasOne(x => x.Play).WithMany()
            .HasForeignKey(x => x.PlayId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Rankings_Plays");
        modelBuilder.Entity<Ranking>().HasOne(x => x.PlayAwardCategory).WithMany()
            .HasForeignKey(x => x.PlayAwardCategoryId).OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Rankings_PlayAwardCategories");
        ConfigureAuditUserRelationships<AdditionalVoting>(modelBuilder);
        ConfigureAuditUserRelationships<AdditionalVotingJury>(modelBuilder);
        ConfigureAuditUserRelationships<AdditionalVotingPlay>(modelBuilder);
        ConfigureAuditUserRelationships<AdditionalVotingUsage>(modelBuilder);
    }

    private static void ConfigureAuditUserRelationships<TEntity>(ModelBuilder modelBuilder)
        where TEntity : class
    {
        var table = modelBuilder.Entity<TEntity>().Metadata.GetTableName()!;
        modelBuilder.Entity<TEntity>().HasOne<User>().WithMany().HasForeignKey("CreatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName($"FK_{table}_Users_CreatedBy");
        modelBuilder.Entity<TEntity>().HasOne<User>().WithMany().HasForeignKey("UpdatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName($"FK_{table}_Users_UpdatedBy");
    }
}
