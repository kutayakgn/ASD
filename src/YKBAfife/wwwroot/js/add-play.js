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
    const juryVotingActive = form?.querySelector("[data-jury-voting-active]");
    if (!form || !jurySelect || !juryTrigger || !juryMenu || !selectedValues || !hiddenInputs ||
        !statusSelect || !statusTrigger || !statusMenu || !statusValue || !statusLabel) return;

    const groups = [...juryMenu.querySelectorAll("[data-jury-group]")];
    const page = form.closest(".add-play-page");
    const requiresJurySelection = !form.querySelector('[name="Id"]');
    let clearanceAnimationFrame = 0;

    const syncJuryVotingAvailability = () => {
        if (juryVotingActive) juryVotingActive.disabled = false;
    };

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
        if (!groupCheckbox) return;
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
        const removeIcon = document.createElement("img");
        removeIcon.className = "add-play-selection-remove-icon";
        removeIcon.setAttribute("aria-hidden", "true");
        removeIcon.src = "/icons/x-white.svg";
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

            if (groupCheckbox?.checked) {
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
        syncJuryVotingAvailability();
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

    let isCheckingSimilarity = false;
    let isReadyToSubmit = false;

    const buildSimilarityMessage = (matches) => {
        const content = document.createDocumentFragment();
        content.append("Kaydetmek istediğiniz oyun ile benzer oyun adı ve tiyatro adına sahip başka bir oyun var.\n");
        matches.forEach((match, index) => {
            if (index > 0) content.append(", ");
            const link = document.createElement("a");
            link.textContent = match.name;
            link.href = match.url;
            content.append(link);
        });
        content.append("\nYine de kayıt yapmak istiyor musunuz?");
        return content;
    };

    const submitAfterConfirmation = (submitter, confirmsSimilarity) => {
        const confirmationInput = form.querySelector("[data-confirm-similar-play]");
        if (confirmationInput) confirmationInput.value = String(confirmsSimilarity);
        isReadyToSubmit = true;
        form.requestSubmit(submitter || undefined);
    };

    form.addEventListener("submit", async (event) => {
        if (isReadyToSubmit) return;

        event.preventDefault();
        event.stopImmediatePropagation();
        if (isCheckingSimilarity) return;

        const messages = [];
        const playName = form.querySelector('[name="PlayName"]')?.value.trim() ?? "";
        const theaterName = form.querySelector('[name="TheaterName"]')?.value.trim() ?? "";
        if (playName.length < 2) messages.push("Oyun adı en az 2 karakter olmalıdır.");
        if (theaterName.length < 2) messages.push("Tiyatro adı en az 2 karakter olmalıdır.");
        if (requiresJurySelection && !juryMenu.querySelector("[data-jury-checkbox]:checked")) {
            messages.push("En az bir jüri veya jüri grubu seçiniz.");
        }
        if (!statusValue.value) messages.push("Oyun statüsü seçiniz.");
        if (messages.length > 0) {
            window.genericPopup?.fail(messages.join(" "));
            return;
        }

        const checkUrl = form.dataset.similarityCheckUrl;
        const verificationToken = form.querySelector('[name="__RequestVerificationToken"]')?.value;
        if (!checkUrl || !verificationToken) {
            window.genericPopup?.fail("Benzer oyun kontrolü başlatılamadı.");
            return;
        }

        const submitter = event.submitter;
        isCheckingSimilarity = true;
        if (submitter) {
            submitter.disabled = true;
            submitter.setAttribute("aria-busy", "true");
        }

        try {
            const body = new FormData();
            body.set("__RequestVerificationToken", verificationToken);
            body.set("playName", playName);
            body.set("theaterName", theaterName);
            const playId = form.querySelector('[name="Id"]')?.value;
            if (playId) body.set("playId", playId);
            const response = await fetch(checkUrl, {
                method: "POST",
                body,
                headers: { "X-Requested-With": "XMLHttpRequest" }
            });
            const result = await response.json().catch(() => ({}));
            if (!response.ok) {
                throw new Error(result.message || "Benzer oyun kontrolü tamamlanamadı.");
            }

            if (result.status === "exact") {
                window.genericPopup?.fail(
                    result.message || "Aynı isimli bir oyun kaydı bulunduğu için, bu oyunu kaydedemezsin.");
                return;
            }

            const matches = Array.isArray(result.matches) ? result.matches : [];
            if (result.status === "similar" && matches.length > 0) {
                window.genericPopup?.show({
                    type: "question",
                    messageContent: buildSimilarityMessage(matches),
                    confirmText: "Evet",
                    cancelText: "İptal",
                    showCancel: true,
                    returnFocus: submitter,
                    onConfirm: () => submitAfterConfirmation(submitter, true)
                });
                return;
            }

            window.genericPopup?.show({
                type: "question",
                message: form.dataset.confirmMessage || "Oyunu eklemek istediğinize emin misiniz?",
                confirmText: "Evet",
                cancelText: "İptal",
                showCancel: true,
                returnFocus: submitter,
                onConfirm: () => submitAfterConfirmation(submitter, false)
            });
        } catch (error) {
            console.error(error);
            window.genericPopup?.fail(error.message || "Benzer oyun kontrolü tamamlanamadı.");
        } finally {
            isCheckingSimilarity = false;
            if (submitter) {
                submitter.disabled = false;
                submitter.removeAttribute("aria-busy");
            }
        }
    });

    groups.forEach(syncGroupState);
    renderJurySelection();
    syncJuryVotingAvailability();
})();
