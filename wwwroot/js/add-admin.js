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
        if (invalidFields.length === 0) return;

        event.preventDefault();
        event.stopImmediatePropagation();
        const messages = [...new Set(invalidFields.map(validationMessage))];
        window.genericPopup?.fail(messages.join("\n"));
    }, true);
})();