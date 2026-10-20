(() => {
    const form = document.querySelector("[data-additional-voting-form]");
    if (!form) return;

    const selects = [...form.querySelectorAll(".additional-voting-select")];
    const page = form.closest(".additional-voting-form-page");
    let clearanceFrame = 0;

    const syncClearance = () => {
        if (!page) return;
        cancelAnimationFrame(clearanceFrame);
        page.style.setProperty("--additional-voting-clearance", "0px");
        clearanceFrame = requestAnimationFrame(() => {
            const menu = selects
                .map(select => select.querySelector("[data-multi-menu]"))
                .find(item => item && !item.hidden);
            if (!menu) return;
            const pageBottom = page.getBoundingClientRect().bottom + scrollY;
            const menuBottom = menu.getBoundingClientRect().bottom + scrollY;
            page.style.setProperty(
                "--additional-voting-clearance",
                `${Math.max(0, Math.ceil(menuBottom + 40 - pageBottom))}px`);
        });
    };

    const closeAll = (except = null) => selects.forEach(select => {
        if (select === except) return;
        select.querySelector("[data-multi-menu]").hidden = true;
        select.querySelector("[data-multi-trigger]").setAttribute("aria-expanded", "false");
        select.classList.remove("is-open");
    });

    const createToken = window.selectionTokens.create;

    const setupSelect = (select, inputName, allLabel, placeholder) => {
        const trigger = select.querySelector("[data-multi-trigger]");
        const menu = select.querySelector("[data-multi-menu]");
        const selected = select.querySelector("[data-multi-selected]");
        const hidden = select.querySelector("[data-hidden-values]");
        const allInput = select.querySelector("[data-all-value]");
        const allCheckbox = select.querySelector("[data-select-all]");
        const options = [...select.querySelectorAll("[data-option]")];
        const groups = [...select.querySelectorAll("[data-selection-group]")];
        const initiallyAll = allInput.value === "true";

        if (initiallyAll) {
            options.forEach(option => { option.checked = true; });
        }

        const syncGroups = () => groups.forEach(group => {
            const checkbox = group.querySelector("[data-group-checkbox]");
            if (!checkbox) return;
            const members = [...group.querySelectorAll("[data-option]")];
            const count = members.filter(item => item.checked).length;
            checkbox.checked = members.length > 0 && count === members.length;
            checkbox.indeterminate = count > 0 && count < members.length;
        });

        const syncAllState = () => {
            if (options.length === 0) {
                allCheckbox.indeterminate = false;
                return;
            }
            const selectedCount = options.filter(option => option.checked).length;
            allCheckbox.checked = selectedCount === options.length;
            allCheckbox.indeterminate = selectedCount > 0 && selectedCount < options.length;
        };

        const render = () => {
            syncGroups();
            syncAllState();
            const isAll = allCheckbox.checked && !allCheckbox.indeterminate;
            allInput.value = String(isAll);
            hidden.replaceChildren();
            selected.replaceChildren();

            if (isAll) {
                selected.append(createToken(allLabel, "all", "all"));
            } else {
                const selectedOptions = options.filter(option => option.checked);
                const represented = new Set();
                groups.forEach(group => {
                    const members = [...group.querySelectorAll("[data-option]")];
                    if (members.length > 0 &&
                        members.every(item => item.checked) &&
                        group.querySelector("[data-group-checkbox]")) {
                        selected.append(createToken(group.dataset.groupName, "group", group.dataset.groupKey));
                        members.forEach(item => represented.add(item.value));
                    }
                });
                selectedOptions
                    .filter(option => !represented.has(option.value))
                    .forEach(option => selected.append(
                        createToken(option.dataset.optionName, "option", option.value)));
                selectedOptions.forEach(option => {
                    const input = document.createElement("input");
                    input.type = "hidden";
                    input.name = inputName;
                    input.value = option.value;
                    hidden.append(input);
                });
                if (selectedOptions.length === 0) {
                    const text = document.createElement("span");
                    text.className = "add-play-select-placeholder";
                    text.textContent = placeholder;
                    selected.append(text);
                }
            }
            syncClearance();
        };

        trigger.addEventListener("click", event => {
            if (event.target.closest("[data-selection-remove]")) return;
            const open = menu.hidden;
            closeAll(select);
            menu.hidden = !open;
            trigger.setAttribute("aria-expanded", String(open));
            select.classList.toggle("is-open", open);
            syncClearance();
        });
        trigger.addEventListener("keydown", event => {
            if (event.key !== "Enter" && event.key !== " ") return;
            if (event.target.closest("[data-selection-remove]")) return;
            event.preventDefault();
            trigger.click();
        });

        allCheckbox.addEventListener("change", () => {
            const selectAll = allCheckbox.checked;
            allCheckbox.indeterminate = false;
            options.forEach(option => { option.checked = selectAll; });
            render();
        });

        menu.addEventListener("change", event => {
            const groupCheckbox = event.target.closest("[data-group-checkbox]");
            if (groupCheckbox) {
                groupCheckbox.closest("[data-selection-group]")
                    .querySelectorAll("[data-option]")
                    .forEach(option => { option.checked = groupCheckbox.checked; });
            }
            render();
        });

        menu.addEventListener("click", event => {
            const toggle = event.target.closest("[data-group-toggle]");
            if (!toggle) return;
            const members = toggle.closest("[data-selection-group]").querySelector("[data-group-members]");
            const open = members.hidden;
            members.hidden = !open;
            toggle.setAttribute("aria-expanded", String(open));
            toggle.classList.toggle("is-open", open);
            syncClearance();
        });

        selected.addEventListener("click", event => {
            const token = event.target.closest("[data-selection-remove]");
            if (!token) return;
            event.stopPropagation();
            if (token.dataset.selectionRemove === "all") {
                allCheckbox.checked = false;
                options.forEach(option => { option.checked = false; });
            } else if (token.dataset.selectionRemove === "group") {
                select.querySelector(
                    `[data-selection-group][data-group-key="${CSS.escape(token.dataset.selectionValue)}"]`)
                    ?.querySelectorAll("[data-option]")
                    .forEach(option => { option.checked = false; });
            } else {
                const option = options.find(item => item.value === token.dataset.selectionValue);
                if (option) option.checked = false;
            }
            render();
        });

        render();
    };

    setupSelect(
        form.querySelector("[data-additional-jury-select]"),
        "SelectedJuryIds", "Tüm Jüriler", "Jürileri Seçin");
    setupSelect(
        form.querySelector("[data-additional-play-select]"),
        "SelectedPlayIds", "Tüm Oyunlar", "Oyunları Seçin");

    document.addEventListener("click", event => {
        if (!event.target.closest(".additional-voting-select")) {
            closeAll();
            syncClearance();
        }
    });
    document.addEventListener("keydown", event => {
        if (event.key === "Escape") {
            closeAll();
            syncClearance();
        }
    });
    window.addEventListener("resize", syncClearance);

    let confirmed = false;
    form.addEventListener("submit", event => {
        if (confirmed) return;
        event.preventDefault();
        const errors = [];
        const start = form.querySelector('[name="StartDate"]')?.value;
        const end = form.querySelector('[name="EndDate"]')?.value;
        if (!start) errors.push("Ek oylama başlangıç tarihi zorunludur.");
        if (!end) errors.push("Ek oylama bitiş tarihi zorunludur.");
        if (start && end && start >= end) {
            errors.push("Ek oylama başlangıç tarihi bitiş tarihinden önce olmalıdır.");
        }
        const allJuries = form.querySelector('[name="AppliesToAllJuries"]')?.value === "true";
        const allPlays = form.querySelector('[name="AppliesToAllPlays"]')?.value === "true";
        if (!allJuries && !form.querySelector('[name="SelectedJuryIds"]')) {
            errors.push("En az bir jüri seçmelisiniz.");
        }
        if (!allPlays && !form.querySelector('[name="SelectedPlayIds"]')) {
            errors.push("En az bir oyun seçmelisiniz.");
        }
        if (errors.length) {
            window.genericPopup?.fail(errors.join("\n"));
            return;
        }
        window.genericPopup?.show({
            type: "question",
            message: form.dataset.confirmMessage,
            confirmText: "Evet",
            cancelText: "İptal",
            showCancel: true,
            onConfirm: () => {
                confirmed = true;
                form.requestSubmit(event.submitter || undefined);
            }
        });
    });
})();
