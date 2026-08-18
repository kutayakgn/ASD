namespace YKBAfife.Helpers;

public static class ImageUploadPolicy
{
    public const long MaximumFileSizeBytes = 150L * 1024 * 1024;

    // Duyuru formunda iki ayrı görsel bulunabildiği için HTTP isteği, iki adet
    // İki ayrı 150 MB dosya ile multipart üstbilgilerini taşıyabilecek büyüklükte olmalı.
    public const long MaximumRequestBodySizeBytes = 320L * 1024 * 1024;

    public const string MaximumFileSizeMessage =
        "Görsel boyutu 150 MB'dan büyük olamaz.";
}
