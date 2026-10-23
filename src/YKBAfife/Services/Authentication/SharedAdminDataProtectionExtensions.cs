using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.DataProtection.KeyManagement;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace YKBAfife.Services.Authentication;

public static class SharedAdminDataProtectionExtensions
{
    public const string ApplicationName = "YKBAfife.Admin";

    public static IServiceCollection AddSharedAdminDataProtection(
        this IServiceCollection services, IConfiguration configuration)
    {
        var protection = services.AddDataProtection().SetApplicationName(ApplicationName);
        services.TryAddSingleton<SqlSharedAdminDataProtectionXmlRepository>();
        services.AddOptions<KeyManagementOptions>()
            .Configure<SqlSharedAdminDataProtectionXmlRepository>((options, repository) =>
                options.XmlRepository = repository);

        // Every node must have the same certificate and private-key permission.
        // Without this opt-in, the SQL key store relies on its DB access controls
        // and at-rest protection; never use per-machine DPAPI in a server farm.
        var thumbprint = configuration["DataProtection:CertificateThumbprint"];
        if (!string.IsNullOrWhiteSpace(thumbprint))
            protection.ProtectKeysWithCertificate(thumbprint.Trim());

        return services;
    }
}
