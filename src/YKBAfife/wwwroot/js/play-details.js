(() => {
    const backLink = document.querySelector("[data-play-details-back]");
    if (!backLink) return;

    backLink.addEventListener("click", (event) => {
        const fallbackUrl = backLink.href;
        let canReturnToReferrer = false;

        try {
            canReturnToReferrer = Boolean(document.referrer) &&
                new URL(document.referrer).origin === window.location.origin;
        } catch {
            canReturnToReferrer = false;
        }

        event.preventDefault();
        if (canReturnToReferrer && window.history.length > 1) {
            window.history.back();
            return;
        }

        window.location.assign(fallbackUrl);
    });
})();
