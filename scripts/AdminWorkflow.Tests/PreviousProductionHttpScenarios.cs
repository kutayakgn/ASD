using System.Globalization;
using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Data;
using YKBAfife.Models.Entities;

// Runs through the already-authenticated disposable HTTP application. This is
// intentionally separate from SQL guard tests: the response and rendered
// category choices must enforce the same rule before a DB exception occurs.
internal static class PreviousProductionHttpScenarios
{
    public static async Task RunAsync(HttpClient client, DbContextOptions<AfifeContext> options,
        Func<string, string> antiforgery, Action<bool, string> check)
    {
        await using var db = new AfifeContext(options);
        var normal = FormFixture("PPH001", false, "Normal HTTP director");
        var previous = FormFixture("PPH002", true, "Submitted true director must be cleared");
        var nullDirector = FormFixture("PPH003", false, null);
        db.Forms.AddRange(normal, previous, nullDirector);
        await db.SaveChangesAsync();
        var plays = await db.Plays.AsNoTracking()
            .Where(play => play.SourceFormId == normal.Id || play.SourceFormId == previous.Id || play.SourceFormId == nullDirector.Id)
            .ToDictionaryAsync(play => play.SourceFormId!.Value);
        check(plays.Count == 3, "HTTP candidate fixtures use real linked normal, previous-production and NULL-director Plays.");
        var normalPlay = plays[normal.Id];
        var previousPlay = plays[previous.Id];
        var nullPlay = plays[nullDirector.Id];
        check(await db.PlayAwardCategories.AsNoTracking().CountAsync(candidate => candidate.PlayId == normalPlay.Id &&
            candidate.AwardCategoryCode == 1002 && candidate.IsPublished && candidate.IsCurrent) == 1,
            "A normal HTTP fixture with a director has its real 1002 slot.");
        check(!await db.PlayAwardCategories.AsNoTracking().AnyAsync(candidate => candidate.PlayId == nullPlay.Id &&
            candidate.AwardCategoryCode == 1002 && (candidate.IsPublished || candidate.IsActive || candidate.IsCurrent)),
            "A normal HTTP fixture with NULL director has no usable 1002 slot.");

        var previousHtml = await Page(previousPlay);
        var normalHtml = await Page(normalPlay);
        var nullHtml = await Page(nullPlay);
        check(CategoryChoices(previousHtml).SequenceEqual(new[] { 1003, 1004, 1005, 1006 }),
            "The previous-production add-candidate dropdown renders only categories 1003-1006.");
        check(CategoryChoices(normalHtml).SequenceEqual(Enumerable.Range(1003, 9)),
            "The normal-production dropdown retains technical categories 1007-1011.");
        check(CategoryChoices(nullHtml).SequenceEqual(Enumerable.Range(1003, 9)),
            "An optional NULL director does not suppress technical categories for a normal production.");
        var token = antiforgery(previousHtml);
        var beforeForbidden = await CandidateSnapshot();
        foreach (var category in new[] { 1002, 1007, 1008, 1009, 1010, 1011 })
        {
            using var response = await Add(previousPlay, previousPlay.Id, category, "Rejected technical " + category);
            check(response.IsSuccessStatusCode && response.RequestMessage?.RequestUri?.AbsolutePath == "/oyunlar/" + previousPlay.Slug,
                "A tampered forbidden add follows the existing failure-popup redirect instead of returning a server error.");
            check(await CandidateSnapshot() == beforeForbidden,
                "The HTTP add guard rejects each excluded category without inserting or changing any candidate.");
        }
        foreach (var category in Enumerable.Range(1003, 4))
        {
            var name = "Allowed HTTP performer " + category;
            using var response = await Add(previousPlay, previousPlay.Id, category, name);
            check(response.IsSuccessStatusCode && await db.PlayAwardCategories.AsNoTracking().AnyAsync(candidate =>
                candidate.PlayId == previousPlay.Id && candidate.AwardCategoryCode == category && candidate.Candidate == name &&
                candidate.IsPublished && candidate.IsCurrent && candidate.IsActive),
                "Each permitted performer category can actually be added through authenticated HTTP.");
        }
        check(await ExcludedFieldsAreNull(previous.Id), "Allowed HTTP additions preserve all six excluded Form fields as SQL NULL.");

        var performer = await db.PlayAwardCategories.AsNoTracking().SingleAsync(candidate => candidate.PlayId == previousPlay.Id &&
            candidate.AwardCategoryCode == 1003 && candidate.IsPublished && candidate.IsCurrent);
        using (var response = await client.GetAsync($"adaylar/{performer.Id}/duzenle"))
            check(response.IsSuccessStatusCode, "An allowed previous-production candidate retains its edit screen.");
        using (var response = await Edit(performer.Id, "Edited HTTP performer", performer.Role!, previousPlay.Id))
            check(response.IsSuccessStatusCode && await db.PlayAwardCategories.AsNoTracking().AnyAsync(candidate =>
                candidate.Id == performer.Id && candidate.Candidate == "Edited HTTP performer" && candidate.PlayId == previousPlay.Id),
                "An allowed previous-production candidate can be edited through authenticated HTTP.");
        check(await ExcludedFieldsAreNull(previous.Id), "HTTP candidate editing does not repopulate excluded Director/technical data.");

        const string technicalName = "Allowed normal HTTP stage person";
        using (var response = await Add(normalPlay, normalPlay.Id, 1007, technicalName))
            check(response.IsSuccessStatusCode && await db.PlayAwardCategories.AsNoTracking().AnyAsync(candidate =>
                candidate.PlayId == normalPlay.Id && candidate.AwardCategoryCode == 1007 && candidate.Candidate == technicalName &&
                candidate.IsPublished && candidate.IsCurrent), "A normal production still accepts a technical candidate through HTTP.");
        var technical = await db.PlayAwardCategories.AsNoTracking().SingleAsync(candidate => candidate.PlayId == normalPlay.Id &&
            candidate.AwardCategoryCode == 1007 && candidate.Candidate == technicalName && candidate.IsPublished && candidate.IsCurrent);
        var beforeTampering = await CandidateSnapshot();
        using (var response = await Add(previousPlay, normalPlay.Id, 1007, "Mismatched normal play"))
            check(response.StatusCode == HttpStatusCode.NotFound && await CandidateSnapshot() == beforeTampering,
                "A previous-production slug cannot be combined with another normal PlayId to bypass the category guard.");
        using (var response = await Add(normalPlay, previousPlay.Id, 1007, "Mismatched previous play"))
            check(response.StatusCode == HttpStatusCode.NotFound && await CandidateSnapshot() == beforeTampering,
                "A normal slug cannot be combined with another previous-production PlayId to bypass the category guard.");

        // Edit uses the persisted candidate's parent/category, never an extra
        // posted PlayId or category field that is absent from the edit model.
        using (var response = await Edit(technical.Id, "Edited normal HTTP stage person", technical.Role!, previousPlay.Id))
            check(response.IsSuccessStatusCode && await db.PlayAwardCategories.AsNoTracking().AnyAsync(candidate =>
                candidate.Id == technical.Id && candidate.PlayId == normalPlay.Id && candidate.AwardCategoryCode == 1007 &&
                candidate.Candidate == "Edited normal HTTP stage person"),
                "A forged edit PlayId cannot move a normal technical candidate into the previous-production Play.");

        await db.Forms.Where(form => form.Id == normal.Id)
            .ExecuteUpdateAsync(update => update.SetProperty(form => form.PreviousProductionVersion, true));
        var retired = await db.PlayAwardCategories.IgnoreQueryFilters().AsNoTracking().SingleAsync(candidate => candidate.Id == technical.Id);
        check(!retired.IsPublished && !retired.IsActive && !retired.IsCurrent,
            "The source transition retires the technical candidate before a stale edit URL is submitted.");
        var retiredSnapshot = await CandidateSnapshot();
        using (var response = await client.GetAsync($"adaylar/{technical.Id}/duzenle"))
            check(response.StatusCode == HttpStatusCode.NotFound, "A stale retired technical candidate has no editable GET screen.");
        using (var response = await Edit(technical.Id, "Stale forbidden edit", technical.Role!, normalPlay.Id))
            check(response.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.BadRequest && await CandidateSnapshot() == retiredSnapshot,
                "A stale forbidden candidate POST is rejected and cannot change or reactivate historical data.");
        using (var response = await client.PostAsync($"adaylar/{technical.Id}/status", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["__RequestVerificationToken"] = token, ["isActive"] = "true"
        })))
            check(response.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.BadRequest && await CandidateSnapshot() == retiredSnapshot,
                "A stale forbidden status toggle cannot reactivate the retired candidate.");
        check(await ExcludedFieldsAreNull(normal.Id), "Stale candidate mutations leave the previous-production Form's six excluded fields NULL.");

        async Task<string> Page(Play play)
        {
            using var response = await client.GetAsync("oyunlar/" + play.Slug);
            check(response.IsSuccessStatusCode, "A linked production details page renders successfully over HTTP.");
            return await response.Content.ReadAsStringAsync();
        }
        Task<HttpResponseMessage> Add(Play routePlay, Guid postedPlayId, int code, string name) => client.PostAsync(
            "oyunlar/" + routePlay.Slug + "/aday-ekle", new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["__RequestVerificationToken"] = token, ["Input.Mode"] = "new", ["Input.PlayId"] = postedPlayId.ToString(),
                ["Input.AwardCategoryCode"] = code.ToString(CultureInfo.InvariantCulture), ["Input.Candidate"] = name,
                ["Input.Role"] = "HTTP role " + code, ["Input.IsActive"] = "true"
            }));
        Task<HttpResponseMessage> Edit(Guid id, string name, string role, Guid forgedParent) => client.PostAsync(
            $"adaylar/{id}/duzenle", new FormUrlEncodedContent(new Dictionary<string, string>
            {
                ["__RequestVerificationToken"] = token, ["Id"] = id.ToString(), ["Candidate"] = name, ["Role"] = role,
                ["IsActive"] = "true", ["RemovePhoto"] = "false", ["ConfirmRoleGroupUpdate"] = "false",
                ["PlayId"] = forgedParent.ToString(), ["AwardCategoryCode"] = "1007"
            }));
        async Task<bool> ExcludedFieldsAreNull(Guid id) => await db.Forms.AsNoTracking().AnyAsync(form => form.Id == id &&
            form.Director == null && form.StageDesign == null && form.ClothesDesign == null && form.LightDesign == null &&
            form.StageMusic == null && form.Choreography == null);
        async Task<string> CandidateSnapshot() => JsonSerializer.Serialize(await db.PlayAwardCategories.IgnoreQueryFilters()
            .AsNoTracking().OrderBy(candidate => candidate.Id).Select(candidate => new
            {
                candidate.Id, candidate.PlayId, candidate.Candidate, candidate.AwardCategoryCode, candidate.Role, candidate.RoleCode,
                candidate.IsPublished, candidate.IsActive, candidate.IsCurrent, candidate.UpdatedAt, candidate.UpdatedBy,
                candidate.SourceFormCandidateOrder, candidate.PhotoImageId
            }).ToListAsync());
    }

    private static int[] CategoryChoices(string html) => Regex.Matches(html, @"<button\b[^>]*>", RegexOptions.IgnoreCase)
        .Select(match => match.Value).Where(tag => tag.Contains("data-multi-candidate=", StringComparison.Ordinal))
        .Select(tag => Regex.Match(tag, "data-value=\"(?<code>[0-9]+)\"").Groups["code"].Value)
        .Where(code => code.Length > 0).Select(code => int.Parse(code, CultureInfo.InvariantCulture)).Order().ToArray();

    private static Form FormFixture(string applicationNumber, bool previous, string? director) => new()
    {
        Id = Guid.NewGuid(), ApplicationNumber = applicationNumber, CreatedDate = new DateTime(2098, 4, 1),
        RepertoireName = "Previous HTTP production " + Guid.NewGuid().ToString("N"), TheatreName = "Workflow theatre",
        PremiereDate = new DateOnly(2098, 4, 1), Display = "[]", ApplicantName = "Workflow Applicant", ApplicantRole = "Contact",
        Phone = "5550000000", Email = "previous-http@example.invalid", Director = director,
        PreviousProductionVersion = previous, IsPublished = true, IsActive = true
    };
}
