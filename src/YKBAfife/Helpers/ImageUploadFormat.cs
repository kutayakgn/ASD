using System.Buffers.Binary;

namespace YKBAfife.Helpers;

public static class ImageUploadFormat
{
    public static bool TryNormalize(
        byte[] data,
        string? submittedFileName,
        out string contentType,
        out string fileName)
    {
        contentType = string.Empty;
        fileName = string.Empty;

        string extension;
        if (IsJpeg(data))
        {
            contentType = "image/jpeg";
            extension = ".jpg";
        }
        else if (IsPng(data))
        {
            contentType = "image/png";
            extension = ".png";
        }
        else if (IsWebP(data))
        {
            contentType = "image/webp";
            extension = ".webp";
        }
        else return false;

        // Client MIME and suffixes can describe a renamed download rather than
        // its bytes. Store matching metadata without changing the image data.
        var leafName = Path.GetFileName((submittedFileName ?? string.Empty).Replace('\\', '/')).Trim();
        var submittedExtension = Path.GetExtension(leafName);
        if (string.Equals(submittedExtension, extension, StringComparison.OrdinalIgnoreCase) ||
            contentType == "image/jpeg" && string.Equals(submittedExtension, ".jpeg", StringComparison.OrdinalIgnoreCase))
            extension = submittedExtension;

        var stem = Path.GetFileNameWithoutExtension(leafName).Trim().TrimEnd('.');
        if (string.IsNullOrWhiteSpace(stem)) stem = "photo";
        var maximumStemLength = 255 - extension.Length;
        if (stem.Length > maximumStemLength)
        {
            if (char.IsHighSurrogate(stem[maximumStemLength - 1])) maximumStemLength--;
            stem = stem[..maximumStemLength];
        }
        fileName = stem + extension;
        return true;
    }

    private static bool IsJpeg(byte[] data) =>
        data.Length >= 4 &&
        data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF &&
        data[^2] == 0xFF && data[^1] == 0xD9;

    private static bool IsPng(byte[] data)
    {
        ReadOnlySpan<byte> signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        ReadOnlySpan<byte> ending = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82];
        return data.Length >= 33 &&
               data.AsSpan(0, signature.Length).SequenceEqual(signature) &&
               data.AsSpan(12, 4).SequenceEqual("IHDR"u8) &&
               data.AsSpan(data.Length - ending.Length).SequenceEqual(ending);
    }

    private static bool IsWebP(byte[] data)
    {
        if (data.Length < 16 || !data.AsSpan(0, 4).SequenceEqual("RIFF"u8) ||
            !data.AsSpan(8, 4).SequenceEqual("WEBP"u8)) return false;

        var chunk = data.AsSpan(12, 4);
        return (chunk.SequenceEqual("VP8 "u8) || chunk.SequenceEqual("VP8L"u8) || chunk.SequenceEqual("VP8X"u8)) &&
               BinaryPrimitives.ReadUInt32LittleEndian(data.AsSpan(4, 4)) == (uint)(data.Length - 8);
    }
}
