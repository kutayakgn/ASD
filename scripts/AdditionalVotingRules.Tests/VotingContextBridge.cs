using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using YKBAfife.Data;
using YKBAfife.Models.Entities;

namespace AdditionalVotingRules.Tests;

// The company kit names Form singular and stores RecordType as an int CLR
// property converted to SQL bit. The admin context uses Forms and a bool.
// This adapter only reconciles those shapes, never the business method bodies.
internal sealed class VotingContextBridge(AfifeContext context)
{
    public DatabaseFacade Database => context.Database;
    public DbSet<User> Users => context.Users;
    public DbSet<Form> Form => context.Forms;
    public DbSet<Blacklist> Blacklists => context.Blacklists;
    public DbSet<AwardCategory> AwardCategories => context.AwardCategories;
    public DbSet<PlayAwardCategory> PlayAwardCategories => context.PlayAwardCategories;
    public DbSet<JuryVote> JuryVotes => context.JuryVotes;
    public DbSet<JuryGameTicketFee> JuryGameTicketFees => context.JuryGameTicketFees;
    public DbSet<AdditionalVoting> AdditionalVotings => context.AdditionalVotings;
    public DbSet<AdditionalVotingJury> AdditionalVotingJuries => context.AdditionalVotingJuries;
    public DbSet<AdditionalVotingPlay> AdditionalVotingPlays => context.AdditionalVotingPlays;
    public DbSet<AdditionalVotingUsage> AdditionalVotingUsages => context.AdditionalVotingUsages;
    public DbSet<JuryLog> JuryLogs => context.JuryLogs;
    public IQueryable<KitPlay> Plays => context.Plays.IgnoreQueryFilters().Select(play => new KitPlay
    {
        Id = play.Id, SourceFormId = play.SourceFormId, RecordType = play.RecordType ? 1 : 0,
        StatusCode = play.StatusCode, JuriOylamaStatus = play.JuriOylamaStatus,
        PlayName = play.PlayName, TheaterName = play.TheaterName, Slug = play.Slug,
        IsPublished = play.IsPublished, IsActive = play.IsActive
    });
    public Task<int> SaveChangesAsync() => context.SaveChangesAsync();
}

internal sealed class KitPlay
{
    public Guid Id { get; init; }
    public Guid? SourceFormId { get; init; }
    public int RecordType { get; init; }
    public int StatusCode { get; init; }
    public bool JuriOylamaStatus { get; init; }
    public string PlayName { get; init; } = string.Empty;
    public string TheaterName { get; init; } = string.Empty;
    public string Slug { get; init; } = string.Empty;
    public bool IsPublished { get; init; }
    public bool IsActive { get; init; }
}
