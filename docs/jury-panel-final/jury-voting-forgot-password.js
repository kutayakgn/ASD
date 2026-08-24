document.addEventListener("DOMContentLoaded", () => {
    const requested = document.getElementById("forgotPasswordRequested");
    const message = document.getElementById("forgotPasswordRequestedMessage");
    if (!requested || !message) return;

    showPasswordFlowPopup("/icon/circle-check-solid.svg", message.value);
});

function showPasswordFlowPopup(iconUrl, message) {
    document.getElementById("voteValidationPopup")?.remove();

    const overlay = document.createElement("div");
    overlay.id = "voteValidationPopup";
    overlay.className = "vote-validation-popup-overlay";

    const card = document.createElement("div");
    card.className = "vote-validation-popup-card";

    const icon = document.createElement("img");
    icon.src = iconUrl;
    icon.alt = "";

    const text = document.createElement("div");
    text.className = "vote-validation-popup-message";
    text.textContent = message;

    const button = document.createElement("button");
    button.type = "button";
    button.className = "vote-validation-popup-ok";
    button.textContent = "Tamam";
    button.addEventListener("click", () => overlay.remove());

    card.append(icon, text, button);
    overlay.append(card);
    document.body.append(overlay);
    button.focus();
}
