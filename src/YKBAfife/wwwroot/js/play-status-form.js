(() => {
    const colorPattern = /^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;

    document.addEventListener("submit", (event) => {
        const form = event.target.closest("[data-play-status-form]");
        if (!form || form.dataset.confirmed === "true") return;

        event.preventDefault();
        event.stopImmediatePropagation();
        const input = form.elements.namedItem("StatusColor");
        const value = input?.value.trim() || "";
        if (!value) {
            window.genericPopup?.fail("Renk kodu zorunludur.");
            return;
        }
        if (!colorPattern.test(value)) {
            window.genericPopup?.fail("Renk kodu # ile başlamalı ve ardından 6 veya 8 hexadecimal karakter içermelidir.");
            return;
        }
        if (value.toLowerCase() === (input.dataset.initialValue || "").trim().toLowerCase()) {
            window.genericPopup?.fail("Herhangi bir değişiklik yapmadınız.");
            return;
        }

        const submitter = event.submitter;
        window.genericPopup?.show({
            type: "question",
            message: form.dataset.confirmMessage,
            confirmText: "Evet",
            cancelText: "İptal",
            showCancel: true,
            returnFocus: submitter,
            onConfirm: () => {
                form.dataset.confirmed = "true";
                form.requestSubmit(submitter || undefined);
            }
        });
    }, true);
})();