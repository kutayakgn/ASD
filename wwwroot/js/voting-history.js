(() => {
    const page = document.querySelector("[data-voting-history]");
    if (!page) return;

    const playInput = page.querySelector("[name='PlayId']");
    const juryInput = page.querySelector("[name='JuryId']");
    const results = page.querySelector("[data-voting-history-results]");
    const token = page.querySelector("[data-voting-history-token] input[name='__RequestVerificationToken']")?.value;
    let requestController;

    const candidateHasVote = (candidate) => {
        if (candidate.tagName === "SELECT") {
            return candidate.selectedOptions[0]?.dataset.hasVote === "true";
        }
        return candidate.dataset.hasVote === "true";
    };

    const syncCard = (card) => {
        const candidate = card.querySelector("[data-vote-candidate]");
        card.querySelector("[data-reset-vote]").disabled = !candidateHasVote(candidate);
    };

    const loadCards = async () => {
        if (!playInput.value || !juryInput.value) {
            results.innerHTML = '<p class="voting-history-empty">Kategorileri görüntülemek için oyun ve jüri seçin.</p>';
            return;
        }

        requestController?.abort();
        requestController = new AbortController();
        results.setAttribute("aria-busy", "true");
        results.innerHTML = '<p class="voting-history-empty">Kategoriler yükleniyor...</p>';
        const query = new URLSearchParams({ playId: playInput.value, juryId: juryInput.value });

        try {
            const response = await fetch(`/oylama-gecmisi/kategoriler?${query}`, {
                headers: { "X-Requested-With": "XMLHttpRequest" },
                credentials: "same-origin",
                signal: requestController.signal
            });
            if (!response.ok) throw new Error();
            results.innerHTML = await response.text();
        } catch (error) {
            if (error.name !== "AbortError") {
                results.innerHTML = '<p class="voting-history-empty is-error">Kategori bilgileri yüklenemedi.</p>';
            }
        } finally {
            results.removeAttribute("aria-busy");
        }
    };

    playInput.addEventListener("change", loadCards);
    juryInput.addEventListener("change", loadCards);
    results.addEventListener("change", (event) => {
        const candidate = event.target.closest("[data-vote-candidate]");
        if (candidate) syncCard(candidate.closest("[data-vote-card]"));
    });
    results.addEventListener("click", (event) => {
        const button = event.target.closest("[data-reset-vote]");
        if (!button || button.disabled) return;
        const card = button.closest("[data-vote-card]");
        const candidate = card.querySelector("[data-vote-candidate]");
        const playAwardCategoryId = candidate.value;

        window.genericPopup.question("Bu oylamayı sıfırlamak istediğinize emin misiniz?", async () => {
            button.disabled = true;
            try {
                const body = new URLSearchParams({
                    playId: playInput.value,
                    juryId: juryInput.value,
                    playAwardCategoryId,
                    __RequestVerificationToken: token
                });
                const response = await fetch("/oylama-gecmisi/oylamayi-sifirla", {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                        "X-Requested-With": "XMLHttpRequest"
                    },
                    credentials: "same-origin",
                    body
                });
                const payload = await response.json();
                if (!response.ok || !payload.success) throw new Error(payload.message);
                await loadCards();
                window.genericPopup.success(payload.message);
            } catch (error) {
                button.disabled = false;
                window.genericPopup.fail(error.message || "Oylama sıfırlanamadı.");
            }
        });
    });
})();
