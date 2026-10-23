(() => {
    const page = document.querySelector("[data-voting-history]");
    if (!page) return;

    const playInput = page.querySelector("[name='PlayId']");
    const juryInput = page.querySelector("[name='JuryId']");
    const results = page.querySelector("[data-voting-history-results]");
    const token = page.querySelector("[data-voting-history-token] input[name='__RequestVerificationToken']")?.value;
    let requestController;
    let generation = 0;
    let resetting = false;

    const candidateHasVote = (candidate) => candidate.tagName === "SELECT"
        ? candidate.selectedOptions[0]?.dataset.hasVote === "true"
        : candidate.dataset.hasVote === "true";

    // Include voted historical options in each rendered card, not only the
    // selected option. A bulk action must not silently leave those votes behind.
    const votedCandidateIds = () => [...new Set(
        [...results.querySelectorAll("[data-vote-candidate]")].flatMap((candidate) =>
            candidate.tagName === "SELECT"
                ? [...candidate.options].filter((option) => option.dataset.hasVote === "true").map((option) => option.value)
                : candidateHasVote(candidate) ? [candidate.value] : [])
    )];

    const syncControls = () => {
        results.querySelectorAll("[data-vote-card]").forEach((card) => {
            const candidate = card.querySelector("[data-vote-candidate]");
            card.querySelector("[data-reset-vote]").disabled = resetting || !candidateHasVote(candidate);
            candidate.disabled = resetting;
        });
        const bulk = results.querySelector("[data-reset-all-votes]");
        if (bulk) bulk.disabled = resetting || votedCandidateIds().length === 0;
    };

    const renderedScope = () => {
        const scope = results.querySelector("[data-voting-history-scope]");
        if (!scope || scope.dataset.playId !== playInput.value || scope.dataset.juryId !== juryInput.value) return null;
        return { playId: scope.dataset.playId, juryId: scope.dataset.juryId, generation };
    };

    const loadCards = async () => {
        const currentGeneration = ++generation;
        requestController?.abort();
        requestController = null;
        if (!playInput.value || !juryInput.value) {
            results.removeAttribute("aria-busy");
            results.innerHTML = '<p class="voting-history-empty">Kategorileri görüntülemek için oyun ve jüri seçin.</p>';
            return;
        }

        const controller = new AbortController();
        requestController = controller;
        results.setAttribute("aria-busy", "true");
        results.innerHTML = '<p class="voting-history-empty">Kategoriler yükleniyor...</p>';
        const query = new URLSearchParams({ playId: playInput.value, juryId: juryInput.value });
        try {
            const response = await fetch(`/oylama-gecmisi/kategoriler?${query}`, {
                headers: { "X-Requested-With": "XMLHttpRequest" },
                credentials: "same-origin",
                signal: controller.signal
            });
            if (!response.ok) throw new Error();
            const html = await response.text();
            if (currentGeneration !== generation) return;
            results.innerHTML = html;
            syncControls();
        } catch (error) {
            if (currentGeneration === generation && error.name !== "AbortError") {
                results.innerHTML = '<p class="voting-history-empty is-error">Kategori bilgileri yüklenemedi.</p>';
            }
        } finally {
            if (currentGeneration === generation) results.removeAttribute("aria-busy");
        }
    };

    const resetVotes = async (snapshot, bulk) => {
        const currentScope = renderedScope();
        if (!currentScope || snapshot.generation !== generation ||
            snapshot.playId !== currentScope.playId || snapshot.juryId !== currentScope.juryId) {
            window.genericPopup.fail("Oyun veya jüri seçimi değişti. Oylamaları kontrol edip tekrar deneyin.");
            return;
        }
        if (resetting) return;
        resetting = true;
        syncControls();
        try {
            const body = new URLSearchParams({
                playId: snapshot.playId,
                juryId: snapshot.juryId,
                __RequestVerificationToken: token
            });
            if (bulk) body.append("playAwardCategoryIdsJson", JSON.stringify(snapshot.candidateIds));
            else body.append("playAwardCategoryId", snapshot.candidateIds[0]);
            const response = await fetch(bulk
                ? "/oylama-gecmisi/tum-oylamalari-sifirla"
                : "/oylama-gecmisi/oylamayi-sifirla", {
                method: "POST",
                headers: {
                    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                    "X-Requested-With": "XMLHttpRequest"
                },
                credentials: "same-origin",
                body
            });
            const payload = await response.json();
            if (!response.ok || !payload.success) throw new Error(payload.message || "Oylama sıfırlanamadı.");
            await loadCards();
            window.genericPopup.success(payload.message);
        } catch (error) {
            window.genericPopup.fail(error.message || "Oylama sıfırlanamadı.");
        } finally {
            resetting = false;
            syncControls();
        }
    };

    playInput.addEventListener("change", loadCards);
    juryInput.addEventListener("change", loadCards);
    results.addEventListener("change", (event) => {
        if (event.target.closest("[data-vote-candidate]")) syncControls();
    });
    results.addEventListener("click", (event) => {
        const button = event.target.closest("[data-reset-vote], [data-reset-all-votes]");
        if (!button || button.disabled || resetting) return;
        const scope = renderedScope();
        if (!scope) return;
        const bulk = button.hasAttribute("data-reset-all-votes");
        const candidateIds = bulk ? votedCandidateIds()
            : [button.closest("[data-vote-card]").querySelector("[data-vote-candidate]").value];
        if (!candidateIds.length) return;
        const snapshot = { ...scope, candidateIds: [...candidateIds] };
        const question = bulk
            ? `Bu ekrandaki ${candidateIds.length} oylamayı sıfırlamak istediğinize emin misiniz?`
            : "Bu oylamayı sıfırlamak istediğinize emin misiniz?";
        window.genericPopup.question(question, () => resetVotes(snapshot, bulk));
    });
    loadCards();
})();
