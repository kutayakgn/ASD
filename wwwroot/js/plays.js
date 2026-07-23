(() => {
    const panel = document.querySelector("#play-filter-panel");
    const backdrop = document.querySelector(".play-filter-backdrop");
    const form = panel?.querySelector("[data-play-filter-form]");
    if (!panel || !backdrop || !form) return;

    let opener = null;
    const resetButton = form.querySelector("[data-play-filter-reset]");
    const updateResetVisibility = () => {
        if (resetButton) resetButton.hidden = !form.querySelector('input[type="radio"]:checked');
    };

    const openPanel = (trigger) => {
        opener = trigger;
        panel.removeAttribute("inert");
        panel.setAttribute("aria-hidden", "false");
        backdrop.hidden = false;
        document.body.classList.add("play-filter-open");
        trigger.setAttribute("aria-expanded", "true");
        window.requestAnimationFrame(() => {
            panel.classList.add("is-open");
            backdrop.classList.add("is-open");
            panel.querySelector("input:checked, input")?.focus({ preventScroll: true });
        });
    };

    const closePanel = () => {
        panel.classList.remove("is-open");
        backdrop.classList.remove("is-open");
        panel.setAttribute("aria-hidden", "true");
        panel.setAttribute("inert", "");
        document.body.classList.remove("play-filter-open");
        opener?.setAttribute("aria-expanded", "false");
        window.setTimeout(() => {
            backdrop.hidden = true;
            opener?.focus({ preventScroll: true });
        }, 200);
    };

    const selectedValue = (name) =>
        form.querySelector(`input[name="${name}"]:checked`)?.value ?? "";

    document.addEventListener("click", (event) => {
        const trigger = event.target.closest('[data-complex-table-panel-target="play-filter-panel"]');
        if (trigger) {
            event.preventDefault();
            openPanel(trigger);
            return;
        }

        if (event.target.closest("[data-play-filter-dismiss]")) {
            closePanel();
            return;
        }

        if (event.target.closest("[data-play-filter-reset]")) {
            form.querySelectorAll('input[type="radio"]').forEach((input) => {
                input.checked = false;
            });
            updateResetVisibility();
            updateTableWithFilters();
        }
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && panel.classList.contains("is-open")) {
            closePanel();
        }
    });

    const updateTableWithFilters = () => {
        const section = document.querySelector("#plays-table[data-complex-table]");
        if (!section) return;

        const filters = {
            JuryVotingStatus: selectedValue("JuryVotingStatus"),
            KunyeGirisStatus: selectedValue("KunyeGirisStatus"),
            RecordType: selectedValue("RecordType"),
            page: "1"
        };

        Object.entries(filters).forEach(([name, value]) => {
            const input = section.querySelector(`[data-complex-table-state] input[name="${name}"]`);
            if (input) input.value = value;
        });

        section.dispatchEvent(new CustomEvent("complex-table:update", {
            bubbles: true,
            detail: filters
        }));
        closePanel();
    };

    form.addEventListener("change", updateResetVisibility);

    form.addEventListener("submit", (event) => {
        event.preventDefault();
        updateTableWithFilters();
    });
})();
