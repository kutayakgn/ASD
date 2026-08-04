(() => {
    const toggle = document.querySelector("[data-password-toggle]");
    const input = document.querySelector("[data-password-input]");
    if (!toggle || !input) return;

    toggle.addEventListener("click", () => {
        const isVisible = input.type === "text";
        input.type = isVisible ? "password" : "text";
        toggle.setAttribute("aria-pressed", String(!isVisible));
        toggle.setAttribute(
            "aria-label",
            isVisible ? "Şifreyi göster" : "Şifreyi gizle");
    });
})();
