(() => {
    const animationDuration = 320;
    const animationTimers = new WeakMap();

    const clearAnimation = (content) => {
        const timer = animationTimers.get(content);
        if (timer) window.clearTimeout(timer);
        animationTimers.delete(content);
    };

    const setOpen = (section, open, animate = true) => {
        const trigger = section.querySelector("[data-settings-trigger]");
        const content = section.querySelector("[data-settings-content]");
        if (!trigger || !content) return;

        clearAnimation(content);
        section.classList.toggle("is-open", open);
        trigger.setAttribute("aria-expanded", open ? "true" : "false");

        if (!animate) {
            content.hidden = !open;
            content.style.height = open ? "auto" : "0px";
            return;
        }

        if (open) {
            content.hidden = false;
            content.style.height = "0px";
            void content.offsetHeight;
            content.style.height = `${content.scrollHeight}px`;
            animationTimers.set(content, window.setTimeout(() => {
                if (section.classList.contains("is-open")) content.style.height = "auto";
                animationTimers.delete(content);
            }, animationDuration));
            return;
        }

        if (content.hidden) {
            content.style.height = "0px";
            return;
        }

        content.style.height = `${content.scrollHeight}px`;
        void content.offsetHeight;
        content.style.height = "0px";
        animationTimers.set(content, window.setTimeout(() => {
            if (!section.classList.contains("is-open")) content.hidden = true;
            animationTimers.delete(content);
        }, animationDuration));
    };

    document.querySelectorAll("[data-settings-accordion]").forEach((accordion) => {
        accordion.querySelectorAll("[data-settings-section]").forEach((section) => {
            setOpen(section, false, false);
        });
    });

    document.addEventListener("click", (event) => {
        const trigger = event.target.closest("[data-settings-trigger]");
        if (!trigger) return;
        const accordion = trigger.closest("[data-settings-accordion]");
        const selected = trigger.closest("[data-settings-section]");
        if (!accordion || !selected) return;

        const willOpen = !selected.classList.contains("is-open");
        accordion.querySelectorAll("[data-settings-section]").forEach((section) => {
            setOpen(section, section === selected && willOpen);
        });
    });
})();