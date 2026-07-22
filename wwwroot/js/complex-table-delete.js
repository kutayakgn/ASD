(() => {
    const submitDelete = (trigger, url) => {
        const section = trigger.closest("[data-complex-table]");
        const token = section?.querySelector('input[name="__RequestVerificationToken"]')?.value;
        if (!url || !token) {
            window.genericPopup?.fail("Silme işlemi başlatılamadı.");
            return;
        }

        const form = document.createElement("form");
        form.method = "post";
        form.action = url;
        const tokenInput = document.createElement("input");
        tokenInput.type = "hidden";
        tokenInput.name = "__RequestVerificationToken";
        tokenInput.value = token;
        form.appendChild(tokenInput);
        document.body.appendChild(form);
        form.submit();
    };

    const requestDelete = (trigger, url, message) => {
        if (!window.genericPopup || !url) return;
        window.genericPopup.show({
            type: "question",
            message: message || "İlgili kayıt silinsin mi?",
            confirmText: "Evet",
            cancelText: "İptal",
            showCancel: true,
            returnFocus: trigger,
            onConfirm: () => submitDelete(trigger, url)
        });
    };

    document.addEventListener("click", (event) => {
        const button = event.target.closest("[data-complex-table-delete-url]");
        if (button) {
            event.preventDefault();
            event.stopPropagation();
            requestDelete(button, button.dataset.complexTableDeleteUrl, button.dataset.deleteConfirmMessage);
            return;
        }

        const row = event.target.closest("tr[data-row-delete-url]");
        if (!row || event.target.closest("a, button, input, select, textarea")) return;
        requestDelete(row, row.dataset.rowDeleteUrl, row.dataset.deleteConfirmMessage);
    });

    document.addEventListener("keydown", (event) => {
        const row = event.target.closest("tr[data-row-delete-url]");
        if (!row || (event.key !== "Enter" && event.key !== " ")) return;
        event.preventDefault();
        requestDelete(row, row.dataset.rowDeleteUrl, row.dataset.deleteConfirmMessage);
    });
})();
