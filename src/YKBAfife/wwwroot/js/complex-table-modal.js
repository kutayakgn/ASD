(() => {
    let modalRequest;

    const openModal = async (trigger, url) => {
        const host = document.querySelector("[data-complex-table-modal-host]");
        if (!host || !url) return;
        modalRequest?.abort();
        modalRequest = new AbortController();
        trigger.setAttribute("aria-busy", "true");
        try {
            const response = await fetch(url, { headers: { "X-Requested-With": "XMLHttpRequest" }, signal: modalRequest.signal });
            if (!response.ok) throw new Error(`Modal yüklenemedi (${response.status}).`);
            host.innerHTML = await response.text();
            const modalElement = host.querySelector(".modal");
            if (!modalElement || !window.bootstrap?.Modal) throw new Error("Modal içeriği başlatılamadı.");
            const modal = window.bootstrap.Modal.getOrCreateInstance(modalElement);
            modalElement.addEventListener("hidden.bs.modal", () => {
                modal.dispose();
                host.replaceChildren();
                trigger.focus?.({ preventScroll: true });
            }, { once: true });
            modal.show();
        } catch (error) {
            if (error.name !== "AbortError") {
                console.error(error);
                window.genericPopup?.fail("Düzenleme ekranı yüklenemedi.");
            }
        } finally {
            trigger.removeAttribute("aria-busy");
        }
    };

    document.addEventListener("click", (event) => {
        const button = event.target.closest("[data-complex-table-modal-url]");
        if (button) {
            event.preventDefault();
            event.stopPropagation();
            openModal(button, button.dataset.complexTableModalUrl);
            return;
        }
        const row = event.target.closest("tr[data-row-modal-url]");
        if (!row || event.target.closest("a, button, input, select, textarea")) return;
        openModal(row, row.dataset.rowModalUrl);
    });

    document.addEventListener("keydown", (event) => {
        const row = event.target.closest("tr[data-row-modal-url]");
        if (!row || (event.key !== "Enter" && event.key !== " ")) return;
        event.preventDefault();
        openModal(row, row.dataset.rowModalUrl);
    });
})();
