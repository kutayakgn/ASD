using YkbAfife.Business.Service;
using YkbAfife.Domain.Model.Data.JuryVoting;

namespace YkbAfife.Business.Service.JuryVoting;

public interface IJuryVotingService : IService
{
    Task<(Guid UserId, string FullName)?> AuthenticateUserAsync(string userName, string password);
    Task<JuryVotingChangePasswordResult> ChangePasswordAsync(Guid authenticatedUserId, string oldPassword, string newPassword);
    Task SendForgotPasswordLinkAsync(string email);
    Task<bool> IsResetTokenValidAsync(string token);
    Task<JuryVotingResetPasswordResult> ResetPasswordAsync(string token, string newPassword);
    Task<JuryVotingHomeViewModel> BuildHomeViewModelAsync(Guid authenticatedUserId, string gameListButtonLink, string mostWatchedButtonLink, string leastWatchedButtonLink);
    Task<JuryVotingComplexTableViewModel> BuildPlaysTableModelAsync(Guid authenticatedUserId, string tab, string search, string sortBy, string sortDirection, int page, string actionName, bool includePlayStatusColumn = false, bool currentPlayStatusesOnly = false, bool includeAssignedPlayColumn = true, bool assignedPlaysOnly = false);
    Task<JuryVotingComplexTableViewModel> BuildGameListTableModelAsync(Guid authenticatedUserId, string tab, string search, string sortBy, string sortDirection, int page, string actionName);
    Task<JuryVotingPlayDetailViewModel> BuildPlayDetailPageModelAsync(Guid authenticatedUserId, string playSlug);
    Task<JuryVotingSaveVoteResult> SaveVoteAsync(Guid authenticatedUserId, SaveVoteRequest request);
    Task<JuryVotingComplexTableViewModel> BuildContactTableModelAsync(string tab, string search, string sortBy, string sortDirection, int page, string actionName);
}
