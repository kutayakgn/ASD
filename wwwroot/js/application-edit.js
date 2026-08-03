(() => {
    const pad = (value) => String(value).padStart(2, "0");
    const toIso = (date) => date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
    const toDisplay = (date) => pad(date.getDate()) + " / " + pad(date.getMonth() + 1) + " / " + date.getFullYear();
    const parseIso = (value) => {
        const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value || "");
        if (!match) return null;
        const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
        return Number.isNaN(date.getTime()) ? null : date;
    };
    const isSameDay = (left, right) => left && right &&
        left.getFullYear() === right.getFullYear() &&
        left.getMonth() === right.getMonth() &&
        left.getDate() === right.getDate();

    document.querySelectorAll("[data-date-picker]").forEach((picker) => {
        const display = picker.querySelector("[data-date-display]");
        const value = picker.querySelector("[data-date-value]");
        const trigger = picker.querySelector("[data-date-trigger]");
        const panel = picker.querySelector("[data-date-panel]");
        const title = picker.querySelector("[data-calendar-title]");
        const days = picker.querySelector("[data-calendar-days]");
        const apply = picker.querySelector("[data-calendar-apply]");
        if (!display || !value || !trigger || !panel || !title || !days || !apply) return;

        let selectedDate = parseIso(value.value);
        let pendingDate = selectedDate ? new Date(selectedDate) : null;
        let visibleMonth = pendingDate
            ? new Date(pendingDate.getFullYear(), pendingDate.getMonth(), 1)
            : new Date(new Date().getFullYear(), new Date().getMonth(), 1);

        const render = () => {
            title.textContent = visibleMonth.toLocaleDateString("tr-TR", {
                month: "long",
                year: "numeric"
            });
            days.replaceChildren();

            const firstDay = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth(), 1);
            const mondayOffset = (firstDay.getDay() + 6) % 7;
            const gridStart = new Date(firstDay);
            gridStart.setDate(firstDay.getDate() - mondayOffset);
            const today = new Date();

            for (let index = 0; index < 42; index += 1) {
                const date = new Date(gridStart);
                date.setDate(gridStart.getDate() + index);
                const button = document.createElement("button");
                button.type = "button";
                button.className = "application-calendar-day";
                button.textContent = pad(date.getDate());
                button.dataset.date = toIso(date);
                button.setAttribute("role", "gridcell");
                button.setAttribute("aria-label", date.toLocaleDateString("tr-TR", {
                    day: "numeric",
                    month: "long",
                    year: "numeric"
                }));
                button.setAttribute("aria-selected", String(isSameDay(date, pendingDate)));
                button.classList.toggle("is-outside", date.getMonth() !== visibleMonth.getMonth());
                button.classList.toggle("is-selected", isSameDay(date, pendingDate));
                button.classList.toggle("is-today", isSameDay(date, today));
                days.append(button);
            }
        };

        const close = () => {
            panel.hidden = true;
            picker.classList.remove("is-open");
            trigger.setAttribute("aria-expanded", "false");
        };

        const open = () => {
            selectedDate = parseIso(value.value);
            pendingDate = selectedDate ? new Date(selectedDate) : null;
            const base = pendingDate || new Date();
            visibleMonth = new Date(base.getFullYear(), base.getMonth(), 1);
            render();
            panel.hidden = false;
            picker.classList.add("is-open");
            trigger.setAttribute("aria-expanded", "true");
        };

        const toggle = () => panel.hidden ? open() : close();
        trigger.addEventListener("click", toggle);
        display.addEventListener("click", toggle);

        panel.addEventListener("click", (event) => {
            const day = event.target.closest("[data-date]");
            if (day) {
                pendingDate = parseIso(day.dataset.date);
                if (pendingDate) {
                    visibleMonth = new Date(pendingDate.getFullYear(), pendingDate.getMonth(), 1);
                    render();
                }
                return;
            }

            const action = event.target.closest("[data-calendar-action]")?.dataset.calendarAction;
            if (!action) return;
            const monthDelta = action === "prev-month" ? -1 : action === "next-month" ? 1 : 0;
            const yearDelta = action === "prev-year" ? -1 : action === "next-year" ? 1 : 0;
            visibleMonth = new Date(
                visibleMonth.getFullYear() + yearDelta,
                visibleMonth.getMonth() + monthDelta,
                1);
            render();
        });

        apply.addEventListener("click", () => {
            if (!pendingDate) {
                window.genericPopup?.fail("Lütfen bir prömiyer tarihi seçiniz.");
                return;
            }
            selectedDate = new Date(pendingDate);
            value.value = toIso(selectedDate);
            display.value = toDisplay(selectedDate);
            value.dispatchEvent(new Event("change", { bubbles: true }));
            close();
            trigger.focus({ preventScroll: true });
        });

        document.addEventListener("click", (event) => {
            if (!panel.hidden && !event.composedPath().includes(picker)) close();
        });
        document.addEventListener("keydown", (event) => {
            if (event.key === "Escape" && !panel.hidden) {
                close();
                trigger.focus({ preventScroll: true });
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

        const invalidFields = Array.from(form.elements)
            .filter((field) =>
                (field instanceof HTMLInputElement || field instanceof HTMLSelectElement) &&
                field.type !== "hidden" &&
                !field.checkValidity());
        const dateValue = form.querySelector("[data-date-value]");
        const messages = invalidFields.map(validationMessage);
        if (!dateValue?.value) messages.push("Prömiyer tarihi zorunludur.");

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
        if (!valueChanged && !statusChanged) {
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