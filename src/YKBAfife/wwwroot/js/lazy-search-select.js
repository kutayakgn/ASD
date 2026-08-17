(() => {
    const normalize = (value) => (value || "")
        .toLocaleLowerCase("tr-TR")
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "");

    document.querySelectorAll("[data-lazy-search-select]").forEach((control) => {
        const endpoint = control.dataset.endpoint;
        const hiddenInput = control.querySelector("[data-lazy-select-value]");
        const trigger = control.querySelector("[data-lazy-select-trigger]");
        const display = control.querySelector("[data-lazy-select-display]");
        const panel = control.querySelector("[data-lazy-select-panel]");
        const search = control.querySelector("[data-lazy-select-search]");
        const clearSearch = control.querySelector("[data-lazy-select-clear]");
        const optionsHost = control.querySelector("[data-lazy-select-options]");
        const status = control.querySelector("[data-lazy-select-status]");
        let options = [];
        let loadPromise;

        const close = (restoreFocus = false) => {
            if (panel.hidden) return;
            panel.hidden = true;
            trigger.setAttribute("aria-expanded", "false");
            control.classList.remove("is-open");
            if (restoreFocus) trigger.focus();
        };

        const selectOption = (option) => {
            hiddenInput.value = option.value;
            display.textContent = option.text;
            trigger.classList.remove("is-placeholder");
            hiddenInput.dispatchEvent(new Event("change", { bubbles: true }));
            close(true);
        };

        const render = () => {
            const term = normalize(search.value.trim());
            const filtered = term
                ? options.filter((option) => normalize(option.text).includes(term))
                : options;

            optionsHost.replaceChildren(...filtered.map((option) => {
                const button = document.createElement("button");
                button.type = "button";
                button.className = "lazy-search-select-option";
                button.setAttribute("role", "option");
                button.setAttribute("aria-selected", String(option.value === hiddenInput.value));
                button.textContent = option.text;
                button.addEventListener("click", () => selectOption(option));
                return button;
            }));

            status.hidden = filtered.length > 0;
            status.textContent = options.length === 0
                ? "Seçenek bulunamadı."
                : "Aramanızla eşleşen seçenek bulunamadı.";
        };

        const load = () => {
            if (loadPromise) return loadPromise;
            status.hidden = false;
            status.textContent = "Seçenekler yükleniyor...";
            loadPromise = fetch(endpoint, {
                headers: { "X-Requested-With": "XMLHttpRequest" },
                credentials: "same-origin"
            })
                .then((response) => {
                    if (!response.ok) throw new Error("Seçenekler yüklenemedi.");
                    return response.json();
                })
                .then((items) => {
                    options = Array.isArray(items) ? items : [];
                    render();
                })
                .catch(() => {
                    loadPromise = undefined;
                    status.hidden = false;
                    status.textContent = "Seçenekler yüklenemedi. Tekrar denemek için alanı kapatıp açın.";
                });
            return loadPromise;
        };

        const open = async () => {
            panel.hidden = false;
            trigger.setAttribute("aria-expanded", "true");
            control.classList.add("is-open");
            await load();
            search.focus();
        };

        trigger.addEventListener("click", () => panel.hidden ? open() : close());
        search.addEventListener("input", render);
        clearSearch?.addEventListener("click", () => {
            search.value = "";
            render();
            search.focus();
        });
        search.addEventListener("keydown", (event) => {
            if (event.key === "Escape") close(true);
            if (event.key === "ArrowDown") {
                event.preventDefault();
                optionsHost.querySelector("button")?.focus();
            }
        });
        optionsHost.addEventListener("keydown", (event) => {
            const buttons = [...optionsHost.querySelectorAll("button")];
            const index = buttons.indexOf(document.activeElement);
            if (event.key === "Escape") close(true);
            if (event.key === "ArrowDown" && index < buttons.length - 1) {
                event.preventDefault();
                buttons[index + 1].focus();
            }
            if (event.key === "ArrowUp") {
                event.preventDefault();
                if (index > 0) buttons[index - 1].focus();
                else search.focus();
            }
        });
        document.addEventListener("pointerdown", (event) => {
            if (!control.contains(event.target)) close();
        });
    });
})();
