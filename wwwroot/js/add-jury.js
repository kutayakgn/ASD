(() => {
    const input = document.querySelector("[data-jury-photo-input]");
    const fileName = document.querySelector("[data-jury-file-name]");
    const pickerButton = document.querySelector("[data-jury-photo-picker]");
    const primaryButton = document.querySelector("[data-jury-photo-primary]");
    const primaryIcon = document.querySelector("[data-jury-photo-primary-icon]");
    const photoActions = document.querySelector("[data-jury-photo-actions]");
    const viewButton = document.querySelector("[data-jury-photo-view]");
    const replaceButton = document.querySelector("[data-jury-photo-replace]");
    const modal = document.querySelector("[data-jury-photo-modal]");
    const preview = document.querySelector("[data-jury-photo-preview]");
    let previewUrl = "";

    const closePreview = () => {
        if (!modal || modal.hidden) return;
        modal.hidden = true;
        document.body.classList.remove("has-photo-preview");
        viewButton?.focus({ preventScroll: true });
    };

    const revokePreviewUrl = () => {
        if (!previewUrl) return;
        URL.revokeObjectURL(previewUrl);
        previewUrl = "";
    };

    const resetPhoto = () => {
        if (!input) return;
        input.value = "";
        revokePreviewUrl();
        closePreview();
        if (preview) preview.removeAttribute("src");
        if (fileName) fileName.textContent = "Dosya Ekle";
        if (pickerButton) pickerButton.disabled = false;
        if (primaryIcon) primaryIcon.src = "/icons/upload.svg";
        if (primaryButton) primaryButton.setAttribute("aria-label", "Dosya ekle");
        if (photoActions) photoActions.hidden = true;
    };

    const applyPhoto = (file) => {
        revokePreviewUrl();
        previewUrl = URL.createObjectURL(file);
        if (fileName) fileName.textContent = file.name;
        if (pickerButton) pickerButton.disabled = true;
        if (primaryIcon) primaryIcon.src = "/icons/trash.svg";
        if (primaryButton) primaryButton.setAttribute("aria-label", "Y\u00FCklenen foto\u011Fraf\u0131 kald\u0131r");
        if (photoActions) photoActions.hidden = false;
    };

    input?.addEventListener("change", () => {
        const file = input.files?.[0];
        if (file) applyPhoto(file);
        else resetPhoto();
    });

    pickerButton?.addEventListener("click", () => {
        if (!input?.files?.length) input?.click();
    });

    primaryButton?.addEventListener("click", () => {
        if (input?.files?.length) resetPhoto();
        else input?.click();
    });

    replaceButton?.addEventListener("click", () => input?.click());

    viewButton?.addEventListener("click", () => {
        if (!modal || !preview || !previewUrl) return;
        preview.src = previewUrl;
        modal.hidden = false;
        document.body.classList.add("has-photo-preview");
    });

    modal?.addEventListener("click", (event) => {
        if (event.target !== preview) closePreview();
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape") closePreview();
    });

    document.addEventListener("click", (event) => {
        const cancel = event.target.closest("[data-history-back]");
        if (!cancel || window.history.length <= 1) return;

        event.preventDefault();
        window.history.back();
    });

    window.addEventListener("pagehide", revokePreviewUrl, { once: true });
})();