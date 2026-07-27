(() => {
    document.addEventListener("click", async (event) => {
        const toggle = event.target.closest("[data-complex-table-toggle-url]");
        if (!toggle || toggle.disabled) return;

        event.preventDefault();
        event.stopPropagation();

        const section = toggle.closest("[data-complex-table]");
        const token = section?.querySelector('input[name="__RequestVerificationToken"]')?.value;
        const url = toggle.dataset.complexTableToggleUrl;
        if (!token || !url) {
            window.genericPopup?.fail("Stat\u00fc g\u00fcncelleme i\u015flemi ba\u015flat\u0131lamad\u0131.");
            return;
        }

        const currentValue = toggle.getAttribute("aria-checked") === "true";
        const formData = new FormData();
        formData.set("__RequestVerificationToken", token);
        formData.set("isActive", String(!currentValue));
        toggle.disabled = true;
        toggle.setAttribute("aria-busy", "true");
        let remainDisabled = false;

        try {
            const response = await fetch(url, {
                method: "POST",
                body: formData,
                headers: { "X-Requested-With": "XMLHttpRequest" }
            });
            const result = await response.json().catch(() => ({}));
            if (!response.ok) {
                throw new Error(result.message || `Statü güncellenemedi (${response.status}).`);
            }
            const isActive = result.isActive === true;
            remainDisabled = result.isDisabled === true;
            toggle.setAttribute("aria-checked", String(isActive));
            toggle.classList.toggle("is-active", isActive);
            if (result.refreshTable === true && section) {
                section.dispatchEvent(new CustomEvent("complex-table:update", { bubbles: true }));
            }
        } catch (error) {
            console.error(error);
            window.genericPopup?.fail("Stat\u00fc g\u00fcncellenemedi. L\u00fctfen tekrar deneyiniz.");
        } finally {
            toggle.disabled = remainDisabled;
            toggle.setAttribute("aria-disabled", String(remainDisabled));
            toggle.removeAttribute("aria-busy");
        }
    });
})();
