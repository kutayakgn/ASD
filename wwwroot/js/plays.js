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
(() => {
    let activeTooltip = null;
    let closeTimer = 0;

    const cancelClose = () => {
        window.clearTimeout(closeTimer);
        closeTimer = 0;
    };

    const closeTooltip = () => {
        cancelClose();
        if (!activeTooltip) return;

        activeTooltip.trigger.setAttribute("aria-expanded", "false");
        activeTooltip.trigger.removeAttribute("aria-describedby");
        activeTooltip.element.remove();
        activeTooltip = null;
    };

    const scheduleClose = () => {
        cancelClose();
        closeTimer = window.setTimeout(() => {
            const focusedElement = document.activeElement;
            if (activeTooltip?.element.contains(focusedElement) ||
                activeTooltip?.trigger.contains(focusedElement)) {
                return;
            }

            closeTooltip();
        }, 160);
    };

    const positionTooltip = (trigger, tooltip) => {
        const gap = 8;
        const viewportPadding = 16;
        const triggerBounds = trigger.getBoundingClientRect();
        const tooltipBounds = tooltip.getBoundingClientRect();
        const maximumLeft = window.innerWidth - tooltipBounds.width - viewportPadding;
        const left = Math.min(
            Math.max(viewportPadding, triggerBounds.left),
            Math.max(viewportPadding, maximumLeft));
        const belowTop = triggerBounds.bottom + gap;
        const top = belowTop + tooltipBounds.height <= window.innerHeight - viewportPadding
            ? belowTop
            : Math.max(viewportPadding, triggerBounds.top - tooltipBounds.height - gap);

        tooltip.style.left = `${left}px`;
        tooltip.style.top = `${top}px`;
    };

    const openTooltip = (trigger) => {
        cancelClose();
        if (activeTooltip?.trigger === trigger) return;

        closeTooltip();
        const template = trigger.parentElement?.querySelector("[data-play-similar-content]");
        if (!(template instanceof HTMLTemplateElement)) return;

        const tooltip = document.createElement("div");
        const tooltipId = `play-similar-tooltip-${crypto.randomUUID()}`;
        tooltip.id = tooltipId;
        tooltip.className = "play-similar-tooltip";
        tooltip.setAttribute("role", "tooltip");
        tooltip.append(template.content.cloneNode(true));
        tooltip.addEventListener("mouseenter", cancelClose);
        tooltip.addEventListener("mouseleave", scheduleClose);
        tooltip.addEventListener("focusin", cancelClose);
        tooltip.addEventListener("focusout", scheduleClose);
        document.body.append(tooltip);

        activeTooltip = { trigger, element: tooltip };
        trigger.setAttribute("aria-expanded", "true");
        trigger.setAttribute("aria-describedby", tooltipId);
        positionTooltip(trigger, tooltip);
    };

    document.addEventListener("mouseover", (event) => {
        const trigger = event.target.closest?.("[data-play-similar-trigger]");
        if (!trigger || trigger.contains(event.relatedTarget)) return;
        openTooltip(trigger);
    });

    document.addEventListener("mouseout", (event) => {
        const trigger = event.target.closest?.("[data-play-similar-trigger]");
        if (!trigger || trigger.contains(event.relatedTarget)) return;
        scheduleClose();
    });

    document.addEventListener("focusin", (event) => {
        const trigger = event.target.closest?.("[data-play-similar-trigger]");
        if (trigger) openTooltip(trigger);
    });

    document.addEventListener("focusout", (event) => {
        if (event.target.closest?.("[data-play-similar-trigger]")) scheduleClose();
    });

    document.addEventListener("click", (event) => {
        const trigger = event.target.closest?.("[data-play-similar-trigger]");
        if (trigger) {
            event.preventDefault();
            event.stopPropagation();
            if (activeTooltip?.trigger === trigger) {
                closeTooltip();
            } else {
                openTooltip(trigger);
            }
            return;
        }

        if (activeTooltip && !activeTooltip.element.contains(event.target)) {
            closeTooltip();
        }
    });

    document.addEventListener("keydown", (event) => {
        if (event.key === "Escape" && activeTooltip) {
            const trigger = activeTooltip.trigger;
            closeTooltip();
            trigger.focus({ preventScroll: true });
        }
    });

    document.addEventListener("complex-table:update", closeTooltip);
    window.addEventListener("resize", closeTooltip);
    window.addEventListener("scroll", closeTooltip, true);
})();
