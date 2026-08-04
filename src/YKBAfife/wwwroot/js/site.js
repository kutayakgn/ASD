(() => {
    const mobileBreakpoint = window.matchMedia("(max-width: 1199.98px)");
    const toggle = document.querySelector("[data-mobile-nav-toggle]");
    const navigation = document.querySelector(".admin-navigation");
    const backdrop = document.querySelector(".admin-mobile-nav-backdrop");
    if (!toggle || !navigation || !backdrop) return;

    const setOpen = (open) => {
        const shouldOpen = open && mobileBreakpoint.matches;
        navigation.classList.toggle("is-open", shouldOpen);
        backdrop.hidden = !shouldOpen;
        toggle.setAttribute("aria-expanded", shouldOpen ? "true" : "false");
        toggle.setAttribute("aria-label", shouldOpen ? "Menüyü kapat" : "Menüyü aç");
        const navigationIsHidden = mobileBreakpoint.matches && !shouldOpen;
        navigation.setAttribute("aria-hidden", navigationIsHidden ? "true" : "false");
        navigation.inert = navigationIsHidden;
        document.body.classList.toggle("mobile-nav-open", shouldOpen);

        if (shouldOpen) {
            window.requestAnimationFrame(() => navigation.querySelector("[data-mobile-nav-dismiss]")?.focus());
        }
    };

    toggle.addEventListener("click", () => {
        setOpen(!navigation.classList.contains("is-open"));
    });

    document.querySelectorAll("[data-mobile-nav-dismiss]").forEach((element) => {
        element.addEventListener("click", () => {
            setOpen(false);
            toggle.focus();
        });
    });

    navigation.addEventListener("click", (event) => {
        if (event.target.closest("a") && mobileBreakpoint.matches) {
            setOpen(false);
        }
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && navigation.classList.contains("is-open")) {
            setOpen(false);
            toggle.focus();
        }
    });

    mobileBreakpoint.addEventListener("change", () => setOpen(false));
    setOpen(false);
})();