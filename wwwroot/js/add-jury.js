(() => {
    const input = document.querySelector("[data-jury-photo-input]");
    const fileName = document.querySelector("[data-jury-file-name]");
    const pickerButton = document.querySelector("[data-jury-photo-picker]");
    const primaryButton = document.querySelector("[data-jury-photo-primary]");
    const primaryIcon = document.querySelector("[data-jury-photo-primary-icon]");
    const photoActions = document.querySelector("[data-jury-photo-actions]");
    const viewButton = document.querySelector("[data-jury-photo-view]");
    const replaceButton = document.querySelector("[data-jury-photo-replace]");
    const removePhotoInput = document.querySelector("[data-jury-remove-photo]");
    const modal = document.querySelector("[data-jury-photo-modal]");
    const preview = document.querySelector("[data-jury-photo-preview]");
    const existingPhotoUrl = input?.dataset.existingPhotoUrl || "";
    const existingPhotoName = input?.dataset.existingPhotoName || "";
    let previewUrl = existingPhotoUrl;
    let previewIsObjectUrl = false;
    let hasPhoto = Boolean(existingPhotoUrl);

    const closePreview = () => {
        if (!modal || modal.hidden) return;
        modal.hidden = true;
        document.body.classList.remove("has-photo-preview");
        viewButton?.focus({ preventScroll: true });
    };

    const revokePreviewUrl = () => {
        if (previewUrl && previewIsObjectUrl) URL.revokeObjectURL(previewUrl);
        previewUrl = "";
        previewIsObjectUrl = false;
    };

    const renderPhotoState = (name) => {
        if (fileName) fileName.textContent = name || "Dosya Ekle";
        if (pickerButton) pickerButton.disabled = hasPhoto;
        if (primaryIcon) primaryIcon.src = hasPhoto ? "/icons/trash.svg" : "/icons/upload.svg";
        if (primaryButton) {
            primaryButton.setAttribute(
                "aria-label",
                hasPhoto ? "Y\u00fcklenen foto\u011fraf\u0131 kald\u0131r" : "Dosya ekle");
        }
        if (photoActions) photoActions.hidden = !hasPhoto;
    };

    const resetPhoto = () => {
        if (!input) return;
        input.value = "";
        revokePreviewUrl();
        closePreview();
        hasPhoto = false;
        if (preview) preview.removeAttribute("src");
        if (removePhotoInput) removePhotoInput.value = "true";
        renderPhotoState("");
    };

    const applyPhoto = (file) => {
        revokePreviewUrl();
        previewUrl = URL.createObjectURL(file);
        previewIsObjectUrl = true;
        hasPhoto = true;
        if (removePhotoInput) removePhotoInput.value = "false";
        renderPhotoState(file.name);
    };

    input?.addEventListener("change", () => {
        const file = input.files?.[0];
        if (file) applyPhoto(file);
    });

    pickerButton?.addEventListener("click", () => {
        if (!hasPhoto) input?.click();
    });

    primaryButton?.addEventListener("click", () => {
        if (hasPhoto) resetPhoto();
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

    if (hasPhoto) renderPhotoState(existingPhotoName);
    window.addEventListener("pagehide", revokePreviewUrl, { once: true });
})();