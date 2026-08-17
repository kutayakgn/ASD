(() => {
    const modal = document.querySelector("[data-announcement-image-modal]");
    const preview = modal?.querySelector("[data-announcement-image-preview]");
    let activeViewButton = null;
    let activePreviewUrl = "";

    const closePreview = () => {
        if (!modal || modal.hidden) return;
        modal.hidden = true;
        preview?.removeAttribute("src");
        document.body.classList.remove("has-photo-preview");
        activeViewButton?.focus({ preventScroll: true });
        activeViewButton = null;
        activePreviewUrl = "";
    };

    document.querySelectorAll("[data-announcement-image-upload]").forEach((component) => {
        const kind = component.dataset.announcementImageUpload;
        const input = component.querySelector("[data-announcement-image-input]");
        const fileName = component.querySelector("[data-announcement-file-name]");
        const picker = component.querySelector("[data-announcement-image-picker]");
        const primary = component.querySelector("[data-announcement-image-primary]");
        const primaryIcon = component.querySelector("[data-announcement-image-primary-icon]");
        const actions = component.querySelector("[data-announcement-image-actions]");
        const view = component.querySelector("[data-announcement-image-view]");
        const replace = component.querySelector("[data-announcement-image-replace]");
        const remove = document.querySelector(`[data-announcement-remove-image="${kind}"]`);
        const existingUrl = input?.dataset.existingImageUrl || "";
        const existingName = input?.dataset.existingImageName || "";
        let previewUrl = existingUrl;
        let objectUrl = false;
        let hasImage = Boolean(existingUrl);

        const revokeObjectUrl = () => {
            if (objectUrl && previewUrl) URL.revokeObjectURL(previewUrl);
            objectUrl = false;
            previewUrl = "";
        };

        const render = (name) => {
            if (fileName) fileName.textContent = name || "Dosya Yükle";
            if (picker) picker.disabled = hasImage;
            if (primaryIcon) primaryIcon.src = hasImage ? "/icons/trash.svg" : "/icons/upload.svg";
            primary?.setAttribute("aria-label", hasImage ? "Yüklenen görseli kaldır" : "Dosya yükle");
            if (actions) actions.hidden = !hasImage;
        };

        const clear = () => {
            if (input) input.value = "";
            revokeObjectUrl();
            hasImage = false;
            if (remove) remove.value = "true";
            closePreview();
            render("");
        };

        const useFile = (file) => {
            revokeObjectUrl();
            previewUrl = URL.createObjectURL(file);
            objectUrl = true;
            hasImage = true;
            if (remove) remove.value = "false";
            render(file.name);
        };

        input?.addEventListener("change", () => {
            const file = input.files?.[0];
            if (file) useFile(file);
        });
        picker?.addEventListener("click", () => { if (!hasImage) input?.click(); });
        primary?.addEventListener("click", () => { if (hasImage) clear(); else input?.click(); });
        replace?.addEventListener("click", () => input?.click());
        view?.addEventListener("click", () => {
            if (!modal || !preview || !previewUrl) return;
            activeViewButton = view;
            activePreviewUrl = previewUrl;
            preview.src = activePreviewUrl;
            modal.hidden = false;
            document.body.classList.add("has-photo-preview");
        });

        if (hasImage) render(existingName);
        window.addEventListener("pagehide", revokeObjectUrl, { once: true });
    });

    modal?.addEventListener("click", (event) => { if (event.target !== preview) closePreview(); });
    document.addEventListener("keydown", (event) => { if (event.key === "Escape") closePreview(); });
})();
