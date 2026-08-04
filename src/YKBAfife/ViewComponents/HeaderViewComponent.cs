using Microsoft.AspNetCore.Mvc;
using YKBAfife.Models.Components;

namespace YKBAfife.ViewComponents;

public sealed class HeaderViewComponent : ViewComponent
{
    public IViewComponentResult Invoke(bool showNavigation = true)
    {
        return View(new HeaderViewModel
        {
            UserFullName = User.Identity?.Name ?? "Yönetici",
            ShowNavigation = showNavigation
        });
    }
}
