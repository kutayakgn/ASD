using System.Data;
using System.Security.Cryptography;
using System.Xml;
using System.Xml.Linq;
using Microsoft.AspNetCore.DataProtection.Repositories;
using Microsoft.Data.SqlClient;

namespace YKBAfife.Services.Authentication;

/// <summary>
/// Framework-owned Data Protection XML, stored once and never updated/removed.
/// The application's normal migration creates the table before serving traffic.
/// </summary>
public sealed class SqlSharedAdminDataProtectionXmlRepository(IConfiguration configuration) : IXmlRepository
{
    private string ConnectionString => configuration.GetConnectionString("AfifeConnectionString")
        ?? throw new InvalidOperationException("The shared admin key-store connection is not configured.");

    public IReadOnlyCollection<XElement> GetAllElements()
    {
        using var connection = new SqlConnection(ConnectionString);
        connection.Open();
        using var command = connection.CreateCommand();
        command.CommandText = "SELECT [Xml] FROM dbo.SharedAdminDataProtectionKeys ORDER BY CreatedAtUtc, Id;";
        using var reader = command.ExecuteReader();
        var elements = new List<XElement>();
        while (reader.Read())
        {
            try
            {
                using var text = new StringReader(reader.GetString(0));
                using var xml = XmlReader.Create(text, new XmlReaderSettings
                {
                    DtdProcessing = DtdProcessing.Prohibit,
                    XmlResolver = null,
                    MaxCharactersInDocument = 1024 * 1024
                });
                elements.Add(XElement.Load(xml, LoadOptions.PreserveWhitespace));
            }
            catch (XmlException)
            {
                // Do not include key XML, parser excerpts or a fallback key ring.
                throw new CryptographicException("The shared admin Data Protection key store contains invalid XML.");
            }
        }
        return elements;
    }

    public void StoreElement(XElement element, string friendlyName)
    {
        ArgumentNullException.ThrowIfNull(element);
        using var connection = new SqlConnection(ConnectionString);
        connection.Open();
        using var command = connection.CreateCommand();
        command.CommandText = """
            INSERT dbo.SharedAdminDataProtectionKeys (Id, FriendlyName, [Xml], CreatedAtUtc, IsPublished)
            VALUES (@id, @name, @xml, SYSUTCDATETIME(), 1);
            """;
        command.Parameters.Add("@id", SqlDbType.UniqueIdentifier).Value = Guid.NewGuid();
        command.Parameters.Add("@name", SqlDbType.NVarChar, 255).Value = (object?)friendlyName ?? DBNull.Value;
        command.Parameters.Add("@xml", SqlDbType.NVarChar, -1).Value = element.ToString(SaveOptions.DisableFormatting);
        command.ExecuteNonQuery();
    }
}
