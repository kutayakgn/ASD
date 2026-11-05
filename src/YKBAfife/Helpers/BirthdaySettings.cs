using System.ComponentModel.DataAnnotations;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Unicode;
using YKBAfife.Models.ViewModels;

namespace YKBAfife.Helpers;

public static class BirthdaySettings
{
    public const string ConfigName = "BirthdaySettings";
    public const int MaximumConfigValueLength = 255;

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        Encoder = JavaScriptEncoder.Create(UnicodeRanges.All)
    };

    public static BirthdaySettingsViewModel Parse(string? configValue)
    {
        if (!string.IsNullOrWhiteSpace(configValue))
        {
            try
            {
                var model = JsonSerializer.Deserialize<BirthdaySettingsViewModel>(configValue, JsonOptions);
                if (model is not null && Validator.TryValidateObject(model, new ValidationContext(model), null, true))
                    return model;
            }
            catch (JsonException)
            {
                // An absent or malformed setting must not prevent opening the settings page.
            }
        }

        return new BirthdaySettingsViewModel
        {
            Message = "Doğum gününüz kutlu olsun",
            DisplayDays = 0
        };
    }

    public static string Serialize(BirthdaySettingsViewModel model) =>
        JsonSerializer.Serialize(model, JsonOptions);
}
