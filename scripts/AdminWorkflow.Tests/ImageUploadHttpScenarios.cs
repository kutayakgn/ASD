using System.Net.Http.Headers;
using System.Text;
using Microsoft.EntityFrameworkCore;
using YKBAfife.Business.Helpers;
using YKBAfife.Data;
using YKBAfife.Models.Entities;

internal static class ImageUploadHttpScenarios
{
    // Synthetic 2x2 images, generated from plain colors. No user photo is
    // embedded in source control: the optional local sample is read only at run time.
    private static readonly byte[] Jpeg = Convert.FromBase64String(
        "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAACAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD7V/Z2+C3w91v9n74ZajqPgTwzf6heeF9MuLm7utHt5JZ5XtImd3dkJZmJJJJySSTRRRXyOL/3ip/if5nwmO/3qr/il+bP/9k=");
    private static readonly byte[] Png = Convert.FromBase64String(
        "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAXSURBVBhXY/jPwPCfoYHhPwMDw38wAABD1Al4TlSdlQAAAABJRU5ErkJggg==");
    private static readonly byte[] Webp = Convert.FromBase64String(
        "UklGRjgAAABXRUJQVlA4ICwAAADQAQCdASoCAAIAAUAmJaACdLoB+AADsAD+4uC/8zRMcx+1f/5SrwWNzfAAAA==");

