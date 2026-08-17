using Microsoft.EntityFrameworkCore;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data;

internal static class AfifeRelationalModelConfiguration
{
    public static void Configure(ModelBuilder modelBuilder)
    {
        ConfigureReferenceKeys(modelBuilder);
        ConfigureRelationships(modelBuilder);
        ConfigureColumns(modelBuilder);
        ConfigureIndexes(modelBuilder);
        ConfigureChecks(modelBuilder);
        RemoveNonCanonicalConventionIndexes(modelBuilder);
    }

    private static void ConfigureReferenceKeys(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AwardCategory>().HasAlternateKey(x => x.CategoryCode)
            .HasName("UQ_AwardCategories_CategoryCode");
        modelBuilder.Entity<Group>().HasAlternateKey(x => x.Code).HasName("UQ_Group_Code");
        modelBuilder.Entity<PlayStatus>().HasAlternateKey(x => x.StatusCode)
            .HasName("UQ_PlayStatuses_StatusCode");
        modelBuilder.Entity<Role>().HasAlternateKey(x => x.RoleCode).HasName("UQ_Roles_RoleCode");
    }

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
    private static void ConfigureColumns(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Announcement>(e =>
        {
            e.Property(x => x.Text).HasMaxLength(255);
            e.Property(x => x.ButtonText).HasMaxLength(255);
            e.Property(x => x.BackgroundColor).HasMaxLength(50);
        });
        modelBuilder.Entity<AwardCategory>(e =>
        {
            e.Property(x => x.CategoryName).HasMaxLength(255);
            e.Property(x => x.MultiCandidate).HasDefaultValue(false);
            e.Property(x => x.HasRoleAndPhoto).HasDefaultValue(false);
        });
        modelBuilder.Entity<Blacklist>().Property(x => x.CreatedOn).HasColumnType("datetime2(0)")
            .HasDefaultValueSql("sysutcdatetime()");
        modelBuilder.Entity<Config>(e =>
        {
            e.Property(x => x.ConfigName).HasMaxLength(255);
            e.Property(x => x.ConfigValue).HasMaxLength(255);
        });
        modelBuilder.Entity<Form>(e =>
        {
            e.Property(x => x.ApplicationNumber).HasMaxLength(6);
            e.Property(x => x.CreatedDate).HasColumnType("datetime");
            e.Property(x => x.UpdatedDate).HasColumnType("datetime");
            e.Property(x => x.RepertoireName).HasMaxLength(500);
            e.Property(x => x.TheatreName).HasMaxLength(500);
            e.Property(x => x.ApplicantName).HasMaxLength(100);
            e.Property(x => x.ApplicantRole).HasMaxLength(200);
            e.Property(x => x.Phone).HasMaxLength(20);
            e.Property(x => x.Email).HasMaxLength(150);
            e.Property(x => x.Director).HasMaxLength(100);
            e.Property(x => x.ContactName).HasMaxLength(100);
            e.Property(x => x.ContactPhone).HasMaxLength(20);
            e.Property(x => x.StageDesign).HasMaxLength(1000);
            e.Property(x => x.ClothesDesign).HasMaxLength(1000);
            e.Property(x => x.LightDesign).HasMaxLength(1000);
            e.Property(x => x.StageMusic).HasMaxLength(1000);
            e.Property(x => x.Choreography).HasMaxLength(1000);
        });
        modelBuilder.Entity<Group>().Property(x => x.GroupName).HasMaxLength(100);
        modelBuilder.Entity<Image>(e =>
        {
            e.Property(x => x.FileName).HasMaxLength(255);
            e.Property(x => x.ContentType).HasMaxLength(100);
        });
        modelBuilder.Entity<Log>(e =>
        {
            e.Property(x => x.Title).HasMaxLength(200);
            e.Property(x => x.Source).HasMaxLength(50);
            e.Property(x => x.EventType).HasMaxLength(50);
            e.Property(x => x.CreatedDate).HasColumnType("datetime");
        });
        modelBuilder.Entity<Manager>(e =>
        {
            e.Property(x => x.FullName).HasColumnType("nchar(100)");
            e.Property(x => x.Email).HasMaxLength(150);
            e.Property(x => x.Password).HasMaxLength(100);
            e.Property(x => x.CreatedDate).HasColumnType("datetime");
            e.Property(x => x.UpdatedDate).HasColumnType("datetime");
        });
        modelBuilder.Entity<Play>(e =>
        {
            e.Property(x => x.PlayName).HasMaxLength(255);
            e.Property(x => x.Slug).HasMaxLength(255).IsUnicode(false);
            e.Property(x => x.TheaterName).HasMaxLength(255);
            e.Property(x => x.Phone).HasMaxLength(255);
            e.Property(x => x.ContactPersonName).HasMaxLength(255);
            e.Property(x => x.ContactPersonPhone).HasMaxLength(255);
            e.Property(x => x.Address).HasMaxLength(255);
            e.Property(x => x.Email).HasMaxLength(255);
            e.Property(x => x.JuriOylamaStatus).HasDefaultValue(false);
            e.Property(x => x.KunyeGirisStatus).HasDefaultValue(false);
            e.Property(x => x.RecordType).HasDefaultValue(false);
            e.Property(x => x.IsActive).HasDefaultValue(true);
        });
        modelBuilder.Entity<PlayAwardCategory>(e =>
        {
            e.Property(x => x.Candidate).HasMaxLength(250);
            e.Property(x => x.Role).HasMaxLength(200);
            e.Property(x => x.IsActive).HasDefaultValue(true);
        });
        modelBuilder.Entity<PlayStatus>(e =>
        {
            e.Property(x => x.StatusName).HasMaxLength(100);
            e.Property(x => x.StatusColor).HasMaxLength(50);
        });
        modelBuilder.Entity<Role>().Property(x => x.RoleName).HasMaxLength(100);
        modelBuilder.Entity<User>(e =>
        {
            e.Property(x => x.FirstName).HasMaxLength(100);
            e.Property(x => x.LastName).HasMaxLength(100);
            e.Property(x => x.Phone).HasMaxLength(30);
            e.Property(x => x.Username).HasMaxLength(100);
            e.Property(x => x.PasswordHash).HasMaxLength(500);
            e.Property(x => x.Email).HasMaxLength(255);
            e.Property(x => x.IsActive).HasDefaultValue(true);
            e.Property(x => x.IsJuryPresident).HasDefaultValue(false);
        });

        foreach (var type in new[] {
            typeof(AdditionalVoting), typeof(AdditionalVotingJury),
            typeof(AdditionalVotingPlay), typeof(AdditionalVotingUsage),
            typeof(FormLifecycleState), typeof(Ranking), typeof(Season) })
        {
            modelBuilder.Entity(type).Property("Id").HasDefaultValueSql("newsequentialid()");
        }
        modelBuilder.Entity<AdditionalVoting>().Property(x => x.CreatedAt).HasDefaultValueSql("sysdatetime()");
        modelBuilder.Entity<AdditionalVoting>().Property(x => x.AppliesToAllJuries).HasDefaultValue(false);
        modelBuilder.Entity<AdditionalVoting>().Property(x => x.AppliesToAllPlays).HasDefaultValue(false);
        modelBuilder.Entity<AdditionalVoting>().Property(x => x.IsActive).HasDefaultValue(true);
        modelBuilder.Entity<AdditionalVotingJury>().Property(x => x.CreatedAt).HasDefaultValueSql("sysdatetime()");
        modelBuilder.Entity<AdditionalVotingJury>().Property(x => x.IsActive).HasDefaultValue(true);
        modelBuilder.Entity<AdditionalVotingPlay>().Property(x => x.CreatedAt).HasDefaultValueSql("sysdatetime()");
        modelBuilder.Entity<AdditionalVotingPlay>().Property(x => x.IsActive).HasDefaultValue(true);
        modelBuilder.Entity<AdditionalVotingUsage>().Property(x => x.CreatedAt).HasDefaultValueSql("sysdatetime()");
        modelBuilder.Entity<AdditionalVotingUsage>().Property(x => x.IsActive).HasDefaultValue(true);
        modelBuilder.Entity<AdditionalVotingUsage>().Property(x => x.UsedAt).HasDefaultValueSql("sysdatetime()");
        modelBuilder.Entity<AdminLog>().Property(x => x.AffectedRowCount).HasDefaultValue(0);
        modelBuilder.Entity<AdminLog>().Property(x => x.Application).HasDefaultValue("AfifeAdmin");
        modelBuilder.Entity<AdminLog>().Property(x => x.IsSuccessful).HasDefaultValue(true);
        modelBuilder.Entity<Blacklist>().Property(x => x.Id).HasDefaultValueSql("newid()");
        modelBuilder.Entity<Form>().Property(x => x.Id).HasDefaultValueSql("newsequentialid()");
        modelBuilder.Entity<Form>().Property(x => x.IsActive).HasDefaultValue(true);
        modelBuilder.Entity<JuryVote>().Property(x => x.IsActive).HasDefaultValue(true);
        modelBuilder.Entity<UserLog>().Property(x => x.Username).HasDefaultValue(string.Empty);
        modelBuilder.Entity<UserLog>().Property(x => x.Application).HasDefaultValue("AfifeAdmin");
        modelBuilder.Entity<Season>().Property(x => x.PlayCount).HasDefaultValue(0);
        modelBuilder.Entity<Season>().Property(x => x.ActivePlayCount).HasDefaultValue(0);
        modelBuilder.Entity<Season>().Property(x => x.VoteCount).HasDefaultValue(0);
        modelBuilder.Entity<Ranking>().Property(x => x.NumberOfActiveVote).HasDefaultValue(0);
    }

