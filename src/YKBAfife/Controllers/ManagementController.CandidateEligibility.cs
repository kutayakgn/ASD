using Microsoft.EntityFrameworkCore;
using YKBAfife.Helpers;

namespace YKBAfife.Controllers;

public sealed partial class ManagementController
{
    private async Task<bool> IsCandidateCategoryAllowedForPlayAsync(
        Guid playId,
        int categoryCode,
        CancellationToken cancellationToken)
    {
        if (!CandidateCategoryPolicy.IsExcludedForPreviousProductionVersion(categoryCode)) return true;

        return !await context.Plays.AsNoTracking().AnyAsync(play => play.Id == playId &&
            play.SourceForm != null && play.SourceForm.PreviousProductionVersion, cancellationToken);
    }
}
