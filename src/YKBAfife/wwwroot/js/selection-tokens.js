(() => {
    const create = (label, type, value) => {
        const token = document.createElement("button");
        token.type = "button";
        token.className = "add-play-selection-token";
        token.setAttribute("aria-label", `${label} seçimini kaldır`);
        token.dataset.selectionRemove = type;
        token.dataset.selectionValue = value;

        const text = document.createElement("span");
        text.textContent = label;
        const removeIcon = document.createElement("img");
        removeIcon.className = "add-play-selection-remove-icon";
        removeIcon.src = "/icons/x-white.svg";
        removeIcon.alt = "";
        removeIcon.setAttribute("aria-hidden", "true");
        token.append(text, removeIcon);
        return token;
    };

    window.selectionTokens = { create };
})();
