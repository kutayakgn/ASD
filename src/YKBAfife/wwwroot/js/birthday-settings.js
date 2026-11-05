(() => {
    document.querySelectorAll("[data-birthday-settings-form]").forEach((form) => {
        const messageInput = form.elements.namedItem("Message");
        const daysInput = form.elements.namedItem("DisplayDays");
        const submitButton = form.querySelector('button[type="submit"]');
        const resultMessage = form.querySelector("[data-birthday-settings-result]");
        let saving = false;

        const showResult = (message, isError = false) => {
            resultMessage.textContent = message;
            resultMessage.classList.toggle("is-error", isError);
        };

        const showFieldError = (name, message) => {
            const input = form.elements.namedItem(name);
            const error = form.querySelector(`[data-birthday-settings-error="${name}"]`);
            if (!input || !error) return;
            error.textContent = message;
            if (message) input.setAttribute("aria-invalid", "true");
            else input.removeAttribute("aria-invalid");
        };

        const validate = () => {
            const message = messageInput.value.trim();
            const days = daysInput.value.trim();
            const messageError = !message
                ? "Mesaj zorunludur."
                : (messageInput.value.length > 200 ? "Mesaj en fazla 200 karakter olabilir." : "");
            const daysError = !/^\d+$/.test(days) || Number(days) < 0 || Number(days) > 10
                ? "Gösterim süresi 0 ile 10 arasında bir tam sayı olmalıdır."
                : "";
            showFieldError("Message", messageError);
            showFieldError("DisplayDays", daysError);
            if (messageError || daysError) {
                (messageError ? messageInput : daysInput).focus();
                return false;
            }
            return true;
        };

        form.addEventListener("input", (event) => {
            if (event.target === messageInput || event.target === daysInput) {
                showFieldError(event.target.name, "");
                showResult("");
            }
        });

        form.addEventListener("submit", async (event) => {
            event.preventDefault();
            if (saving) return;
            showResult("");
            if (!validate()) return;

            const messageWasReadOnly = messageInput.readOnly;
            const daysWereReadOnly = daysInput.readOnly;
            saving = true;
            messageInput.readOnly = true;
            daysInput.readOnly = true;
            submitButton.disabled = true;
            form.setAttribute("aria-busy", "true");

            try {
                const response = await fetch(form.action, {
                    method: "POST",
                    body: new FormData(form),
                    headers: { "X-Requested-With": "XMLHttpRequest" }
                });
                const result = await response.json().catch(() => ({}));
                if (!response.ok || result.success !== true) {
                    for (const name of ["Message", "DisplayDays"]) {
                        const errors = result.errors?.[name];
                        if (Array.isArray(errors) && errors.length > 0) {
                            showFieldError(name, errors.join(" "));
                        }
                    }
                    showResult(result.message || "Doğum günü ayarları kaydedilemedi. Lütfen tekrar deneyiniz.", true);
                    form.querySelector('[aria-invalid="true"]')?.focus();
                    return;
                }
                showResult(result.message || "Doğum günü ayarları kaydedildi.");
            } catch {
                showResult("Doğum günü ayarları kaydedilemedi. Lütfen tekrar deneyiniz.", true);
            } finally {
                saving = false;
                messageInput.readOnly = messageWasReadOnly;
                daysInput.readOnly = daysWereReadOnly;
                submitButton.disabled = false;
                form.removeAttribute("aria-busy");
            }
        });
    });
})();
