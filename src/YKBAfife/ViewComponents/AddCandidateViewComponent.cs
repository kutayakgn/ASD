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
        var plays = await context.Plays
            .AsNoTracking()
            .Where(play => play.IsPublished && !play.RecordType)
            .OrderBy(play => play.PlayName)
            .ThenBy(play => play.TheaterName)
            .Select(play => new SelectListItem
            {
                Value = play.Id.ToString(),
                Text = play.PlayName + " / " + play.TheaterName,
                Selected = playId.HasValue && play.Id == playId.Value
            })
            .ToListAsync(cancellationToken);

        var categories = await context.AwardCategories
            .AsNoTracking()
            .Where(category => category.IsPublished &&
                               category.CategoryCode != CandidateCategoryPolicy.BestPlayCategoryCode &&
                               category.CategoryCode != CandidateCategoryPolicy.BestDirectorCategoryCode)
            .OrderBy(category => category.CategoryName)
            .Select(category => new AddCandidateCategoryOptionViewModel
            {
                CategoryCode = category.CategoryCode,
                CategoryName = category.CategoryName,
                MultiCandidate = category.MultiCandidate
            })
            .ToListAsync(cancellationToken);

        var replacementRows = playId.HasValue
            ? await context.PlayAwardCategories
                .AsNoTracking()
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
            LockPlay = playId.HasValue,
            FormAction = formAction ?? string.Empty
        });
    }
}
