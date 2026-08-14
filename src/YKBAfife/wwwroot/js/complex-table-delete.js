(() => {
    const submitDelete = async (trigger, url) => {
        const section = trigger.closest("[data-complex-table]");
        const token = section?.querySelector('input[name="__RequestVerificationToken"]')?.value;
        if (!url || !token) {
            window.genericPopup?.fail("Silme işlemi başlatılamadı.");
            return;
        }

        const formData = new FormData();
        formData.set("__RequestVerificationToken", token);
        trigger.disabled = true;
        trigger.setAttribute("aria-busy", "true");

        try {
            const response = await fetch(url, {
                method: "POST",
                body: formData,
                headers: { "X-Requested-With": "XMLHttpRequest" }
            });
            if (response.redirected) {
                window.location.assign(response.url);
                return;
            }

            const result = await response.json().catch(() => ({}));
            if (!response.ok || result.success === false) {
                throw new Error(result.message || "Silme işlemi tamamlanamadı.");
            }

            if (result.refreshTable === true && section) {
                section.dispatchEvent(new CustomEvent("complex-table:update", { bubbles: true }));
            }
            window.genericPopup?.success(result.message || "Kayıt silindi.");
        } catch (error) {
            console.error(error);
            window.genericPopup?.fail(error.message || "Silme işlemi tamamlanamadı.");
        } finally {
            trigger.disabled = false;
            trigger.removeAttribute("aria-busy");
        }
    };

    const requestDelete = (trigger, url, message) => {
        if (!window.genericPopup || !url) return;
        const focusTarget = trigger.matches("button")
            ? trigger
            : trigger.querySelector(".complex-table-delete-button") || trigger;
        window.genericPopup.show({
            type: "question",
            message: message || "İlgili kayıt silinsin mi?",
            confirmText: "Evet",
            cancelText: "İptal",
            showCancel: true,
            returnFocus: focusTarget,
            onConfirm: () => submitDelete(focusTarget, url)
        });
    };

    document.addEventListener("click", (event) => {
        const deleteCell = event.target.closest("[data-complex-table-delete-url]");
        if (deleteCell) {
            event.preventDefault();
            event.stopPropagation();
            requestDelete(deleteCell, deleteCell.dataset.complexTableDeleteUrl, deleteCell.dataset.deleteConfirmMessage);
        }
    });
})();
