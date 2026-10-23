using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Helpers;
using YKBAfife.Models.Components;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.ViewComponents;

public sealed class AddCandidateViewComponent(AfifeContext context) : ViewComponent
{
    public async Task<IViewComponentResult> InvokeAsync(
        Guid? playId = null,
        string? formAction = null,
        CancellationToken cancellationToken = default)
    {
        var playRecords = await context.Plays
            .AsNoTracking()
            .Where(play => play.IsPublished && !play.RecordType)
            .OrderBy(play => play.PlayName)
            .ThenBy(play => play.TheaterName)
            .Select(play => new
            {
                play.Id,
                Text = play.PlayName + " / " + play.TheaterName,
                PreviousProductionVersion = play.SourceForm != null && play.SourceForm.PreviousProductionVersion
            })
            .ToListAsync(cancellationToken);
        var previousProductionVersionPlayIds = playRecords
            .Where(play => play.PreviousProductionVersion)
            .Select(play => play.Id)
            .ToHashSet();
        var selectedPreviousProductionVersion = playId.HasValue &&
            previousProductionVersionPlayIds.Contains(playId.Value);
        var plays = playRecords.Select(play => new SelectListItem
        {
            Value = play.Id.ToString(),
            Text = play.Text,
            Selected = playId.HasValue && play.Id == playId.Value
        }).ToArray();

        var categoryRecords = await context.AwardCategories
            .AsNoTracking()
            .Where(category => category.IsPublished &&
                               category.CategoryCode != CandidateCategoryPolicy.BestPlayCategoryCode &&
                               category.CategoryCode != CandidateCategoryPolicy.BestDirectorCategoryCode)
            .OrderBy(category => category.CategoryCode)
            .Select(category => new AddCandidateCategoryOptionViewModel
            {
                CategoryCode = category.CategoryCode,
                CategoryName = category.CategoryName,
                MultiCandidate = category.MultiCandidate
            })
            .ToListAsync(cancellationToken);
        var categories = categoryRecords.Where(category => CandidateCategoryPolicy.IsAllowedForProductionVersion(
            category.CategoryCode, selectedPreviousProductionVersion)).ToArray();

        var replacementRows = playId.HasValue
            ? await context.PlayAwardCategories
                .AsNoTracking()
                .WhereAllowedForProductionVersion()
                .Where(candidate =>
                    candidate.PlayId == playId.Value &&
                    candidate.IsPublished &&
                    candidate.IsCurrent &&
                    candidate.AwardCategoryCode != CandidateCategoryPolicy.BestPlayCategoryCode &&
                    candidate.AwardCategoryCode != CandidateCategoryPolicy.BestDirectorCategoryCode)
                .OrderBy(candidate => candidate.Candidate)
                .Select(candidate => new
                {
                    candidate.Id,
                    CategoryCode = candidate.AwardCategoryCode,
                    CandidateName = candidate.Candidate,
                    candidate.Role,
                    candidate.RoleCode
                })
                .ToListAsync(cancellationToken)
            : [];

        var replacementCandidates = replacementRows
            .Select(candidate => new AddCandidateReplacementOptionViewModel
            {
                Id = candidate.Id,
                CategoryCode = candidate.CategoryCode,
                CandidateName = candidate.CandidateName,
                Role = candidate.Role,
                RoleCode = candidate.RoleCode,
                DisplayName = string.IsNullOrWhiteSpace(candidate.Role)
                    ? candidate.CandidateName
                    : $"{candidate.CandidateName} / {candidate.Role}"
            })
            .ToArray();

        return View(new AddCandidateViewModel
        {
            Input = new AddCandidateInputModel { PlayId = playId },
            Plays = plays,
            AwardCategories = categories,
            ReplacementCandidates = replacementCandidates,
            PreviousProductionVersionPlayIds = previousProductionVersionPlayIds,
            LockPlay = playId.HasValue,
            FormAction = formAction ?? string.Empty
        });
    }
}
