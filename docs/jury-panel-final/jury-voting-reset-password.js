document.addEventListener("DOMContentLoaded", () => {
    // Token hidden inputta kaldığı için adres çubuğundan ve sonraki Referer değerlerinden temizlenir.
    if (window.location.search) {
        window.history.replaceState(null, document.title, window.location.pathname);
    }

    const form = document.querySelector(".jury-voting-reset-password-form");
    const password = document.getElementById("NewPassword");
    const confirmation = document.getElementById("ConfirmPassword");
    if (!form || !password || !confirmation) return;

    form.addEventListener("submit", event => {
        const missingRules = [];
        const value = password.value;

        if (value.length < 8 || value.length > 100) missingRules.push("Şifre 8-100 karakter olmalıdır.");
        if (!/[A-Z]/.test(value) || !/[a-z]/.test(value)) missingRules.push("Büyük ve küçük harf içermelidir.");
        if (!/\d/.test(value)) missingRules.push("En az bir rakam içermelidir.");
        if (!/[.,*!+\-@]/.test(value)) missingRules.push("En az bir özel karakter (.,*!+-@) içermelidir.");
        if (value !== confirmation.value) missingRules.push("Şifreler eşleşmelidir.");

        if (missingRules.length === 0) return;
        event.preventDefault();
        showResetValidationPopup(missingRules);
    });
});

function showResetValidationPopup(messages) {
    document.getElementById("voteValidationPopup")?.remove();

    const overlay = document.createElement("div");
    overlay.id = "voteValidationPopup";
    overlay.className = "vote-validation-popup-overlay";

    const card = document.createElement("div");
    card.className = "vote-validation-popup-card";

    const icon = document.createElement("img");
    icon.src = "/icon/circle-exclamation-solid.svg";
    icon.alt = "";

    const list = document.createElement("ul");
    list.className = "vote-validation-popup-message";
    messages.forEach(message => {
        const item = document.createElement("li");
        item.textContent = message;
        list.append(item);
    });

    const button = document.createElement("button");
    button.type = "button";
    button.className = "vote-validation-popup-ok";
    button.textContent = "Tamam";
    button.addEventListener("click", () => overlay.remove());

    card.append(icon, list, button);
    overlay.append(card);
    document.body.append(overlay);
    button.focus();
}
