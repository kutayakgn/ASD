document.addEventListener("change", (event) => {
    const modeInput = event.target.closest("[data-add-candidate] input[name='Input.Mode']");
    if (!modeInput) return;

    const component = modeInput.closest("[data-add-candidate]");
    component.querySelectorAll("[data-candidate-fields]").forEach((section) => {
        section.hidden = section.dataset.candidateFields !== modeInput.value;
    });
});
