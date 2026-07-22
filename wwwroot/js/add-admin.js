(() => {
    const fieldName = (field) => field
        .closest(".add-jury-field, .add-jury-status")
        ?.querySelector("label, legend")
        ?.textContent
        ?.trim();

    const validationMessage = (field) => {
        const name = fieldName(field);
        if (field.validity.valueMissing && name) {
            return `${name} alan\u0131 zorunludur.`;
        }

        return field.dataset.failMessage || `${name || "Form alan\u0131"} ge\u00e7erli de\u011fildir.`;
    };

    document.addEventListener("submit", (event) => {
        const form = event.target.closest("[data-admin-form]");
        if (!form) return;

        const invalidFields = Array.from(form.elements)
            .filter((field) => field instanceof HTMLInputElement && !field.checkValidity());
        if (invalidFields.length > 0) {
            event.preventDefault();
            event.stopImmediatePropagation();
            const messages = [...new Set(invalidFields.map(validationMessage))];
            window.genericPopup?.fail(messages.join("\n"));
            return;
        }

        if (form.matches("[data-admin-edit-form]")) {
            const normalize = (value) => value.trim().replace(/\s+/g, " ");
            const statusInputs = form.querySelectorAll('input[name="IsActive"]');
            const active = form.querySelector('input[name="IsActive"]:checked')?.value?.toLowerCase();
            const statusChanged = statusInputs.length > 0 && active !== form.dataset.initialActive;
            const changed = normalize(form.elements.Username.value) !== normalize(form.dataset.initialUsername || "") ||
                normalize(form.elements.Email.value) !== normalize(form.dataset.initialEmail || "") ||
                normalize(form.elements.FullName.value) !== normalize(form.dataset.initialFullName || "") ||
                statusChanged ||
                form.elements.Password.value.trim().length > 0;
            if (!changed) {
                event.preventDefault();
                event.stopImmediatePropagation();
                window.genericPopup?.fail("Herhangi bir de\u011fi\u015fiklik yapmad\u0131n\u0131z.");
            }
        }
    }, true);
})();