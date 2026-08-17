using System.Data;
using System.Diagnostics;
using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using YkbAfife.Domain.Model.Data.JuryVoting;
using YkbAfife.Domain.Model.Entity.Form;
using YkbAfife.Domain.Model.Entity.JuryVoting;
using YkbAfife.Domain.Model.Entity.User;

namespace YkbAfife.Business.Service.JuryVoting
{
    public class JuryVotingService : IJuryVotingService
    {
        private static readonly TimeSpan ResetPasswordTokenLifetime = TimeSpan.FromHours(2);
        private readonly AfifeContext _context;
        private readonly MySettings _settings;
        private readonly ILogger<JuryVotingService> _logger;
        private readonly string _resetPasswordSecret;

        public JuryVotingService(AfifeContext context, IOptions<MySettings> options, ILogger<JuryVotingService> logger)
        {
            _context = context;
            _settings = options.Value;
            _logger = logger;
            _resetPasswordSecret = string.IsNullOrWhiteSpace(_settings.JuryVotingResetPasswordSecret)
                ? "ykb-afife-jury-voting-reset-secret"                : _settings.JuryVotingResetPasswordSecret;
        }

        public async Task<(Guid UserId, string FullName)?> AuthenticateUserAsync(string userName, string password)
        {
            var user = await _context.Users
                .AsNoTracking()
                .Where(x => x.IsPublished && x.IsActive && x.RoleCode == 2 && x.Username == userName)
                .Select(x => new                {
                    x.Id,
                    x.PasswordHash,
                    x.FirstName,
                    x.LastName
                })
                .FirstOrDefaultAsync();

            if (user is null || string.IsNullOrEmpty(user.PasswordHash) || !PasswordHashHelper.VerifyPassword(password, user.PasswordHash))
            {
                return null;
            }

            return (user.Id, $"{user.FirstName} {user.LastName}".Trim());
        }

        public async Task<JuryVotingChangePasswordResult> ChangePasswordAsync(Guid authenticatedUserId, string oldPassword, string newPassword)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(x => x.IsPublished && x.IsActive && x.RoleCode == 2 && x.Id == authenticatedUserId);

            if (user is null || string.IsNullOrWhiteSpace(user.PasswordHash))
            {
                return JuryVotingChangePasswordResult.UserNotFound;
            }

            if (!PasswordHashHelper.VerifyPassword(oldPassword, user.PasswordHash))
            {
                return JuryVotingChangePasswordResult.OldPasswordIncorrect;
            }

            user.PasswordHash = PasswordHashHelper.HashPassword(newPassword);
            user.UpdatedAt = DateTime.Now;
            user.UpdatedBy = authenticatedUserId;

            await _context.SaveChangesAsync();

            return JuryVotingChangePasswordResult.Success;
        }

        public async Task SendForgotPasswordLinkAsync(string email, string resetPasswordBaseUrl)
        {
            if (string.IsNullOrWhiteSpace(email))
            {
                return;
            }

            var normalizedEmail = email.Trim();

            var user = await _context.Users
                .AsNoTracking()
                .FirstOrDefaultAsync(x => x.IsPublished
                    && x.IsActive
                    && x.RoleCode == 2
                    && x.Email != null                    && x.Email.ToLower() == normalizedEmail.ToLower());

            if (user is null || string.IsNullOrWhiteSpace(user.Email))
            {
                return;
            }

            var resetUrlBase = string.IsNullOrWhiteSpace(resetPasswordBaseUrl)
                ? _settings.JuryVotingResetPasswordBaseUrl
                : resetPasswordBaseUrl;

            if (string.IsNullOrWhiteSpace(resetUrlBase))
            {
                _logger.LogWarning("JuryVoting forgot-password email was skipped because reset URL base is missing.");
                return;
            }

            var token = GenerateResetToken(user.Id);
            var separator = resetUrlBase.Contains('?') ? "&" : "?";
            var resetLink = $"{resetUrlBase}{separator}token={WebUtility.UrlEncode(token)}";

            await SendResetPasswordEmailAsync(user.Email, (user.FirstName + " " + user.LastName).Trim(), resetLink);
        }

        public Task<bool> IsResetTokenValidAsync(string token)
        {
            var tokenResult = TryReadResetToken(token);
            return Task.FromResult(tokenResult.IsValid);
        }

        public async Task<JuryVotingResetPasswordResult> ResetPasswordAsync(string token, string newPassword)
        {
            var tokenResult = TryReadResetToken(token);
            if (!tokenResult.IsValid || !tokenResult.UserId.HasValue)
            {
                return JuryVotingResetPasswordResult.InvalidOrExpiredToken;
            }

            var user = await _context.Users
                .FirstOrDefaultAsync(x => x.IsPublished && x.IsActive && x.RoleCode == 2 && x.Id == tokenResult.UserId.Value);

            if (user is null)
            {
                return JuryVotingResetPasswordResult.UserNotFound;
            }

            user.PasswordHash = PasswordHashHelper.HashPassword(newPassword);
            user.UpdatedAt = DateTime.Now;
            user.UpdatedBy = user.Id;

            await _context.SaveChangesAsync();

            return JuryVotingResetPasswordResult.Success;
        }

        private string GenerateResetToken(Guid userId)
        {
            var expiresAt = DateTimeOffset.UtcNow.Add(ResetPasswordTokenLifetime).ToUnixTimeSeconds();
            var nonce = Guid.NewGuid().ToString("N");
            var payload = $"{userId:N}|{expiresAt}|{nonce}";
            var signature = ComputeTokenSignature(payload);
            var tokenRaw = $"{payload}|{signature}";
            return Convert.ToBase64String(Encoding.UTF8.GetBytes(tokenRaw));
        }

        private (bool IsValid, Guid? UserId) TryReadResetToken(string token)
        {
            if (string.IsNullOrWhiteSpace(token))
            {
                return (false, null);
            }

            try            {
                var payload = Encoding.UTF8.GetString(Convert.FromBase64String(token));
                var parts = payload.Split('|');
                if (parts.Length != 4)
                {
                    return (false, null);
                }

                var unsignedPayload = $"{parts[0]}|{parts[1]}|{parts[2]}";
                var expectedSignature = ComputeTokenSignature(unsignedPayload);
                if (!CryptographicOperations.FixedTimeEquals(
                        Encoding.UTF8.GetBytes(expectedSignature),
                        Encoding.UTF8.GetBytes(parts[3])))
                {
                    return (false, null);
                }

                var userIdParsed = Guid.TryParseExact(parts[0], "N", out var userId);
                var expiresAtParsed = long.TryParse(parts[1], out var expiresAtUnix);
                if (!userIdParsed || !expiresAtParsed)
                {
                    return (false, null);
                }

                var expiresAt = DateTimeOffset.FromUnixTimeSeconds(expiresAtUnix);
                if (DateTimeOffset.UtcNow > expiresAt)
                {
                    return (false, null);
                }

                return (true, userId);
            }
            catch            {
                return (false, null);
            }
        }
 


        private string ComputeTokenSignature(string payload)

        {

            using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(_resetPasswordSecret));

