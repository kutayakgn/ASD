(() => {
    const activeRequests = new Map();
    const searchTimers = new Map();
    const searchDelayMs = 300;
    const legacyQueryKeys = ["tab", "search", "sortBy", "sortDirection", "page"];

    const removeLegacyQueryParameters = () => {
        const url = new URL(window.location.href);
        const hadLegacyParameters = legacyQueryKeys.some((key) => url.searchParams.has(key));
        if (!hadLegacyParameters) return;

        legacyQueryKeys.forEach((key) => url.searchParams.delete(key));
        window.history.replaceState(window.history.state, "", `${url.pathname}${url.search}${url.hash}`);
    };

    removeLegacyQueryParameters();

    const updateTable = async (section, overrides = {}, restoreSearchFocus = false) => {
        const endpoint = section.dataset.complexTableUrl;
        const stateForm = section.querySelector("[data-complex-table-state]");
        if (!endpoint || !stateForm) return;

        const requestKey = section.id;
        activeRequests.get(requestKey)?.abort();

        const controller = new AbortController();
        activeRequests.set(requestKey, controller);

        const formData = new FormData(stateForm);
        Object.entries(overrides).forEach(([key, value]) => formData.set(key, value));

        section.classList.add("is-loading");
        section.setAttribute("aria-busy", "true");

        try {
            const response = await fetch(endpoint, {
                method: "POST",
                body: formData,
                headers: { "X-Requested-With": "XMLHttpRequest" },
                signal: controller.signal
            });

            if (!response.ok) {
                throw new Error(`Tablo güncellenemedi (${response.status}).`);
            }

            const template = document.createElement("template");
            template.innerHTML = (await response.text()).trim();
            const nextSection = template.content.querySelector("[data-complex-table]");
            if (!nextSection) {
                throw new Error("Sunucudan geçerli tablo içeriği dönmedi.");
            }

            section.replaceWith(nextSection);

            if (restoreSearchFocus) {
                const nextInput = nextSection.querySelector("[data-complex-table-search]");
                if (nextInput) {
                    nextInput.focus({ preventScroll: true });
                    const position = nextInput.value.length;
                    nextInput.setSelectionRange(position, position);
                }
            }
        } catch (error) {
            if (error.name !== "AbortError") {
                section.classList.remove("is-loading");
                section.removeAttribute("aria-busy");
                console.error(error);
            }
        } finally {
            if (activeRequests.get(requestKey) === controller) {
                activeRequests.delete(requestKey);
            }
        }
    };

    const cancelScheduledSearch = (section) => {
        const requestKey = section.id;
        window.clearTimeout(searchTimers.get(requestKey));
        searchTimers.delete(requestKey);
    };

    document.addEventListener("input", (event) => {
        const input = event.target.closest("[data-complex-table-search]");
        if (!input) return;

        const section = input.closest("[data-complex-table]");
        if (!section) return;

        const requestKey = section.id;
        const searchValue = input.value;

        cancelScheduledSearch(section);
        activeRequests.get(requestKey)?.abort();
        section.classList.remove("is-loading");
        section.removeAttribute("aria-busy");

        const timer = window.setTimeout(() => {
            searchTimers.delete(requestKey);
            updateTable(section, { search: searchValue, page: "1" }, true);
        }, searchDelayMs);

        searchTimers.set(requestKey, timer);
    });

    document.addEventListener("submit", (event) => {
        const stateForm = event.target.closest("[data-complex-table-state]");
        if (!stateForm) return;

        event.preventDefault();
        const section = stateForm.closest("[data-complex-table]");
        const input = stateForm.querySelector("[data-complex-table-search]");
        if (!section || !input) return;

        cancelScheduledSearch(section);
        updateTable(section, { search: input.value, page: "1" }, true);
    });
    document.addEventListener("click", (event) => {
        const clearButton = event.target.closest("[data-complex-table-clear]");
        if (clearButton) {
            const section = clearButton.closest("[data-complex-table]");
            const input = section?.querySelector("[data-complex-table-search]");
            if (section && input) {
                cancelScheduledSearch(section);
                input.value = "";
                updateTable(section, { search: "", page: "1" }, true);
            }
            return;
        }

        const action = event.target.closest("[data-complex-table-action]");
        if (action) {
            const section = action.closest("[data-complex-table]");
            if (!section || action.disabled) return;

            cancelScheduledSearch(section);
            const overrides = {};
            ["tab", "sortBy", "sortDirection", "page"].forEach((key) => {
                if (action.dataset[key] !== undefined) {
                    overrides[key] = action.dataset[key];
                }
            });

            updateTable(section, overrides);
            return;
        }

        const row = event.target.closest("tr[data-row-link]");
        if (!row || event.target.closest("a, button, input, select, textarea, .complex-table-toggle-cell")) return;
        if (row.dataset.rowLink) window.location.href = row.dataset.rowLink;
    });

    document.addEventListener("complex-table:update", (event) => {
        const section = event.target.closest?.("[data-complex-table]");
        if (!section) return;
        cancelScheduledSearch(section);
        updateTable(section, event.detail ?? {});
    });
    document.addEventListener("keydown", (event) => {
        const row = event.target.closest("tr[data-row-link]");
        if (!row || (event.key !== "Enter" && event.key !== " ")) return;
        event.preventDefault();
        if (row.dataset.rowLink) window.location.href = row.dataset.rowLink;
    });
})();
(() => {
    let modalRequest;

    document.addEventListener("click", async (event) => {
        const trigger = event.target.closest("[data-play-viewers-modal-url]");
        if (!trigger) return;

        event.preventDefault();
        const host = document.querySelector("[data-play-viewers-modal-host]");
        const url = trigger.dataset.playViewersModalUrl;
        if (!host || !url) return;

        modalRequest?.abort();
        modalRequest = new AbortController();
        trigger.setAttribute("aria-busy", "true");

        try {
            const response = await fetch(url, {
                headers: { "X-Requested-With": "XMLHttpRequest" },
                signal: modalRequest.signal
            });

            if (!response.ok) {
                throw new Error(`Jüri listesi yüklenemedi (${response.status}).`);
            }

            host.innerHTML = await response.text();
            const modalElement = host.querySelector(".play-viewers-modal");
            if (!modalElement || !window.bootstrap?.Modal) {
                throw new Error("Modal içeriği başlatılamadı.");
            }

            const modal = window.bootstrap.Modal.getOrCreateInstance(modalElement);
            modalElement.addEventListener("hidden.bs.modal", () => {
                modal.dispose();
                host.replaceChildren();
                trigger.focus({ preventScroll: true });
            }, { once: true });
            modal.show();
        } catch (error) {
            if (error.name !== "AbortError") {
                console.error(error);
            }
        } finally {
            trigger.removeAttribute("aria-busy");
        }
    });
})();