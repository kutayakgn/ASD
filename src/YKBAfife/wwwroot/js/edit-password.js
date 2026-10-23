(() => {
    document.querySelectorAll("[data-edit-password]").forEach((field) => {
        const input = field.querySelector("[data-edit-password-input]");
        const toggle = field.querySelector("[data-edit-password-toggle]");
        if (!input || !toggle) return;

        const sync = () => {
            toggle.disabled = input.value.length === 0;
            if (toggle.disabled) input.type = "password";
            const visible = input.type === "text";
            toggle.setAttribute("aria-pressed", String(visible));
            toggle.setAttribute("aria-label", visible ? "Yeni şifreyi gizle" : "Yeni şifreyi göster");
        };
        toggle.addEventListener("click", () => {
            if (!input.value) return;
            input.type = input.type === "password" ? "text" : "password";
            sync();
        });
        input.addEventListener("input", sync);
        input.addEventListener("change", sync);
        input.form?.addEventListener("reset", () => queueMicrotask(sync));
        sync();
    });
})();
