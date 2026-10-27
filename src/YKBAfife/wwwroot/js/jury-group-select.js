(() => {
    document.querySelectorAll("[data-jury-group-select]").forEach((field) => {
        const value = field.querySelector("[data-jury-group-value]");
        const custom = field.querySelector("[data-jury-group-custom]");
        const trigger = field.querySelector("[data-jury-group-trigger]");
        const selected = field.querySelector("[data-jury-group-selected]");
        const menu = field.querySelector("[data-jury-group-menu]");
        const options = [...field.querySelectorAll("[data-jury-group-option]")];
        if (!value || !custom || !trigger || !selected || !menu || !options.length ||
            !window.selectionTokens?.create) return;

        const setOpen = (open, returnFocus = false) => {
            menu.hidden = !open;
            field.classList.toggle("is-open", open);
            trigger.setAttribute("aria-expanded", String(open));
            if (open) {
                const current = options.find((option) => option.dataset.value === value.value) || options[0];
                current.focus({ preventScroll: true });
                current.scrollIntoView({ block: "nearest" });
            } else if (returnFocus) trigger.focus({ preventScroll: true });
        };

        const render = () => {
            selected.replaceChildren();
            const current = [...value.options].find((option) => option.value === value.value);
            if (value.value && current) {
                selected.append(window.selectionTokens.create(current.textContent, "jury-group", value.value));
            } else {
                const placeholder = document.createElement("span");
                placeholder.className = "add-play-select-placeholder";
                placeholder.textContent = "Jüri Grubunu Seçin";
                selected.append(placeholder);
            }
            options.forEach((option) => option.setAttribute("aria-selected", String(option.dataset.value === value.value)));
        };

        const choose = (code) => {
            value.value = code;
            value.dispatchEvent(new Event("change", { bubbles: true }));
            setOpen(false, true);
        };

        trigger.addEventListener("click", () => setOpen(menu.hidden));
        trigger.addEventListener("keydown", (event) => {
            if (event.target.closest("[data-selection-remove]")) return;
            if (["Enter", " ", "ArrowDown", "ArrowUp"].includes(event.key)) {
                event.preventDefault();
                setOpen(true);
            }
        });
        selected.addEventListener("click", (event) => {
            if (!event.target.closest("[data-selection-remove]")) return;
            event.stopPropagation();
            choose("");
        });
        menu.addEventListener("click", (event) => {
            const option = event.target.closest("[data-jury-group-option]");
            if (option) choose(option.dataset.value);
        });
        menu.addEventListener("keydown", (event) => {
            const currentIndex = options.indexOf(event.target.closest("[data-jury-group-option]"));
            let nextIndex;
            if (event.key === "ArrowDown") nextIndex = (currentIndex + 1) % options.length;
            else if (event.key === "ArrowUp") nextIndex = (currentIndex - 1 + options.length) % options.length;
            else if (event.key === "Home") nextIndex = 0;
            else if (event.key === "End") nextIndex = options.length - 1;
            if (nextIndex !== undefined) {
                event.preventDefault();
                options[nextIndex].focus({ preventScroll: true });
                options[nextIndex].scrollIntoView({ block: "nearest" });
            }
        });
        field.addEventListener("keydown", (event) => {
            if (event.key === "Escape") {
                event.preventDefault();
                event.stopPropagation();
                setOpen(false, true);
            } else if (event.key === "Tab") setOpen(false);
        });
        document.addEventListener("click", (event) => {
            if (!field.contains(event.target)) setOpen(false);
        });
        field.closest(".add-jury-field")?.querySelector("label")?.addEventListener("click", (event) => {
            event.preventDefault();
            trigger.focus({ preventScroll: true });
        });
        value.addEventListener("change", render);
        value.form?.addEventListener("reset", () => queueMicrotask(() => {
            render();
            setOpen(false);
        }));

        render();
        value.hidden = true;
        custom.hidden = false;
    });
})();
