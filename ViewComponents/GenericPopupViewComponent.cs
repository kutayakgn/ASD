using Microsoft.AspNetCore.Mvc;
using YKBAfife.Models.Components;

namespace YKBAfife.ViewComponents;

public sealed class GenericPopupViewComponent : ViewComponent
{
    public IViewComponentResult Invoke()
    {
        return View(new GenericPopupViewModel
        {
            InitialType = TempData["GenericPopup.Type"]?.ToString() ?? string.Empty,
            InitialMessage = TempData["GenericPopup.Message"]?.ToString() ?? string.Empty,
            InitialRedirectUrl = TempData["GenericPopup.RedirectUrl"]?.ToString() ?? string.Empty
        });
    }
}
