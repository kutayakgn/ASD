(() => {
    const placeholderFor = (select) => {
        if (select.matches("[data-candidate-category-select]")) return "Kategori seçiniz";
        if (select.matches("[data-candidate-replacement-select]")) return "Aday/rol seçiniz";
        return "Oyun seçiniz";
    };

    const closeSelect = (select) => {
        const trigger = select.querySelector("[data-candidate-select-trigger]");
        const menu = select.querySelector("[data-candidate-select-menu]");
        if (!trigger || !menu) return;
        select.classList.remove("is-open");
        trigger.setAttribute("aria-expanded", "false");
        menu.hidden = true;
    };

    const openSelect = (select) => {
        const trigger = select.querySelector("[data-candidate-select-trigger]");
        const menu = select.querySelector("[data-candidate-select-menu]");
        if (!trigger || !menu || trigger.disabled) return;
        document.querySelectorAll("[data-candidate-select].is-open").forEach((item) => {
            if (item !== select) closeSelect(item);
        });
        select.classList.add("is-open");
        trigger.setAttribute("aria-expanded", "true");
        menu.hidden = false;
        menu.querySelector("[data-candidate-select-option]:not([hidden])")?.focus({ preventScroll: true });
    };

    const clearSelect = (select, placeholder = placeholderFor(select)) => {
        const input = select.querySelector("[data-candidate-select-value]");
        const label = select.querySelector("[data-candidate-select-label]");
        if (input) input.value = "";
        if (label) {
            label.textContent = placeholder;
            label.classList.add("is-placeholder");
        }
        select.querySelectorAll("[data-candidate-select-option]").forEach((option) => {
            option.setAttribute("aria-selected", "false");
        });
    };

    const selectOption = (select, option, dispatchChange = true) => {
        const input = select.querySelector("[data-candidate-select-value]");
        const label = select.querySelector("[data-candidate-select-label]");
        if (!input || !label) return;
        input.value = option.dataset.value || "";
        label.textContent = option.dataset.label || option.textContent.trim();
        label.classList.remove("is-placeholder");
        select.querySelectorAll("[data-candidate-select-option]").forEach((item) => {
            item.setAttribute("aria-selected", String(item === option));
        });
        closeSelect(select);
        if (dispatchChange) input.dispatchEvent(new Event("change", { bubbles: true }));
    };

    const setupPhoto = (component) => {
        const input = component.querySelector("[data-candidate-photo-input]");
        const fileName = component.querySelector("[data-candidate-file-name]");
        const picker = component.querySelector("[data-candidate-photo-picker]");
        const primary = component.querySelector("[data-candidate-photo-primary]");
        const primaryIcon = component.querySelector("[data-candidate-photo-primary-icon]");
        const actions = component.querySelector("[data-candidate-photo-actions]");
        const view = component.querySelector("[data-candidate-photo-view]");
        const replace = component.querySelector("[data-candidate-photo-replace]");
        const modal = component.querySelector("[data-candidate-photo-modal]");
        const preview = component.querySelector("[data-candidate-photo-preview]");
        let previewUrl = "";

        const closePreview = () => {
            if (!modal || modal.hidden) return;
            modal.hidden = true;
            document.body.classList.remove("has-photo-preview");
            view?.focus({ preventScroll: true });
        };

        const revokePreview = () => {
            if (previewUrl) URL.revokeObjectURL(previewUrl);
            previewUrl = "";
        };

        const render = (file) => {
            const hasPhoto = Boolean(file);
            if (fileName) fileName.textContent = file?.name || "Dosya Yükle";
            if (picker) picker.disabled = hasPhoto;
            if (primaryIcon) primaryIcon.src = hasPhoto ? "/icons/trash.svg" : "/icons/upload.svg";
            if (primary) primary.setAttribute("aria-label", hasPhoto ? "Yüklenen fotoğrafı kaldır" : "Dosya yükle");
            if (actions) actions.hidden = !hasPhoto;
        };

        const reset = () => {
            if (input) input.value = "";
            revokePreview();
            closePreview();
            if (preview) preview.removeAttribute("src");
            render(null);
        };

        input?.addEventListener("change", () => {
            const file = input.files?.[0];
            if (!file) return reset();
            revokePreview();
            previewUrl = URL.createObjectURL(file);
            render(file);
        });
        picker?.addEventListener("click", () => input?.click());
        primary?.addEventListener("click", () => input?.files?.length ? reset() : input?.click());
        replace?.addEventListener("click", () => input?.click());
        view?.addEventListener("click", () => {
            if (!modal || !preview || !previewUrl) return;
            preview.src = previewUrl;
            modal.hidden = false;
            document.body.classList.add("has-photo-preview");
        });
        modal?.addEventListener("click", (event) => {
            if (event.target !== preview) closePreview();
        });
        window.addEventListener("pagehide", revokePreview, { once: true });

        return { reset, closePreview };
    };

    const setupComponent = (component) => {
        const form = component.querySelector("[data-candidate-form]");
        const categorySelect = component.querySelector("[data-candidate-category-select]");
        const categoryInput = component.querySelector("[data-candidate-category]");
        const replacementField = component.querySelector("[data-candidate-replacement-field]");
        const replacementSelect = component.querySelector("[data-candidate-replacement-select]");
        const replacementInput = component.querySelector("[data-candidate-replacement]");
        const roleField = component.querySelector("[data-candidate-role-field]");
        const roleInput = component.querySelector("[data-candidate-role]");
        const photoField = component.querySelector("[data-candidate-photo-field]");
        const photo = setupPhoto(component);

        const selectedMode = () => component.querySelector("input[name='Input.Mode']:checked")?.value ?? "new";
        const selectedCategoryOption = () => categorySelect?.querySelector(
            `[data-candidate-select-option][data-value='${CSS.escape(categoryInput?.value || "")}']`);
        const selectedReplacementOption = () => replacementSelect?.querySelector(
            `[data-candidate-select-option][data-value='${CSS.escape(replacementInput?.value || "")}']`);

        const syncRole = () => {
            if (!roleField || !roleInput) return;
            const supportsRoleAndPhoto = selectedCategoryOption()?.dataset.supportsRolePhoto === "true";
            const changeMode = selectedMode() === "change";
            const replacement = selectedReplacementOption();
            roleField.hidden = !supportsRoleAndPhoto || changeMode;
            roleInput.disabled = !supportsRoleAndPhoto || changeMode;
            roleInput.required = supportsRoleAndPhoto && !changeMode;
            roleInput.readOnly = false;
            if (!supportsRoleAndPhoto) roleInput.value = "";
            else if (changeMode) roleInput.value = replacement?.dataset.role || "";
        };

        const syncPhoto = () => {
            if (!photoField) return;
            const supportsPhoto = selectedCategoryOption()?.dataset.supportsRolePhoto === "true";
            const photoInput = component.querySelector("[data-candidate-photo-input]");
            photoField.hidden = !supportsPhoto;
            if (!supportsPhoto) photo.reset();
            if (photoInput) photoInput.disabled = !supportsPhoto;
        };

        const syncReplacements = () => {
            if (!replacementField || !replacementSelect || !replacementInput) return;
            const changeMode = selectedMode() === "change";
            replacementField.hidden = !changeMode;
            if (!changeMode) {
                clearSelect(replacementSelect);
                syncRole();
                return;
            }

            const categoryCode = categoryInput?.value || "";
            const options = [...replacementSelect.querySelectorAll("[data-candidate-select-option]")];
            const matching = options.filter((option) => option.dataset.categoryCode === categoryCode);
            options.forEach((option) => { option.hidden = !matching.includes(option); });

            const selected = selectedReplacementOption();
            if (!selected || selected.hidden) clearSelect(replacementSelect);
            const trigger = replacementSelect.querySelector("[data-candidate-select-trigger]");
            if (trigger) trigger.disabled = matching.length === 0;

            if (matching.length === 1) selectOption(replacementSelect, matching[0], false);
            else if (matching.length === 0) clearSelect(replacementSelect, "Bu kategoride güncel aday yok");
            else if (!selected || selected.hidden) clearSelect(replacementSelect);
            syncRole();
        };

        const syncAll = () => {
            syncReplacements();
            syncRole();
            syncPhoto();
        };

        component.querySelectorAll("[data-candidate-select]").forEach((select) => {
            select.querySelector("[data-candidate-select-trigger]")?.addEventListener("click", () => {
                if (select.classList.contains("is-open")) closeSelect(select);
                else openSelect(select);
            });
            select.querySelectorAll("[data-candidate-select-option]").forEach((option) => {
                option.addEventListener("click", () => selectOption(select, option));
            });
        });

        component.querySelectorAll("input[name='Input.Mode']").forEach((input) => {
            input.addEventListener("change", () => {
                if (input.checked && input.value === "new" && roleInput) roleInput.value = "";
                syncAll();
            });
        });
        categoryInput?.addEventListener("change", () => {
            if (replacementSelect) clearSelect(replacementSelect);
            if (roleInput) roleInput.value = "";
            syncAll();
        });
        replacementInput?.addEventListener("change", syncRole);

        form?.addEventListener("submit", (event) => {
            const errors = [];
            const candidate = form.querySelector("[name='Input.Candidate']")?.value.trim() || "";
            const status = form.querySelector("input[name='Input.IsActive']:checked");
            const photoInput = component.querySelector("[data-candidate-photo-input]");
            const supportsRoleAndPhoto = selectedCategoryOption()?.dataset.supportsRolePhoto === "true";
            if (!form.querySelector("[name='Input.PlayId']")?.value) errors.push("Oyun seçimi zorunludur.");
            if (!categoryInput?.value) errors.push("Ödül kategorisi seçimi zorunludur.");
            if (selectedMode() === "change" && !replacementInput?.value) errors.push("Değişimi yapılacak aday/rol seçimi zorunludur.");
            if (candidate.length < 2) errors.push("Adı Soyadı alanı en az 2 karakter olmalıdır.");
            if (!status) errors.push("Statü seçimi zorunludur.");
            if (supportsRoleAndPhoto && selectedMode() === "new" && !roleInput?.value.trim()) errors.push("Rol Adı alanı zorunludur.");
            const file = photoInput?.files?.[0];
            if (file && !supportsRoleAndPhoto) errors.push("Bu ödül kategorisine fotoğraf eklenemez.");
            if (file && file.size > 150 * 1024 * 1024) errors.push("Görsel boyutu 150 MB'dan büyük olamaz.");
            if (file && !["image/jpeg", "image/png", "image/webp"].includes(file.type)) errors.push("Yalnızca JPEG, PNG veya WebP formatında fotoğraf yükleyebilirsiniz.");
            if (errors.length === 0) return;
            event.preventDefault();
            event.stopImmediatePropagation();
            window.genericPopup?.fail(errors.join(" "));
        }, true);

        syncAll();
    };

    document.querySelectorAll("[data-add-candidate]").forEach(setupComponent);

    document.addEventListener("click", (event) => {
        document.querySelectorAll("[data-candidate-select].is-open").forEach((select) => {
            if (!select.contains(event.target)) closeSelect(select);
        });
    });
    document.addEventListener("keydown", (event) => {
        if (event.key !== "Escape") return;
        document.querySelectorAll("[data-candidate-select].is-open").forEach(closeSelect);
        document.querySelectorAll("[data-add-candidate]").forEach((component) => {
            const modal = component.querySelector("[data-candidate-photo-modal]");
            if (modal && !modal.hidden) modal.click();
        });
    });
})();
