(() => {
    const form = document.querySelector("[data-edit-candidate-form]");
    if (!form) return;

    const candidateInput = form.querySelector("[name='Candidate']");
    const roleInput = form.querySelector("[name='Role']");
    const originalRoleInput = form.querySelector("[name='OriginalRole']");
    const statusInputs = [...form.querySelectorAll("[name='IsActive']")];
    const confirmGroupInput = form.querySelector("[data-confirm-role-group-update]");
    const otherRolesSource = document.querySelector("[data-edit-candidate-other-roles]");
    const relatedCandidatesSource = document.querySelector("[data-edit-candidate-related-candidates]");
    const otherRoles = JSON.parse(otherRolesSource?.textContent || "[]");
    const relatedCandidates = JSON.parse(relatedCandidatesSource?.textContent || "[]");
    const duplicateMessage = "Böyle bir rol zaten mevcut, lütfen başka bir rol için aday girişi yapın veya Oyun Detay ekranından Aday/Rol Değişim seçeneği ile ilerleyin";

    const normalize = (value) => (value || "").trim().toLocaleLowerCase("tr-TR");

    const validate = () => {
        const errors = [];
        const candidate = candidateInput?.value.trim() || "";
        const role = roleInput?.value.trim() || "";
        if (candidate.length < 2 || candidate.length > 250) {
            errors.push("Adı Soyadı alanı 2 ile 250 karakter arasında olmalıdır.");
        }
        if (roleInput && !role) errors.push("Rol Adı alanı zorunludur.");
        if (role.length > 200) errors.push("Rol Adı en fazla 200 karakter olabilir.");
        if (!statusInputs.some((input) => input.checked)) errors.push("Statü seçimi zorunludur.");
        return errors;
    };

    const showRoleGroupQuestion = (submitter) => {
        const content = document.createDocumentFragment();
        content.append(document.createTextNode("Bu rolde adaylar da var:"), document.createElement("br"));
        relatedCandidates.forEach((candidate, index) => {
            const link = document.createElement("a");
            link.href = candidate.Url;
            link.textContent = candidate.Name;
            if (index > 0) content.append(document.createElement("br"));
            content.append(link);
        });
        content.append(
            document.createElement("br"),
            document.createTextNode("Devam ederseniz onların da Rol Adı güncellenecektir."),
            document.createElement("br"),
            document.createTextNode("Devam Etmek İstediğinize emin misiniz?")
        );

        window.genericPopup?.show({
            type: "question",
            messageContent: content,
            confirmText: "Evet",
            cancelText: "İptal",
            showCancel: true,
            returnFocus: submitter,
            onConfirm: () => {
                if (confirmGroupInput) confirmGroupInput.value = "true";
                form.dataset.editCandidateConfirmed = "true";
                form.requestSubmit(submitter || undefined);
            }
        });
    };

    form.addEventListener("submit", (event) => {
        if (form.dataset.editCandidateConfirmed === "true") return;
        event.preventDefault();

        const errors = validate();
        if (errors.length) {
            window.genericPopup?.fail(errors.join("\n"));
            return;
        }

        const roleChanged = roleInput && roleInput.value.trim() !== (originalRoleInput?.value || "").trim();
        if (roleChanged && otherRoles.some((role) => normalize(role) === normalize(roleInput.value))) {
            window.genericPopup?.fail(duplicateMessage);
            return;
        }

        if (roleChanged && relatedCandidates.length > 0) {
            showRoleGroupQuestion(event.submitter);
            return;
        }

        form.dataset.editCandidateConfirmed = "true";
        form.requestSubmit(event.submitter || undefined);
    });
})();