            var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(payload));

            return Convert.ToBase64String(hash);

        }
 
        private async Task SendResetPasswordEmailAsync(string toEmail, string fullName, string resetLink)

        {

            var smtp = _settings.Smtp;

            if (smtp is null

                || string.IsNullOrWhiteSpace(smtp.Host)

                || string.IsNullOrWhiteSpace(smtp.FromEmail)

                || string.IsNullOrWhiteSpace(toEmail))

            {

                _logger.LogWarning("JuryVoting forgot-password email was skipped because SMTP settings are incomplete.");

                return;

            }
 
            using var mailMessage = new MailMessage

            {

                From = string.IsNullOrWhiteSpace(smtp.FromName)

                    ? new MailAddress(smtp.FromEmail)

                    : new MailAddress(smtp.FromEmail, smtp.FromName),

                Subject = "Afife Jüri Oylama - Şifre Sıfırlama",

                Body = BuildResetPasswordMailBody(fullName, resetLink),

                IsBodyHtml = true

            };
 
            mailMessage.To.Add(toEmail);
 
            using var smtpClient = new SmtpClient(smtp.Host, smtp.Port)

            {

                EnableSsl = smtp.EnableSsl,

                DeliveryMethod = SmtpDeliveryMethod.Network,

                UseDefaultCredentials = false,

                Credentials = string.IsNullOrWhiteSpace(smtp.UserName)

                    ? CredentialCache.DefaultNetworkCredentials

                    : new NetworkCredential(smtp.UserName, smtp.Password)

            };
 
            await smtpClient.SendMailAsync(mailMessage);

        }
 
        private static string BuildResetPasswordMailBody(string fullName, string resetLink)

        {

            var safeName = string.IsNullOrWhiteSpace(fullName) ? "Değerli Kullanıcı" : WebUtility.HtmlEncode(fullName);

            var safeLink = WebUtility.HtmlEncode(resetLink);
 
            var builder = new StringBuilder();

            builder.Append("<p>").Append(safeName).Append(",</p>");

            builder.Append("<p>Şifrenizi sıfırlamak için aşağıdaki bağlantıya tıklayabilirsiniz:</p>");

            builder.Append("<p><a href=\"").Append(safeLink).Append("\">Şifreyi Sıfırla</a></p>");

            builder.Append("<p>Bu bağlantı 2 saat boyunca geçerlidir.</p>");
 
            return builder.ToString();

        }
 
        public async Task<JuryVotingHomeViewModel> BuildHomeViewModelAsync(Guid authenticatedUserId, string gameListButtonLink, string mostWatchedButtonLink, string leastWatchedButtonLink)

        {

            var watchedActivities = BuildUserPlayActivitiesQuery()

                .Select(x => new { x.UserId, x.PlayId })

                .Distinct();
 
            var scoredVoteCountsByPlay = _context.JuryVotes

                .AsNoTracking()

                .Where(juryVote => juryVote.IsPublished && juryVote.IsActive && juryVote.JuryId == authenticatedUserId && juryVote.Score > 0)

                .Join(

                    _context.PlayAwardCategories.AsNoTracking().Where(playAwardCategory => playAwardCategory.IsPublished && playAwardCategory.IsActive),

                    juryVote => juryVote.PlayAwardCategoryId,

                    playAwardCategory => playAwardCategory.Id,

                    (juryVote, playAwardCategory) => new

                    {

                        playAwardCategory.PlayId,

                        playAwardCategory.AwardCategoryCode,

                        playAwardCategory.RoleCode,

                        Role = (playAwardCategory.Role ?? string.Empty).Trim()

                    })

                .Distinct()

                .GroupBy(x => x.PlayId)

                .Select(group => new

                {

                    PlayId = group.Key,

                    ScoredCount = group.Count()

                });
 
            var totalCategoryCountsByPlay = _context.PlayAwardCategories

                .AsNoTracking()

                .Where(playAwardCategory => playAwardCategory.IsPublished && playAwardCategory.IsActive)

                .Select(playAwardCategory => new

                {

                    playAwardCategory.PlayId,

                    playAwardCategory.AwardCategoryCode,

                    playAwardCategory.RoleCode,

                    Role = (playAwardCategory.Role ?? string.Empty).Trim()

                })

                .Distinct()

                .GroupBy(playAwardCategory => playAwardCategory.PlayId)

                .Select(group => new

                {

                    PlayId = group.Key,

                    TotalCount = group.Count()

                });
 
            var completedVotePlayIds = totalCategoryCountsByPlay

                .Join(

                    scoredVoteCountsByPlay,

                    total => total.PlayId,

                    scored => scored.PlayId,

                    (total, scored) => new { total.PlayId, total.TotalCount, scored.ScoredCount })

                .Where(x => x.TotalCount > 0 && x.ScoredCount >= x.TotalCount)

                .Select(x => x.PlayId);
 
            var partialVotePlayIds = totalCategoryCountsByPlay

                .Join(

                    scoredVoteCountsByPlay,

                    total => total.PlayId,

                    scored => scored.PlayId,

                    (total, scored) => new { total.PlayId, total.TotalCount, scored.ScoredCount })

                .Where(x => x.ScoredCount > 0 && x.ScoredCount < x.TotalCount)

                .Select(x => x.PlayId);
 
            var watchedPlaySummaries = await _context.Users

                .AsNoTracking()

                .Where(user => user.IsPublished && user.IsActive && user.RoleCode == 2)

                .Select(user => new JuryWatchedPlaySummaryViewModel

                {

                    Username = user.Username ?? "",

                    FirstName = user.FirstName ?? "",

                    LastName = user.LastName ?? "",

                    PhotoImageId = user.PhotoImageId,

                    TotalWatchedPlayCount = watchedActivities

                        .Where(activity => activity.UserId == user.Id)

                        .Select(activity => activity.PlayId)

                        .Distinct()

                        .Count()

                })

                .OrderBy(x => x.FirstName)

                .ThenBy(x => x.LastName)

                .ToListAsync();
 
            var assignedPlays = await (from assignedPlay in _context.JuryAssignedPlays.AsNoTracking()

                                       where assignedPlay.IsPublished && assignedPlay.JuryId == authenticatedUserId

                                       join play in _context.Plays.AsNoTracking().Where(x => x.IsPublished && x.IsActive)

                                           on assignedPlay.PlayId equals play.Id

                                       orderby assignedPlay.UpdatedAt descending, assignedPlay.CreatedAt descending

                                       select new

                                       {

                                           PlayName = play.PlayName ?? string.Empty,

                                           VoteStatus = completedVotePlayIds.Contains(assignedPlay.PlayId)

                                               ? "Oylandı"

                                               : (partialVotePlayIds.Contains(assignedPlay.PlayId) ? "Ek Oylama Gerekli" : "Oylanmadı")

                                       })

                    .ToListAsync();
 
            var playWatchSummaries = await _context.Plays

                .AsNoTracking()

                .Where(play => play.IsPublished && play.IsActive && play.JuriOylamaStatus)

                .Select(play => new

                {

                    PlayName = play.PlayName ?? string.Empty,

                    TotalWatchedCount = watchedActivities

                        .Where(activity => activity.PlayId == play.Id)

                        .Select(activity => activity.UserId)

                        .Distinct()

                        .Count()

                })

                .ToListAsync();
 
            var mostWatchedPlays = playWatchSummaries.Where(x => x.TotalWatchedCount > 4)

                .OrderByDescending(x => x.TotalWatchedCount)

                .ThenBy(x => x.PlayName)

                .Take(5)

                .ToList();
 
            var leastWatchedPlays = playWatchSummaries.Where(x => x.TotalWatchedCount < 4)

                .OrderBy(x => x.TotalWatchedCount)

                .ThenBy(x => x.PlayName)

                .Take(5)

                .ToList();
 
            var announcements = (await _context.Announcements

                .AsNoTracking()

                .Where(x => x.IsPublished && (x.AnnouncementLocationId == 1 || x.AnnouncementLocationId == 2))

                .OrderBy(x => x.AnnouncementLocationId)

                .ThenByDescending(x => x.UpdatedAt ?? x.CreatedAt)

                .Select(x => new JuryVotingAnnouncementViewModel

                {

                    Id = x.Id,

                    AnnouncementLocationId = x.AnnouncementLocationId,

                    Text = x.Text,

                    ButtonText = x.ButtonText,

                    ButtonLink = x.ButtonLink,

                    ImageId = x.ImageId,

                    BackgroundImageId = x.BackgroundImageId,

                    BackgroundColor = x.BackgroundColor

                })

                .ToListAsync())

                .GroupBy(x => x.AnnouncementLocationId)

                .Select(x => x.First())

                .OrderBy(x => x.AnnouncementLocationId)

                .ToList();
 
            return new JuryVotingHomeViewModel

            {

                Announcements = announcements,

                AssignedPlays = new JuryVotingTableViewModel

                {

                    Title = "Görev Oyunların",

                    Columns = ["Oyun Adı", "Oylama Durumu"],

                    ButtonText = "Listeye Git",

                    IsSlimRow = true,

                    IsBodyScrollable = true,

                    CoverImage = "/images/jury-voting/gorev-oyunlari-kapak.png",

                    ButtonLink = gameListButtonLink,

                    Data = assignedPlays

                        .Select(x => (IReadOnlyList<string>)[x.PlayName, x.VoteStatus switch

                        {

                            "Oylandı" => "<div class=\"color-green\">Oylandı</div>",

                            "Ek Oylama Gerekli" => "<div class=\"color-yellow\">Ek Oylama Gerekli <img src=\"/icon/circle-info-yellow-solid.svg\" alt=\"Ek Oylama Gerekli\" /></div>",

                            _ => "<div class=\"color-red\">Oylanmadı</div>"

                        }])

                        .ToList()

                },

                Table = new JuryVotingTableViewModel

                {

                    Title = "Jüri Üyeleri",

                    Columns = ["Jüri Üyesi", "İzlenen Oyun Sayısı"],

                    IsBodyScrollable = true,
 
                    Data = watchedPlaySummaries

                        .Select(x => (IReadOnlyList<string>)["<img class=\"table-row-photo\" src=\"" + x.PhotoUrl + "\"/> " + x.FirstName + " " + x.LastName, x.TotalWatchedPlayCount.ToString()])

                        .ToList()

                },

                MostWatchedPlays = new JuryVotingTableViewModel

                {

                    Title = "Çok İzlenen Oyunlar",

                    Columns = ["Oyun Adı", "İzlenme Sayısı"],

                    ButtonText = "Tümünü Gör",

                    IsSlimRow = true,

                    ButtonLink = mostWatchedButtonLink,

                    Data = mostWatchedPlays

                        .Select(x => (IReadOnlyList<string>)[x.PlayName, x.TotalWatchedCount.ToString()])

                        .ToList()

                },

                LeastWatchedPlays = new JuryVotingTableViewModel

                {

                    Title = "Az İzlenen Oyunlar",

                    Columns = ["Oyun Adı", "İzlenme Sayısı"],

                    ButtonText = "Tümünü Gör",

                    IsSlimRow = true,

                    ButtonLink = leastWatchedButtonLink,

                    Data = leastWatchedPlays

                        .Select(x => (IReadOnlyList<string>)[x.PlayName, x.TotalWatchedCount.ToString()])

                        .ToList()

                }

            };

        }
 
        public async Task<JuryVotingPlayDetailViewModel> BuildPlayDetailPageModelAsync(
            Guid authenticatedUserId,
            string playSlug)
        {
            var juryIsEligible = await _context.Users
                .AsNoTracking()
                .AnyAsync(x =>
                    x.Id == authenticatedUserId &&
                    x.RoleCode == 2 &&
                    x.IsActive &&
                    x.IsPublished);

            if (!juryIsEligible)
            {
                return new JuryVotingPlayDetailViewModel
                {
                    ResultCode = JuryVotingResultCodes.JuryNotEligible,
                    AwardCategoriesMessage = "Jüri hesabınız aktif olmadığı için işlem yapılamaz."
                };
            }

            var play = await _context.Plays
                .AsNoTracking()
                .Where(x =>
                    x.IsPublished &&
                    x.IsActive &&
                    x.Slug == playSlug)
                .Select(x => new
                {
                    x.Id,
                    x.SourceFormId,
                    x.RecordType,
                    x.StatusCode,
                    x.JuriOylamaStatus,
                    PlayName = x.PlayName ?? string.Empty,
                    TheaterName = x.TheaterName ?? string.Empty
                })
                .FirstOrDefaultAsync();

            if (play is null)
            {
                return new JuryVotingPlayDetailViewModel
                {
                    ResultCode = JuryVotingResultCodes.PlayNotFound,
                    AwardCategoriesMessage = "Oyun bulunamadı veya yayından kaldırılmış."
                };
            }

            var sourceFormIsEligible =
                play.RecordType != 0 ||
                (play.SourceFormId.HasValue &&
                 await _context.Form.AsNoTracking().AnyAsync(x =>
                     x.Id == play.SourceFormId.Value &&
                     x.IsActive &&
                     x.IsPublished));

            var isBlacklisted = await _context.Blacklists
                .AsNoTracking()
                .AnyAsync(x =>
                    x.IsPublished &&
                    x.JuryId == authenticatedUserId &&
                    x.PlayId == play.Id);

            var additionalVotingId = await GetAvailableAdditionalVotingIdAsync(
                authenticatedUserId,
                play.Id);

            var ticketFee = await _context.JuryGameTicketFees
                .AsNoTracking()
                .Where(x =>
                    x.IsPublished &&
                    x.UserId == authenticatedUserId &&
                    x.PlayId == play.Id)
                .Select(x => new
                {
                    TicketFeeId = (Guid?)x.Id,
                    x.TicketFee
                })
                .FirstOrDefaultAsync();

            var canShowCandidates =
                play.StatusCode == 1 &&
                sourceFormIsEligible &&
                !isBlacklisted;

            var awardCategoryRows = canShowCandidates
                ? await (
                    from category in _context.PlayAwardCategories.AsNoTracking()
                    where
                        category.IsPublished &&
                        category.IsActive &&
                        category.PlayId == play.Id
                    join awardCategory in _context.AwardCategories
                            .AsNoTracking()
                            .Where(x => x.IsPublished)
                        on category.AwardCategoryCode equals awardCategory.CategoryCode
                        into awardCategoryGroup
                    from awardCategory in awardCategoryGroup.DefaultIfEmpty()
                    join vote in _context.JuryVotes
                            .AsNoTracking()
                            .Where(x =>
                                x.IsPublished &&
                                x.IsActive &&
                                x.JuryId == authenticatedUserId)
                        on category.Id equals vote.PlayAwardCategoryId
                        into voteGroup
                    from vote in voteGroup.DefaultIfEmpty()
                    select new
                    {
                        category.Id,
                        category.AwardCategoryCode,
                        Role = category.Role ?? string.Empty,
                        category.RoleCode,
                        Candidate = category.Candidate ?? string.Empty,
                        category.IsCurrent,
                        CategoryName = awardCategory != null
                            ? awardCategory.CategoryName ?? string.Empty
                            : string.Empty,
                        category.PhotoImageId,
                        JuryVoteId = vote != null ? vote.Id : (Guid?)null,
                        Score = vote != null ? vote.Score : (int?)null
                    })
                    .ToListAsync()
                : [];

            var awardCategories = awardCategoryRows
                .GroupBy(x => new
                {
                    x.AwardCategoryCode,
                    x.RoleCode,
                    Role = x.Role.Trim()
                })
                .Select(group =>
                {
                    var candidates = group
                        .OrderByDescending(x => x.JuryVoteId.HasValue)
                        .ThenByDescending(x => x.IsCurrent)
                        .ThenBy(x => x.Candidate)
                        .Select(x => new JuryVotingPlayAwardCategoryCandidateOptionViewModel
                        {
                            PlayAwardCategoryId = x.Id,
                            Candidate = group.Count() > 1
                                ? string.Concat(
                                    x.Candidate,
                                    x.IsCurrent ? " / Yeni Oyuncu" : " / Eski Oyuncu")
                                : x.Candidate,
                            PlayCategoryPhoto = BuildMediaUrl(x.PhotoImageId),
                            JuryVoteId = x.JuryVoteId,
                            Score = x.Score,
                            IsCurrent = x.IsCurrent
                        })
                        .ToList();

                    var votedCandidate = candidates.SingleOrDefault(x =>
                        x.JuryVoteId.HasValue &&
                        x.Score is >= 1 and <= 10);

                    // Tek adaylı kartta seçim nettir. Birden fazla eski/yeni aday varsa
                    // jüri seçmeden hiçbir aday otomatik seçilmez.
                    var selectedCandidate = votedCandidate ??
                        (candidates.Count == 1 ? candidates[0] : null);

                    var firstRow = group.First();

                    return new JuryVotingPlayAwardCategoryScoreViewModel
                    {
                        CategoryName = firstRow.CategoryName,
                        AwardCategoryCode = firstRow.AwardCategoryCode,
                        Role = firstRow.Role,
                        RoleCode = firstRow.RoleCode,
                        SelectedPlayAwardCategoryId =
                            selectedCandidate?.PlayAwardCategoryId ?? Guid.Empty,
                        SelectedJuryVoteId = votedCandidate?.JuryVoteId,
                        SelectedCandidate = selectedCandidate?.Candidate ?? string.Empty,
                        SelectedPlayCategoryPhoto =
                            selectedCandidate?.PlayCategoryPhoto ?? string.Empty,
                        SelectedScore = votedCandidate?.Score,
                        IsEditable =
                            (play.JuriOylamaStatus || additionalVotingId.HasValue) &&
                            (votedCandidate is null ||
                             !votedCandidate.JuryVoteId.HasValue ||
                             additionalVotingId.HasValue),
                        Candidates = candidates
                    };
                })
                .OrderBy(x => x.AwardCategoryCode)
                .ThenBy(x => x.RoleCode)
                .ThenBy(x => x.Role)
                .ToList();

            var canEnterCandidateVotes =
                canShowCandidates &&
                awardCategories.Count > 0 &&
                (play.JuriOylamaStatus || additionalVotingId.HasValue);

            var hasPendingCandidateVote =
                canEnterCandidateVotes &&
                awardCategories.Any(x => !x.SelectedScore.HasValue);

            var canEditExistingVotes =
                canShowCandidates &&
                additionalVotingId.HasValue;

            var isTicketFeeEditable =
                ticketFee is null ||
                additionalVotingId.HasValue;

            var message = string.Empty;

            if (!sourceFormIsEligible)
            {
                message = "Oyunun bağlı olduğu başvuru aktif/yayında değildir. Oy ve bilet ücreti kaydedilemez.";
            }
            else if (isBlacklisted)
            {
                message = "Bu oyun için blacklist kaydınız bulunduğundan adaylara oy veremezsiniz. Bilet ücreti girişi yapabilirsiniz.";
            }
            else if (play.StatusCode != 1)
            {
                message = "Oyun oylanabilir statüde olmadığı için yalnızca bilet ücreti girişi yapabilirsiniz.";
            }
            else if (!play.JuriOylamaStatus && !additionalVotingId.HasValue)
            {
                message = "Normal oylama kapalıdır ve kullanılabilir ek oylama hakkınız bulunmamaktadır.";
            }

            return new JuryVotingPlayDetailViewModel
            {
                ResultCode = JuryVotingResultCodes.Success,
                UserId = authenticatedUserId,
                PlayId = play.Id,
                PlayName = play.PlayName,
                TheaterName = play.TheaterName,
                PlayStatusCode = play.StatusCode,
                IsBlacklisted = isBlacklisted,
                IsSourceFormEligible = sourceFormIsEligible,
                AdditionalVotingId = additionalVotingId,
                TicketFeeId = ticketFee?.TicketFeeId,
                TicketFee = ticketFee is null
                    ? null
                    : decimal.Truncate(ticketFee.TicketFee),
                IsTicketFeeEditable = sourceFormIsEligible && isTicketFeeEditable,
                IsVotingActive = canEnterCandidateVotes,
                CanEditExistingVotes = canEditExistingVotes,
                CanSubmit =
                    sourceFormIsEligible &&
                    (isTicketFeeEditable ||
                     hasPendingCandidateVote ||
                     canEditExistingVotes),
                ShowAwardCategories = canShowCandidates && awardCategories.Count > 0,
                AwardCategoriesMessage = message,
                AwardCategories = awardCategories
            };
        }

        private static string BuildMediaUrl(Guid? imageId)
        {
            return imageId.HasValue ? $"/media/{imageId.Value}" : string.Empty;
        }

        public async Task<JuryVotingSaveVoteResult> SaveVoteAsync(
            Guid authenticatedUserId,
            SaveVoteRequest request)
        {
            var stopwatch = Stopwatch.StartNew();
            var correlationId = request.OperationContext?.CorrelationId ?? Guid.NewGuid();
            var requestJson = SerializeForLog(request);

            await using var transaction = await _context.Database.BeginTransactionAsync(
                IsolationLevel.Serializable);

            Guid? loggedJuryId = null;
            string? juryUsername = null;
            Guid? playId = null;
            string? playName = null;
            Guid? additionalVotingId = null;
            Guid? additionalVotingUsageId = null;
            AdditionalVotingUsageType? additionalUsageType = null;
            decimal? oldTicketFee = null;
            decimal? newTicketFee = null;
            string? oldVotesJson = null;
            string? newVotesJson = null;
            string? stateSnapshotJson = null;

            async Task<JuryVotingSaveVoteResult> FailAsync(
                JuryVotingSaveVoteResult result,
                string failureReason,
                object? state = null)
            {
                try
                {
                    await transaction.RollbackAsync();
                }
                catch
                {
                    // Asıl hata kodunu koru; loglama aşağıda bağımsız olarak denenir.
                }

                stopwatch.Stop();
                stateSnapshotJson = SerializeForLog(state);

                await WriteFailureLogSafeAsync(new JuryLogWriteModel
                {
                    CorrelationId = correlationId,
                    JuryId = loggedJuryId,
                    JuryUsername = juryUsername,
                    PlayId = playId,
                    PlayName = playName,
                    AdditionalVotingId = additionalVotingId,
                    AdditionalVotingUsageId = additionalVotingUsageId,
                    AdditionalVotingUsageType = additionalUsageType,
                    IsAdditionalVoting = additionalVotingId.HasValue,
                    OperationName = "Oy ve bilet ücreti kaydet",
                    OperationType = "VoteSaveRejected",
                    SubmittedVotesJson = SerializeForLog(request.Scores),
                    OldVotesJson = oldVotesJson,
                    NewVotesJson = newVotesJson,
                    SubmittedTicketFee = request.TicketFee,
                    OldTicketFee = oldTicketFee,
                    NewTicketFee = newTicketFee,
                    RequestPayloadJson = requestJson,
                    StateSnapshotJson = stateSnapshotJson,
                    AffectedVoteCount = 0,
                    OccurredAt = GetTurkeyNow(),
                    DurationMilliseconds = stopwatch.ElapsedMilliseconds,
                    IsSuccessful = false,
                    ResultCode = result.ToString(),
                    FailureReason = failureReason,
                    Context = request.OperationContext
                });

                return result;
            }

            try
            {
                if (authenticatedUserId == Guid.Empty)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.Unauthorized,
                        "Kimliği doğrulanmış jüri bilgisi bulunamadı.");
                }

                if (request.PlayId == Guid.Empty)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.InvalidRequest,
                        "PlayId boş olamaz.");
                }

                var jury = await _context.Users
                    .AsNoTracking()
                    .Where(x => x.Id == authenticatedUserId)
                    .Select(x => new
                    {
                        x.Id,
                        x.Username,
                        x.FirstName,
                        x.LastName,
                        x.RoleCode,
                        x.IsActive,
                        x.IsPublished
                    })
                    .SingleOrDefaultAsync();

                loggedJuryId = jury?.Id;
                juryUsername = jury?.Username;

                if (jury is null ||
                    jury.RoleCode != 2 ||
                    !jury.IsActive ||
                    !jury.IsPublished)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.JuryNotEligible,
                        "Jüri hesabı bulunamadı, aktif değil, yayında değil veya RoleCode=2 değil.",
                        jury);
                }

                var play = await _context.Plays
                    .AsNoTracking()
                    .Where(x => x.Id == request.PlayId)
                    .Select(x => new
                    {
                        x.Id,
                        x.PlayName,
                        x.SourceFormId,
                        x.RecordType,
                        x.StatusCode,
                        x.JuriOylamaStatus,
                        x.IsActive,
                        x.IsPublished
                    })
                    .SingleOrDefaultAsync();

                playId = play?.Id;
                playName = play?.PlayName;

                if (play is null || !play.IsActive || !play.IsPublished)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.PlayNotEligible,
                        "Oyun bulunamadı, aktif değil veya yayında değil.",
                        play);
                }

                var sourceFormIsEligible =
                    play.RecordType != 0 ||
                    (play.SourceFormId.HasValue &&
                     await _context.Form.AsNoTracking().AnyAsync(x =>
                         x.Id == play.SourceFormId.Value &&
                         x.IsActive &&
                         x.IsPublished));

                if (!sourceFormIsEligible)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.SourceFormNotEligible,
                        "RecordType=0 oyunun bağlı olduğu başvuru aktif veya yayında değil.",
                        new { play.RecordType, play.SourceFormId });
                }

                var isBlacklisted = await _context.Blacklists
                    .AsNoTracking()
                    .AnyAsync(x =>
                        x.IsPublished &&
                        x.JuryId == authenticatedUserId &&
                        x.PlayId == request.PlayId);

                additionalVotingId = await GetAvailableAdditionalVotingIdAsync(
                    authenticatedUserId,
                    request.PlayId);

                var submittedScores = request.Scores ?? [];

                if (submittedScores.Any(x =>
                        x.PlayAwardCategoryId == Guid.Empty ||
                        x.Score is < 1 or > 10))
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.ScoreOutOfRange,
                        "Her puan integer olarak 1 ile 10 arasında olmalıdır.",
                        submittedScores);
                }

                if (submittedScores
                    .GroupBy(x => x.PlayAwardCategoryId)
                    .Any(x => x.Count() != 1))
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.DuplicateCandidateSelection,
                        "Aynı aday kaydı birden fazla kez gönderilemez.",
                        submittedScores);
                }

                if (request.TicketFee is null ||
                    request.TicketFee <= 0 ||
                    request.TicketFee > 99999)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.InvalidTicketFee,
                        "Bilet ücreti 1-99999 arasında, en fazla 5 haneli integer olmalıdır.",
                        new { request.TicketFee });
                }

                var categoryRows = await _context.PlayAwardCategories
                    .AsNoTracking()
                    .Where(x =>
                        x.IsPublished &&
                        x.IsActive &&
                        x.PlayId == request.PlayId)
                    .Select(x => new
                    {
                        x.Id,
                        x.AwardCategoryCode,
                        x.RoleCode,
                        Role = (x.Role ?? string.Empty).Trim(),
                        x.Candidate,
                        x.IsCurrent
                    })
                    .ToListAsync();

                var categoryIds = categoryRows.Select(x => x.Id).ToList();

                List<JuryVotes> existingVotes = categoryIds.Count == 0
                    ? []
                    : await _context.JuryVotes
                        .Where(x =>
                            x.JuryId == authenticatedUserId &&
                            categoryIds.Contains(x.PlayAwardCategoryId))
                        .ToListAsync();

                var activeVotes = existingVotes
                    .Where(x =>
                        x.IsPublished &&
                        x.IsActive &&
                        x.Score is >= 1 and <= 10)
                    .ToList();

                oldVotesJson = SerializeForLog(activeVotes.Select(x => new
                {
                    x.Id,
                    x.PlayAwardCategoryId,
                    x.Score,
                    x.IsActive,
                    x.IsPublished
                }));

                var candidateVotingAllowed =
                    play.StatusCode == 1 &&
                    !isBlacklisted;

                if (!candidateVotingAllowed && submittedScores.Count != 0)
                {
                    return await FailAsync(
                        isBlacklisted
                            ? JuryVotingSaveVoteResult.Blacklisted
                            : JuryVotingSaveVoteResult.PlayStatusNotValidForVoting,
                        isBlacklisted
                            ? "Blacklist kaydı bulunan jüri aday oyu gönderemez."
                            : "StatusCode=1 olmayan oyunda aday oyu gönderilemez.",
                        new
                        {
                            play.StatusCode,
                            IsBlacklisted = isBlacklisted,
                            SubmittedScoreCount = submittedScores.Count
                        });
                }

                var groups = categoryRows
                    .GroupBy(x => new
                    {
                        x.AwardCategoryCode,
                        x.RoleCode,
                        x.Role
                    })
                    .ToList();

                if (candidateVotingAllowed)
                {
                    foreach (var group in groups)
                    {
                        var groupIds = group.Select(x => x.Id).ToHashSet();
                        var groupVotes = activeVotes
                            .Where(x => groupIds.Contains(x.PlayAwardCategoryId))
                            .ToList();

                        if (groupVotes.Count > 1)
                        {
                            return await FailAsync(
                                JuryVotingSaveVoteResult.InconsistentExistingVotes,
                                "Aynı mantıksal aday kartında birden fazla aktif oy bulundu.",
                                new { group.Key, Votes = groupVotes });
                        }
                    }
                }

                var normalVotingOpen =
                    candidateVotingAllowed &&
                    play.JuriOylamaStatus;

                var extraVotingAvailable =
                    candidateVotingAllowed &&
                    additionalVotingId.HasValue;

                var mustSubmitEveryCard =
                    candidateVotingAllowed &&
                    (normalVotingOpen || extraVotingAvailable);

                if (mustSubmitEveryCard && submittedScores.Count != groups.Count)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.IncompleteVoteSet,
                        "Ekrandaki her mantıksal aday kartı için tam olarak bir aday ve puan gönderilmelidir.",
                        new
                        {
                            RequiredGroupCount = groups.Count,
                            SubmittedScoreCount = submittedScores.Count
                        });
                }

                var submittedByGroup = new Dictionary<string, CategoryVoteRequest>();
                var selectedCategoryById = categoryRows.ToDictionary(x => x.Id);
                var voteChanges = new List<VoteChange>();
                var requiresAdditionalVoting = false;
                var hasExistingVoteUpdate = false;

                foreach (var submitted in submittedScores)
                {
                    if (!selectedCategoryById.TryGetValue(
                            submitted.PlayAwardCategoryId,
                            out var selectedCategory))
                    {
                        return await FailAsync(
                            JuryVotingSaveVoteResult.CandidateNotEligible,
                            "Gönderilen aday aktif/yayında değildir veya bu oyuna ait değildir.",
                            submitted);
                    }

                    var groupKey = BuildCandidateGroupKey(
                        selectedCategory.AwardCategoryCode,
                        selectedCategory.RoleCode,
                        selectedCategory.Role);

                    if (!submittedByGroup.TryAdd(groupKey, submitted))
                    {
                        return await FailAsync(
                            JuryVotingSaveVoteResult.MultipleCandidatesForSameCard,
                            "Aynı mantıksal aday kartından birden fazla adaya oy gönderilemez.",
                            new { GroupKey = groupKey, submittedScores });
                    }

                    var groupIds = categoryRows
                        .Where(x =>
                            x.AwardCategoryCode == selectedCategory.AwardCategoryCode &&
                            x.RoleCode == selectedCategory.RoleCode &&
                            x.Role == selectedCategory.Role)
                        .Select(x => x.Id)
                        .ToHashSet();

                    var existingGroupVote = activeVotes
                        .SingleOrDefault(x =>
                            groupIds.Contains(x.PlayAwardCategoryId));

                    var isChanged =
                        existingGroupVote is null ||
                        existingGroupVote.PlayAwardCategoryId !=
                            submitted.PlayAwardCategoryId ||
                        existingGroupVote.Score != submitted.Score;

                    if (!isChanged)
                    {
                        continue;
                    }

                    if (existingGroupVote is not null)
                    {
                        requiresAdditionalVoting = true;
                        hasExistingVoteUpdate = true;
                    }
                    else if (!normalVotingOpen)
                    {
                        requiresAdditionalVoting = true;
                    }

                    voteChanges.Add(new VoteChange(
                        submitted,
                        existingGroupVote,
                        groupIds));
                }

                if (mustSubmitEveryCard)
                {
                    foreach (var group in groups)
                    {
                        var key = BuildCandidateGroupKey(
                            group.Key.AwardCategoryCode,
                            group.Key.RoleCode,
                            group.Key.Role);

                        if (!submittedByGroup.ContainsKey(key))
                        {
                            return await FailAsync(
                                JuryVotingSaveVoteResult.IncompleteVoteSet,
                                "Bir veya daha fazla aday kartı gönderilmemiş.",
                                new { MissingGroupKey = key });
                        }
                    }
                }
                else if (submittedScores.Count > 0)
                {
                    // Oylama kapalıyken istemci yalnızca ekrandaki mevcut disabled
                    // oyları gönderebilir; değişiklik denemesi kabul edilmez.
                    foreach (var submitted in submittedScores)
                    {
                        var matchingVote = activeVotes.SingleOrDefault(x =>
                            x.PlayAwardCategoryId ==
                                submitted.PlayAwardCategoryId);

                        if (matchingVote is null ||
                            matchingVote.Score != submitted.Score)
                        {
                            return await FailAsync(
                                JuryVotingSaveVoteResult.VotingClosed,
                                "Normal oylama kapalı ve kullanılabilir ek oylama hakkı yok.",
                                new
                                {
                                    play.JuriOylamaStatus,
                                    AdditionalVotingId = additionalVotingId
                                });
                        }
                    }
                }

                var feeEntity = await _context.JuryGameTicketFees
                    .FirstOrDefaultAsync(x =>
                        x.UserId == authenticatedUserId &&
                        x.PlayId == request.PlayId);

                if (request.TicketFeeId.HasValue &&
                    feeEntity?.Id != request.TicketFeeId.Value)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.ConcurrencyConflict,
                        "Gönderilen bilet ücreti kaydı güncel kayıtla eşleşmiyor.",
                        new
                        {
                            request.TicketFeeId,
                            CurrentTicketFeeId = feeEntity?.Id
                        });
                }

                if (feeEntity is { IsPublished: true } &&
                    request.TicketFeeId != feeEntity.Id)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.ConcurrencyConflict,
                        "Mevcut bilet ücreti için güncel TicketFeeId gönderilmelidir.",
                        new
                        {
                            request.TicketFeeId,
                            CurrentTicketFeeId = feeEntity.Id
                        });
                }

                oldTicketFee =
                    feeEntity is { IsPublished: true }
                        ? feeEntity.TicketFee
                        : null;

                var submittedTicketFee = (decimal)request.TicketFee.Value;
                var ticketFeeChanged =
                    oldTicketFee is null ||
                    decimal.Truncate(oldTicketFee.Value) != submittedTicketFee;

                if (oldTicketFee.HasValue && ticketFeeChanged)
                {
                    requiresAdditionalVoting = true;
                    hasExistingVoteUpdate = true;
                }

                if (requiresAdditionalVoting && !additionalVotingId.HasValue)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.AdditionalVotingNotAvailable,
                        "Mevcut oy/bilet ücreti yalnızca kullanılabilir ek oylama hakkıyla güncellenebilir.",
                        new
                        {
                            VoteChangeCount = voteChanges.Count,
                            TicketFeeChanged = ticketFeeChanged
                        });
                }

                if (!normalVotingOpen &&
                    voteChanges.Any(x => x.ExistingVote is null) &&
                    !additionalVotingId.HasValue)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.VotingClosed,
                        "İlk aday oyları için normal veya ek oylama açık olmalıdır.");
                }

                if (isBlacklisted && voteChanges.Count != 0)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.Blacklisted,
                        "Blacklist ek oylama dahil bütün aday oyu işlemlerini engeller.");
                }

                if (voteChanges.Count == 0 && !ticketFeeChanged)
                {
                    return await FailAsync(
                        JuryVotingSaveVoteResult.NoChanges,
                        "Kaydedilecek bir değişiklik bulunamadı.");
                }

                var now = GetTurkeyNow();

                foreach (var change in voteChanges)
                {
                    foreach (var previousVote in existingVotes.Where(x =>
                                 change.GroupIds.Contains(
                                     x.PlayAwardCategoryId) &&
                                 x.PlayAwardCategoryId !=
                                     change.Request.PlayAwardCategoryId &&
                                 x.IsActive))
                    {
                        previousVote.IsActive = false;
                        previousVote.UpdatedAt = now;
                        previousVote.UpdatedBy = authenticatedUserId;
                    }

                    var targetVote = existingVotes.FirstOrDefault(x =>
                        x.PlayAwardCategoryId ==
                            change.Request.PlayAwardCategoryId);

                    if (targetVote is null)
                    {
                        targetVote = new JuryVotes
                        {
                            Id = Guid.NewGuid(),
                            JuryId = authenticatedUserId,
                            PlayAwardCategoryId =
                                change.Request.PlayAwardCategoryId,
                            CreatedAt = now,
                            CreatedBy = authenticatedUserId
                        };

                        _context.JuryVotes.Add(targetVote);
                        existingVotes.Add(targetVote);
                    }

                    targetVote.Score = change.Request.Score;
                    targetVote.IsPublished = true;
                    targetVote.IsActive = true;
                    targetVote.UpdatedAt = now;
                    targetVote.UpdatedBy = authenticatedUserId;
                }

                if (ticketFeeChanged)
                {
                    if (feeEntity is null)
                    {
                        feeEntity = new JuryGameTicketFee
                        {
                            Id = Guid.NewGuid(),
                            UserId = authenticatedUserId,
                            PlayId = request.PlayId,
                            CreatedAt = now,
                            CreatedBy = authenticatedUserId
                        };

                        _context.JuryGameTicketFees.Add(feeEntity);
                    }

                    feeEntity.TicketFee = submittedTicketFee;
                    feeEntity.IsPublished = true;
                    feeEntity.UpdatedAt = now;
                    feeEntity.UpdatedBy = authenticatedUserId;
                    newTicketFee = submittedTicketFee;
                }
                else
                {
                    newTicketFee = oldTicketFee;
                }

                var useAdditionalVoting =
                    additionalVotingId.HasValue &&
                    requiresAdditionalVoting;

                if (useAdditionalVoting)
                {
                    var usageAlreadyExists =
                        await _context.AdditionalVotingUsages.AnyAsync(x =>
                            x.IsPublished &&
                            x.IsActive &&
                            x.AdditionalVotingId ==
                                additionalVotingId.Value &&
                            x.JuryId == authenticatedUserId &&
                            x.PlayId == request.PlayId);

                    if (usageAlreadyExists)
                    {
                        return await FailAsync(
                            JuryVotingSaveVoteResult.AdditionalVotingAlreadyUsed,
                            "Ek oylama hakkı başka bir işlem tarafından kullanılmış.");
                    }

                    additionalUsageType = hasExistingVoteUpdate
                        ? AdditionalVotingUsageType.VoteUpdate
                        : AdditionalVotingUsageType.FirstVote;

                    var usage = CreateAdditionalVotingUsage(
                        additionalVotingId.Value,
                        authenticatedUserId,
                        request.PlayId,
                        additionalUsageType.Value);

                    additionalVotingUsageId = usage.Id;
                    _context.AdditionalVotingUsages.Add(usage);
                }

                newVotesJson = SerializeForLog(
                    existingVotes
                        .Where(x => x.IsPublished && x.IsActive)
                        .Select(x => new
                        {
                            x.Id,
                            x.PlayAwardCategoryId,
                            x.Score,
                            x.IsActive,
                            x.IsPublished
                        }));

                var operationType = useAdditionalVoting
                    ? additionalUsageType ==
                        AdditionalVotingUsageType.VoteUpdate
                        ? "AdditionalVoteUpdate"
                        : "AdditionalFirstVote"
                    : voteChanges.Count > 0
                        ? "VoteSave"
                        : oldTicketFee.HasValue
                            ? "TicketFeeUpdate"
                            : "TicketFeeCreate";

                stopwatch.Stop();

                _context.JuryLogs.Add(new JuryLog
                {
                    Id = Guid.NewGuid(),
                    CorrelationId = correlationId,
                    JuryId = authenticatedUserId,
                    JuryUsername = jury.Username,
                    PlayId = request.PlayId,
                    PlayName = play.PlayName,
                    AdditionalVotingId = useAdditionalVoting
                        ? additionalVotingId
                        : null,
                    AdditionalVotingUsageId = additionalVotingUsageId,
                    AdditionalVotingUsageType =
                        additionalUsageType.HasValue
                            ? (byte)additionalUsageType.Value
                            : null,
                    IsAdditionalVoting = useAdditionalVoting,
                    OperationName = "Oy ve bilet ücreti kaydet",
                    OperationType = operationType,
                    SubmittedVotesJson =
                        SerializeForLog(request.Scores),
                    OldVotesJson = oldVotesJson,
                    NewVotesJson = newVotesJson,
                    SubmittedTicketFee = request.TicketFee,
                    OldTicketFee = oldTicketFee,
                    NewTicketFee = newTicketFee,
                    RequestPayloadJson = requestJson,
                    StateSnapshotJson = SerializeForLog(new
                    {
                        play.StatusCode,
                        play.JuriOylamaStatus,
                        IsBlacklisted = isBlacklisted,
                        SourceFormIsEligible = sourceFormIsEligible,
                        NormalVotingOpen = normalVotingOpen,
                        AdditionalVotingId = additionalVotingId,
                        UsesAdditionalVoting = useAdditionalVoting
                    }),
                    AffectedVoteCount = voteChanges.Count,
                    OccurredAt = now,
                    DurationMilliseconds = stopwatch.ElapsedMilliseconds,
                    IpAddress = request.OperationContext?.IpAddress,
                    UserAgent = request.OperationContext?.UserAgent,
                    HttpMethod = request.OperationContext?.HttpMethod,
                    RequestPath = request.OperationContext?.RequestPath,
                    ControllerName =
                        request.OperationContext?.ControllerName,
                    ActionName = request.OperationContext?.ActionName,
                    Application = "AfifeJury",
                    Source = "JuryPanel",
                    IsSuccessful = true,
                    ResultCode = JuryVotingSaveVoteResult.Success.ToString(),
                    Details =
                        $"Oy değişikliği: {voteChanges.Count}; bilet değişikliği: {ticketFeeChanged}; ek oylama: {useAdditionalVoting}",
                    IsPublished = true
                });

                await _context.SaveChangesAsync();
                await transaction.CommitAsync();

                return JuryVotingSaveVoteResult.Success;
            }
            catch (DbUpdateException exception)
            {
                _logger.LogError(
                    exception,
                    "Jüri oy kaydı DB hatası. CorrelationId={CorrelationId}",
                    correlationId);

                return await FailAsync(
                    JuryVotingSaveVoteResult.ConcurrencyConflict,
                    "Oy kaydı eşzamanlı başka bir işlemle çakıştı.",
                    new
                    {
                        Exception = exception.GetType().FullName,
                        exception.Message
                    });
            }
            catch (Exception exception)
            {
                _logger.LogError(
                    exception,
                    "Jüri oy kaydı beklenmeyen hata. CorrelationId={CorrelationId}",
                    correlationId);

                return await FailAsync(
                    JuryVotingSaveVoteResult.UnexpectedError,
                    "Oy kaydı sırasında beklenmeyen bir hata oluştu.",
                    new
                    {
                        Exception = exception.GetType().FullName,
                        exception.Message
                    });
            }
        }

        private async Task<Guid?> GetAvailableAdditionalVotingIdAsync(
            Guid juryId,
            Guid playId)
        {
            var localNow = GetTurkeyNow();
            var today = DateOnly.FromDateTime(localNow);
            var startDayFirstSecondReached =
                localNow.TimeOfDay >= TimeSpan.FromSeconds(1);

            return await _context.AdditionalVotings
                .Where(voting =>
                    voting.IsPublished &&
                    voting.IsActive &&
                    voting.StartDate <= today &&
                    (voting.StartDate < today || startDayFirstSecondReached) &&
                    today <= voting.EndDate)
                .Where(voting =>
                    voting.AppliesToAllJuries ||
                    _context.AdditionalVotingJuries.Any(jury =>
                        jury.IsPublished &&
                        jury.IsActive &&
                        jury.AdditionalVotingId == voting.Id &&
                        jury.JuryId == juryId))
                .Where(voting =>
                    voting.AppliesToAllPlays ||
                    _context.AdditionalVotingPlays.Any(play =>
                        play.IsPublished &&
                        play.IsActive &&
                        play.AdditionalVotingId == voting.Id &&
                        play.PlayId == playId))
                .Where(voting =>
                    !_context.AdditionalVotingUsages.Any(usage =>
                        usage.IsPublished &&
                        usage.IsActive &&
                        usage.AdditionalVotingId == voting.Id &&
                        usage.JuryId == juryId &&
                        usage.PlayId == playId))
                .OrderBy(voting => voting.EndDate)
                .ThenBy(voting => voting.StartDate)
                .Select(voting => (Guid?)voting.Id)
                .FirstOrDefaultAsync();
        }

        private static AdditionalVotingUsage CreateAdditionalVotingUsage(
            Guid additionalVotingId,
            Guid juryId,
            Guid playId,
            AdditionalVotingUsageType usageType)
        {
            var now = GetTurkeyNow();

            return new AdditionalVotingUsage
            {
                Id = Guid.NewGuid(),
                AdditionalVotingId = additionalVotingId,
                JuryId = juryId,
                PlayId = playId,
                UsageType = usageType,
                UsedAt = now,
                CreatedAt = now,
                CreatedBy = juryId,
                IsActive = true,
                IsPublished = true
            };
        }

        private async Task WriteFailureLogSafeAsync(JuryLogWriteModel model)
        {
            try
            {
                // Bu INSERT özellikle SaveChanges kullanılmadan çalıştırılır.
                // Böylece rollback edilmiş oy entity'leri yanlışlıkla tekrar
                // kaydedilmez ve başarısız işlem logu ana transaction'dan bağımsızdır.
                await _context.Database.ExecuteSqlInterpolatedAsync($@"
INSERT INTO dbo.JuryLogs
(
    Id, CorrelationId, JuryId, JuryUsername, PlayId, PlayName,
    AdditionalVotingId, AdditionalVotingUsageId, AdditionalVotingUsageType,
    IsAdditionalVoting, OperationName, OperationType,
    SubmittedVotesJson, OldVotesJson, NewVotesJson,
    SubmittedTicketFee, OldTicketFee, NewTicketFee,
    RequestPayloadJson, StateSnapshotJson, AffectedVoteCount,
    OccurredAt, DurationMilliseconds, IpAddress, UserAgent,
    HttpMethod, RequestPath, ControllerName, ActionName,
    Application, Source, IsSuccessful, ResultCode,
    Details, FailureReason, IsPublished
)
VALUES
(
    {Guid.NewGuid()}, {model.CorrelationId}, {model.JuryId},
    {model.JuryUsername}, {model.PlayId}, {model.PlayName},
    {model.AdditionalVotingId}, {model.AdditionalVotingUsageId},
    {model.AdditionalVotingUsageType}, {model.IsAdditionalVoting},
    {model.OperationName}, {model.OperationType},
    {model.SubmittedVotesJson}, {model.OldVotesJson}, {model.NewVotesJson},
    {model.SubmittedTicketFee}, {model.OldTicketFee}, {model.NewTicketFee},
    {model.RequestPayloadJson}, {model.StateSnapshotJson},
    {model.AffectedVoteCount}, {model.OccurredAt},
    {model.DurationMilliseconds}, {model.Context?.IpAddress},
    {model.Context?.UserAgent}, {model.Context?.HttpMethod},
    {model.Context?.RequestPath}, {model.Context?.ControllerName},
    {model.Context?.ActionName}, {"AfifeJury"}, {"JuryPanel"},
    {false}, {model.ResultCode}, {model.Details},
    {model.FailureReason}, {true}
)");
            }
            catch (Exception logException)
            {
                _logger.LogError(
                    logException,
                    "Başarısız jüri işlemi JuryLogs tablosuna yazılamadı. CorrelationId={CorrelationId}",
                    model.CorrelationId);
            }
        }

        private static DateTime GetTurkeyNow()
        {
            var timeZone = TimeZoneInfo.FindSystemTimeZoneById(
                OperatingSystem.IsWindows()
                    ? "Turkey Standard Time"
                    : "Europe/Istanbul");

            return TimeZoneInfo.ConvertTimeFromUtc(
                DateTime.UtcNow,
                timeZone);
        }

        private static string BuildCandidateGroupKey(
            int awardCategoryCode,
            int roleCode,
            string? role)
        {
            return string.Concat(
                awardCategoryCode,
                "|",
                roleCode,
                "|",
                (role ?? string.Empty).Trim());
        }

        private static string? SerializeForLog(object? value)
        {
            return value is null
                ? null
                : JsonSerializer.Serialize(
                    value,
                    new JsonSerializerOptions
                    {
                        PropertyNamingPolicy =
                            JsonNamingPolicy.CamelCase
                    });
        }

        private sealed record VoteChange(
            CategoryVoteRequest Request,
            JuryVotes? ExistingVote,
            HashSet<Guid> GroupIds);

        private sealed class JuryLogWriteModel
        {
            public Guid CorrelationId { get; init; }
            public Guid? JuryId { get; init; }
            public string? JuryUsername { get; init; }
            public Guid? PlayId { get; init; }
            public string? PlayName { get; init; }
            public Guid? AdditionalVotingId { get; init; }
            public Guid? AdditionalVotingUsageId { get; init; }
            public AdditionalVotingUsageType? AdditionalVotingUsageType { get; init; }
            public bool IsAdditionalVoting { get; init; }
            public string OperationName { get; init; } = string.Empty;
            public string OperationType { get; init; } = string.Empty;
            public string? SubmittedVotesJson { get; init; }
            public string? OldVotesJson { get; init; }
            public string? NewVotesJson { get; init; }
            public decimal? SubmittedTicketFee { get; init; }
            public decimal? OldTicketFee { get; init; }
            public decimal? NewTicketFee { get; init; }
            public string? RequestPayloadJson { get; init; }
            public string? StateSnapshotJson { get; init; }
            public int AffectedVoteCount { get; init; }
            public DateTime OccurredAt { get; init; }
            public long DurationMilliseconds { get; init; }
            public bool IsSuccessful { get; init; }
            public string? ResultCode { get; init; }
            public string? Details { get; init; }
            public string? FailureReason { get; init; }
            public JuryOperationContext? Context { get; init; }
        }

        
public async Task<JuryVotingComplexTableViewModel> BuildGameListTableModelAsync(Guid authenticatedUserId, string tab, string search, string sortBy, string sortDirection, int page, string actionName)

{

     page = page < 1 ? 1 : page;

     tab = string.IsNullOrWhiteSpace(tab) ? "all" : tab.Trim().ToLowerInvariant();

     sortBy = string.IsNullOrWhiteSpace(sortBy) ? "PlayName" : sortBy.Trim();

     sortDirection = string.Equals(sortDirection, "desc", StringComparison.OrdinalIgnoreCase) ? "desc" : "asc";

     var trimmedSearch = search?.Trim() ?? string.Empty;
 
     var tabs = GetGameListTabs();

     var activeTab = tabs.FirstOrDefault(x => x.Key == tab) ?? tabs[0];

     tab = activeTab.Key;
 
     sortBy = tab switch

     {

         "assigned" when sortBy == "VoteStatus" => "VoteStatus",

         "assigned" when sortBy == "TotalWatchCount" => "TotalWatchCount",

         "all" when sortBy == "GroupName" => "GroupName",

         _ when sortBy == "PlayStatus" => "PlayStatus",

         _ when sortBy == "TheaterName" => "TheaterName",

         _ => "PlayName"

     };
 
     var scoredVoteCountsByPlay = _context.JuryVotes

         .AsNoTracking()

         .Where(juryVote => juryVote.IsPublished && juryVote.IsActive && juryVote.JuryId == authenticatedUserId && juryVote.Score > 0)

         .Join(

             _context.PlayAwardCategories.AsNoTracking().Where(playAwardCategory => playAwardCategory.IsPublished && playAwardCategory.IsActive),

             juryVote => juryVote.PlayAwardCategoryId,

             playAwardCategory => playAwardCategory.Id,

             (juryVote, playAwardCategory) => new

             {

                 playAwardCategory.PlayId,

                 playAwardCategory.AwardCategoryCode,

                 playAwardCategory.RoleCode,

                 Role = (playAwardCategory.Role ?? string.Empty).Trim()

             })

         .Distinct()

         .GroupBy(x => x.PlayId)

         .Select(group => new

         {

             PlayId = group.Key,

             ScoredCount = group.Count()

         });
 
     var totalCategoryCountsByPlay = _context.PlayAwardCategories

         .AsNoTracking()

         .Where(playAwardCategory => playAwardCategory.IsPublished && playAwardCategory.IsActive)

         .Select(playAwardCategory => new

         {

             playAwardCategory.PlayId,

             playAwardCategory.AwardCategoryCode,

             playAwardCategory.RoleCode,

             Role = (playAwardCategory.Role ?? string.Empty).Trim()

         })

         .Distinct()

         .GroupBy(playAwardCategory => playAwardCategory.PlayId)

         .Select(group => new

         {

             PlayId = group.Key,

             TotalCount = group.Count()

         });
 
     var completedVotePlayIds = totalCategoryCountsByPlay

         .Join(

             scoredVoteCountsByPlay,

             total => total.PlayId,

             scored => scored.PlayId,

             (total, scored) => new { total.PlayId, total.TotalCount, scored.ScoredCount })

         .Where(x => x.TotalCount > 0 && x.ScoredCount >= x.TotalCount)

         .Select(x => x.PlayId);
 
     var partialVotePlayIds = totalCategoryCountsByPlay

         .Join(

             scoredVoteCountsByPlay,

             total => total.PlayId,

             scored => scored.PlayId,

             (total, scored) => new { total.PlayId, total.TotalCount, scored.ScoredCount })

         .Where(x => x.ScoredCount > 0 && x.ScoredCount < x.TotalCount)

         .Select(x => x.PlayId);
 
     // Oyun Listesi gerçekten bütün aktif/yayımlanmış oyunları gösterir.
     // JuriOylamaStatus yalnızca "Oylanabilir Oyunlar" ekranının filtresidir.
     var filteredRows = _context.Plays

         .AsNoTracking()

         .Where(play => play.IsPublished && play.IsActive)

         .Where(play => tab != "assigned" || _context.JuryAssignedPlays

             .AsNoTracking()

             .Any(assignedPlay => assignedPlay.IsPublished && assignedPlay.JuryId == authenticatedUserId && assignedPlay.PlayId == play.Id))

         .Select(play => new JuryVotingPlayTableQueryRow

         {

             PlayId = play.Id,

             PlayName = play.PlayName ?? string.Empty,

             Slug = play.Slug,

             PlayStatus = _context.PlayStatuses

                 .AsNoTracking()

                 .Where(playStatus => playStatus.IsPublished && playStatus.StatusCode == play.StatusCode)

                 .Select(playStatus => playStatus.StatusName ?? string.Empty)

                 .FirstOrDefault() ?? string.Empty,

             TheaterName = play.TheaterName ?? string.Empty,

             StatusColor = _context.PlayStatuses

                 .AsNoTracking()

                 .Where(playStatus => playStatus.IsPublished && playStatus.StatusCode == play.StatusCode)

                 .Select(playStatus => playStatus.StatusColor ?? string.Empty)

                 .FirstOrDefault() ?? string.Empty,

             PlayStatusCode = _context.PlayStatuses

                 .AsNoTracking()

                 .Where(playStatus => playStatus.IsPublished && playStatus.StatusCode == play.StatusCode)

                 .Select(playStatus => playStatus.StatusCode)

                 .FirstOrDefault(),
 
             VoteStatus = completedVotePlayIds.Contains(play.Id)

                 ? "Oylandı"

                 : (partialVotePlayIds.Contains(play.Id) ? "Ek Oylama Gerekli" : "Oylanmadı"),

             VoteStatusSortOrder = completedVotePlayIds.Contains(play.Id)

                 ? 3

                 : (partialVotePlayIds.Contains(play.Id) ? 2 : 1),

             GroupSortName = _context.JuryAssignedPlays

                 .AsNoTracking()

                 .Where(assignedPlay => assignedPlay.IsPublished && assignedPlay.PlayId == play.Id)

                 .Join(

                     _context.Users.AsNoTracking().Where(user => user.IsPublished && user.IsActive && user.RoleCode == 2),

                     assignedPlay => assignedPlay.JuryId,

                     user => user.Id,

                     (assignedPlay, user) => ((user.FirstName ?? string.Empty) + " " + (user.LastName ?? string.Empty)).Trim())

                 .Where(juryName => !string.IsNullOrWhiteSpace(juryName))

                 .OrderBy(juryName => juryName)

                 .FirstOrDefault() ?? string.Empty,

             TotalWatchCount = BuildUserPlayActivitiesQuery()

                 .Where(activity => activity.PlayId == play.Id)

                 .Select(activity => activity.UserId)

                 .Distinct()

                 .Count()

         });
 
     if (!string.IsNullOrWhiteSpace(trimmedSearch))

     {

         filteredRows = filteredRows.Where(x => EF.Functions.Like(x.PlayName, $"%{trimmedSearch}%"));

     }
 
     filteredRows = (sortBy, sortDirection) switch

     {

         ("VoteStatus", "desc") when tab == "assigned" => filteredRows.OrderByDescending(x => x.VoteStatusSortOrder).ThenBy(x => x.PlayName),

         ("VoteStatus", _) when tab == "assigned" => filteredRows.OrderBy(x => x.VoteStatusSortOrder).ThenBy(x => x.PlayName),

         ("TotalWatchCount", "desc") when tab == "assigned" => filteredRows.OrderByDescending(x => x.TotalWatchCount).ThenBy(x => x.PlayName),

         ("TotalWatchCount", _) when tab == "assigned" => filteredRows.OrderBy(x => x.TotalWatchCount).ThenBy(x => x.PlayName),

         ("GroupName", "desc") when tab == "all" => filteredRows.OrderByDescending(x => x.GroupSortName).ThenBy(x => x.PlayName),

         ("GroupName", _) when tab == "all" => filteredRows.OrderBy(x => x.GroupSortName).ThenBy(x => x.PlayName),

         ("PlayStatus", "desc") => filteredRows.OrderByDescending(x => x.PlayStatus).ThenBy(x => x.PlayName),

         ("PlayStatus", _) => filteredRows.OrderBy(x => x.PlayStatus).ThenBy(x => x.PlayName),

         ("TheaterName", "desc") => filteredRows.OrderByDescending(x => x.TheaterName).ThenBy(x => x.PlayName),

         ("TheaterName", _) => filteredRows.OrderBy(x => x.TheaterName).ThenBy(x => x.PlayName),

         ("PlayName", "desc") => filteredRows.OrderByDescending(x => x.PlayName),

         _ => filteredRows.OrderBy(x => x.PlayName)

     };
 
     const int pageSize = 8;

     var totalCount = await filteredRows.CountAsync();

     var totalPages = totalCount == 0 ? 1 : (int)Math.Ceiling(totalCount / (double)pageSize);

     page = Math.Min(page, totalPages);
 
     var rows = await filteredRows

         .Skip((page - 1) * pageSize)

         .Take(pageSize)

         .ToListAsync();
 
     var playIds = rows.Select(x => x.PlayId).ToList();

     var juryNamesByPlayId = await _context.JuryAssignedPlays

         .AsNoTracking()

         .Where(x => x.IsPublished && playIds.Contains(x.PlayId))

         .Join(

             _context.Users.AsNoTracking().Where(user => user.IsPublished && user.IsActive && user.RoleCode == 2),

             assignedPlay => assignedPlay.JuryId,

             user => user.Id,

             (assignedPlay, user) => new

             {

                 assignedPlay.PlayId,

                 user.Id,

                 user.GroupCode,

                 JuryName = ((user.FirstName ?? string.Empty) + " " + (user.LastName ?? string.Empty)).Trim()

             })

         .ToListAsync();
 
     var assignedGroupCodes = juryNamesByPlayId

         .Where(item => item.GroupCode.HasValue)

         .Select(item => item.GroupCode!.Value)

         .Distinct()

         .ToList();
 
     var groupNames = await _context.Groups

         .AsNoTracking()

         .Where(group => group.IsPublished && assignedGroupCodes.Contains(group.Code))

         .ToDictionaryAsync(group => group.Code, group => group.GroupName);
 
     var activeGroupMembers = await _context.Users

         .AsNoTracking()

         .Where(user => user.IsPublished
&& user.IsActive
&& user.RoleCode == 2
&& user.GroupCode.HasValue
&& assignedGroupCodes.Contains(user.GroupCode.Value))

         .Select(user => new

         {

             user.Id,

             GroupCode = user.GroupCode!.Value,

             JuryName = ((user.FirstName ?? string.Empty) + " " + (user.LastName ?? string.Empty)).Trim()

         })

         .ToListAsync();
 
     var activeMembersByGroupCode = activeGroupMembers

         .GroupBy(member => member.GroupCode)

         .ToDictionary(

             group => group.Key,

             group => group

                 .Where(member => !string.IsNullOrWhiteSpace(member.JuryName))

                 .GroupBy(member => member.Id)

                 .Select(member => new { UserId = member.Key, JuryName = member.First().JuryName })

                 .OrderBy(member => member.JuryName)

                 .ToList());
 
     foreach (var row in rows)

     {

         var assignedJuries = juryNamesByPlayId

             .Where(item => item.PlayId == row.PlayId)

             .GroupBy(item => item.Id)

             .Select(group => group.First())

             .ToList();
 
         var assignedJuryIds = assignedJuries.Select(item => item.Id).ToHashSet();

         var completeGroupCodes = assignedJuries

             .Where(item => item.GroupCode.HasValue)

             .Select(item => item.GroupCode!.Value)

             .Distinct()

             .Where(groupCode => groupNames.ContainsKey(groupCode)
&& activeMembersByGroupCode.TryGetValue(groupCode, out var members)
&& members.Count > 0
&& members.All(member => assignedJuryIds.Contains(member.UserId)))

             .ToHashSet();
 
         var displayItems = completeGroupCodes

             .OrderBy(groupCode => groupNames[groupCode])

             .Select(groupCode => new JuryAssignmentDisplayItem

             {

                 Label = groupNames[groupCode],

                 GroupMembers = activeMembersByGroupCode[groupCode]

                     .Select(member => member.JuryName)

                     .ToList()

             })

             .ToList();
 
         displayItems.AddRange(assignedJuries

             .Where(item => !item.GroupCode.HasValue || !completeGroupCodes.Contains(item.GroupCode.Value))

             .Where(item => !string.IsNullOrWhiteSpace(item.JuryName))

             .OrderBy(item => item.JuryName)

             .Select(item => new JuryAssignmentDisplayItem { Label = item.JuryName }));
 
         row.JuryAssignments = displayItems;

         row.GroupName = string.Join(", ", displayItems.Select(item => item.Label));

     }
 
     return new JuryVotingComplexTableViewModel

     {

         ActionName = actionName,

         CurrentTabKey = tab,

         Tabs = tabs.Select(tabItem => new JuryVotingComplexTableTabViewModel

         {

             Title = tabItem.Title,

             Key = tabItem.Key,

             Search = search,

             SearchColumn = "Oyun Adı",

             SortBy = sortBy,

             SortDirection = sortDirection,

             CurrentPage = tabItem.Key == tab ? page : 1,

             PageSize = pageSize,

             TotalCount = tabItem.Key == tab ? totalCount : 0,

             Columns = GetGameListColumns(tabItem.Key),

             Data = tabItem.Key == tab ? rows.Select(row => BuildGameListRow(row, tab)).ToList() : []

         }).ToList()

     };

}

 
   public async Task<JuryVotingComplexTableViewModel> BuildPlaysTableModelAsync(Guid authenticatedUserId, string tab, string search, string sortBy, string sortDirection, int page, string actionName, bool includePlayStatusColumn = false, bool currentPlayStatusesOnly = false, bool includeAssignedPlayColumn = true, bool assignedPlaysOnly = false)

   {

       page = page < 1 ? 1 : page;

       tab = string.IsNullOrWhiteSpace(tab) ? "all" : tab.Trim().ToLowerInvariant();

       sortBy = string.IsNullOrWhiteSpace(sortBy) ? "PlayName" : sortBy.Trim();

       sortDirection = string.Equals(sortDirection, "desc", StringComparison.OrdinalIgnoreCase) ? "desc" : "asc";

       var trimmedSearch = search?.Trim() ?? string.Empty;
 
       var tabs = GetTableTabs(currentPlayStatusesOnly, assignedPlaysOnly);

       var activeTab = tabs.FirstOrDefault(x => x.Key == tab) ?? tabs[0];

       tab = activeTab.Key;
 
       var columns = BuildColumns(includeAssignedPlayColumn, includePlayStatusColumn);
 
       sortBy = sortBy switch

       {

           "IsAssignedPlay" when includeAssignedPlayColumn => "IsAssignedPlay",

           "VoteStatus" => "VoteStatus",

           "PremiereDate" => "PremiereDate",

           "TotalWatchCount" => "TotalWatchCount",

           "PlayStatus" when includePlayStatusColumn => "PlayStatus",

           _ => "PlayName"

       };
 
       var scoredVoteCountsByPlay = _context.JuryVotes

           .AsNoTracking()

           .Where(juryVote => juryVote.IsPublished && juryVote.IsActive && juryVote.JuryId == authenticatedUserId && juryVote.Score > 0)

           .Join(

               _context.PlayAwardCategories.AsNoTracking().Where(playAwardCategory => playAwardCategory.IsPublished && playAwardCategory.IsActive),

               juryVote => juryVote.PlayAwardCategoryId,

               playAwardCategory => playAwardCategory.Id,

               (juryVote, playAwardCategory) => new

               {

                   playAwardCategory.PlayId,

                   playAwardCategory.AwardCategoryCode,

                   playAwardCategory.RoleCode,

                   Role = (playAwardCategory.Role ?? string.Empty).Trim()

               })

           .Distinct()

           .GroupBy(x => x.PlayId)

           .Select(group => new

           {

               PlayId = group.Key,

               ScoredCount = group.Count()

           });
 
       var totalCategoryCountsByPlay = _context.PlayAwardCategories

           .AsNoTracking()

           .Where(playAwardCategory => playAwardCategory.IsPublished && playAwardCategory.IsActive)

           .Select(playAwardCategory => new

           {

               playAwardCategory.PlayId,

               playAwardCategory.AwardCategoryCode,

               playAwardCategory.RoleCode,

               Role = (playAwardCategory.Role ?? string.Empty).Trim()

           })

           .Distinct()

           .GroupBy(playAwardCategory => playAwardCategory.PlayId)

           .Select(group => new

           {

               PlayId = group.Key,

               TotalCount = group.Count()

           });
 
       var completedVotePlayIds = totalCategoryCountsByPlay

           .Join(

               scoredVoteCountsByPlay,

               total => total.PlayId,

               scored => scored.PlayId,

               (total, scored) => new { total.PlayId, total.TotalCount, scored.ScoredCount })

           .Where(x => x.TotalCount > 0 && x.ScoredCount >= x.TotalCount)

           .Select(x => x.PlayId);
 
       var partialVotePlayIds = totalCategoryCountsByPlay

           .Join(

               scoredVoteCountsByPlay,

               total => total.PlayId,

               scored => scored.PlayId,

               (total, scored) => new { total.PlayId, total.TotalCount, scored.ScoredCount })

           .Where(x => x.ScoredCount > 0 && x.ScoredCount < x.TotalCount)

           .Select(x => x.PlayId);
 
       var filteredRows =

from play in _context.Plays

    .AsNoTracking()

    .Where(play => play.IsPublished && play.IsActive && play.JuriOylamaStatus)

join form in _context.Form

    .AsNoTracking()

    .Where(form => form.IsPublished && form.IsActive)

    on play.SourceFormId equals (Guid?)form.Id into formGroup

from form in formGroup.DefaultIfEmpty()

where !activeTab.IsOnlyActivePlays || play.JuriOylamaStatus

where !assignedPlaysOnly || _context.JuryAssignedPlays

    .AsNoTracking()

    .Any(assignedPlay =>

        assignedPlay.IsPublished &&

        assignedPlay.JuryId == authenticatedUserId &&

        assignedPlay.PlayId == play.Id)

select new JuryVotingPlayTableQueryRow

{

    PlayId = play.Id,

    PlayName = play.PlayName ?? string.Empty,

    Slug = play.Slug ?? string.Empty,

    PremiereDate = form == null

        ? (DateOnly?)null

        : form.PremiereDate,

    PlayStatus = _context.PlayStatuses

                              .AsNoTracking()

                              .Where(playStatus => playStatus.IsPublished && playStatus.StatusCode == play.StatusCode)

                              .Select(playStatus => playStatus.StatusName ?? string.Empty)

                              .FirstOrDefault() ?? string.Empty,

    PlayStatusCode = _context.PlayStatuses

                              .AsNoTracking()

                              .Where(playStatus => playStatus.IsPublished && playStatus.StatusCode == play.StatusCode)

                              .Select(playStatus => playStatus.StatusCode)

                              .FirstOrDefault(),

    IsAssignedPlay = _context.JuryAssignedPlays

                              .AsNoTracking()

                              .Any(assignedPlay => assignedPlay.IsPublished && assignedPlay.JuryId == authenticatedUserId && assignedPlay.PlayId == play.Id),

    VoteStatus = completedVotePlayIds.Contains(play.Id)

                              ? "Oylandı"

                              : (partialVotePlayIds.Contains(play.Id) ? "Ek Oylama Gerekli" : "Oylanmadı"),

    VoteStatusSortOrder = completedVotePlayIds.Contains(play.Id)

                              ? 3

                              : (partialVotePlayIds.Contains(play.Id) ? 2 : 1),

    TotalWatchCount = BuildUserPlayActivitiesQuery()

                              .Where(activity => activity.PlayId == play.Id)

                              .Select(activity => activity.UserId)

                              .Distinct()

                              .Count()

};
 
       filteredRows = tab switch

       {

           "most" => filteredRows.Where(x => x.TotalWatchCount >= 4),

           "least" => filteredRows.Where(x => x.TotalWatchCount < 4),

           _ => filteredRows

       };
 
       if (!string.IsNullOrWhiteSpace(trimmedSearch))

       {

           filteredRows = filteredRows.Where(x => EF.Functions.Like(x.PlayName, $"%{trimmedSearch}%"));

       }
 
       filteredRows = (sortBy, sortDirection) switch

       {

           ("IsAssignedPlay", "desc") => filteredRows.OrderByDescending(x => x.IsAssignedPlay).ThenBy(x => x.PlayName),

           ("IsAssignedPlay", _) => filteredRows.OrderBy(x => x.IsAssignedPlay).ThenBy(x => x.PlayName),

           ("PremiereDate", "desc") => filteredRows.OrderByDescending(x => x.PremiereDate).ThenBy(x => x.PlayName),

           ("PremiereDate", _) => filteredRows.OrderBy(x => x.PremiereDate).ThenBy(x => x.PlayName),

           ("VoteStatus", "desc") => filteredRows.OrderByDescending(x => x.VoteStatusSortOrder).ThenBy(x => x.PlayName),

           ("VoteStatus", _) => filteredRows.OrderBy(x => x.VoteStatusSortOrder).ThenBy(x => x.PlayName),

           ("TotalWatchCount", "desc") => filteredRows.OrderByDescending(x => x.TotalWatchCount).ThenBy(x => x.PlayName),

           ("TotalWatchCount", _) => filteredRows.OrderBy(x => x.TotalWatchCount).ThenBy(x => x.PlayName),

           ("PlayStatus", "desc") => filteredRows.OrderByDescending(x => x.PlayStatus).ThenBy(x => x.PlayName),

           ("PlayStatus", _) => filteredRows.OrderBy(x => x.PlayStatus).ThenBy(x => x.PlayName),

           ("PlayName", "desc") => filteredRows.OrderByDescending(x => x.PlayName),

           _ => filteredRows.OrderBy(x => x.PlayName)

       };
 
       const int pageSize = 8;

       var totalCount = await filteredRows.CountAsync();

       var totalPages = totalCount == 0 ? 1 : (int)Math.Ceiling(totalCount / (double)pageSize);

       page = Math.Min(page, totalPages);
 
       var rows = await filteredRows

           .Skip((page - 1) * pageSize)

           .Take(pageSize)

           .ToListAsync();
 
       return new JuryVotingComplexTableViewModel

       {

           ActionName = actionName,

           CurrentTabKey = tab,

           Tabs = tabs.Select(tabItem => new JuryVotingComplexTableTabViewModel

           {

               Title = tabItem.Title,

               Key = tabItem.Key,

               Search = search,

               SearchColumn = "Oyun Adı",

               SortBy = sortBy,

               SortDirection = sortDirection,

               CurrentPage = tabItem.Key == tab ? page : 1,

               PageSize = pageSize,

               TotalCount = tabItem.Key == tab ? totalCount : 0,

               Columns = columns,

               Data = tabItem.Key == tab ? rows.Select(row => BuildRow(row, includeAssignedPlayColumn, includePlayStatusColumn)).ToList() : []

           }).ToList()

       };

   }
 
   public async Task<JuryVotingComplexTableViewModel> BuildContactTableModelAsync(string tab, string search, string sortBy, string sortDirection, int page, string actionName)

   {

       page = page < 1 ? 1 : page;

       tab = string.IsNullOrWhiteSpace(tab) ? "theaters" : tab.Trim().ToLowerInvariant();
 
       sortDirection = string.Equals(sortDirection, "desc", StringComparison.OrdinalIgnoreCase) ? "desc" : "asc";
 
       var tabs = GetContactTableTabs();

       var activeTab = tabs.FirstOrDefault(x => x.Key == tab) ?? tabs[0];

       tab = activeTab.Key;
 
       const int pageSize = 8;
 
       return tab switch

       {

           "jury" => await BuildUserContactTableModelAsync(tabs, activeTab, search, sortBy, sortDirection, page, roleCode: 2, pageSize, actionName),

           "coordination" => await BuildUserContactTableModelAsync(tabs, activeTab, search, sortBy, sortDirection, page, roleCode: 1, pageSize, actionName),

           _ => await BuildTheaterContactTableModelAsync(tabs, activeTab, search, sortBy, sortDirection, page, pageSize, actionName)

       };

   }
 
   private IQueryable<JuryVotingUserPlayActivityQueryRow> BuildUserPlayActivitiesQuery()

   {

       var voteActivities = _context.JuryVotes

           .AsNoTracking()

           .Where(juryVote => juryVote.IsPublished && juryVote.IsActive)

           .Join(

               _context.PlayAwardCategories.AsNoTracking().Where(playAwardCategory => playAwardCategory.IsPublished && playAwardCategory.IsActive),

               juryVote => juryVote.PlayAwardCategoryId,

               playAwardCategory => playAwardCategory.Id,

               (juryVote, playAwardCategory) => new JuryVotingUserPlayActivityQueryRow

               {

                   UserId = juryVote.JuryId,

                   PlayId = playAwardCategory.PlayId

               });

       var ticketFeeActivities = _context.JuryGameTicketFees.AsNoTracking().Where(ticketFee => ticketFee.IsPublished)

           .Select(

           ticketFee => new JuryVotingUserPlayActivityQueryRow

           {

               UserId = ticketFee.UserId,

               PlayId = ticketFee.PlayId

           });
 
       return voteActivities.Union(ticketFeeActivities);

   }
 
 
   private async Task<JuryVotingComplexTableViewModel> BuildTheaterContactTableModelAsync(IReadOnlyList<JuryVotingComplexTableTabViewModel> tabs, JuryVotingComplexTableTabViewModel activeTab, string search, string sortBy, string sortDirection, int page, int pageSize, string actionName)

   {

       var trimmedSearch = search?.Trim() ?? string.Empty;

       sortBy = sortBy switch

       {

           "Phone" => "Phone",

           "ContactPersonName" => "ContactPersonName",

           "ContactPersonPhone" => "ContactPersonPhone",

           "Address" => "Address",

           "Email" => "Email",

           _ => "TheaterName"

       };
 
       var query = _context.Plays

           .AsNoTracking()

           .Where(x => x.IsPublished && x.IsActive && x.JuriOylamaStatus)

           .Select(x => new TheaterContactQueryRow

           {

               TheaterName = x.TheaterName ?? string.Empty,

               Phone = x.Phone ?? "-",

               ContactPersonName = x.ContactPersonName ?? "-",

               ContactPersonPhone = x.ContactPersonPhone ?? "-",

               Address = x.Address ?? "-",

               Email = x.Email ?? "-"

           }).Distinct();
 
       if (!string.IsNullOrWhiteSpace(trimmedSearch))

       {

           query = query.Where(x => EF.Functions.Like(x.TheaterName, $"%{trimmedSearch}%"));

       }
 
       query = (sortBy, sortDirection) switch

       {

           ("Phone", "desc") => query.OrderByDescending(x => x.Phone).ThenBy(x => x.TheaterName),

           ("Phone", _) => query.OrderBy(x => x.Phone).ThenBy(x => x.TheaterName),

           ("ContactPersonName", "desc") => query.OrderByDescending(x => x.ContactPersonName).ThenBy(x => x.TheaterName),

           ("ContactPersonName", _) => query.OrderBy(x => x.ContactPersonName).ThenBy(x => x.TheaterName),

           ("ContactPersonPhone", "desc") => query.OrderByDescending(x => x.ContactPersonPhone).ThenBy(x => x.TheaterName),

           ("ContactPersonPhone", _) => query.OrderBy(x => x.ContactPersonPhone).ThenBy(x => x.TheaterName),

           ("Address", "desc") => query.OrderByDescending(x => x.Address).ThenBy(x => x.TheaterName),

           ("Address", _) => query.OrderBy(x => x.Address).ThenBy(x => x.TheaterName),

           ("Email", "desc") => query.OrderByDescending(x => x.Email).ThenBy(x => x.TheaterName),

           ("Email", _) => query.OrderBy(x => x.Email).ThenBy(x => x.TheaterName),

           ("TheaterName", "desc") => query.OrderByDescending(x => x.TheaterName),

           _ => query.OrderBy(x => x.TheaterName)

       };
 
       var totalCount = await query.CountAsync();

       var totalPages = totalCount == 0 ? 1 : (int)Math.Ceiling(totalCount / (double)pageSize);

       page = Math.Min(page, totalPages);
 
       var rows = await query

           .Skip((page - 1) * pageSize)

           .Take(pageSize)

           .ToListAsync();
 
       return new JuryVotingComplexTableViewModel

       {

           ActionName = actionName,

           CurrentTabKey = activeTab.Key,

           Tabs = tabs.Select(tabItem => new JuryVotingComplexTableTabViewModel

           {

               Title = tabItem.Title,

               Key = tabItem.Key,

               Search = tabItem.Key == activeTab.Key ? search : string.Empty,

               SearchColumn = tabItem.SearchColumn,

               SortBy = tabItem.Key == activeTab.Key ? sortBy : GetDefaultContactSortBy(tabItem.Key),

               SortDirection = tabItem.Key == activeTab.Key ? sortDirection : "asc",

               CurrentPage = tabItem.Key == activeTab.Key ? page : 1,

               PageSize = pageSize,

               TotalCount = tabItem.Key == activeTab.Key ? totalCount : 0,

               Columns = GetContactColumns(tabItem.Key),

               Data = tabItem.Key == activeTab.Key ? rows.Select(BuildTheaterContactRow).ToList() : []

           }).ToList()

       };

   }
 
   private async Task<JuryVotingComplexTableViewModel> BuildUserContactTableModelAsync(IReadOnlyList<JuryVotingComplexTableTabViewModel> tabs, JuryVotingComplexTableTabViewModel activeTab, string search, string sortBy, string sortDirection, int page, int roleCode, int pageSize, string actionName)

   {

       var includeGroupName = activeTab.Key == "jury";

       var trimmedSearch = search?.Trim() ?? string.Empty;

       sortBy = sortBy switch

       {

           "Phone" => "Phone",

           "Email" => "Email",

           "GroupName" when includeGroupName => "GroupName",

           _ => "FullName"

       };
 
       var query =

           from user in _context.Users.AsNoTracking().Where(x => x.IsPublished && x.IsActive && x.RoleCode == roleCode)

           join grp in _context.Groups.AsNoTracking().Where(x => x.IsPublished)

               on user.GroupCode equals grp.Code into userGroups

           from grp in userGroups.DefaultIfEmpty()

           select new UserContactQueryRow

           {

               FirstName = user.FirstName ?? "-",

               LastName = user.LastName ?? "-",

               IsJuryPresident = user.IsJuryPresident == false ? false : true,

               Phone = user.Phone ?? "-",

               Email = user.Email ?? "-",

               GroupName = grp != null ? grp.GroupName ?? "-" : "-",

           };

       if (!string.IsNullOrWhiteSpace(trimmedSearch))

       {

           query = query.Where(x => EF.Functions.Like((x.FirstName + " " + x.LastName).Trim(), $"%{trimmedSearch}%"));

       }
 
       query = (sortBy, sortDirection) switch

       {

           ("Phone", "desc") => query.OrderByDescending(x => x.Phone).ThenBy(x => x.FirstName).ThenBy(x => x.LastName),

           ("Phone", _) => query.OrderBy(x => x.Phone).ThenBy(x => x.FirstName).ThenBy(x => x.LastName),

           ("Email", "desc") => query.OrderByDescending(x => x.Email).ThenBy(x => x.FirstName).ThenBy(x => x.LastName),

           ("Email", _) => query.OrderBy(x => x.Email).ThenBy(x => x.FirstName).ThenBy(x => x.LastName),

           ("GroupName", "desc") => query.OrderByDescending(x => x.GroupName).ThenBy(x => x.FirstName).ThenBy(x => x.LastName),

           ("GroupName", _) => query.OrderBy(x => x.GroupName).ThenBy(x => x.FirstName).ThenBy(x => x.LastName),

           ("FullName", "desc") => query.OrderByDescending(x => x.FirstName).ThenByDescending(x => x.LastName),

           _ => query.OrderBy(x => x.FirstName).ThenBy(x => x.LastName)

       };
 
       var totalCount = await query.CountAsync();

       var totalPages = totalCount == 0 ? 1 : (int)Math.Ceiling(totalCount / (double)pageSize);

       page = Math.Min(page, totalPages);
 
       var rows = await query

           .Skip((page - 1) * pageSize)

           .Take(pageSize)

           .ToListAsync();
 
       return new JuryVotingComplexTableViewModel

       {

           ActionName = actionName,

           CurrentTabKey = activeTab.Key,

           Tabs = tabs.Select(tabItem => new JuryVotingComplexTableTabViewModel

           {

               Title = tabItem.Title,

               Key = tabItem.Key,

               Search = tabItem.Key == activeTab.Key ? search : string.Empty,

               SearchColumn = tabItem.SearchColumn,

               SortBy = tabItem.Key == activeTab.Key ? sortBy : GetDefaultContactSortBy(tabItem.Key),

               SortDirection = tabItem.Key == activeTab.Key ? sortDirection : "asc",

               CurrentPage = tabItem.Key == activeTab.Key ? page : 1,

               PageSize = pageSize,

               TotalCount = tabItem.Key == activeTab.Key ? totalCount : 0,

               Columns = GetContactColumns(tabItem.Key),

               Data = tabItem.Key == activeTab.Key ? rows.Select(row => BuildUserContactRow(row, includeGroupName)).ToList() : []

           }).ToList()

       };

   }
 
   private static IReadOnlyList<JuryVotingComplexTableColumnViewModel> BuildColumns(bool includeAssignedPlayColumn, bool includePlayStatusColumn)

   {

       var columns = new List<JuryVotingComplexTableColumnViewModel>

       {

           new() { Title = "Oyun Adı", Key = "PlayName" }

       };
 
       columns.Add(new JuryVotingComplexTableColumnViewModel

       {

           Title = "Prömiyer Tarihi",

           Key = "PremiereDate"

       });
 
       if (includeAssignedPlayColumn)

       {

           columns.Add(new JuryVotingComplexTableColumnViewModel

           {

               Title = "Görev Oyunu",

               Key = "IsAssignedPlay"

           });

       }
 
       columns.Add(new JuryVotingComplexTableColumnViewModel

       {

           Title = "Oylama Durumu",

           Key = "VoteStatus"

       });
 
       columns.Add(new JuryVotingComplexTableColumnViewModel

       {

           Title = "İzlenme Sayısı",

           Key = "TotalWatchCount"

       });
 
       if (includePlayStatusColumn)

       {

           columns.Add(new JuryVotingComplexTableColumnViewModel

           {

               Title = "Oyun Durumu",

               Key = "PlayStatus"

           });

       }
 
       columns.Add(new JuryVotingComplexTableColumnViewModel

       {

           Title = string.Empty,

           Key = string.Empty,

           IsSortable = false,

           ColumnClass = "angle-col"

       });
 
       return columns;

   }

 
        private static IReadOnlyList<JuryVotingComplexTableTabViewModel> GetGameListTabs()

        {

            return

            [

                new JuryVotingComplexTableTabViewModel { Title = "Tüm Oyunlar", Key = "all" },

                new JuryVotingComplexTableTabViewModel { Title = "Görev Oyunların", Key = "assigned" }

            ];

        }
 
        private static IReadOnlyList<JuryVotingComplexTableColumnViewModel> GetGameListColumns(string tabKey)

        {

            return tabKey switch

            {

                "assigned" =>

                [

                    new() { Title = "Oyun Adı", Key = "PlayName",ColumnClass = "a-playname-col"},

                    new() { Title = "Tiyatro Adı", Key = "TheaterName",ColumnClass = "a-theatername-col" },

                    new() { Title = "Oylama Durumu", Key = "VoteStatus",ColumnClass = "a-votestatus-col" },

                    new() { Title = "Toplam İzlenme Sayısı", Key = "TotalWatchCount",ColumnClass = "a-totalwatch-col" },

                    new() { Title = "Oyun Durumu", Key = "PlayStatus",ColumnClass = "a-playstatus-col" },

                    new() { Title = "", Key = "", IsSortable = false,ColumnClass = "angle-col" }

                ],

                _ =>

                [

                    new() { Title = "Oyun Adı", Key = "PlayName",ColumnClass = "playname-col" },

                    new() { Title = "Tiyatro Adı", Key = "TheaterName",ColumnClass = "theatername-col" },

                    new() { Title = "Görev Oyunu", Key = "GroupName",ColumnClass = "groupname-col" },

                    new() { Title = "Statü", Key = "PlayStatus",ColumnClass = "playstatus-col" },

                    new() { Title = "", Key = "", IsSortable = false ,ColumnClass = "angle-col" }

                ]

            };

        }
 
        private static IReadOnlyList<JuryVotingComplexTableTabViewModel> GetTableTabs(bool currentPlayStatusesOnly, bool assignedPlaysOnly)

        {

            if (assignedPlaysOnly)

            {

                return [new JuryVotingComplexTableTabViewModel { Title = "Görev Oyunların", Key = "all", IsOnlyActivePlays = false }];

            }
 
            if (currentPlayStatusesOnly)

            {

                return [new JuryVotingComplexTableTabViewModel { Title = "Güncel Oyunlar", Key = "all", IsOnlyActivePlays = false }];

            }
 
            return

            [

                new JuryVotingComplexTableTabViewModel { Title = "Tüm Oylanabilir Oyunlar", Key = "all", IsOnlyActivePlays = true },

                new JuryVotingComplexTableTabViewModel { Title = "Çok İzlenen Oylanabilir Oyunlar", Key = "most", IsOnlyActivePlays = true },

                new JuryVotingComplexTableTabViewModel { Title = "Az İzlenen Oylanabilir Oyunlar", Key = "least", IsOnlyActivePlays = true }

            ];

        }
 
        private static IReadOnlyList<JuryVotingComplexTableTabViewModel> GetContactTableTabs()

        {

            return

            [

                new JuryVotingComplexTableTabViewModel { Title = "Tiyatrolar", Key = "theaters", SearchColumn = "Tiyatro Adı" },

                new JuryVotingComplexTableTabViewModel { Title = "Jüri Üyeleri", Key = "jury", SearchColumn = "Ad Soyad" },

                new JuryVotingComplexTableTabViewModel { Title = "Koordinasyon", Key = "coordination", SearchColumn = "Ad Soyad" }

            ];

        }
 
        private static IReadOnlyList<JuryVotingComplexTableColumnViewModel> GetContactColumns(string tabKey)

        {

            return tabKey switch

            {

                "jury" =>

                [

                    new() { Title = "Ad Soyad", Key = "FullName" },

                    new() { Title = "Telefon", Key = "Phone" },

                    new() { Title = "E-posta Adresi", Key = "Email" },

                    new() { Title = "Jüri Grup Bilgisi", Key = "GroupName", ColumnClass="align-left"  }

                ],

                "coordination" =>

                [

                    new() { Title = "Ad Soyad", Key = "FullName" },

                    new() { Title = "Telefon", Key = "Phone" },

                    new() { Title = "E-posta Adresi", Key = "Email", ColumnClass="align-left" },

                ],

                _ =>

                [

                    new() { Title = "Tiyatro Adı", Key = "TheaterName" },

                    new() { Title = "Tiyatro Telefonu", Key = "Phone" },

                    new() { Title = "İlgili Kişi", Key = "ContactPersonName" },

                    new() { Title = "İlgili Kişi Telefonu", Key = "ContactPersonPhone" },

                    new() { Title = "Adres", Key = "Address"},

                    new() { Title = "E-posta Adresi", Key = "Email", ColumnClass="align-left"  }

                ]

            };

        }
 
        private static string GetDefaultContactSortBy(string tabKey)

        {

            return tabKey switch

            {

                "jury" or "coordination" => "FullName",

                _ => "TheaterName"

            };

        }
 
        private static JuryVotingComplexTableCellViewModel BuildVoteStatusCell(string voteStatus)

        {

            if (voteStatus == "Ek Oylama Gerekli")

            {

                return new JuryVotingComplexTableCellViewModel

                {

                    Content = "Ek Oylama Gerekli <img src=\"/icon/circle-info-yellow-solid.svg\" class=\"vote-status-info-icon\" alt=\"Ek Oylama Gerekli\" />",

                    IsHtml = true,

                    CssClass = "yellow"

                };

            }
 
            return new JuryVotingComplexTableCellViewModel

            {

                Content = voteStatus,

                CssClass = voteStatus == "Oylandı" ? "green" : "red"

            };

        }
 
        private static JuryVotingComplexTableRowViewModel BuildRow(JuryVotingPlayTableQueryRow row, bool includeAssignedPlayColumn, bool includePlayStatusColumn)

        {

            var cells = new List<JuryVotingComplexTableCellViewModel>

            {

                new() { Content = row.PlayName }

            };

            cells.Add(new JuryVotingComplexTableCellViewModel

            {

                Content = row.PremiereDate.HasValue ? row.PremiereDate.Value.ToString("dd.MM.yyyy") : "-",
 
            });

            if (includeAssignedPlayColumn)

            {

                cells.Add(new JuryVotingComplexTableCellViewModel

                {

                    Content = row.IsAssignedPlay ? "Evet" : "Hayır"

                });

            }
 
            cells.Add(BuildVoteStatusCell(row.VoteStatus));
 
            cells.Add(new JuryVotingComplexTableCellViewModel

            {

                Content = row.TotalWatchCount.ToString()

            });
 
            if (includePlayStatusColumn)

            {

                cells.Add(new JuryVotingComplexTableCellViewModel

                {

                    Content = row.PlayStatus

                });

            }
 
            cells.Add(new JuryVotingComplexTableCellViewModel

            {

                Content = "<img src=\"/icon/angle-right.svg\" alt=\"\" />",

                IsHtml = true

            });
 
            return new JuryVotingComplexTableRowViewModel

            {

                RowId = row.PlayId.ToString(),

                RowLink = $"/oylama/oylanabilir-oyunlar/{row.Slug}",

                Cells = cells

            };

        }
 
        private static JuryVotingComplexTableRowViewModel BuildGameListRow(JuryVotingPlayTableQueryRow row, string tab)

        {

            var cells = new List<JuryVotingComplexTableCellViewModel>

            {

                new() { Content = row.PlayName }
 
            };
 
            cells.Add(new JuryVotingComplexTableCellViewModel

            {

                Content = row.TheaterName

            });
 
 
            var statusColor = $"<div color='{row.StatusColor}' class='status-dot'></div>";
 
            if (tab == "assigned")

            {

                cells.Add(BuildVoteStatusCell(row.VoteStatus));
 
                cells.Add(new JuryVotingComplexTableCellViewModel

                {

                    Content = row.TotalWatchCount > 0 ? row.TotalWatchCount.ToString() : "-"

                });

                cells.Add(new JuryVotingComplexTableCellViewModel

                {

                    Content = string.Concat(statusColor, row.PlayStatus.ToString()),

                    IsHtml = true

                });

            }

            else

            {

                var juryAssignmentsHtml = BuildJuryAssignmentsHtml(row.JuryAssignments);

                cells.Add(new JuryVotingComplexTableCellViewModel

                {

                    Content = string.IsNullOrWhiteSpace(juryAssignmentsHtml) ? "-" : juryAssignmentsHtml,

                    IsHtml = !string.IsNullOrWhiteSpace(juryAssignmentsHtml),

                    CssClass = "jury-assignment-table-cell"

                });

                cells.Add(new JuryVotingComplexTableCellViewModel

                {

                    Content = string.Concat(statusColor, row.PlayStatus.ToString()),

                    IsHtml = true

                });

            }
 
            cells.Add(new JuryVotingComplexTableCellViewModel

            {

                Content = "<img src=\"/icon/angle-right.svg\" alt=\"\" />",

                IsHtml = true

            });
 
            return new JuryVotingComplexTableRowViewModel

            {

                RowId = row.PlayId.ToString(),

                RowLink = string.IsNullOrWhiteSpace(row.Slug) ? string.Empty : $"/oylama/oylanabilir-oyunlar/{row.Slug}",

                Cells = cells

            };

        }
 
        private static string BuildJuryAssignmentsHtml(IReadOnlyList<JuryAssignmentDisplayItem> assignments)

        {

            if (assignments.Count == 0)

            {

                return string.Empty;

            }
 
            var itemMarkup = string.Join(", ", assignments.Select(BuildJuryAssignmentItemHtml));

            var accessibleText = WebUtility.HtmlEncode(string.Join(", ", assignments.Select(item => item.Label)));
 
            return $"<div class=\"jury-assignment-cell\" data-jury-assignment-cell aria-label=\"{accessibleText}\">"

                + $"<div class=\"jury-assignment-summary\" data-jury-assignment-summary>{itemMarkup}</div>"

                + $"<template data-jury-assignment-template><div class=\"jury-assignment-tooltip-content\">{itemMarkup}</div></template>"

                + "</div>";

        }
 
        private static string BuildJuryAssignmentItemHtml(JuryAssignmentDisplayItem item)

        {

            var label = WebUtility.HtmlEncode(item.Label);

            if (!item.IsGroup)

            {

                return $"<span class=\"jury-assignment-person\">{label}</span>";

            }
 
            var members = WebUtility.HtmlEncode(string.Join(", ", item.GroupMembers));

            return $"<span class=\"jury-assignment-group\" tabindex=\"0\" data-jury-group-members=\"{members}\" aria-label=\"{label} grubu jürileri: {members}\">{label}</span>";

        }
 
        private static JuryVotingComplexTableRowViewModel BuildTheaterContactRow(TheaterContactQueryRow row)

        {

            return new JuryVotingComplexTableRowViewModel

            {

                RowId = row.TheaterName,

                Cells =

                [

                    new() { Content = row.TheaterName },

                    new() { Content = row.Phone },

                    new() { Content = row.ContactPersonName },

                    new() { Content = row.ContactPersonPhone },

                    new() { Content = row.Address },

                    new() { Content = row.Email }

                ]

            };

        }
 
        private static JuryVotingComplexTableRowViewModel BuildUserContactRow(UserContactQueryRow row, bool includeGroupName)

        {

            var FullName = string.Join(" ", new[] { row.FirstName, row.LastName }.Where(x => !string.IsNullOrWhiteSpace(x)));

            var cells = new List<JuryVotingComplexTableCellViewModel>

            {

                new() { Content = row.IsJuryPresident !=true ? FullName : $"{FullName} <span class=\"jury-president-tag\"><img src=\"/icon/asterisk.svg\"/>Jüri Başkanı</span>" , IsHtml=true },

                new() { Content = row.Phone },

                new() { Content = row.Email }

            };
 
            if (includeGroupName)

            {

                cells.Add(new JuryVotingComplexTableCellViewModel

                {

                    Content = row.GroupName

                });

            }
 
            return new JuryVotingComplexTableRowViewModel

            {

                RowId = (row.FirstName + row.LastName + row.Email).Replace(" ", string.Empty),

                Cells = cells

            };

        }

    }

}
