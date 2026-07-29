(() => {
    const popup = document.querySelector("[data-generic-popup]");
    if (!popup) return;

    const icon = popup.querySelector("[data-generic-popup-icon]");
    const message = popup.querySelector("[data-generic-popup-message]");
    const confirmButton = popup.querySelector("[data-generic-popup-confirm]");
    const cancelButton = popup.querySelector("[data-generic-popup-cancel]");
    const icons = {
        question: "/icons/popup-question.svg",
        success: "/icons/popup-success.svg",
        fail: "/icons/popup-fail.svg"
    };
    let currentOptions = {};

    const close = () => {
        popup.hidden = true;
        document.body.classList.remove("has-generic-popup");
        currentOptions.returnFocus?.focus?.({ preventScroll: true });
        currentOptions = {};
    };

    const show = (options = {}) => {
        const type = icons[options.type] ? options.type : "fail";
        currentOptions = options;
        popup.dataset.type = type;
        icon.src = icons[type];
        message.replaceChildren();
        if (options.messageContent instanceof Node) {
            message.append(options.messageContent);
        } else {
            message.textContent = options.message || "İşlem tamamlanamadı.";
        }
        confirmButton.textContent = options.confirmText || "Tamam";
        cancelButton.textContent = options.cancelText || "İptal";
        cancelButton.hidden = !options.showCancel;
        popup.hidden = false;
        document.body.classList.add("has-generic-popup");
        confirmButton.focus({ preventScroll: true });
    };

    confirmButton.addEventListener("click", () => {
        const onConfirm = currentOptions.onConfirm;
        const redirectUrl = currentOptions.redirectUrl;
        close();
        if (onConfirm) onConfirm();
        else if (redirectUrl) window.location.href = redirectUrl;
    });

    cancelButton.addEventListener("click", close);

    popup.addEventListener("click", (event) => {
        if (event.target === popup && currentOptions.closeOnBackdrop !== false) close();
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && !popup.hidden && currentOptions.closeOnEscape !== false) close();
    });

    document.addEventListener("submit", (event) => {
        const form = event.target.closest("form[data-generic-confirm]");
        if (!form || form.dataset.genericConfirmed === "true") return;

        if (!form.checkValidity()) {
            event.preventDefault();
            form.reportValidity();
            return;
        }

        if (window.jQuery && window.jQuery(form).data("validator") && !window.jQuery(form).valid()) {
            event.preventDefault();
            return;
        }

        event.preventDefault();
        const submitter = event.submitter;
        show({
            type: "question",
            message: form.dataset.confirmMessage || "İşlemi gerçekleştirmek istediğinize emin misiniz?",
            confirmText: form.dataset.confirmText || "Evet",
            cancelText: form.dataset.cancelText || "İptal",
            showCancel: true,
            returnFocus: submitter,
            onConfirm: () => {
                form.dataset.genericConfirmed = "true";
                form.requestSubmit(submitter || undefined);
            }
        });
    });

    window.genericPopup = {
        show,
        close,
        question: (messageText, onConfirm) => show({
            type: "question",
            message: messageText,
            confirmText: "Evet",
            cancelText: "İptal",
            showCancel: true,
            onConfirm
        }),
        success: (messageText, redirectUrl) => show({
            type: "success",
            message: messageText,
            redirectUrl
        }),
        fail: (messageText) => show({ type: "fail", message: messageText })
    };

    if (popup.dataset.initialType && popup.dataset.initialMessage) {
        show({
            type: popup.dataset.initialType,
            message: popup.dataset.initialMessage,
            redirectUrl: popup.dataset.initialRedirectUrl,
            closeOnBackdrop: popup.dataset.initialType !== "success",
            closeOnEscape: popup.dataset.initialType !== "success"
        });
    }
})();
