(() => {
    const controls = document.querySelectorAll("[data-rotating-select]");

    controls.forEach((control) => {
        const select = control.querySelector("select");
        if (!select) return;

        const close = () => control.classList.remove("is-open");

        select.addEventListener("pointerdown", () => {
            control.classList.toggle("is-open");
        });
        select.addEventListener("change", close);
        select.addEventListener("blur", close);
        select.addEventListener("keydown", (event) => {
            if (event.key === "Escape" || event.key === "Enter") close();
        });
    });
})();
