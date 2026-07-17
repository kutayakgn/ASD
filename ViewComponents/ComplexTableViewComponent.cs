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

            if (tab.Columns.Any(column => column.ColWidth <= 0))
            {
                throw new InvalidOperationException(
                    $"Every column in complex table tab '{tab.Key}' must have a ColWidth greater than zero.");
            }

            var totalWidth = tab.Columns.Sum(column => column.ColWidth);
            if (totalWidth != 100)
            {
                throw new InvalidOperationException(
                    $"Column ColWidth values in complex table tab '{tab.Key}' must total 100. Current total: {totalWidth}.");
            }
        }
    }
}