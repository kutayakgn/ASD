using Microsoft.EntityFrameworkCore;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data;

internal static partial class AfifeRelationalModelConfiguration
{
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
            .HasFilter("[IsCurrent] = 1 AND [IsPublished] = 1")
            .HasDatabaseName("IX_PlayAwardCategories_Current_Play_Category_Role");
        modelBuilder.Entity<PlayAwardCategory>().HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.RoleCode, x.Candidate })
            .HasDatabaseName("UX_PlayAwardCategories_Play_Category_Role_Candidate");
        modelBuilder.Entity<PlayAwardCategory>().HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.SourceFormCandidateOrder })
            .HasFilter("[SourceFormCandidateOrder] IS NOT NULL AND [IsCurrent] = 1")
            .HasDatabaseName("IX_PlayAwardCategories_FormSourceSlot");
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
}
