using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using YKBAfife.Helpers;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data.Configurations;

// One configuration per entity: columns, keys, indexes, relationships and checks
// are kept together. Edit the relevant class, then create an EF migration.

internal sealed class AdditionalVotingConfiguration : IEntityTypeConfiguration<AdditionalVoting>
{
    public void Configure(EntityTypeBuilder<AdditionalVoting> entity)
    {
        entity.ToTable("AdditionalVotings", "dbo", table =>
            table.HasCheckConstraint("CK_AdditionalVotings_DateRange", "[StartDate] < [EndDate]"));
        entity.HasOne<User>()
            .WithMany()
            .HasForeignKey("CreatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotings_Users_CreatedBy");
        entity.HasOne<User>()
            .WithMany()
            .HasForeignKey("UpdatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotings_Users_UpdatedBy");
        entity.Property("Id")
            .HasDefaultValueSql("newsequentialid()");
        entity.Property(x => x.CreatedAt)
            .HasDefaultValueSql("sysdatetime()");
        entity.Property(x => x.AppliesToAllJuries)
            .HasDefaultValue(false);
        entity.Property(x => x.AppliesToAllPlays)
            .HasDefaultValue(false);
        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);
    }
}

internal sealed class AdditionalVotingJuryConfiguration : IEntityTypeConfiguration<AdditionalVotingJury>
{
    public void Configure(EntityTypeBuilder<AdditionalVotingJury> entity)
    {
        entity.ToTable("AdditionalVotingJuries", "dbo");
        entity.HasIndex(x => new { x.AdditionalVotingId, x.JuryId })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_AdditionalVotingJuries_Published");
        entity.HasOne(x => x.Jury)
            .WithMany()
            .HasForeignKey(x => x.JuryId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingJuries_Users_Jury");
        entity.HasOne(x => x.AdditionalVoting)
            .WithMany(x => x.EligibleJuries)
            .HasForeignKey(x => x.AdditionalVotingId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingJuries_AdditionalVotings");
        entity.HasOne<User>()
            .WithMany()
            .HasForeignKey("CreatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingJuries_Users_CreatedBy");
        entity.HasOne<User>()
            .WithMany()
            .HasForeignKey("UpdatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingJuries_Users_UpdatedBy");
        entity.Property("Id")
            .HasDefaultValueSql("newsequentialid()");
        entity.Property(x => x.CreatedAt)
            .HasDefaultValueSql("sysdatetime()");
        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);
    }
}

internal sealed class AdditionalVotingPlayConfiguration : IEntityTypeConfiguration<AdditionalVotingPlay>
{
    public void Configure(EntityTypeBuilder<AdditionalVotingPlay> entity)
    {
        entity.ToTable("AdditionalVotingPlays", "dbo");
        entity.HasIndex(x => new { x.AdditionalVotingId, x.PlayId })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_AdditionalVotingPlays_Published");
        entity.HasOne(x => x.Play)
            .WithMany()
            .HasForeignKey(x => x.PlayId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingPlays_Plays");
        entity.HasOne(x => x.AdditionalVoting)
            .WithMany(x => x.EligiblePlays)
            .HasForeignKey(x => x.AdditionalVotingId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingPlays_AdditionalVotings");
        entity.HasOne<User>()
            .WithMany()
            .HasForeignKey("CreatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingPlays_Users_CreatedBy");
        entity.HasOne<User>()
            .WithMany()
            .HasForeignKey("UpdatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingPlays_Users_UpdatedBy");
        entity.Property("Id")
            .HasDefaultValueSql("newsequentialid()");
        entity.Property(x => x.CreatedAt)
            .HasDefaultValueSql("sysdatetime()");
        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);
    }
}

internal sealed class AdditionalVotingUsageConfiguration : IEntityTypeConfiguration<AdditionalVotingUsage>
{
    public void Configure(EntityTypeBuilder<AdditionalVotingUsage> entity)
    {
        entity.ToTable("AdditionalVotingUsages", "dbo", table =>
            table.HasCheckConstraint("CK_AdditionalVotingUsages_UsageType", "[UsageType] IN (0, 1)"));
        entity.HasIndex(x => new { x.AdditionalVotingId, x.JuryId, x.PlayId })
            .IsUnique(false)
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("IX_AdditionalVotingUsages_Jury_Play");
        entity.HasOne(x => x.Jury)
            .WithMany()
            .HasForeignKey(x => x.JuryId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingUsages_Users_Jury");
        entity.HasOne(x => x.Play)
            .WithMany()
            .HasForeignKey(x => x.PlayId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingUsages_Plays");
        entity.HasOne(x => x.AdditionalVoting)
            .WithMany(x => x.Usages)
            .HasForeignKey(x => x.AdditionalVotingId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingUsages_AdditionalVotings");
        entity.HasOne<User>()
            .WithMany()
            .HasForeignKey("CreatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingUsages_Users_CreatedBy");
        entity.HasOne<User>()
            .WithMany()
            .HasForeignKey("UpdatedBy")
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_AdditionalVotingUsages_Users_UpdatedBy");
        entity.Property("Id")
            .HasDefaultValueSql("newsequentialid()");
        entity.Property(x => x.CreatedAt)
            .HasDefaultValueSql("sysdatetime()");
        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);
        entity.Property(x => x.UsedAt)
            .HasDefaultValueSql("sysdatetime()");
        entity.HasIndex(x => new { x.AdditionalVotingId, x.UsageType, x.JuryId })
            .HasDatabaseName("IX_AdditionalVotingUsages_Lookup")
            .HasFilter("[IsPublished] = 1");
    }
}

internal sealed class AdminLogConfiguration : IEntityTypeConfiguration<AdminLog>
{
    public void Configure(EntityTypeBuilder<AdminLog> entity)
    {
        entity.ToTable("AdminLogs", "dbo");
        entity.Property(x => x.Username)
            .HasMaxLength(100);
        entity.Property(x => x.OperationName)
            .HasMaxLength(256);
        entity.Property(x => x.OperationType)
            .HasMaxLength(30);
        entity.Property(x => x.SchemaName)
            .HasMaxLength(128);
        entity.Property(x => x.TableName)
            .HasMaxLength(128);
        entity.Property(x => x.IpAddress)
            .HasMaxLength(64);
        entity.Property(x => x.UserAgent)
            .HasMaxLength(1000);
        entity.Property(x => x.Application)
            .HasMaxLength(100)
            .HasDefaultValue("AfifeAdmin");
        entity.Property(x => x.HttpMethod)
            .HasMaxLength(16);
        entity.Property(x => x.RequestPath)
            .HasMaxLength(2048);
        entity.Property(x => x.ControllerName)
            .HasMaxLength(128);
        entity.Property(x => x.ActionName)
            .HasMaxLength(128);
        entity.Property(x => x.Source)
            .HasMaxLength(50);
        entity.Property(x => x.FailureReason)
            .HasMaxLength(2000);
        entity.HasIndex(x => new { x.UserId, x.OccurredAt })
            .IsDescending(false, true)
            .IncludeProperties(x => new { x.OperationType, x.TableName, x.IsSuccessful, x.IsPublished })
            .HasDatabaseName("IX_AdminLogs_UserId_OccurredAt");
        entity.HasIndex(x => new { x.TableName, x.OccurredAt })
            .IsDescending(false, true)
            .IncludeProperties(x => new { x.OperationType, x.UserId, x.IsPublished })
            .HasDatabaseName("IX_AdminLogs_TableName_OccurredAt");
        entity.HasIndex(x => x.CorrelationId)
            .HasDatabaseName("IX_AdminLogs_CorrelationId1");
        entity.Property(x => x.AffectedRowCount)
            .HasDefaultValue(0);
        entity.Property(x => x.IsSuccessful)
            .HasDefaultValue(true);
        entity.HasIndex(x => new { x.CorrelationId, x.OccurredAt })
            .HasDatabaseName("IX_AdminLogs_CorrelationId");
        entity.HasIndex(x => new { x.OccurredAt, x.OperationType, x.SchemaName, x.TableName, x.ActionName })
            .IsDescending(true, false, false, false, false)
            .IncludeProperties(x => new { x.CorrelationId, x.Username, x.IsPublished })
            .HasDatabaseName("IX_AdminLogs_FilterConsole");
    }
}

internal sealed class AnnouncementConfiguration : IEntityTypeConfiguration<Announcement>
{
    public void Configure(EntityTypeBuilder<Announcement> entity)
    {
        entity.ToTable("Announcements", "dbo");
        entity.HasOne(x => x.ImageAsset)
            .WithMany(x => x.AnnouncementImages)
            .HasForeignKey(x => x.ImageId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Announcements_Images_ImageId");
        entity.HasOne(x => x.BackgroundImageAsset)
            .WithMany(x => x.AnnouncementBackgroundImages)
            .HasForeignKey(x => x.BackgroundImageId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Announcements_Images_BackgroundImageId");
        entity.Property(x => x.Text)
            .HasMaxLength(255);
        entity.Property(x => x.ButtonText)
            .HasMaxLength(255);
        entity.Property(x => x.BackgroundColor)
            .HasMaxLength(50);
        entity.HasIndex(x => x.BackgroundImageId)
            .HasDatabaseName("IX_Announcements_BackgroundImageId");
        entity.HasIndex(x => x.ImageId)
            .HasDatabaseName("IX_Announcements_ImageId");
    }
}

internal sealed class AwardCategoryConfiguration : IEntityTypeConfiguration<AwardCategory>
{
    public void Configure(EntityTypeBuilder<AwardCategory> entity)
    {
        entity.ToTable("AwardCategories", "dbo");
        entity.HasAlternateKey(x => x.CategoryCode)
            .HasName("UQ_AwardCategories_CategoryCode");
        entity.Property(x => x.CategoryName)
            .HasMaxLength(255);
        entity.Property(x => x.MultiCandidate)
            .HasDefaultValue(false);
        entity.Property(x => x.HasRoleAndPhoto)
            .HasDefaultValue(false);
    }
}

internal sealed class BlacklistConfiguration : IEntityTypeConfiguration<Blacklist>
{
    public void Configure(EntityTypeBuilder<Blacklist> entity)
    {
        entity.ToTable("Blacklist", "dbo", table => table.UseSqlOutputClause(false));
        entity.HasIndex(x => new { x.JuryId, x.PlayId })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_Blacklist_JuryId_PlayId_Published");
        entity.HasOne(x => x.Jury)
            .WithMany()
            .HasForeignKey(x => x.JuryId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Blacklist_Users_JuryId");
        entity.HasOne(x => x.Play)
            .WithMany()
            .HasForeignKey(x => x.PlayId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Blacklist_Plays_PlayId");
        entity.HasOne(x => x.Creator)
            .WithMany()
            .HasForeignKey(x => x.CreatedBy)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Blacklist_Users_CreatedBy");
        entity.Property(x => x.CreatedOn)
            .HasColumnType("datetime2(0)")
            .HasDefaultValueSql("sysutcdatetime()");
        entity.Property(x => x.Id)
            .HasDefaultValueSql("newid()");
        entity.HasIndex(x => x.CreatedOn)
            .IsDescending()
            .HasDatabaseName("IX_Blacklist_CreatedOn");
        entity.HasIndex(x => new { x.PlayId, x.IsPublished })
            .HasDatabaseName("IX_Blacklist_PlayId_IsPublished");
    }
}

internal sealed class ConfigConfiguration : IEntityTypeConfiguration<Config>
{
    public void Configure(EntityTypeBuilder<Config> entity)
    {
        entity.ToTable("Configs", "dbo", table =>
        table.HasCheckConstraint("CK_Configs_JuryHomePageTableValue", JuryHomePageTableSettings.ValueCheck));
        entity.Property(x => x.ConfigName)
            .HasMaxLength(255);
        entity.Property(x => x.ConfigValue)
            .HasMaxLength(255);
        entity.HasIndex(x => x.ConfigName)
            .IsUnique()
            .HasFilter(JuryHomePageTableSettings.NameFilter)
            .HasDatabaseName("UX_Configs_JuryHomePageTableName");
    }
}

internal sealed class FormConfiguration : IEntityTypeConfiguration<Form>
{
    public void Configure(EntityTypeBuilder<Form> entity)
    {
        entity.ToTable("Form", "dbo");
        entity.HasIndex(x => x.CreatedDate)
            .IncludeProperties(x => x.SeasonId)
            .HasDatabaseName("IX_Form_SeasonAssignment_Date");
        entity.HasIndex(x => x.SeasonId)
            .HasDatabaseName("IX_Form_SeasonAssignment_Season");
        entity.HasIndex(x => x.ApplicationNumber)
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_Form_ApplicationNumber_Published");
        entity.HasOne(x => x.Season)
            .WithMany()
            .HasForeignKey(x => x.SeasonId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Form_Seasons");
        entity.Property(x => x.ApplicationNumber)
            .HasMaxLength(6);
        entity.Property(x => x.CreatedDate)
            .HasColumnType("datetime");
        entity.Property(x => x.UpdatedDate)
            .HasColumnType("datetime");
        entity.Property(x => x.RepertoireName)
            .HasMaxLength(500);
        entity.Property(x => x.TheatreName)
            .HasMaxLength(500);
        entity.Property(x => x.ApplicantName)
            .HasMaxLength(100);
        entity.Property(x => x.ApplicantRole)
            .HasMaxLength(200);
        entity.Property(x => x.Phone)
            .HasMaxLength(20);
        entity.Property(x => x.Email)
            .HasMaxLength(150);
        entity.Property(x => x.Director)
            .HasMaxLength(100);
        entity.Property(x => x.ContactName)
            .HasMaxLength(100);
        entity.Property(x => x.ContactPhone)
            .HasMaxLength(20);
        entity.Property(x => x.StageDesign)
            .HasMaxLength(1000);
        entity.Property(x => x.ClothesDesign)
            .HasMaxLength(1000);
        entity.Property(x => x.LightDesign)
            .HasMaxLength(1000);
        entity.Property(x => x.StageMusic)
            .HasMaxLength(1000);
        entity.Property(x => x.Choreography)
            .HasMaxLength(1000);
        entity.Property(x => x.Id)
            .HasDefaultValueSql("newsequentialid()");
        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);
        entity.HasIndex(x => x.LegacyId)
            .IsUnique()
            .HasFilter("[LegacyId] IS NOT NULL")
            .HasDatabaseName("UX_Form_LegacyId");
    }
}

internal sealed class FormLifecycleStateConfiguration : IEntityTypeConfiguration<FormLifecycleState>
{
    public void Configure(EntityTypeBuilder<FormLifecycleState> entity)
    {
        entity.ToTable("FormLifecycleStates", "dbo");
        entity.Property(x => x.EntityName)
            .HasMaxLength(64);
        entity.HasIndex(x => new { x.FormId, x.EntityName, x.EntityId })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_FormLifecycleStates_OpenEntity");
        entity.HasOne(x => x.Form)
            .WithMany()
            .HasForeignKey(x => x.FormId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_FormLifecycleStates_Form");
        entity.Property("Id")
            .HasDefaultValueSql("newsequentialid()");
    }
}

internal sealed class GroupConfiguration : IEntityTypeConfiguration<Group>
{
    public void Configure(EntityTypeBuilder<Group> entity)
    {
        entity.ToTable("Group", "dbo");
        entity.HasAlternateKey(x => x.Code)
            .HasName("UQ_Group_Code");
        entity.Property(x => x.GroupName)
            .HasMaxLength(100);
    }
}

internal sealed class ImageConfiguration : IEntityTypeConfiguration<Image>
{
    public void Configure(EntityTypeBuilder<Image> entity)
    {
        entity.ToTable("Images", "dbo");
        entity.Property(x => x.FileName)
            .HasMaxLength(255);
        entity.Property(x => x.ContentType)
            .HasMaxLength(100);
    }
}

internal sealed class JuryAssignedPlayConfiguration : IEntityTypeConfiguration<JuryAssignedPlay>
{
    public void Configure(EntityTypeBuilder<JuryAssignedPlay> entity)
    {
        entity.ToTable("JuryAssignedPlays", "dbo");
        entity.HasIndex(x => new { x.PlayId, x.JuryId })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_JuryAssignedPlays_PlayId_JuryId");
        entity.HasOne(x => x.Jury)
            .WithMany(x => x.AssignedPlays)
            .HasForeignKey(x => x.JuryId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryAssignedPlays_Users");
        entity.HasIndex(x => x.JuryId)
            .HasDatabaseName("IX_JuryAssignedPlays_JuryId");
        entity.HasIndex(x => x.PlayId)
            .HasDatabaseName("IX_JuryAssignedPlays_PlayId");
    }
}

internal sealed class JuryGameTicketFeeConfiguration : IEntityTypeConfiguration<JuryGameTicketFee>
{
    public void Configure(EntityTypeBuilder<JuryGameTicketFee> entity)
    {
        entity.ToTable("JuryGameTicketFees", "dbo");
        entity.Property(x => x.TicketFee)
            .HasPrecision(10, 2);
        entity.HasIndex(x => new { x.UserId, x.PlayId })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_JuryGameTicketFees_UserId_PlayId");
        entity.HasOne(x => x.User)
            .WithMany(x => x.JuryGameTicketFees)
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryGameTicketFees_Users");
        entity.HasOne(x => x.Play)
            .WithMany(x => x.JuryGameTicketFees)
            .HasForeignKey(x => x.PlayId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryGameTicketFees_Plays");
        entity.HasIndex(x => x.PlayId)
            .HasDatabaseName("IX_JuryGameTicketFees_PlayId");
        entity.HasIndex(x => x.UserId)
            .HasDatabaseName("IX_JuryGameTicketFees_UserId");
    }
}

internal sealed class JuryLogConfiguration : IEntityTypeConfiguration<JuryLog>
{
    public void Configure(EntityTypeBuilder<JuryLog> entity)
    {
        entity.ToTable("JuryLogs", "dbo");
        entity.Property(x => x.Id)
            .HasDefaultValueSql("newsequentialid()");
        entity.Property(x => x.CorrelationId)
            .HasDefaultValueSql("newid()");
        entity.Property(x => x.JuryUsername)
            .HasMaxLength(100);
        entity.Property(x => x.PlayName)
            .HasMaxLength(250);
        entity.Property(x => x.OperationName)
            .HasMaxLength(256);
        entity.Property(x => x.OperationType)
            .HasMaxLength(50);
        entity.Property(x => x.SubmittedTicketFee)
            .HasPrecision(10, 2);
        entity.Property(x => x.OldTicketFee)
            .HasPrecision(10, 2);
        entity.Property(x => x.NewTicketFee)
            .HasPrecision(10, 2);
        entity.Property(x => x.IpAddress)
            .HasMaxLength(64);
        entity.Property(x => x.UserAgent)
            .HasMaxLength(1000);
        entity.Property(x => x.HttpMethod)
            .HasMaxLength(16);
        entity.Property(x => x.RequestPath)
            .HasMaxLength(2048);
        entity.Property(x => x.ControllerName)
            .HasMaxLength(128);
        entity.Property(x => x.ActionName)
            .HasMaxLength(128);
        entity.Property(x => x.Application)
            .HasMaxLength(100)
            .HasDefaultValue("AfifeJury");
        entity.Property(x => x.Source)
            .HasMaxLength(50)
            .HasDefaultValue("JuryPanel");
        entity.Property(x => x.ResultCode)
            .HasMaxLength(100);
        entity.Property(x => x.FailureReason)
            .HasMaxLength(2000);
        entity.Property(x => x.IsAdditionalVoting)
            .HasDefaultValue(false);
        entity.Property(x => x.AffectedVoteCount)
            .HasDefaultValue(0);
        entity.Property(x => x.OccurredAt)
            .HasColumnType("datetime2(7)")
            .HasDefaultValueSql("DATEADD(HOUR, 3, SYSUTCDATETIME())");
        entity.Property(x => x.IsSuccessful)
            .HasDefaultValue(false);
        entity.Property(x => x.IsPublished)
            .HasDefaultValue(true);
        entity.HasIndex(x => x.CorrelationId)
            .HasDatabaseName("IX_JuryLogs_CorrelationId");
        entity.HasIndex(x => new { x.JuryId, x.OccurredAt })
            .HasDatabaseName("IX_JuryLogs_JuryId_OccurredAt");
        entity.HasIndex(x => new { x.PlayId, x.OccurredAt })
            .HasDatabaseName("IX_JuryLogs_PlayId_OccurredAt");
        entity.HasIndex(x => new { x.OperationType, x.IsSuccessful, x.OccurredAt })
            .HasDatabaseName("IX_JuryLogs_OperationType_IsSuccessful_OccurredAt");
        entity.HasOne(x => x.Jury)
            .WithMany()
            .HasForeignKey(x => x.JuryId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryLogs_Users_JuryId");
        entity.HasOne(x => x.Play)
            .WithMany()
            .HasForeignKey(x => x.PlayId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryLogs_Plays_PlayId");
        entity.HasOne(x => x.AdditionalVoting)
            .WithMany()
            .HasForeignKey(x => x.AdditionalVotingId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryLogs_AdditionalVotings_AdditionalVotingId");
    }
}

internal sealed class JuryPasswordResetTokenConfiguration : IEntityTypeConfiguration<JuryPasswordResetToken>
{
    public void Configure(EntityTypeBuilder<JuryPasswordResetToken> entity)
    {
        entity.ToTable("JuryPasswordResetTokens", "dbo", table =>
        {
            table.HasCheckConstraint(
                "CK_JuryPasswordResetTokens_Expiry",
                "[ExpiresAtUtc] > [CreatedAtUtc] AND [ExpiresAtUtc] <= DATEADD(MINUTE, 5, [CreatedAtUtc])");
            table.HasCheckConstraint(
                "CK_JuryPasswordResetTokens_UsedAt",
                "[UsedAtUtc] IS NULL OR [UsedAtUtc] >= [CreatedAtUtc]");
        });
        entity.Property(x => x.Id)
            .HasDefaultValueSql("newsequentialid()");
        entity.Property(x => x.TokenHash)
            .HasColumnType("binary(32)");
        entity.Property(x => x.CreatedAtUtc)
            .HasColumnType("datetime2(7)");
        entity.Property(x => x.ExpiresAtUtc)
            .HasColumnType("datetime2(7)");
        entity.Property(x => x.UsedAtUtc)
            .HasColumnType("datetime2(7)");
        entity.Property(x => x.RowVersion)
            .IsRowVersion();
        entity.HasIndex(x => x.TokenHash)
            .IsUnique()
            .HasDatabaseName("UX_JuryPasswordResetTokens_TokenHash");
        entity.HasIndex(x => new { x.UserId, x.CreatedAtUtc })
            .IsDescending(false, true)
            .HasDatabaseName("IX_JuryPasswordResetTokens_UserId_CreatedAtUtc");
        entity.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryPasswordResetTokens_Users_UserId");
    }
}

internal sealed class JuryVoteConfiguration : IEntityTypeConfiguration<JuryVote>
{
    public void Configure(EntityTypeBuilder<JuryVote> entity)
    {
        entity.ToTable("JuryVotes", "dbo", table =>
        {
            table.UseSqlOutputClause(false);
            table.HasCheckConstraint("CK_JuryVotes_Score", "[Score] >= 1 AND [Score] <= 10");
        });
        entity.HasIndex(x => new { x.PlayAwardCategoryId, x.JuryId })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_JuryVotes_JuryId_PlayAwardCategoryId");
        entity.HasOne(x => x.Jury)
            .WithMany(x => x.JuryVotes)
            .HasForeignKey(x => x.JuryId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryVotes_Users");
        entity.HasOne(x => x.PlayAwardCategory)
            .WithMany(x => x.JuryVotes)
            .HasForeignKey(x => x.PlayAwardCategoryId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryVotes_PlayAwardCategories");
        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);
        entity.HasIndex(x => x.JuryId)
            .HasDatabaseName("IX_JuryVotes_JuryId");
        entity.HasIndex(x => x.PlayAwardCategoryId)
            .HasDatabaseName("IX_JuryVotes_PlayAwardCategoryId");
        entity.HasIndex(x => new { x.PlayAwardCategoryId, x.IsPublished, x.IsActive })
            .IncludeProperties(x => new { x.Score, x.Id })
            .HasDatabaseName("IX_JuryVotes_RankingProjection");
        entity.HasIndex(x => x.CreatedAt)
            .IncludeProperties(x => new { x.IsPublished, x.IsActive })
            .HasFilter("[CreatedAt] IS NOT NULL")
            .HasDatabaseName("IX_JuryVotes_SeasonStatistics");
    }
}

internal sealed class LogConfiguration : IEntityTypeConfiguration<Log>
{
    public void Configure(EntityTypeBuilder<Log> entity)
    {
        entity.ToTable("Log", "dbo");
        entity.Property(x => x.Title)
            .HasMaxLength(200);
        entity.Property(x => x.Source)
            .HasMaxLength(50);
        entity.Property(x => x.EventType)
            .HasMaxLength(50);
        entity.Property(x => x.CreatedDate)
            .HasColumnType("datetime");
    }
}

internal sealed class ManagerConfiguration : IEntityTypeConfiguration<Manager>
{
    public void Configure(EntityTypeBuilder<Manager> entity)
    {
        entity.ToTable("Manager", "dbo");
        entity.Property(x => x.FullName)
            .HasColumnType("nchar(100)");
        entity.Property(x => x.Email)
            .HasMaxLength(150);
        entity.Property(x => x.Password)
            .HasMaxLength(100);
        entity.Property(x => x.CreatedDate)
            .HasColumnType("datetime");
        entity.Property(x => x.UpdatedDate)
            .HasColumnType("datetime");
    }
}

internal sealed class PlayConfiguration : IEntityTypeConfiguration<Play>
{
    public void Configure(EntityTypeBuilder<Play> entity)
    {
        entity.ToTable("Plays", "dbo", t =>
        {
            t.UseSqlOutputClause(false);
            t.HasCheckConstraint("CK_Plays_AdminRecord_StatusCode", "[RecordType] = 0 OR [StatusCode] <> 1");
            t.HasCheckConstraint("CK_Plays_AdminRecord_KunyeStatusDisabled", "[RecordType] = 0 OR [KunyeGirisStatus] = 0");
            t.HasCheckConstraint("CK_Plays_KunyeMustRemainPublished", "[RecordType] = 1 OR [IsPublished] = 1");
            t.HasCheckConstraint("CK_Plays_SourceFormRequiresKunye", "[SourceFormId] IS NULL OR [RecordType] = 0");
        });
        entity.Property(x => x.RecordType)
            .HasDefaultValue(false);
        entity.Property(x => x.RecordType)
            .Metadata.SetAfterSaveBehavior(PropertySaveBehavior.Throw);
        entity.HasOne(x => x.SourceForm)
            .WithOne(x => x.Play)
            .HasForeignKey<Play>(x => x.SourceFormId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Plays_Form_SourceFormId");
        entity.HasOne(x => x.Status)
            .WithMany(x => x.Plays)
            .HasForeignKey(x => x.StatusCode)
            .HasPrincipalKey(x => x.StatusCode)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Plays_PlayStatuses");
        entity.HasMany(x => x.JuryAssignments)
            .WithOne(x => x.Play)
            .HasForeignKey(x => x.PlayId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_JuryAssignedPlays_Plays");
        entity.Property(x => x.PlayName)
            .HasMaxLength(500);
        entity.Property(x => x.Slug)
            .HasMaxLength(255)
            .IsUnicode(false);
        entity.Property(x => x.TheaterName)
            .HasMaxLength(500);
        entity.Property(x => x.Phone)
            .HasMaxLength(255);
        entity.Property(x => x.ContactPersonName)
            .HasMaxLength(255);
        entity.Property(x => x.ContactPersonPhone)
            .HasMaxLength(255);
        entity.Property(x => x.Address)
            .HasMaxLength(255);
        entity.Property(x => x.Email)
            .HasMaxLength(255);
        entity.Property(x => x.JuriOylamaStatus)
            .HasDefaultValue(false);
        entity.Property(x => x.KunyeGirisStatus)
            .HasDefaultValue(false);
        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);
        entity.HasIndex(x => x.CreatedAt)
            .IncludeProperties(x => new { x.IsPublished, x.StatusCode })
            .HasFilter("[CreatedAt] IS NOT NULL")
            .HasDatabaseName("IX_Plays_SeasonStatistics");
        entity.HasIndex(x => x.StatusCode)
            .HasDatabaseName("IX_Plays_StatusCode");
        entity.HasIndex(x => x.Slug)
            .HasDatabaseName("IX_Plays_Slug");
        entity.HasIndex(x => x.SourceFormId, "IX_Plays_UnlinkedFormMatch")
            .IncludeProperties(x => new { x.RecordType, x.PlayName, x.TheaterName })
            .HasFilter("[SourceFormId] IS NULL")
            .HasDatabaseName("IX_Plays_UnlinkedFormMatch");
        entity.HasIndex(x => x.SourceFormId)
            .IsUnique()
            .HasFilter("[SourceFormId] IS NOT NULL")
            .HasDatabaseName("UX_Plays_SourceFormId");
    }
}

internal sealed class PlayAwardCategoryConfiguration : IEntityTypeConfiguration<PlayAwardCategory>
{
    public void Configure(EntityTypeBuilder<PlayAwardCategory> entity)
    {
        entity.ToTable("PlayAwardCategories", "dbo", table => table.UseSqlOutputClause(false));
        entity.HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.RoleCode, x.Candidate })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_PlayAwardCategories_Play_Category_Role_Candidate");
        entity.HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.RoleCode, x.IsCurrent })
            .HasFilter("[IsCurrent] = 1 AND [IsPublished] = 1")
            .HasDatabaseName("IX_PlayAwardCategories_Current_Play_Category_Role");
        entity.HasIndex(x => new { x.PlayId, x.AwardCategoryCode, x.SourceFormCandidateOrder })
            .HasFilter("[SourceFormCandidateOrder] IS NOT NULL AND [IsCurrent] = 1")
            .HasDatabaseName("IX_PlayAwardCategories_FormSourceSlot");
        entity.HasOne(x => x.PhotoImage)
            .WithMany(x => x.CandidatePhotos)
            .HasForeignKey(x => x.PhotoImageId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_PlayAwardCategories_Images_PhotoImageId");
        entity.HasMany(x => x.JuryVotes)
            .WithOne(x => x.PlayAwardCategory)
            .HasForeignKey(x => x.PlayAwardCategoryId)
            .OnDelete(DeleteBehavior.NoAction);
        entity.HasOne(x => x.AwardCategory)
            .WithMany(x => x.PlayAwardCategories)
            .HasForeignKey(x => x.AwardCategoryCode)
            .HasPrincipalKey(x => x.CategoryCode)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_PlayAwardCategories_AwardCategories");
        entity.HasOne(x => x.Play)
            .WithMany(x => x.PlayAwardCategories)
            .HasForeignKey(x => x.PlayId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_PlayAwardCategories_Plays");
        entity.Property(x => x.Candidate)
            .HasMaxLength(500);
        entity.Property(x => x.Role)
            .HasMaxLength(200);
        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);
        entity.HasIndex(x => x.AwardCategoryCode)
            .HasDatabaseName("IX_PlayAwardCategories_AwardCategoryCode");
        entity.HasIndex(x => x.PhotoImageId)
            .HasDatabaseName("IX_PlayAwardCategories_PhotoImageId");
        entity.HasIndex(x => x.PlayId)
            .HasDatabaseName("UX_PlayAwardCategories_DefaultPlayCategory")
            .IsUnique()
            .HasFilter("[AwardCategoryCode] = 1001 AND [RoleCode] = 0");
    }
}

internal sealed class PlayStatusConfiguration : IEntityTypeConfiguration<PlayStatus>
{
    public void Configure(EntityTypeBuilder<PlayStatus> entity)
    {
        entity.ToTable("PlayStatuses", "dbo");
        entity.HasAlternateKey(x => x.StatusCode)
            .HasName("UQ_PlayStatuses_StatusCode");
        entity.Property(x => x.StatusName)
            .HasMaxLength(100);
        entity.Property(x => x.StatusColor)
            .HasMaxLength(50);
    }
}

internal sealed class RankingConfiguration : IEntityTypeConfiguration<Ranking>
{
    public void Configure(EntityTypeBuilder<Ranking> entity)
    {
        entity.ToTable("Rankings", "dbo", t =>
        {
            t.HasCheckConstraint("CK_Rankings_ArithmeticRank", "[ArithmeticRank] IS NULL OR [ArithmeticRank] > 0");
            t.HasCheckConstraint("CK_Rankings_TrimmedRank", "[TrimmedRank] IS NULL OR [TrimmedRank] > 0");
            t.HasCheckConstraint("CK_Rankings_ConfidenceValue", "[ConfidenceValue] IS NULL OR ([ConfidenceValue] >= 1 AND [ConfidenceValue] <= 4)");
            t.HasCheckConstraint("CK_Rankings_NumberOfActiveVote", "[NumberOfActiveVote] >= 0");
        });
        entity.Property(x => x.ArithmeticMean)
            .HasColumnType("float");
        entity.Property(x => x.TrimmedMean)
            .HasColumnType("float");
        entity.Property(x => x.ArithmeticVariance)
            .HasColumnType("float");
        entity.HasIndex(x => x.PlayAwardCategoryId)
            .IsUnique()
            .HasDatabaseName("UX_Rankings_PlayAwardCategoryId");
        entity.HasIndex(x => new { x.PlayId, x.IsPublished })
            .IncludeProperties(x => new { x.PlayAwardCategoryId, x.NumberOfActiveVote, x.ArithmeticMean, x.TrimmedMean, x.ArithmeticRank, x.TrimmedRank, x.ArithmeticVariance })
            .HasDatabaseName("IX_Rankings_PlayId_IsPublished");
        entity.HasOne(x => x.Play)
            .WithMany()
            .HasForeignKey(x => x.PlayId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Rankings_Plays");
        entity.HasOne(x => x.PlayAwardCategory)
            .WithMany()
            .HasForeignKey(x => x.PlayAwardCategoryId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Rankings_PlayAwardCategories");
        entity.Property("Id")
            .HasDefaultValueSql("newsequentialid()");
        entity.Property(x => x.NumberOfActiveVote)
            .HasDefaultValue(0);
    }
}

internal sealed class RoleConfiguration : IEntityTypeConfiguration<Role>
{
    public void Configure(EntityTypeBuilder<Role> entity)
    {
        entity.ToTable("Roles", "dbo");
        entity.HasAlternateKey(x => x.RoleCode)
            .HasName("UQ_Roles_RoleCode");
        entity.Property(x => x.RoleName)
            .HasMaxLength(100);
    }
}

internal sealed class SeasonConfiguration : IEntityTypeConfiguration<Season>
{
    public void Configure(EntityTypeBuilder<Season> entity)
    {
        entity.ToTable("Seasons", "dbo", t =>
        {
            t.HasCheckConstraint("CK_Seasons_SeasonDateRange", "[SeasonStartDate] < [SeasonEndDate]");
            t.HasCheckConstraint("CK_Seasons_KunyeRegistrationDateRange", "[KunyeRegistrationStartDate] >= [SeasonStartDate] AND [KunyeRegistrationStartDate] < [KunyeRegistrationEndDate] AND [KunyeRegistrationEndDate] <= [SeasonEndDate]");
            t.HasCheckConstraint("CK_Seasons_VotingDateRange", "[VotingStartDate] >= [SeasonStartDate] AND [VotingStartDate] < [VotingEndDate] AND [VotingEndDate] <= [SeasonEndDate]");
            t.HasCheckConstraint("CK_Seasons_NonNegativeCounts", "[PlayCount] >= 0 AND [ActivePlayCount] >= 0 AND [VoteCount] >= 0");
        });
        entity.HasIndex(season => new { season.SeasonStartDate, season.SeasonEndDate })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_Seasons_PublishedDateRange");
        entity.Property("Id")
            .HasDefaultValueSql("newsequentialid()");
        entity.Property(x => x.PlayCount)
            .HasDefaultValue(0);
        entity.Property(x => x.ActivePlayCount)
            .HasDefaultValue(0);
        entity.Property(x => x.VoteCount)
            .HasDefaultValue(0);
    }
}

internal sealed class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> entity)
    {
        entity.ToTable("Users", "dbo", t =>
        {
            t.HasCheckConstraint(
                "CK_Users_JuryPresident",
                "[IsJuryPresident] = 0 OR ([RoleCode] = 2 AND [IsActive] = 1)");
            t.HasCheckConstraint(
                "CK_Users_Username_InstagramFormat",
                "LEN([Username]) BETWEEN 3 AND 30 AND " +
                "DATALENGTH([Username]) = LEN([Username]) * 2 AND " +
                "[Username] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Za-z0-9._]%'");
        });
        entity.HasIndex(x => new { x.RoleCode, x.Username })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_Users_RoleCode_Username_Published");
        entity.HasIndex(x => new { x.RoleCode, x.Email })
            .IsUnique()
            .HasFilter("[IsPublished] = 1")
            .HasDatabaseName("UX_Users_RoleCode_Email_Published");
        entity.HasIndex(x => x.IsJuryPresident)
            .IsUnique()
            .HasFilter("[IsPublished] = 1 AND [IsJuryPresident] = 1")
            .HasDatabaseName("UX_Users_OnePublishedJuryPresident");
        entity.HasOne(x => x.PhotoImage)
            .WithMany(x => x.UserPhotos)
            .HasForeignKey(x => x.PhotoImageId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Users_Images_PhotoImageId");
        entity.HasOne(x => x.Role)
            .WithMany(x => x.Users)
            .HasForeignKey(x => x.RoleCode)
            .HasPrincipalKey(x => x.RoleCode)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Users_Roles");
        entity.HasOne(x => x.Group)
            .WithMany(x => x.Users)
            .HasForeignKey(x => x.GroupCode)
            .HasPrincipalKey(x => x.Code)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_Users_Group");
        entity.Property(x => x.FirstName)
            .HasMaxLength(100);
        entity.Property(x => x.LastName)
            .HasMaxLength(100);
        entity.Property(x => x.Phone)
            .HasMaxLength(30);
        entity.Property(x => x.Username)
            .HasMaxLength(100);
        entity.Property(x => x.PasswordHash)
            .HasMaxLength(500);
        entity.Property(x => x.Email)
            .HasMaxLength(255);
        entity.Property(x => x.IsActive)
            .HasDefaultValue(true);
        entity.Property(x => x.IsJuryPresident)
            .HasDefaultValue(false);
        entity.HasIndex(x => x.GroupCode)
            .HasDatabaseName("IX_Users_GroupCode");
        entity.HasIndex(x => x.PhotoImageId)
            .HasDatabaseName("IX_Users_PhotoImageId");
        entity.HasIndex(x => x.RoleCode)
            .HasDatabaseName("IX_Users_RoleCode");
    }
}

internal sealed class UserLogConfiguration : IEntityTypeConfiguration<UserLog>
{
    public void Configure(EntityTypeBuilder<UserLog> entity)
    {
        entity.ToTable("UsersLog", "dbo");
        entity.Property(x => x.Username)
            .HasMaxLength(100)
            .HasDefaultValue(string.Empty);
        entity.Property(x => x.EventType)
            .HasMaxLength(50);
        entity.Property(x => x.IpAddress)
            .HasMaxLength(64);
        entity.Property(x => x.UserAgent)
            .HasMaxLength(1000);
        entity.Property(x => x.Application)
            .HasMaxLength(100)
            .HasDefaultValue("AfifeAdmin");
        entity.Property(x => x.Details)
            .HasMaxLength(2000);
        entity.Property(x => x.FailureReason)
            .HasMaxLength(500);
        entity.HasIndex(x => new { x.UserId, x.EventType, x.OccurredAt })
            .IsDescending(false, false, true)
            .IncludeProperties(x => new { x.IsSuccessful, x.IsPublished })
            .HasDatabaseName("IX_UsersLog_UserId_EventType_OccurredAt");
        entity.HasIndex(x => new { x.Username, x.OccurredAt })
            .IsDescending(false, true)
            .HasDatabaseName("IX_UsersLog_Username_OccurredAt");
        entity.HasOne<User>()
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.NoAction)
            .HasConstraintName("FK_UsersLog_Users_UserId");
        entity.HasIndex(x => new { x.CorrelationId, x.OccurredAt })
            .IsDescending(false, true)
            .HasDatabaseName("IX_UsersLog_CorrelationId");
        entity.HasIndex(x => new { x.OccurredAt, x.Application })
            .IsDescending(true, false)
            .IncludeProperties(x => new { x.UserId, x.ActorUserId, x.Username, x.CorrelationId, x.IsPublished })
            .HasDatabaseName("IX_UsersLog_FilterConsole");
    }
}

internal sealed class SharedAdminDataProtectionKeyConfiguration : IEntityTypeConfiguration<SharedAdminDataProtectionKey>
{
    public void Configure(EntityTypeBuilder<SharedAdminDataProtectionKey> entity)
    {
        entity.ToTable("SharedAdminDataProtectionKeys", "dbo", table =>
        {
            table.UseSqlOutputClause(false);
            table.HasCheckConstraint("CK_SharedAdminDataProtectionKeys_Published", "[IsPublished] = 1");
        });
        entity.HasKey(key => key.Id);
        entity.Property(key => key.Id).HasDefaultValueSql("newsequentialid()");
        entity.Property(key => key.FriendlyName).HasMaxLength(255);
        entity.Property(key => key.Xml).IsRequired();
        entity.Property(key => key.CreatedAtUtc).HasDefaultValueSql("sysutcdatetime()");
    }
}

internal static class AfifeModelConventions
{
    // Preserve the legacy physical index set; shared FK conventions would otherwise
    // create additional indexes during this organization-only refactor.
    public static void RemoveLegacyConventionIndexes(ModelBuilder modelBuilder)
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