    private static void ConfigureIndexes(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AdminLog>().HasIndex(x => new { x.CorrelationId, x.OccurredAt })
            .HasDatabaseName("IX_AdminLogs_CorrelationId");
        modelBuilder.Entity<AdminLog>().HasIndex(x => new { x.OccurredAt, x.OperationType, x.SchemaName, x.TableName, x.ActionName })
            .IsDescending(true, false, false, false, false)
            .IncludeProperties(x => new { x.CorrelationId, x.Username, x.IsPublished })
            .HasDatabaseName("IX_AdminLogs_FilterConsole");
        modelBuilder.Entity<AdminLog>().HasIndex(x => new { x.TableName, x.OccurredAt })
            .IsDescending(false, true)
            .IncludeProperties(x => new { x.OperationType, x.UserId, x.IsPublished })
            .HasDatabaseName("IX_AdminLogs_TableName_OccurredAt");
        modelBuilder.Entity<AdminLog>().HasIndex(x => new { x.UserId, x.OccurredAt })
            .IsDescending(false, true)
            .IncludeProperties(x => new { x.OperationType, x.TableName, x.IsSuccessful, x.IsPublished })
            .HasDatabaseName("IX_AdminLogs_UserId_OccurredAt");
        modelBuilder.Entity<Announcement>().HasIndex(x => x.BackgroundImageId).HasDatabaseName("IX_Announcements_BackgroundImageId");
        modelBuilder.Entity<Announcement>().HasIndex(x => x.ImageId).HasDatabaseName("IX_Announcements_ImageId");
        modelBuilder.Entity<JuryAssignedPlay>().HasIndex(x => x.JuryId).HasDatabaseName("IX_JuryAssignedPlays_JuryId");
        modelBuilder.Entity<JuryAssignedPlay>().HasIndex(x => x.PlayId).HasDatabaseName("IX_JuryAssignedPlays_PlayId");
        modelBuilder.Entity<JuryGameTicketFee>().HasIndex(x => x.PlayId).HasDatabaseName("IX_JuryGameTicketFees_PlayId");
        modelBuilder.Entity<JuryGameTicketFee>().HasIndex(x => x.UserId).HasDatabaseName("IX_JuryGameTicketFees_UserId");
        modelBuilder.Entity<JuryVote>().HasIndex(x => x.JuryId).HasDatabaseName("IX_JuryVotes_JuryId");
        modelBuilder.Entity<JuryVote>().HasIndex(x => x.PlayAwardCategoryId).HasDatabaseName("IX_JuryVotes_PlayAwardCategoryId");
        modelBuilder.Entity<JuryVote>().HasIndex(x => new { x.PlayAwardCategoryId, x.IsPublished, x.IsActive })
            .IncludeProperties(x => new { x.Score, x.Id }).HasDatabaseName("IX_JuryVotes_RankingProjection");
        modelBuilder.Entity<JuryVote>().HasIndex(x => x.CreatedAt)
            .IncludeProperties(x => new { x.IsPublished, x.IsActive }).HasFilter("[CreatedAt] IS NOT NULL")
            .HasDatabaseName("IX_JuryVotes_SeasonStatistics");
        modelBuilder.Entity<PlayAwardCategory>().HasIndex(x => x.AwardCategoryCode).HasDatabaseName("IX_PlayAwardCategories_AwardCategoryCode");
        modelBuilder.Entity<PlayAwardCategory>().HasIndex(x => x.PhotoImageId).HasDatabaseName("IX_PlayAwardCategories_PhotoImageId");
        modelBuilder.Entity<PlayAwardCategory>().HasIndex(x => x.PlayId).HasDatabaseName("IX_PlayAwardCategories_PlayId");
        modelBuilder.Entity<Play>().HasIndex(x => x.CreatedAt)
            .IncludeProperties(x => new { x.IsPublished, x.StatusCode }).HasFilter("[CreatedAt] IS NOT NULL")
            .HasDatabaseName("IX_Plays_SeasonStatistics");
        modelBuilder.Entity<Play>().HasIndex(x => x.StatusCode).HasDatabaseName("IX_Plays_StatusCode");
        modelBuilder.Entity<Ranking>().HasIndex(x => new { x.PlayId, x.IsPublished })
            .IncludeProperties(x => new { x.PlayAwardCategoryId, x.NumberOfActiveVote, x.ArithmeticMean, x.TrimmedMean, x.ArithmeticRank, x.TrimmedRank, x.ArithmeticVariance })
            .HasDatabaseName("IX_Rankings_PlayId_IsPublished");
        modelBuilder.Entity<User>().HasIndex(x => x.GroupCode).HasDatabaseName("IX_Users_GroupCode");
        modelBuilder.Entity<User>().HasIndex(x => x.PhotoImageId).HasDatabaseName("IX_Users_PhotoImageId");
        modelBuilder.Entity<User>().HasIndex(x => x.RoleCode).HasDatabaseName("IX_Users_RoleCode");
        modelBuilder.Entity<User>().HasIndex(x => x.IsJuryPresident)
            .IsUnique().HasFilter("[IsPublished] = 1 AND [IsJuryPresident] = 1")
            .HasDatabaseName("UX_Users_OnePublishedJuryPresident");
        modelBuilder.Entity<UserLog>().HasIndex(x => new { x.CorrelationId, x.OccurredAt })
            .IsDescending(false, true).HasDatabaseName("IX_UsersLog_CorrelationId");
        modelBuilder.Entity<UserLog>().HasIndex(x => new { x.OccurredAt, x.Application })
            .IsDescending(true, false)
            .IncludeProperties(x => new { x.UserId, x.ActorUserId, x.Username, x.CorrelationId, x.IsPublished })
            .HasDatabaseName("IX_UsersLog_FilterConsole");
        modelBuilder.Entity<UserLog>().HasIndex(x => new { x.UserId, x.EventType, x.OccurredAt })
            .IsDescending(false, false, true).IncludeProperties(x => new { x.IsSuccessful, x.IsPublished })
            .HasDatabaseName("IX_UsersLog_UserId_EventType_OccurredAt");
        modelBuilder.Entity<UserLog>().HasIndex(x => new { x.Username, x.OccurredAt })
            .IsDescending(false, true).HasDatabaseName("IX_UsersLog_Username_OccurredAt");
        modelBuilder.Entity<AdditionalVotingJury>().HasIndex(x => new { x.AdditionalVotingId, x.JuryId })
            .HasDatabaseName("UX_AdditionalVotingJuries_Published");
        modelBuilder.Entity<AdditionalVotingPlay>().HasIndex(x => new { x.AdditionalVotingId, x.PlayId })
            .HasDatabaseName("UX_AdditionalVotingPlays_Published");
        modelBuilder.Entity<AdditionalVotingUsage>().HasIndex(x => new { x.AdditionalVotingId, x.JuryId, x.PlayId })
            .HasDatabaseName("UX_AdditionalVotingUsages_OneTime");
        modelBuilder.Entity<AdditionalVotingUsage>().HasIndex(x => new { x.AdditionalVotingId, x.UsageType, x.JuryId })
            .HasDatabaseName("IX_AdditionalVotingUsages_Lookup").HasFilter("[IsPublished] = 1");
        modelBuilder.Entity<Blacklist>().HasIndex(x => new { x.JuryId, x.PlayId })
            .HasDatabaseName("UX_Blacklist_JuryId_PlayId_Published");
        modelBuilder.Entity<Blacklist>().HasIndex(x => x.CreatedOn).IsDescending().HasDatabaseName("IX_Blacklist_CreatedOn");
        modelBuilder.Entity<Form>().HasIndex(x => x.ApplicationNumber)
            .HasDatabaseName("UX_Form_ApplicationNumber_Published");
        modelBuilder.Entity<Form>().HasIndex(x => x.LegacyId).IsUnique()
            .HasFilter("[LegacyId] IS NOT NULL").HasDatabaseName("UX_Form_LegacyId");
        modelBuilder.Entity<FormLifecycleState>().HasIndex(x => new { x.FormId, x.EntityName, x.EntityId })
            .HasDatabaseName("UX_FormLifecycleStates_OpenEntity");
        modelBuilder.Entity<JuryAssignedPlay>().HasIndex(x => new { x.PlayId, x.JuryId })
            .HasDatabaseName("UX_JuryAssignedPlays_PlayId_JuryId");
        modelBuilder.Entity<JuryGameTicketFee>().HasIndex(x => new { x.UserId, x.PlayId })
            .HasDatabaseName("UX_JuryGameTicketFees_UserId_PlayId");
        modelBuilder.Entity<JuryVote>().HasIndex(x => new { x.PlayAwardCategoryId, x.JuryId })
            .HasDatabaseName("UX_JuryVotes_JuryId_PlayAwardCategoryId");
        modelBuilder.Entity<PlayAwardCategory>().HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.RoleCode, x.IsCurrent })
            .HasDatabaseName("UX_PlayAwardCategories_Current_Play_Category_Role");
        modelBuilder.Entity<PlayAwardCategory>().HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.RoleCode, x.Candidate })
            .HasDatabaseName("UX_PlayAwardCategories_Play_Category_Role_Candidate");
        modelBuilder.Entity<PlayAwardCategory>().HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.SourceFormCandidateOrder })
            .IsUnique().HasFilter("[SourceFormCandidateOrder] IS NOT NULL AND [IsCurrent] = 1")
            .HasDatabaseName("UX_PlayAwardCategories_FormSourceSlot");
        modelBuilder.Entity<PlayAwardCategory>().HasIndex(x => x.PlayId)
            .IsUnique().HasFilter("[AwardCategoryCode] = 1001 AND [RoleCode] = 0")
            .HasDatabaseName("UX_PlayAwardCategories_DefaultPlayCategory");
        modelBuilder.Entity<Play>().HasIndex(x => x.SourceFormId).IsUnique()
            .HasFilter("[SourceFormId] IS NOT NULL").HasDatabaseName("UX_Plays_SourceFormId");
        modelBuilder.Entity<Ranking>().HasIndex(x => x.PlayAwardCategoryId)
            .HasDatabaseName("UX_Rankings_PlayAwardCategoryId");
        modelBuilder.Entity<Ranking>().HasIndex(x => new { x.PlayId, x.IsPublished })
            .HasDatabaseName("IX_Rankings_PlayId_IsPublished");
        modelBuilder.Entity<Season>().HasIndex(x => new { x.SeasonStartDate, x.SeasonEndDate })
            .HasDatabaseName("UX_Seasons_PublishedDateRange");
        modelBuilder.Entity<User>().HasIndex(x => new { x.RoleCode, x.Email })
            .HasDatabaseName("UX_Users_RoleCode_Email_Published");
        modelBuilder.Entity<User>().HasIndex(x => new { x.RoleCode, x.Username })
            .HasDatabaseName("UX_Users_RoleCode_Username_Published");
    }

    private static void RemoveNonCanonicalConventionIndexes(ModelBuilder modelBuilder)
    {
        RemoveIndex<AdditionalVoting>(modelBuilder, "CreatedBy");
        RemoveIndex<AdditionalVoting>(modelBuilder, "UpdatedBy");
        RemoveIndex<AdditionalVotingJury>(modelBuilder, "CreatedBy");
        RemoveIndex<AdditionalVotingJury>(modelBuilder, "UpdatedBy");
        RemoveIndex<AdditionalVotingJury>(modelBuilder, "JuryId");
        RemoveIndex<AdditionalVotingPlay>(modelBuilder, "CreatedBy");
        RemoveIndex<AdditionalVotingPlay>(modelBuilder, "UpdatedBy");
        RemoveIndex<AdditionalVotingPlay>(modelBuilder, "PlayId");
        RemoveIndex<AdditionalVotingUsage>(modelBuilder, "CreatedBy");
        RemoveIndex<AdditionalVotingUsage>(modelBuilder, "UpdatedBy");
        RemoveIndex<AdditionalVotingUsage>(modelBuilder, "JuryId");
        RemoveIndex<AdditionalVotingUsage>(modelBuilder, "PlayId");
        RemoveIndex<Blacklist>(modelBuilder, "CreatedBy");
        RemoveIndex<Blacklist>(modelBuilder, "PlayId");
        RemoveIndex<Form>(modelBuilder, "SeasonId");
    }

    private static void RemoveIndex<TEntity>(ModelBuilder modelBuilder, params string[] propertyNames)
        where TEntity : class
    {
        var entityType = modelBuilder.Entity<TEntity>().Metadata;
        var properties = propertyNames.Select(name => entityType.FindProperty(name)!).ToArray();
        var index = entityType.FindIndex(properties);
        if (index is not null)
        {
            entityType.RemoveIndex(index);
        }
    }
    private static void ConfigureChecks(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>().ToTable("Users", "dbo", t =>
            t.HasCheckConstraint(
                "CK_Users_JuryPresident",
                "[IsJuryPresident] = 0 OR ([RoleCode] = 2 AND [IsActive] = 1)"));
        modelBuilder.Entity<Play>().ToTable("Plays", "dbo", t =>
        {
            t.UseSqlOutputClause(false);
            t.HasCheckConstraint("CK_Plays_AdminRecord_StatusCode", "[RecordType] = 0 OR [StatusCode] <> 1");
            t.HasCheckConstraint("CK_Plays_AdminRecord_StatusesDisabled", "[RecordType] = 0 OR ([JuriOylamaStatus] = 0 AND [KunyeGirisStatus] = 0)");
            t.HasCheckConstraint("CK_Plays_KunyeMustRemainPublished", "[RecordType] = 1 OR [IsPublished] = 1");
            t.HasCheckConstraint("CK_Plays_SourceFormRequiresKunye", "[SourceFormId] IS NULL OR [RecordType] = 0");
        });
        modelBuilder.Entity<Ranking>().ToTable("Rankings", "dbo", t =>
        {
            t.HasCheckConstraint("CK_Rankings_ArithmeticRank", "[ArithmeticRank] IS NULL OR [ArithmeticRank] > 0");
            t.HasCheckConstraint("CK_Rankings_TrimmedRank", "[TrimmedRank] IS NULL OR [TrimmedRank] > 0");
            t.HasCheckConstraint("CK_Rankings_ConfidenceValue", "[ConfidenceValue] IS NULL OR ([ConfidenceValue] >= 1 AND [ConfidenceValue] <= 4)");
            t.HasCheckConstraint("CK_Rankings_NumberOfActiveVote", "[NumberOfActiveVote] >= 0");
        });
        modelBuilder.Entity<Season>().ToTable("Seasons", "dbo", t =>
        {
            t.HasCheckConstraint("CK_Seasons_SeasonDateRange", "[SeasonStartDate] < [SeasonEndDate]");
            t.HasCheckConstraint("CK_Seasons_KunyeRegistrationDateRange", "[KunyeRegistrationStartDate] >= [SeasonStartDate] AND [KunyeRegistrationStartDate] < [KunyeRegistrationEndDate] AND [KunyeRegistrationEndDate] <= [SeasonEndDate]");
            t.HasCheckConstraint("CK_Seasons_VotingDateRange", "[VotingStartDate] >= [SeasonStartDate] AND [VotingStartDate] < [VotingEndDate] AND [VotingEndDate] <= [SeasonEndDate]");
            t.HasCheckConstraint("CK_Seasons_NonNegativeCounts", "[PlayCount] >= 0 AND [ActivePlayCount] >= 0 AND [VoteCount] >= 0");
        });
    }
}
