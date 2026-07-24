(() => {
    const syncCandidateFields = (component) => {
        const selectedMode = component.querySelector("input[name='Input.Mode']:checked")?.value ?? "new";
        component.querySelectorAll("[data-candidate-fields]").forEach((section) => {
            const supportedModes = section.dataset.candidateFields.split(/\s+/);
            section.hidden = !supportedModes.includes(selectedMode);
        });
    };

    const syncRoleField = (component) => {
        const categorySelect = component.querySelector("[data-candidate-category]");
        const roleField = component.querySelector("[data-candidate-role-field]");
        const roleInput = component.querySelector("[data-candidate-role]");
        if (!categorySelect || !roleField || !roleInput) return;

        const isMultiCandidate = categorySelect.selectedOptions[0]?.dataset.multiCandidate === "true";
        roleField.hidden = !isMultiCandidate;
        roleInput.disabled = !isMultiCandidate;
        roleInput.required = isMultiCandidate;
        if (!isMultiCandidate) roleInput.value = "";
    };

    document.addEventListener("change", (event) => {
        const component = event.target.closest?.("[data-add-candidate]");
        if (!component) return;

        if (event.target.matches("input[name='Input.Mode']")) {
            syncCandidateFields(component);
        }
        if (event.target.matches("[data-candidate-category]")) {
            syncRoleField(component);
        }
    });

    document.querySelectorAll("[data-add-candidate]").forEach((component) => {
        syncCandidateFields(component);
        syncRoleField(component);
    });
})();