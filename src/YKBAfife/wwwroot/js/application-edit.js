(() => {
    const displaysAreEdited = (form) => form.querySelector("[data-displays-edited]")?.value.toLowerCase() === "true";
    const markDisplaysEdited = (form) => {
        const field = form.querySelector("[data-displays-edited]");
        if (field) field.value = "true";
    };

    const setRowIndex = (row, index) => {
        const previousIndex = row.dataset.displayIndex;
        const oldPrefix = `Displays[${previousIndex}]`;
        const newPrefix = `Displays[${index}]`;
        const oldIdPrefix = `application-display-${previousIndex}-`;
        const newIdPrefix = `application-display-${index}-`;
        row.querySelectorAll("*").forEach((element) => {
            for (const attribute of ["name", "id", "for", "aria-controls", "aria-describedby", "aria-labelledby", "data-valmsg-for"]) {
                const value = element.getAttribute(attribute);
                if (value === null) continue;
                element.setAttribute(attribute, value.replaceAll(oldPrefix, newPrefix).replaceAll(oldIdPrefix, newIdPrefix));
            }
        });
        row.dataset.displayIndex = String(index);
        const heading = row.querySelector("[data-display-heading]");
        if (heading) heading.textContent = `${index + 1}. Gösterim`;
    };

    document.querySelectorAll("[data-application-displays]").forEach((section) => {
        const form = section.closest("[data-application-edit-form]");
        const list = section.querySelector("[data-application-display-list]");
        const template = section.querySelector("[data-display-template]");
        const emptyMessage = section.querySelector("[data-display-empty]");
        const addButton = section.querySelector("[data-display-add]");
        if (!form || !list || !template || !emptyMessage || !addButton) return;

        const updateRows = () => {
            const rows = Array.from(list.querySelectorAll("[data-application-display-row]"));
            rows.forEach(setRowIndex);
            emptyMessage.hidden = rows.length > 0;
            return rows;
        };

        addButton.addEventListener("click", () => {
            const fragment = template.content.cloneNode(true);
            const row = fragment.querySelector("[data-application-display-row]");
            if (!row) return;
            setRowIndex(row, list.querySelectorAll("[data-application-display-row]").length);
            list.append(fragment);
            updateRows();
            window.initializeDatePickers?.(row);
            markDisplaysEdited(form);
            row.querySelector("[data-display-location]")?.focus();
        });

        list.addEventListener("click", (event) => {
            const button = event.target.closest("[data-display-remove]");
            const row = button?.closest("[data-application-display-row]");
            if (!row) return;
            const previousIndex = Number(row.dataset.displayIndex);
            row.remove();
            const rows = updateRows();
            markDisplaysEdited(form);
            const focusTarget = rows[Math.min(previousIndex, rows.length - 1)]?.querySelector("[data-display-location]") || addButton;
            focusTarget.focus();
        });

        list.addEventListener("input", (event) => {
            if (event.target.matches("[data-display-location]")) markDisplaysEdited(form);
        });
        list.addEventListener("change", (event) => {
            if (event.target.matches('input[type="hidden"][data-date-value], input[type="hidden"][data-time-value]')) {
                markDisplaysEdited(form);
            }
        });
    });

    const fieldName = (field) => field
        .closest(".add-jury-field, .add-jury-status")
        ?.querySelector("label, legend")
        ?.textContent
        ?.trim();

    const validationMessage = (field) => {
        const name = fieldName(field);
        if (field.validity?.valueMissing && name) return name + " alanı zorunludur.";
        return field.dataset.failMessage || (name || "Form alanı") + " geçerli değildir.";
    };

    document.addEventListener("submit", (event) => {
        const form = event.target.closest("[data-application-edit-form]");
        if (!form || form.dataset.applicationConfirmed === "true") return;

        const displaysEdited = displaysAreEdited(form);
        const invalidFields = Array.from(form.elements)
            .filter((field) =>
                (field instanceof HTMLInputElement || field instanceof HTMLSelectElement) &&
                field.type !== "hidden" &&
                (displaysEdited || !field.closest("[data-application-display-row]")) &&
                !field.checkValidity());
        const dateValue = form.querySelector('input[name="PremiereDate"]');
        const messages = invalidFields.map(validationMessage);
        if (!dateValue?.value) messages.push("Prömiyer tarihi zorunludur.");
        if (displaysEdited) {
            form.querySelectorAll("[data-application-display-row]").forEach((row, index) => {
                if (!row.querySelector("[data-display-location]")?.value.trim()) {
                    messages.push(`${index + 1}. gösterim için gösterim yeri zorunludur.`);
                }
                if (!row.querySelector("[data-date-value]")?.value) {
                    messages.push(`${index + 1}. gösterim için tarih seçiniz.`);
                }
            });
        }

        if (messages.length > 0) {
            event.preventDefault();
            event.stopImmediatePropagation();
            window.genericPopup?.fail([...new Set(messages)].join("\n"));
            return;
        }

        const normalize = (value) => (value || "").trim().replace(/\s+/g, " ");
        const valueChanged = Array.from(form.querySelectorAll("[data-track-change]"))
            .some((field) => normalize(field.value) !== normalize(field.dataset.initialValue));
        const active = form.querySelector('input[name="IsActive"]:checked')?.value?.toLowerCase();
        const statusChanged = active !== form.dataset.initialActive;
        if (!valueChanged && !statusChanged && !displaysEdited) {
            event.preventDefault();
            event.stopImmediatePropagation();
            window.genericPopup?.fail("Herhangi bir değişiklik yapmadınız.");
            return;
        }

        event.preventDefault();
        event.stopImmediatePropagation();
        const submitter = event.submitter;
        window.genericPopup?.show({
            type: "question",
            message: form.dataset.confirmMessage,
            confirmText: "Evet",
            cancelText: "İptal",
            showCancel: true,
            returnFocus: submitter,
            onConfirm: () => {
                form.dataset.applicationConfirmed = "true";
                form.requestSubmit(submitter || undefined);
            }
        });
    }, true);
})();
