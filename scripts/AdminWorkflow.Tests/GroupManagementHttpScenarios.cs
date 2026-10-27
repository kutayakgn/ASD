using System.Net;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Models.Entities;
using Group = YKBAfife.Models.Entities.Group;

internal static class GroupManagementHttpScenarios
{
    public static async Task RunAsync(HttpClient client, DbContextOptions<AfifeContext> options,
        Func<string, string> antiforgery, Action<bool, string> check)
    {
        await using var db = new AfifeContext(options);
        const int originalCode = 870001;
        const int changedCode = 870002;
        const int directCode = 870003;
        const int hiddenCode = 870004;
        const int occupiedCode = 870005;
        const string name = "Zeta HTTP jury group & checked";
        var hidden = new Group { Id = Guid.NewGuid(), Code = hiddenCode, GroupName = "Hidden HTTP group", IsPublished = false, CreatedAt = DateTime.UtcNow };
        var occupied = new Group { Id = Guid.NewGuid(), Code = occupiedCode, GroupName = "Alpha HTTP group", IsPublished = true, CreatedAt = DateTime.UtcNow };
        db.Groups.AddRange(hidden, occupied);
        await db.SaveChangesAsync();
        // Added entities are published by AfifeContext's persistence rules.
        // Model an existing unpublished row with a separate database update.
        await db.Groups.IgnoreQueryFilters().Where(item => item.Id == hidden.Id)
            .ExecuteUpdateAsync(update => update.SetProperty(item => item.IsPublished, false));
        var addPage = await Page("diger-ayarlar/gruplar/ekle");
        var token = antiforgery(addPage);
        var groupCount = await db.Groups.IgnoreQueryFilters().CountAsync();

        using (var response = await client.PostAsync("diger-ayarlar/gruplar/ekle", GroupBody(null, originalCode.ToString(), name, false)))
            check(response.StatusCode == HttpStatusCode.BadRequest && await db.Groups.IgnoreQueryFilters().CountAsync() == groupCount,
                "Group creation without antiforgery is rejected without inserting a group.");
        using (var response = await client.PostAsync("diger-ayarlar/gruplar/ekle", GroupBody(null, "invalid-code", name)))
            check(response.IsSuccessStatusCode && await db.Groups.IgnoreQueryFilters().CountAsync() == groupCount,
                "A malformed group Code redisplays validation without creating a record.");
        using (var response = await client.PostAsync("diger-ayarlar/gruplar/ekle", GroupBody(null, "", name)))
            check(response.IsSuccessStatusCode && await db.Groups.IgnoreQueryFilters().CountAsync() == groupCount,
                "A missing group Code is not silently interpreted as zero.");
        using (var response = await client.PostAsync("diger-ayarlar/gruplar/ekle", GroupBody(null, originalCode.ToString(), new string('x', 101))))
            check(response.IsSuccessStatusCode && await db.Groups.IgnoreQueryFilters().CountAsync() == groupCount,
                "A group name exceeding the SQL column's 100-character limit is rejected before persistence.");
        using (var response = await client.PostAsync("diger-ayarlar/gruplar/ekle", GroupBody(null, originalCode.ToString(), " ")))
            check(response.IsSuccessStatusCode && await db.Groups.IgnoreQueryFilters().CountAsync() == groupCount,
                "Whitespace-only group names are rejected.");
        using (var response = await client.PostAsync("diger-ayarlar/gruplar/ekle", GroupBody(null, originalCode.ToString(), name)))
            check(response.IsSuccessStatusCode, "A group can be created through authenticated HTTP.");
        var group = await db.Groups.IgnoreQueryFilters().AsNoTracking().SingleAsync(item => item.Code == originalCode);
        check(group.IsPublished && group.GroupName == name && group.CreatedBy.HasValue,
            "Group creation persists exactly Code and GroupName plus server-owned publication and audit fields.");
        using (var response = await client.PostAsync("diger-ayarlar/gruplar/ekle", GroupBody(null, originalCode.ToString(), "Duplicate active")))
            check(response.IsSuccessStatusCode && await db.Groups.IgnoreQueryFilters().CountAsync() == groupCount + 1,
                "Duplicate published group codes return validation instead of an SQL/server error.");
        using (var response = await client.PostAsync("diger-ayarlar/gruplar/ekle", GroupBody(null, hiddenCode.ToString(), "Duplicate hidden")))
            check(response.IsSuccessStatusCode && await db.Groups.IgnoreQueryFilters().CountAsync() == groupCount + 1,
                "Codes belonging to unpublished groups are not silently reused.");

        var settings = await Page("diger-ayarlar");
        check(settings.Contains("group-settings", StringComparison.Ordinal) && settings.Contains(WebUtility.HtmlEncode(name), StringComparison.Ordinal),
            "Other Settings renders the new group section and safely encodes group names.");
        using (var response = await client.PostAsync("diger-ayarlar/gruplar/tablo", new FormUrlEncodedContent(new Dictionary<string, string>
        { ["__RequestVerificationToken"] = token })))
        {
            var html = await response.Content.ReadAsStringAsync();
            check(response.IsSuccessStatusCode && html.Contains(WebUtility.HtmlEncode(name), StringComparison.Ordinal) &&
                  !html.Contains(hidden.GroupName, StringComparison.Ordinal),
                "The refresh endpoint returns published groups only, including after AJAX deletes.");
        }

        var jury = Account("groups.current", "Group Current", 2);
        var inactive = Account("groups.inactive", "Group Inactive", 2, active: false);
        var retired = Account("groups.retired", "Group Retired", 2, published: false);
        var admin = Account("groups.admin", "Group Admin", 1);
        inactive.GroupCode = retired.GroupCode = admin.GroupCode = originalCode;
        db.Users.AddRange(jury, inactive, retired, admin);
        await db.SaveChangesAsync();
        await db.Users.IgnoreQueryFilters().Where(user => user.Id == retired.Id)
            .ExecuteUpdateAsync(update => update.SetProperty(user => user.IsPublished, false));
        var baselineHashes = await Hashes();
        var editPath = $"juriler/{jury.Id}/duzenle";
        var editPage = await Page(editPath);
        var select = GroupSelect(editPage);
        check(!Regex.IsMatch(select, @"\bmultiple(?:\s|=|>)", RegexOptions.IgnoreCase) &&
              select.Contains($"value=\"{originalCode}\"", StringComparison.Ordinal) &&
              !select.Contains($"value=\"{hiddenCode}\"", StringComparison.Ordinal) &&
              select.Contains("value=\"\"", StringComparison.Ordinal),
            "Jury group selection is a single dropdown containing published groups and an explicit unassigned choice.");
        var renderedGroups = GroupOptions(select).Where(option => option.Value.Length > 0).ToArray();
        var expectedGroups = await db.Groups.AsNoTracking().OrderBy(item => item.Code)
            .Select(item => new { item.Code, item.GroupName }).ToArrayAsync();
        check(renderedGroups.Select(option => option.Value).SequenceEqual(expectedGroups.Select(item =>
                  item.Code.ToString(System.Globalization.CultureInfo.InvariantCulture))),
            "Jury group choices follow numeric Code order even when the group names have the opposite alphabetical order.");
        check(renderedGroups.Select(option => option.Text).SequenceEqual(expectedGroups.Select(item => item.GroupName)),
            "Every jury group option displays only GroupName; Code is retained solely as the submitted value.");
        using (var response = await client.PostAsync(editPath, JuryBody(jury, "not-an-integer")))
        {
            var html = await response.Content.ReadAsStringAsync();
            check(response.IsSuccessStatusCode && await UserCode(jury.Id) is null &&
                  GroupSelect(html).Contains($"value=\"{originalCode}\"", StringComparison.Ordinal),
                "Malformed group selections remain validation errors after ModelState normalization and repopulate the dropdown.");
        }
        using (var response = await client.PostAsync(editPath, JuryBody(jury, hiddenCode.ToString())))
            check(response.IsSuccessStatusCode && await UserCode(jury.Id) is null,
                "A forged unpublished group selection is rejected by the jury edit endpoint.");
        using (var response = await client.PostAsync(editPath, JuryBody(jury, originalCode.ToString())))
            check(response.IsSuccessStatusCode && await UserCode(jury.Id) == originalCode,
                "A group-only jury edit saves the selected group while leaving the password blank.");
        var details = await Page($"juriler/{jury.Id}");
        var groupDetails = Regex.Match(WebUtility.HtmlDecode(details),
            @"<dt>\s*Jüri Grubu\s*</dt>\s*<dd>(?<value>.*?)</dd>", RegexOptions.Singleline);
        check(groupDetails.Success && Regex.Replace(groupDetails.Groups["value"].Value, "<[^>]+>", "").Trim() == name,
            "Jury details displays only the assigned GroupName, without appending its Code.");

        // Exercise a group rejection after validation has already succeeded:
        // a concurrent change is reported as the same trigger error. The test
        // trigger is limited to one disposable user and always removed.
        var beforeConflict = await UserSnapshot(jury.Id);
        // DDL cannot parameterize the embedded trigger predicate. Its sole
        // interpolated value is a freshly generated Guid, never user input.
#pragma warning disable EF1002
        await db.Database.ExecuteSqlRawAsync($"""
            CREATE TRIGGER dbo.[TR_GroupWorkflow_ForcedSaveConflict] ON dbo.Users AFTER UPDATE
            AS
            BEGIN
                SET NOCOUNT ON;
                IF UPDATE(GroupCode) AND EXISTS (SELECT 1 FROM inserted WHERE Id = '{jury.Id}')
                    THROW 52821, N'Forced disposable workflow group conflict.', 1;
            END;
            """);
#pragma warning restore EF1002
        try
        {
            using var response = await client.PostAsync(editPath, JuryBody(jury, occupiedCode.ToString(),
                "Group Rejected Rename", "groups.rejected@example.invalid", "GroupsRejected99<>"));
            var html = await response.Content.ReadAsStringAsync();
            check(response.IsSuccessStatusCode && response.RequestMessage?.RequestUri?.AbsolutePath == "/" + editPath &&
                  WebUtility.HtmlDecode(html).Contains("Değişiklikler uygulanmadı", StringComparison.Ordinal),
                "An actual SQL52821 failure after successful validation returns the jury edit view with a group error, not HTTP500.");
            check(await UserSnapshot(jury.Id) == beforeConflict,
                "A late SQL group rejection rolls back the group, name, email, replacement password and user audit fields together.");
            check(GroupSelect(html).Contains($"value=\"{occupiedCode}\"", StringComparison.Ordinal) &&
                  !html.Contains("GroupsRejected99", StringComparison.Ordinal),
                "The late group-conflict view repopulates valid choices and never reflects the submitted replacement password.");
        }
        finally
        {
            await db.Database.ExecuteSqlRawAsync("DROP TRIGGER IF EXISTS dbo.[TR_GroupWorkflow_ForcedSaveConflict];");
        }

        using (var response = await client.PostAsync($"diger-ayarlar/gruplar/{group.Id}/duzenle", GroupBody(group.Id, occupiedCode.ToString(), "Rejected duplicate")))
            check(response.IsSuccessStatusCode && await GroupCode(group.Id) == originalCode && await UserCode(jury.Id) == originalCode,
                "Editing a group's Code to an occupied Code preserves the group and every membership atomically.");
        using (var response = await client.PostAsync($"diger-ayarlar/gruplar/{group.Id}/duzenle", GroupBody(group.Id, changedCode.ToString(), "Updated HTTP group")))
            check(response.IsSuccessStatusCode && await GroupCode(group.Id) == changedCode,
                "The group editor changes Code and GroupName without mutating an EF-tracked alternate key.");
        var linkedIds = new[] { jury.Id, inactive.Id, retired.Id, admin.Id };
        check(await db.Users.IgnoreQueryFilters().AsNoTracking().CountAsync(user => linkedIds.Contains(user.Id) && user.GroupCode == changedCode) == 4,
            "A group Code change cascades to active, inactive, unpublished and admin Users while preserving group identity.");
        await db.Database.ExecuteSqlInterpolatedAsync($"UPDATE dbo.[Group] SET Code = {directCode} WHERE Id = {group.Id}");
        check(await db.Users.IgnoreQueryFilters().AsNoTracking().CountAsync(user => linkedIds.Contains(user.Id) && user.GroupCode == directCode) == 4,
            "Direct SQL Code updates use the same FK cascade and cannot strand any account membership.");
        var rebound = GroupSelect(await Page(editPath));
        check(Regex.IsMatch(rebound, $"<option\\b(?=[^>]*value=\"{directCode}\")(?=[^>]*selected)[^>]*>", RegexOptions.IgnoreCase),
            "Jury editing selects the new group Code after cascading an existing membership.");

        var blocked = await Delete(group.Id);
        check(blocked.Status == HttpStatusCode.Conflict && !blocked.Success &&
              new[] { jury, inactive }.All(user => blocked.Message.Contains(user.Username, StringComparison.Ordinal) &&
                  blocked.Message.Contains(user.FirstName + " " + user.LastName, StringComparison.Ordinal)) &&
              new[] { retired, admin }.All(user => !blocked.Message.Contains(user.Username, StringComparison.Ordinal) &&
                  !blocked.Message.Contains(user.FirstName + " " + user.LastName, StringComparison.Ordinal)),
            "Deleting a group lists only its published juries, including inactive juries; deleted juries and admins are not blockers.");
        check(await IsPublished(group.Id), "A blocked deletion does not unpublish the group.");
        check(await SqlRejected($"UPDATE dbo.[Group] SET IsPublished = 0 WHERE Id = '{group.Id}'") && await IsPublished(group.Id),
            "The SQL guard also rejects direct soft deletion of a group that still has published jury memberships.");
        check(await SqlRejected($"DELETE dbo.[Group] WHERE Id = '{group.Id}'") && await IsPublished(group.Id),
            "Physical DELETE follows the protected soft-delete rule without losing the assigned group.");
        check(await SqlRejected($"UPDATE dbo.Users SET GroupCode = {hiddenCode} WHERE Id = '{jury.Id}'") && await UserCode(jury.Id) == directCode,
            "Direct assignment to an unpublished group is rejected without replacing the existing membership.");

        using (var response = await client.PostAsync(editPath, JuryBody(jury, "")))
            check(response.IsSuccessStatusCode && await UserCode(jury.Id) is null,
                "The Grupsuz choice severs the selected jury's membership without rewriting a password.");
        var stillBlocked = await Delete(group.Id);
        check(!stillBlocked.Success && await IsPublished(group.Id) &&
              stillBlocked.Message.Contains(inactive.Username, StringComparison.Ordinal),
            "Removing the active jury is insufficient while a published inactive jury still references the group.");
        await db.Users.IgnoreQueryFilters().Where(user => user.Id == inactive.Id)
            .ExecuteUpdateAsync(update => update.SetProperty(user => user.GroupCode, (int?)null));
        var retiredBeforeDeletion = await UserSnapshot(retired.Id);
        var adminBeforeDeletion = await UserSnapshot(admin.Id);
        using (var response = await client.PostAsync($"diger-ayarlar/gruplar/{group.Id}/sil", new FormUrlEncodedContent(new Dictionary<string, string>())))
            check(response.StatusCode == HttpStatusCode.BadRequest && await IsPublished(group.Id),
                "Even a group without published jury members cannot be deleted without an antiforgery token.");
        var deleted = await Delete(group.Id);
        check(deleted.Status == HttpStatusCode.OK && deleted.Success && !await IsPublished(group.Id) &&
              await db.Groups.IgnoreQueryFilters().AsNoTracking().AnyAsync(item => item.Id == group.Id),
            "A group referenced only by a deleted jury and an admin is removed through HTTP with soft deletion and its row preserved.");
        check(await UserCode(retired.Id) == directCode && await UserCode(admin.Id) == directCode &&
              await UserSnapshot(retired.Id) == retiredBeforeDeletion && await UserSnapshot(admin.Id) == adminBeforeDeletion,
            "HTTP group deletion preserves deleted-jury/admin GroupCode links and every field of both users byte-exact.");
        check((await Hashes()).OrderBy(pair => pair.Key).SequenceEqual(baselineHashes.OrderBy(pair => pair.Key)),
            "Group CRUD, cascade, failed deletes and jury group edits leave all password hashes byte-exact.");
        check(await db.Users.IgnoreQueryFilters().AsNoTracking().CountAsync(user => linkedIds.Contains(user.Id)) == 4,
            "Group management removes no user records.");

        // The revised rule also applies to SQL clients: historical/admin links
        // remain intact whether they request soft deletion or physical DELETE.
        foreach (var physicalDelete in new[] { false, true })
        {
            var suffix = physicalDelete ? "delete" : "unpublish";
            var sqlCode = physicalDelete ? 870007 : 870006;
            var sqlGroup = new Group
            {
                Id = Guid.NewGuid(), Code = sqlCode, GroupName = "Direct SQL group " + suffix,
                IsPublished = true, CreatedAt = DateTime.UtcNow
            };
            var deletedJury = Account("groups.sql." + suffix + ".retired", "SQL DeletedJury", 2);
            var linkedAdmin = Account("groups.sql." + suffix + ".admin", "SQL Admin", 1);
            deletedJury.GroupCode = linkedAdmin.GroupCode = sqlCode;
            db.Groups.Add(sqlGroup);
            db.Users.AddRange(deletedJury, linkedAdmin);
            await db.SaveChangesAsync();
            await db.Users.IgnoreQueryFilters().Where(user => user.Id == deletedJury.Id)
                .ExecuteUpdateAsync(update => update.SetProperty(user => user.IsPublished, false));
            var deletedJuryBefore = await UserSnapshot(deletedJury.Id);
            var linkedAdminBefore = await UserSnapshot(linkedAdmin.Id);
            var hashesBeforeSql = await Hashes();
            if (physicalDelete)
                await db.Database.ExecuteSqlInterpolatedAsync($"DELETE dbo.[Group] WHERE Id = {sqlGroup.Id}");
            else
                await db.Database.ExecuteSqlInterpolatedAsync($"UPDATE dbo.[Group] SET IsPublished = 0 WHERE Id = {sqlGroup.Id}");
            check(await db.Groups.IgnoreQueryFilters().AsNoTracking().AnyAsync(item => item.Id == sqlGroup.Id && !item.IsPublished),
                "Direct SQL " + suffix + " succeeds with only deleted-jury/admin references and retains the Group row.");
            check(await UserCode(deletedJury.Id) == sqlCode && await UserCode(linkedAdmin.Id) == sqlCode &&
                  await UserSnapshot(deletedJury.Id) == deletedJuryBefore && await UserSnapshot(linkedAdmin.Id) == linkedAdminBefore &&
                  (await Hashes()).OrderBy(pair => pair.Key).SequenceEqual(hashesBeforeSql.OrderBy(pair => pair.Key)),
                "Direct SQL " + suffix + " preserves historical/admin user records, GroupCode links and all password hashes byte-exact.");
        }

        FormUrlEncodedContent GroupBody(Guid? id, string code, string groupName, bool csrf = true)
        {
            var values = new Dictionary<string, string> { ["Code"] = code, ["GroupName"] = groupName };
            if (csrf) values["__RequestVerificationToken"] = token;
            if (id.HasValue) values["Id"] = id.Value.ToString();
            return new FormUrlEncodedContent(values);
        }
        FormUrlEncodedContent JuryBody(User user, string code, string? fullName = null, string? email = null, string password = "") => new(new Dictionary<string, string>
        {
            ["__RequestVerificationToken"] = token, ["Id"] = user.Id.ToString(), ["Username"] = user.Username,
            ["Email"] = email ?? user.Email, ["FullName"] = fullName ?? user.FirstName + " " + user.LastName, ["Phone"] = user.Phone!,
            ["Password"] = password, ["IsActive"] = "true", ["IsJuryPresident"] = "false", ["RemovePhoto"] = "false", ["GroupCode"] = code
        });
        async Task<string> Page(string path)
        {
            using var response = await client.GetAsync(path);
            check(response.IsSuccessStatusCode, "A group-management/jury page renders successfully over authenticated HTTP.");
            return await response.Content.ReadAsStringAsync();
        }
        async Task<(HttpStatusCode Status, bool Success, string Message)> Delete(Guid id)
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, $"diger-ayarlar/gruplar/{id}/sil")
            { Content = new FormUrlEncodedContent(new Dictionary<string, string> { ["__RequestVerificationToken"] = token }) };
            request.Headers.Add("X-Requested-With", "XMLHttpRequest");
            using var response = await client.SendAsync(request);
            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
            return (response.StatusCode, json.RootElement.GetProperty("success").GetBoolean(), json.RootElement.GetProperty("message").GetString() ?? "");
        }
        async Task<bool> SqlRejected(string sql)
        {
            try { await db.Database.ExecuteSqlRawAsync(sql); return false; }
            catch (SqlException error) when (error.Errors.Cast<SqlError>().Any(item => item.Number >= 50000)) { return true; }
        }
        Task<int> GroupCode(Guid id) => db.Groups.IgnoreQueryFilters().AsNoTracking().Where(item => item.Id == id).Select(item => item.Code).SingleAsync();
        Task<int?> UserCode(Guid id) => db.Users.IgnoreQueryFilters().AsNoTracking().Where(item => item.Id == id).Select(item => item.GroupCode).SingleAsync();
        Task<bool> IsPublished(Guid id) => db.Groups.IgnoreQueryFilters().AsNoTracking().Where(item => item.Id == id).Select(item => item.IsPublished).SingleAsync();
        Task<Dictionary<Guid, string>> Hashes() => db.Users.IgnoreQueryFilters().AsNoTracking().ToDictionaryAsync(user => user.Id, user => user.PasswordHash);
        async Task<string> UserSnapshot(Guid id) => JsonSerializer.Serialize(await db.Users.IgnoreQueryFilters().AsNoTracking()
            .Where(user => user.Id == id).Select(user => new
            {
                user.Id, user.Username, user.FirstName, user.LastName, user.Email, user.Phone, user.PasswordHash, user.PhotoImageId,
                user.GroupCode, user.RoleCode, user.IsActive, user.IsPublished, user.IsJuryPresident,
                user.CreatedAt, user.CreatedBy, user.UpdatedAt, user.UpdatedBy
            }).SingleAsync());
    }

    private static string GroupSelect(string html) => Regex.Matches(html, @"<select\b[^>]*>.*?</select>", RegexOptions.IgnoreCase | RegexOptions.Singleline)
        .Select(match => match.Value).Single(select => Regex.IsMatch(select, "\\bname=\"GroupCode\"", RegexOptions.IgnoreCase));

    private static IEnumerable<(string Value, string Text)> GroupOptions(string select) =>
        Regex.Matches(select, @"<option\b(?<attributes>[^>]*)>(?<text>.*?)</option>", RegexOptions.IgnoreCase | RegexOptions.Singleline)
            .Select(match => (
                WebUtility.HtmlDecode(Regex.Match(match.Groups["attributes"].Value, "\\bvalue=\"(?<value>[^\"]*)\"", RegexOptions.IgnoreCase).Groups["value"].Value),
                WebUtility.HtmlDecode(Regex.Replace(match.Groups["text"].Value, "<[^>]+>", "")).Trim()));

    private static User Account(string username, string name, int role, bool active = true, bool published = true)
    {
        var pieces = name.Split(' ', 2);
        return new User
        {
            Id = Guid.NewGuid(), Username = username, FirstName = pieces[0], LastName = pieces[1], Email = username + "@example.invalid",
            Phone = "5550000000", PasswordHash = PasswordHashHelper.HashPassword("GroupsWorkflow42<>"),
            RoleCode = role, CreatedAt = DateTime.UtcNow, IsPublished = published, IsActive = active
        };
    }
}
