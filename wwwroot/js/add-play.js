(() => {
    const form = document.querySelector("[data-add-play-form]");
    const jurySelect = document.querySelector("[data-jury-multiselect]");
    const juryTrigger = jurySelect?.querySelector("[data-jury-select-trigger]");
    const juryMenu = jurySelect?.querySelector("[data-jury-menu]");
    const selectedValues = jurySelect?.querySelector("[data-jury-selected-values]");
    const hiddenInputs = jurySelect?.querySelector("[data-jury-hidden-inputs]");
    const statusSelect = document.querySelector("[data-play-status-select]");
    const statusTrigger = statusSelect?.querySelector("[data-play-status-trigger]");
    const statusMenu = statusSelect?.querySelector("[data-play-status-menu]");
    const statusValue = statusSelect?.querySelector("[data-play-status-value]");
    const statusLabel = statusSelect?.querySelector("[data-play-status-label]");
    if (!form || !jurySelect || !juryTrigger || !juryMenu || !selectedValues || !hiddenInputs ||
        !statusSelect || !statusTrigger || !statusMenu || !statusValue || !statusLabel) return;

    const groups = [...juryMenu.querySelectorAll("[data-jury-group]")];
    const page = form.closest(".add-play-page");
    let clearanceAnimationFrame = 0;

    const syncDropdownClearance = () => {
        if (!page) return;
        window.cancelAnimationFrame(clearanceAnimationFrame);
        page.style.setProperty("--add-play-dropdown-clearance", "0px");
        clearanceAnimationFrame = window.requestAnimationFrame(() => {
            const openMenu = [juryMenu, statusMenu].find((menu) => !menu.hidden);
            if (!openMenu) return;

            const menuBottom = openMenu.getBoundingClientRect().bottom + window.scrollY;
            const pageBottom = page.getBoundingClientRect().bottom + window.scrollY;
            const clearance = Math.max(0, Math.ceil(menuBottom + 40 - pageBottom));
            page.style.setProperty("--add-play-dropdown-clearance", `${clearance}px`);
        });
    };

    const setDropdownState = (trigger, menu, isOpen) => {
        trigger.setAttribute("aria-expanded", String(isOpen));
        menu.hidden = !isOpen;
        trigger.closest(".add-play-jury-select, .add-play-status-select")?.classList.toggle("is-open", isOpen);
        syncDropdownClearance();
    };

    const closeDropdowns = () => {
        setDropdownState(juryTrigger, juryMenu, false);
        setDropdownState(statusTrigger, statusMenu, false);
    };

    const syncGroupState = (group) => {
        const groupCheckbox = group.querySelector("[data-jury-group-checkbox]");
        const members = [...group.querySelectorAll("[data-jury-checkbox]")];
        const selectedCount = members.filter((member) => member.checked).length;
        groupCheckbox.checked = members.length > 0 && selectedCount === members.length;
        groupCheckbox.indeterminate = selectedCount > 0 && selectedCount < members.length;
    };

    const createToken = (text, type, value) => {
        const token = document.createElement("button");
        token.type = "button";
        token.className = "add-play-selection-token";
        token.setAttribute("aria-label", `${text} seçimini kaldır`);
        token.dataset.selectionRemove = type;
        token.dataset.selectionValue = value;
        const label = document.createElement("span");
        label.textContent = text;
        const removeIcon = document.createElement("span");
        removeIcon.className = "add-play-selection-remove-icon";
        removeIcon.setAttribute("aria-hidden", "true");
        removeIcon.textContent = "×";
        token.append(label, removeIcon);
        return token;
    };

    const renderJurySelection = () => {
        groups.forEach(syncGroupState);
        selectedValues.replaceChildren();
        hiddenInputs.replaceChildren();
        let selectionCount = 0;

        groups.forEach((group) => {
            const groupCheckbox = group.querySelector("[data-jury-group-checkbox]");
            const members = [...group.querySelectorAll("[data-jury-checkbox]")];
            const selectedMembers = members.filter((member) => member.checked);
            selectionCount += selectedMembers.length;

            if (groupCheckbox.checked) {
                selectedValues.append(createToken(group.dataset.groupName, "group", group.dataset.groupKey));
            } else {
                selectedMembers.forEach((member) => {
                    selectedValues.append(createToken(member.dataset.juryName, "jury", member.value));
                });
            }

            selectedMembers.forEach((member) => {
                const input = document.createElement("input");
                input.type = "hidden";
                input.name = "SelectedJuryIds";
                input.value = member.value;
                hiddenInputs.append(input);
            });
        });

        if (selectionCount === 0) {
            const placeholder = document.createElement("span");
            placeholder.className = "add-play-select-placeholder";
            placeholder.textContent = "Jüri Grubunu Seçin";
            selectedValues.append(placeholder);
        }
        syncDropdownClearance();
    };

    juryTrigger.addEventListener("click", (event) => {
        if (event.target.closest("[data-selection-remove]")) return;
        const open = juryMenu.hidden;
        closeDropdowns();
        setDropdownState(juryTrigger, juryMenu, open);
    });

    juryTrigger.addEventListener("keydown", (event) => {
        if (event.key !== "Enter" && event.key !== " ") return;
        if (event.target.closest("[data-selection-remove]")) return;
        event.preventDefault();
        juryTrigger.click();
    });

    juryMenu.addEventListener("change", (event) => {
        const groupCheckbox = event.target.closest("[data-jury-group-checkbox]");
        if (groupCheckbox) {
            groupCheckbox.closest("[data-jury-group]")
                .querySelectorAll("[data-jury-checkbox]")
                .forEach((member) => { member.checked = groupCheckbox.checked; });
        }
        renderJurySelection();
    });

    juryMenu.addEventListener("click", (event) => {
        const toggle = event.target.closest("[data-jury-group-toggle]");
        if (!toggle) return;
        const group = toggle.closest("[data-jury-group]");
        const members = group.querySelector("[data-jury-members]");
        const open = members.hidden;
        members.hidden = !open;
        toggle.setAttribute("aria-expanded", String(open));
        toggle.classList.toggle("is-open", open);
        syncDropdownClearance();
    });

    selectedValues.addEventListener("click", (event) => {
        const remove = event.target.closest("[data-selection-remove]");
        if (!remove) return;
        event.stopPropagation();
        if (remove.dataset.selectionRemove === "group") {
            const group = groups.find((item) => item.dataset.groupKey === remove.dataset.selectionValue);
            group?.querySelectorAll("[data-jury-checkbox]").forEach((member) => { member.checked = false; });
        } else {
            const member = juryMenu.querySelector(`[data-jury-checkbox][value="${remove.dataset.selectionValue}"]`);
            if (member) member.checked = false;
        }
        renderJurySelection();
    });

    statusTrigger.addEventListener("click", () => {
        const open = statusMenu.hidden;
        closeDropdowns();
        setDropdownState(statusTrigger, statusMenu, open);
    });

    statusMenu.addEventListener("click", (event) => {
        const option = event.target.closest("[data-status-code]");
        if (!option) return;
        statusValue.value = option.dataset.statusCode;
        statusLabel.classList.remove("is-placeholder");
        statusLabel.replaceChildren();
        const dot = document.createElement("i");
        dot.style.setProperty("--status-color", option.dataset.statusColor);
        dot.setAttribute("aria-hidden", "true");
        statusLabel.append(dot, document.createTextNode(option.dataset.statusName));
        statusMenu.querySelectorAll("[role=option]").forEach((item) => {
            item.setAttribute("aria-selected", String(item === option));
        });
        setDropdownState(statusTrigger, statusMenu, false);
        statusTrigger.focus({ preventScroll: true });
    });

    document.addEventListener("click", (event) => {
        if (!event.target.closest("[data-jury-multiselect], [data-play-status-select]")) closeDropdowns();
        const cancel = event.target.closest("[data-history-back]");
        if (cancel && window.history.length > 1) {
            event.preventDefault();
            window.history.back();
        }
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape") closeDropdowns();
    });

    window.addEventListener("resize", syncDropdownClearance);

    form.addEventListener("submit", (event) => {
        const messages = [];
        const playName = form.querySelector('[name="PlayName"]')?.value.trim() ?? "";
        const theaterName = form.querySelector('[name="TheaterName"]')?.value.trim() ?? "";
        if (playName.length < 2) messages.push("Oyun adı en az 2 karakter olmalıdır.");
        if (theaterName.length < 2) messages.push("Tiyatro adı en az 2 karakter olmalıdır.");
        if (!juryMenu.querySelector("[data-jury-checkbox]:checked")) messages.push("En az bir jüri veya jüri grubu seçiniz.");
        if (!statusValue.value) messages.push("Oyun statüsü seçiniz.");
        if (messages.length === 0) return;

        event.preventDefault();
        event.stopImmediatePropagation();
        window.genericPopup?.fail(messages.join(" "));
    });

    groups.forEach(syncGroupState);
    renderJurySelection();
})();
