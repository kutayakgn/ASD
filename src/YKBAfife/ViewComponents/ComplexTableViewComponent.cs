using Microsoft.AspNetCore.Mvc;
using YKBAfife.Models.Components;

namespace YKBAfife.ViewComponents;

public sealed class ComplexTableViewComponent : ViewComponent
{
    public IViewComponentResult Invoke(ComplexTableViewModel model)
    {
        ValidateColumnWidths(model);
        return View(model);
    }

    private static void ValidateColumnWidths(ComplexTableViewModel model)
    {
        if (model.MinimumTableWidth <= 0)
        {
            throw new InvalidOperationException("Complex table minimum width must be greater than zero.");
        }

        foreach (var tab in model.Tabs)
        {
            if (tab.Columns.Count == 0)
            {
                continue;
            }

            var usesPixelWidths = tab.Columns.Any(column => column.ColWidth.IsPixel);
            if (usesPixelWidths)
            {
                if (tab.Columns.Any(column => !column.ColWidth.IsPixel))
                {
                    throw new InvalidOperationException(
                        $"Every column in complex table tab '{tab.Key}' must use pixel widths when one pixel width is defined.");
                }

                if (tab.Columns.Any(column => column.ColWidth.Value <= 2))
                {
                    throw new InvalidOperationException(
                        $"Every pixel ColWidth in complex table tab '{tab.Key}' must be greater than the two-pixel border allowance.");
                }

                continue;
            }

            if (tab.Columns.Any(column => column.ColWidth.Value <= 0))
            {
                throw new InvalidOperationException(
                    $"Every column in complex table tab '{tab.Key}' must have a ColWidth greater than zero.");
            }

            var totalWidth = tab.Columns.Sum(column => column.ColWidth.Value);
            if (totalWidth != 100)
            {
                throw new InvalidOperationException(
                    $"Column ColWidth values in complex table tab '{tab.Key}' must total 100. Current total: {totalWidth}.");
            }
        }
    }
}
