(() => {
    const getValue = (form, name) => form.elements.namedItem(name)?.value || "";
    const unique = (messages) => [...new Set(messages)];

    const validateDates = (form) => {
        const values = {
            seasonStart: getValue(form, "SeasonStartDate"),
            seasonEnd: getValue(form, "SeasonEndDate"),
            kunyeStart: getValue(form, "KunyeRegistrationStartDate"),
            kunyeEnd: getValue(form, "KunyeRegistrationEndDate"),
            votingStart: getValue(form, "VotingStartDate"),
            votingEnd: getValue(form, "VotingEndDate")
        };
        const messages = [];
        const required = [
            [values.seasonStart, "Sezon başlangıç tarihi zorunludur."],
            [values.kunyeStart, "Künye kayıt başlangıç tarihi zorunludur."],
            [values.kunyeEnd, "Künye kayıt bitiş tarihi zorunludur."],
            [values.votingStart, "Oylama başlangıç tarihi zorunludur."],
            [values.votingEnd, "Oylama bitiş tarihi zorunludur."],
            [values.seasonEnd, "Sezon bitiş tarihi zorunludur."]
        ];
        required.forEach(([value, message]) => { if (!value) messages.push(message); });
        if (messages.length > 0) return unique(messages);

        if (values.seasonStart >= values.seasonEnd) {
            messages.push("Sezon başlangıç tarihi sezon bitiş tarihinden önce olmalıdır.");
        }
        if (values.kunyeStart < values.seasonStart) {
            messages.push("Künye kayıt başlangıç tarihi sezon başlangıç tarihinden önce olamaz.");
        }
        if (values.kunyeEnd <= values.kunyeStart) {
            messages.push("Künye kayıt bitiş tarihi künye kayıt başlangıç tarihinden sonra olmalıdır.");
        }
        if (values.kunyeEnd > values.seasonEnd) {
            messages.push("Künye kayıt bitiş tarihi sezon bitiş tarihinden sonra olamaz.");
        }
        if (values.votingStart < values.seasonStart || values.votingStart > values.seasonEnd) {
            messages.push("Oylama başlangıç tarihi sezon tarihleri arasında olmalıdır.");
        }
        if (values.votingEnd < values.seasonStart || values.votingEnd > values.seasonEnd) {
            messages.push("Oylama bitiş tarihi sezon tarihleri arasında olmalıdır.");
        }
        if (values.votingStart >= values.votingEnd) {
            messages.push("Oylama başlangıç tarihi oylama bitiş tarihinden önce olmalıdır.");
        }

        if (values.seasonStart < values.seasonEnd) {
            const conflictingSeason = Array.from(form.querySelectorAll("[data-season-range]"))
                .find((season) =>
                    values.seasonStart <= season.dataset.seasonEnd &&
                    values.seasonEnd >= season.dataset.seasonStart);
            if (conflictingSeason) {
                const exactRange = values.seasonStart === conflictingSeason.dataset.seasonStart &&
                    values.seasonEnd === conflictingSeason.dataset.seasonEnd;
                messages.push(exactRange
                    ? conflictingSeason.dataset.seasonName + " sezonuyla aynı başlangıç ve bitiş tarihleri kullanılamaz."
                    : "Sezon tarihleri " + conflictingSeason.dataset.seasonName +
                        " sezonuyla çakışıyor. Sezonlar ortak tarihe sahip olamaz.");
            }
        }
        return unique(messages);
    };

    document.addEventListener("submit", (event) => {
        const form = event.target.closest("[data-season-form]");
        if (!form || form.dataset.seasonConfirmed === "true") return;

        const messages = validateDates(form);
        if (messages.length > 0) {
            event.preventDefault();
            event.stopImmediatePropagation();
            window.genericPopup?.fail(messages.join("\n"));
            return;
        }

        if (form.dataset.seasonFormMode === "edit") {
            const changed = Array.from(form.querySelectorAll("[data-track-change]"))
                .some((field) => field.value !== field.dataset.initialValue);
            if (!changed) {
                event.preventDefault();
                event.stopImmediatePropagation();
                window.genericPopup?.fail("Herhangi bir değişiklik yapmadınız.");
                return;
            }
        }

        event.preventDefault();
        event.stopImmediatePropagation();
        const submitter = event.submitter;
        window.genericPopup?.show({
            type: "question",
            message: form.dataset.confirmMessage,
            confirmText: "Evet",
            cancelText: "İptal",
            showCancel: true,
            returnFocus: submitter,
            onConfirm: () => {
                form.dataset.seasonConfirmed = "true";
                form.requestSubmit(submitter || undefined);
            }
        });
    }, true);
})();
