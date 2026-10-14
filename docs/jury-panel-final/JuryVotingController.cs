using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using YkbAfife.Business.Service.JuryVoting;
using YkbAfife.Domain.Model.Data.JuryVoting;
namespace YkbAfife.Controllers
{
    public class JuryVotingController : Controller
    {
        private
        const string JuryVotingSessionKey = "JuryVotingAuthenticated";
        private
        const string JuryVotingUserIdSessionKey = "JuryVotingUserId";
        private
        const string JuryVotingUserFullNameSessionKey = "JuryVotingUserFullName";
        private readonly IJuryVotingCaptchaService _captchaService;
        private readonly IJuryVotingService _juryVotingService;
        private readonly IJuryForgotPasswordRequestLimiter _forgotPasswordRequestLimiter;
        private readonly JuryVotingPasswordResetOptions _passwordResetOptions;
        public JuryVotingController(
            IJuryVotingCaptchaService captchaService,
            IJuryVotingService juryVotingService,
            IJuryForgotPasswordRequestLimiter forgotPasswordRequestLimiter,
            IOptions<JuryVotingPasswordResetOptions> passwordResetOptions)
        {
            _captchaService = captchaService;
            _juryVotingService = juryVotingService;
            _forgotPasswordRequestLimiter = forgotPasswordRequestLimiter;
            _passwordResetOptions = passwordResetOptions.Value;
        }
        [HttpGet("oylama")]
        public IActionResult Index()
        {
            return IsAuthenticated() ? RedirectToAction(nameof(Home)) : RedirectToAction(nameof(Login));
        }
        [HttpGet("oylama/giris-yap")]
        public IActionResult Login()
        {
            if (IsAuthenticated())
            {
                return RedirectToAction(nameof(Home));
            }
            ViewData["Login"] = "true";
            ViewData["PasswordResetEnabled"] = _passwordResetOptions.Enabled;
            return View(new JuryLoginViewModel
            {
                Password = ""
            });
        }
        [HttpPost("oylama/giris-yap")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(JuryLoginViewModel model)
        {
            ViewData["Login"] = "true";
            ViewData["PasswordResetEnabled"] = _passwordResetOptions.Enabled;
            if (string.IsNullOrWhiteSpace(model.CaptchaToken) || !_captchaService.VerifyToken(model.CaptchaToken))
            {
                ModelState.AddModelError(nameof(model.CaptchaToken), "Lütfen robot doğrulamasını tamamlayın.");
            }
            if (!ModelState.IsValid)
            {
                return View(model);
            }
            var authenticatedUser = await _juryVotingService.AuthenticateUserAsync(model.UserName, model.Password);
            if (authenticatedUser.HasValue)
            {
                HttpContext.Session.SetString(JuryVotingSessionKey, "true");
                HttpContext.Session.SetString(JuryVotingUserIdSessionKey, authenticatedUser.Value.UserId.ToString());
                HttpContext.Session.SetString(JuryVotingUserFullNameSessionKey, authenticatedUser.Value.FullName);
                return RedirectToAction(nameof(Home));
            }
            ViewBag.LoginError = "Kullanıcı adı veya şifre hatalı.";
            return View(model);
        }
        [HttpGet("oylama/anasayfa")]
        public async Task<IActionResult> Home()
        {
            var redirectResult = EnsureAuthenticated();
            if (redirectResult is not null)
            {
                return redirectResult;
            }
            if (!TryGetAuthenticatedUserId(out
                    var authenticatedUserId))
            {
                return RedirectToAction(nameof(Login));
            }
            SetActivePage("Anasayfa");
            var model = await _juryVotingService.BuildHomeViewModelAsync(authenticatedUserId, Url.Action(nameof(GameList), "JuryVoting", new
            {
                tab = "assigned"
            }, Request.Scheme) ?? string.Empty, Url.Action(nameof(Plays), "JuryVoting", new
            {
                tab = "most"
            }, Request.Scheme) ?? string.Empty, Url.Action(nameof(Plays), "JuryVoting", new
            {
                tab = "least"
            }, Request.Scheme) ?? string.Empty);
            return View(model);
        }
        [HttpGet("oylama/oylanabilir-oyunlar")]
        public async Task<IActionResult> Plays(string tab = "all", string search = "", string sortBy = "PlayName", string sortDirection = "asc", int page = 1)
        {
            var redirectResult = EnsureAuthenticated();
            if (redirectResult is not null)
            {
                return redirectResult;
            }
            if (!TryGetAuthenticatedUserId(out
                    var authenticatedUserId))
            {
                return RedirectToAction(nameof(Login));
            }
            SetActivePage("Oyunlar");
            var model = new JuryVotingPlaysViewModel
            {
                Table = await _juryVotingService.BuildPlaysTableModelAsync(authenticatedUserId, tab, search, sortBy, sortDirection, page, actionName: nameof(Plays))
            };
            if (IsAjaxRequest())
            {
                return PartialView("~/Views/JuryVoting/Shared/Components/_ComplexTable.cshtml", model.Table);
            }
            return View(model);
        }
        [HttpGet("oylama/oyun-listesi")]
        public async Task<IActionResult> GameList(string tab = "all", string search = "", string sortBy = "PlayName", string sortDirection = "asc", int page = 1)
        {
            var redirectResult = EnsureAuthenticated();
            if (redirectResult is not null)
            {
                return redirectResult;
            }
            if (!TryGetAuthenticatedUserId(out
                    var authenticatedUserId))
            {
                return RedirectToAction(nameof(Login));
            }
            SetActivePage("OyunListesi");
            var model = new JuryVotingPlaysViewModel
            {
                Table = await _juryVotingService.BuildGameListTableModelAsync(authenticatedUserId, tab, search, sortBy, sortDirection, page, actionName: nameof(GameList))
            };
            if (IsAjaxRequest())
            {
                return PartialView("~/Views/JuryVoting/Shared/Components/_ComplexTable.cshtml", model.Table);
            }
            return View("Plays", model);
        }
        [HttpGet("oylama/oylanabilir-oyunlar/{playSlug}")]
        public async Task<IActionResult> PlayDetailAsync(string playSlug = "")
        {
            var redirectResult = EnsureAuthenticated();
            if (redirectResult is not null)
            {
                return redirectResult;
            }
            if (!TryGetAuthenticatedUserId(out
                    var authenticatedUserId))
            {
                return RedirectToAction(nameof(Login));
            }
            SetActivePage("OyunDetay");
            var model = await _juryVotingService.BuildPlayDetailPageModelAsync(authenticatedUserId, playSlug);
            return View(model);
        }
        [HttpPost("oylama/oy-kaydet")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> SaveVote(
            [FromBody] SaveVoteRequest? request)
        {
            request ??= new SaveVoteRequest();
            var correlationId = Guid.TryParse(Request.Headers["X-Correlation-ID"].FirstOrDefault(), out
                var suppliedCorrelationId) ? suppliedCorrelationId : Guid.NewGuid();
            request.OperationContext = new JuryOperationContext
            {
                CorrelationId = correlationId,
                IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString(),
                UserAgent = Request.Headers.UserAgent.ToString(),
                HttpMethod = Request.Method,
                RequestPath = Request.Path,
                ControllerName = nameof(JuryVotingController),
                ActionName = nameof(SaveVote)
            };
            Response.Headers["X-Correlation-ID"] = correlationId.ToString();
            // Oturum yokluğu da başarısız JuryLogs kaydı üretir.
            var authenticatedUserId = TryGetAuthenticatedUserId(out
                var juryId) ? juryId : Guid.Empty;
            var result = await _juryVotingService.SaveVoteAsync(authenticatedUserId, request);
            var responseBody = new
            {
                isSuccessful = result == JuryVotingSaveVoteResult.Success,
                resultCode = result.ToString(),
                correlationId
            };
            return result
            switch
            {
                JuryVotingSaveVoteResult.Success => Ok(responseBody),
                JuryVotingSaveVoteResult.Unauthorized => Unauthorized(responseBody),
                JuryVotingSaveVoteResult.PlayNotFound => NotFound(responseBody),
                JuryVotingSaveVoteResult.UnexpectedError => StatusCode(StatusCodes.Status500InternalServerError, responseBody),
                JuryVotingSaveVoteResult.ConcurrencyConflict or
            JuryVotingSaveVoteResult.AdditionalVotingAlreadyUsed or
            JuryVotingSaveVoteResult.TicketFeeAlreadySaved => Conflict(responseBody),
                JuryVotingSaveVoteResult.JuryNotEligible or
            JuryVotingSaveVoteResult.PlayNotEligible or
            JuryVotingSaveVoteResult.SourceFormNotEligible or
            JuryVotingSaveVoteResult.PlayStatusNotValidForVoting or
            JuryVotingSaveVoteResult.VotingClosed or
            JuryVotingSaveVoteResult.Blacklisted or
            JuryVotingSaveVoteResult.AdditionalVotingNotAvailable => StatusCode(StatusCodes.Status403Forbidden, responseBody),
                _ => BadRequest(responseBody)
            };
        }
        [HttpGet("oylama/iletisim")]
        public async Task<IActionResult> Contact(string tab = "theaters", string search = "", string sortBy = "TheaterName", string sortDirection = "asc", int page = 1)
        {
            var redirectResult = EnsureAuthenticated();
            if (redirectResult is not null)
            {
                return redirectResult;
            }
            SetActivePage("Iletisim");
            var model = new JuryVotingPlaysViewModel
            {
                Table = await _juryVotingService.BuildContactTableModelAsync(tab, search, sortBy, sortDirection, page, actionName: nameof(Contact))
            };
            if (IsAjaxRequest())
            {
                return PartialView("~/Views/JuryVoting/Shared/Components/_ComplexTable.cshtml", model.Table);
            }
            return View(model);
        }
        [HttpGet("oylama/sifre-degistir")]
        public IActionResult ChangePassword(bool passwordChanged = false)
        {
            var redirectResult = EnsureAuthenticated();
            if (redirectResult is not null)
            {
                return redirectResult;
            }
            ViewData["ChangePasswordSuccessMessage"] = passwordChanged ? "Şifreniz başarıyla güncellendi." : string.Empty;
            return View(new JuryChangePasswordViewModel());
        }
        [HttpPost("oylama/sifre-degistir")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ChangePassword(JuryChangePasswordViewModel model)
        {
            var redirectResult = EnsureAuthenticated();
            if (redirectResult is not null)
            {
                return redirectResult;
            }
            if (!TryGetAuthenticatedUserId(out
                    var authenticatedUserId))
            {
                return RedirectToAction(nameof(Login));
            }
            if (!ModelState.IsValid)
            {
                return View(model);
            }
            var result = await _juryVotingService.ChangePasswordAsync(authenticatedUserId, model.OldPassword, model.NewPassword);
            if (result == JuryVotingChangePasswordResult.Success)
            {
                return RedirectToAction(nameof(ChangePassword), new
                {
                    passwordChanged = true
                });
            }
            if (result == JuryVotingChangePasswordResult.OldPasswordIncorrect)
            {
                ModelState.AddModelError(nameof(model.OldPassword), "Girdiğiniz şifre geçersizdir. Lütfen tekrar deneyin.");
                return View(model);
            }
            return RedirectToAction(nameof(Login));
        }
        [HttpGet("oylama/sifremi-unuttum")]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult ForgotPassword(bool requested = false)
        {
            if (!_passwordResetOptions.Enabled)
            {
                return NotFound();
            }

            ViewData["Login"] = "true";
            ViewData["ForgotPasswordRequested"] = requested;
            return View(new JuryForgotPasswordViewModel());
        }

        [HttpPost("oylama/sifremi-unuttum")]
        [ValidateAntiForgeryToken]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public async Task<IActionResult> ForgotPassword(JuryForgotPasswordViewModel model)
        {
            if (!_passwordResetOptions.Enabled)
            {
                return NotFound();
            }

            ViewData["Login"] = "true";
            var remoteIpAddress = HttpContext.Connection.RemoteIpAddress?.ToString();
            if (!_forgotPasswordRequestLimiter.TryAcquire(remoteIpAddress))
            {
                Response.StatusCode = StatusCodes.Status429TooManyRequests;
                ModelState.AddModelError(string.Empty,
                    "Çok fazla şifre sıfırlama isteği gönderdiniz. Lütfen daha sonra tekrar deneyin.");
                return View(model);
            }

            if (!ModelState.IsValid)
            {
                return View(model);
            }

            await _juryVotingService.SendForgotPasswordLinkAsync(model.Email);
            return RedirectToAction(nameof(ForgotPassword), new { requested = true });
        }

        [HttpGet("oylama/sifre-sifirla")]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public async Task<IActionResult> ResetPassword(string token)
        {
            if (!_passwordResetOptions.Enabled)
            {
                return NotFound();
            }

            ViewData["Login"] = "true";
            Response.Headers["Referrer-Policy"] = "no-referrer";
            Response.Headers["X-Robots-Tag"] = "noindex, nofollow";

            if (!await _juryVotingService.IsResetTokenValidAsync(token))
            {
                return View("ResetPasswordInvalid");
            }

            return View(new JuryResetPasswordViewModel { Token = token });
        }

        [HttpPost("oylama/sifre-sifirla")]
        [ValidateAntiForgeryToken]
        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public async Task<IActionResult> ResetPassword(JuryResetPasswordViewModel model)
        {
            if (!_passwordResetOptions.Enabled)
            {
                return NotFound();
            }

            ViewData["Login"] = "true";
            Response.Headers["Referrer-Policy"] = "no-referrer";
            Response.Headers["X-Robots-Tag"] = "noindex, nofollow";

            if (!await _juryVotingService.IsResetTokenValidAsync(model.Token))
            {
                return View("ResetPasswordInvalid");
            }

            if (!ModelState.IsValid)
            {
                return View(model);
            }

            var result = await _juryVotingService.ResetPasswordAsync(model.Token, model.NewPassword);
            if (result == YkbAfife.Business.Service.JuryVoting.JuryVotingResetPasswordResult.Success)
            {
                TempData["ResetPasswordSuccess"] = "Şifreniz başarıyla güncellendi.";
                return RedirectToAction(nameof(Login));
            }

            return View("ResetPasswordInvalid");
        }
        [HttpPost("oylama/cikis-yap")]
        [ValidateAntiForgeryToken]
        public IActionResult Logout()
        {
            HttpContext.Session.Remove(JuryVotingSessionKey);
            HttpContext.Session.Remove(JuryVotingUserIdSessionKey);
            HttpContext.Session.Remove(JuryVotingUserFullNameSessionKey);
            return RedirectToAction(nameof(Login));
        }
        private bool IsAuthenticated()
        {
            return HttpContext.Session.GetString(JuryVotingSessionKey) == "true";
        }
        private IActionResult? EnsureAuthenticated()
        {
            return IsAuthenticated() ? null : RedirectToAction(nameof(Login));
        }
        private bool TryGetAuthenticatedUserId(out Guid userId)
        {
            var userIdValue = HttpContext.Session.GetString(JuryVotingUserIdSessionKey);
            return Guid.TryParse(userIdValue, out userId);
        }
        private bool IsAjaxRequest()
        {
            return string.Equals(Request.Headers["X-Requested-With"], "XMLHttpRequest", StringComparison.OrdinalIgnoreCase);
        }
        private void SetActivePage(string activePage)
        {
            ViewData["ActivePage"] = activePage;
        }
    }
}
