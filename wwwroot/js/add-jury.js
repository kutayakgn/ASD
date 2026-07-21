(() => {
    document.addEventListener("change", (event) => {
        const input = event.target.closest("[data-jury-photo-input]");
        if (!input) return;

        const fileName = document.querySelector("[data-jury-file-name]");
        if (fileName) {
            fileName.textContent = input.files?.[0]?.name || "Dosya Ekle";
        }
    });

    document.addEventListener("click", (event) => {
        const cancel = event.target.closest("[data-history-back]");
        if (!cancel || window.history.length <= 1) return;

        event.preventDefault();
        window.history.back();
    });
})();
