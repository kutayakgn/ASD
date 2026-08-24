(() => {
    const usernameInput = document.querySelector("[data-jury-username]");
    const phoneInput = document.querySelector("[data-jury-phone]");
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

    const setUsernameValidationMessage = () => {
        if (!usernameInput) return;

        usernameInput.setCustomValidity("");
        if (usernameInput.validity.valueMissing) {
            usernameInput.setCustomValidity("Kullanıcı adı zorunludur.");
        } else if (usernameInput.validity.tooShort || usernameInput.validity.tooLong) {
            usernameInput.setCustomValidity("Kullanıcı adı 3-30 karakter arasında olmalıdır.");
        } else if (usernameInput.validity.patternMismatch) {
            usernameInput.setCustomValidity(
                "Kullanıcı adı yalnızca İngilizce harf, rakam, nokta ve alt çizgi içerebilir; boşluk içeremez.");
        }
    };

    usernameInput?.addEventListener("input", setUsernameValidationMessage);
    usernameInput?.addEventListener("invalid", setUsernameValidationMessage);

    const setPhoneValidationMessage = () => {
        if (!phoneInput) return;

        phoneInput.setCustomValidity("");
        if (phoneInput.validity.valueMissing) {
            phoneInput.setCustomValidity("Telefon numarası zorunludur.");
        } else if (!/^\d{10,11}$/.test(phoneInput.value)) {
            phoneInput.setCustomValidity("Telefon numarası 10 veya 11 rakamdan oluşmalıdır.");
        }
    };

    phoneInput?.addEventListener("input", setPhoneValidationMessage);
    phoneInput?.addEventListener("invalid", setPhoneValidationMessage);

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
        if (fileName) fileName.textContent = name || "Dosya Yükle";
        if (pickerButton) pickerButton.disabled = hasPhoto;
        if (primaryIcon) primaryIcon.src = hasPhoto ? "/icons/trash.svg" : "/icons/upload.svg";
        if (primaryButton) {
            primaryButton.setAttribute(
                "aria-label",
                hasPhoto ? "Yüklenen fotoğrafı kaldır" : "Dosya yükle");
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

    const confirmPhotoRemoval = () => {
        const message = "Kayıtlı jüri fotoğrafını silmek istediğinize emin misiniz?";
        if (window.genericPopup?.question) {
            window.genericPopup.question(message, resetPhoto);
            return;
        }

        if (window.confirm(message)) resetPhoto();
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
        if (hasPhoto) confirmPhotoRemoval();
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
