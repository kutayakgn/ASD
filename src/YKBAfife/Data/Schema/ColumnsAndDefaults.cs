using Microsoft.EntityFrameworkCore;
using YKBAfife.Models.Entities;

namespace YKBAfife.Data;

internal static partial class AfifeRelationalModelConfiguration
{
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
}