    public static async Task RunAsync(HttpClient client, DbContextOptions<AfifeContext> options,
        Func<string, string> antiforgery, Action<bool, string> check)
    {
        await using var db = new AfifeContext(options);
        var originalHashes = await Hashes();
        using var addPage = await client.GetAsync("juri-ekle");
        check(addPage.IsSuccessStatusCode, "The jury creation page renders before multipart image upload scenarios.");
        var token = antiforgery(await addPage.Content.ReadAsStringAsync());
        const string password = "UploadWorkflow42<>";
        var cases = new List<UploadCase>
        {
            new("jpeg.disguised", Jpeg, "portrait.png", "image/png", "portrait.jpg", "image/jpeg"),
            new("jpeg.octet", Jpeg, "portrait.dat", "application/octet-stream", "portrait.jpg", "image/jpeg"),
            new("jpeg.no.mime", Jpeg, "portrait.png", null, "portrait.jpg", "image/jpeg"),
            new("png.disguised", Png, "portrait.jpg", "image/jpeg", "portrait.png", "image/png"),
            new("webp.disguised", Webp, "portrait.png", "image/png", "portrait.webp", "image/webp"),
            new("jpeg.matched", Jpeg, "portrait.jpeg", "image/jpeg", "portrait.jpeg", "image/jpeg"),
            new("png.matched", Png, "portrait.png", "image/png", "portrait.png", "image/png")
        };
        var localSample = Environment.GetEnvironmentVariable("AFIFE_TEST_UPLOAD_SAMPLE");
        if (!string.IsNullOrWhiteSpace(localSample))
        {
            cases.Add(new("local.sample", await File.ReadAllBytesAsync(localSample), Path.GetFileName(localSample),
                "image/png", Path.ChangeExtension(Path.GetFileName(localSample), ".jpg"), "image/jpeg"));
        }

        User? target = null;
        foreach (var upload in cases)
        {
            var username = "uploads." + upload.Suffix;
            using var body = Body(username, password, upload);
            using var response = await client.PostAsync("juri-ekle", body);
            var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(item => item.Username == username && item.RoleCode == 2);
            check(response.IsSuccessStatusCode && user?.PhotoImageId is not null,
                $"AddJury accepts real {upload.ExpectedType} bytes independently of the submitted MIME and extension ({upload.Suffix}).");
            var image = await db.Images.IgnoreQueryFilters().AsNoTracking().SingleAsync(item => item.Id == user!.PhotoImageId);
            check(image.IsPublished && image.ContentType == upload.ExpectedType && image.FileName == upload.ExpectedName &&
                  image.ImageData.SequenceEqual(upload.Data),
                "The created image stores byte-exact data and the detected content type/normalized filename: " + upload.Suffix + ".");
            using var photoResponse = await client.GetAsync($"juriler/{user!.Id}/fotograf");
            check(photoResponse.IsSuccessStatusCode && photoResponse.Content.Headers.ContentType?.MediaType == upload.ExpectedType &&
                  (await photoResponse.Content.ReadAsByteArrayAsync()).SequenceEqual(upload.Data),
                "The jury photo endpoint serves the normalized MIME with the unchanged original image bytes.");
            target ??= user;
        }

        check(target is not null, "A jury created with a disguised JPEG is available for photo-only edit regressions.");
        var editTarget = target!;
        var targetHash = editTarget.PasswordHash;
        check(PasswordHashHelper.VerifyPassword(password, targetHash), "Image normalization does not alter the newly created user's chosen password.");
        foreach (var upload in new[]
        {
            new UploadCase("edit.png", Png, "updated.jpeg", "application/octet-stream", "updated.png", "image/png"),
            new UploadCase("edit.jpeg", Jpeg, "updated.jpg", null, "updated.jpg", "image/jpeg")
        })
        {
            var before = await CurrentTarget();
            using var body = Body(editTarget.Username, "", upload, editTarget.Id);
            using var response = await client.PostAsync($"juriler/{editTarget.Id}/duzenle", body);
            var after = await CurrentTarget();
            var image = await db.Images.IgnoreQueryFilters().AsNoTracking().SingleAsync(item => item.Id == after.PhotoImageId);
            check(response.IsSuccessStatusCode && after.PhotoImageId != before.PhotoImageId &&
                  image.ContentType == upload.ExpectedType && image.FileName == upload.ExpectedName && image.ImageData.SequenceEqual(upload.Data),
                "A jury photo-only edit accepts mismatched metadata and stores the detected format without transcoding.");
            check(after.PasswordHash == targetHash && after.Username == before.Username && after.Email == before.Email &&
                  after.FirstName == before.FirstName && after.LastName == before.LastName && after.GroupCode == before.GroupCode,
                "Replacing a photo preserves the user's existing password hash, profile and group relationship.");
            check(await db.Images.IgnoreQueryFilters().AsNoTracking().AnyAsync(item => item.Id == before.PhotoImageId && !item.IsPublished),
                "Replacing a normalized image retains the preceding photo through the existing soft-delete flow.");
        }

        var invalidCases = new[]
        {
            new UploadCase("fake", Encoding.UTF8.GetBytes("This is not image data."), "fake.png", "image/png", "", ""),
            new UploadCase("truncated.jpeg", Jpeg[..^2], "truncated.png", "image/png", "", ""),
            new UploadCase("truncated.png", Png[..^12], "truncated.jpg", "image/jpeg", "", ""),
            new UploadCase("truncated.webp", Webp[..^1], "truncated.webp", "image/webp", "", ""),
            new UploadCase("unsupported", Convert.FromBase64String("R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="), "disguised.jpg", "image/jpeg", "", ""),
            new UploadCase("empty", [], "empty.png", "image/png", "", "")
        };
        foreach (var upload in invalidCases)
        {
            var usersBefore = await db.Users.IgnoreQueryFilters().CountAsync();
            var imagesBefore = await db.Images.IgnoreQueryFilters().CountAsync();
            using (var body = Body("uploads.bad." + upload.Suffix, password, upload))
            using (var response = await client.PostAsync("juri-ekle", body))
            {
                check(response.IsSuccessStatusCode && await db.Users.IgnoreQueryFilters().CountAsync() == usersBefore &&
                      await db.Images.IgnoreQueryFilters().CountAsync() == imagesBefore,
                    "Invalid/unsupported/truncated bytes cannot create a jury or image despite their claimed filename and MIME: " + upload.Suffix + ".");
            }
            var before = await CurrentTarget();
            using (var body = Body(editTarget.Username, "", upload, editTarget.Id))
            using (var response = await client.PostAsync($"juriler/{editTarget.Id}/duzenle", body))
            {
                var after = await CurrentTarget();
                check(response.IsSuccessStatusCode && after.PhotoImageId == before.PhotoImageId && after.PasswordHash == targetHash &&
                      await db.Images.IgnoreQueryFilters().CountAsync() == imagesBefore,
                    "A rejected photo edit preserves the current image, image history and existing hash: " + upload.Suffix + ".");
            }
        }
        var afterHashes = await Hashes();
        check(originalHashes.All(pair => afterHashes.TryGetValue(pair.Key, out var hash) && hash == pair.Value),
            "Every account that existed before the image-upload scenarios retains its original password hash byte-exact.");

        MultipartFormDataContent Body(string username, string submittedPassword, UploadCase upload, Guid? userId = null)
        {
            var body = new MultipartFormDataContent();
            var fields = new Dictionary<string, string>
            {
                ["__RequestVerificationToken"] = token,
                ["Username"] = username,
                ["Email"] = username + "@example.invalid",
                ["FullName"] = "Upload Sample",
                ["Phone"] = "5550000000",
                ["Password"] = submittedPassword,
                ["IsActive"] = "true",
                ["IsJuryPresident"] = "false"
            };
            if (userId.HasValue)
            {
                fields["Id"] = userId.Value.ToString();
                fields["RemovePhoto"] = "false";
                fields["GroupCode"] = "";
            }
            foreach (var (key, value) in fields) body.Add(new StringContent(value), key);
            var file = new ByteArrayContent(upload.Data);
            if (upload.DeclaredType is not null) file.Headers.ContentType = new MediaTypeHeaderValue(upload.DeclaredType);
            body.Add(file, "Photo", upload.SubmittedName);
            return body;
        }
        Task<User> CurrentTarget() => db.Users.IgnoreQueryFilters().AsNoTracking().SingleAsync(user => user.Id == editTarget.Id);
        Task<Dictionary<Guid, string>> Hashes() => db.Users.IgnoreQueryFilters().AsNoTracking().ToDictionaryAsync(user => user.Id, user => user.PasswordHash);
    }

    private sealed record UploadCase(string Suffix, byte[] Data, string SubmittedName, string? DeclaredType,
        string ExpectedName, string ExpectedType);
}
