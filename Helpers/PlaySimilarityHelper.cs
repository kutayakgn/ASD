using System.Globalization;
using System.Text;

namespace YKBAfife.Helpers;

public static class PlaySimilarityHelper
{
    private const double DuplicateConfidenceThreshold = 0.95;

    public static bool AreLikelyDuplicates(
        string firstPlayName,
        string firstTheaterName,
        string secondPlayName,
        string secondTheaterName)
    {
        var playConfidence = CalculateTypoTolerantConfidence(firstPlayName, secondPlayName);
        var theaterConfidence = CalculateTypoTolerantConfidence(firstTheaterName, secondTheaterName);

        return playConfidence >= DuplicateConfidenceThreshold &&
               theaterConfidence >= DuplicateConfidenceThreshold;
    }

    private static double CalculateTypoTolerantConfidence(string first, string second)
    {
        var normalizedFirst = Normalize(first);
        var normalizedSecond = Normalize(second);
        if (normalizedFirst.Length == 0 || normalizedSecond.Length == 0)
        {
            return 0;
        }

        var maximumLength = Math.Max(normalizedFirst.Length, normalizedSecond.Length);
        var distance = CalculateDamerauLevenshteinDistance(normalizedFirst, normalizedSecond);

        // Requiring both fields to pass keeps the tolerance focused on likely typos.
        return 1d - distance / (maximumLength * 5d);
    }

    private static string Normalize(string value)
    {
        var decomposed = value
            .Trim()
            .ToLower(new CultureInfo("tr-TR"))
            .Replace('ı', 'i')
            .Normalize(NormalizationForm.FormD);
        var result = new StringBuilder(decomposed.Length);
        var pendingSpace = false;

        foreach (var character in decomposed)
        {
            if (CharUnicodeInfo.GetUnicodeCategory(character) == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }

            if (char.IsLetterOrDigit(character))
            {
                if (pendingSpace && result.Length > 0)
                {
                    result.Append(' ');
                }

                result.Append(character);
                pendingSpace = false;
            }
            else
            {
                pendingSpace = result.Length > 0;
            }
        }

        return result.ToString();
    }

    private static int CalculateDamerauLevenshteinDistance(string first, string second)
    {
        var distances = new int[first.Length + 1, second.Length + 1];
        for (var row = 0; row <= first.Length; row++)
        {
            distances[row, 0] = row;
        }

        for (var column = 0; column <= second.Length; column++)
        {
            distances[0, column] = column;
        }

        for (var row = 1; row <= first.Length; row++)
        {
            for (var column = 1; column <= second.Length; column++)
            {
                var substitutionCost = first[row - 1] == second[column - 1] ? 0 : 1;
                distances[row, column] = Math.Min(
                    Math.Min(
                        distances[row - 1, column] + 1,
                        distances[row, column - 1] + 1),
                    distances[row - 1, column - 1] + substitutionCost);

                if (row > 1 &&
                    column > 1 &&
                    first[row - 1] == second[column - 2] &&
                    first[row - 2] == second[column - 1])
                {
                    distances[row, column] = Math.Min(
                        distances[row, column],
                        distances[row - 2, column - 2] + substitutionCost);
                }
            }
        }

        return distances[first.Length, second.Length];
    }
}