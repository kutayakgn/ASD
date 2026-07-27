(() => {
    const getFileName = (response) => {
        const disposition = response.headers.get("Content-Disposition") || "";
        const encodedName = /filename\*=UTF-8''([^;]+)/i.exec(disposition)?.[1];
        if (encodedName) {
            try {
                return decodeURIComponent(encodedName);
            } catch {
                // Fall back to the plain filename when the encoded value is malformed.
            }
        }

        return /filename="?([^";]+)"?/i.exec(disposition)?.[1] || "rapor.xlsx";
    };

    document.addEventListener("submit", async (event) => {
        const form = event.target.closest("form[data-excel-export]");
        if (!form) return;

        event.preventDefault();
        if (form.dataset.exportBusy === "true") return;

        const submitter = event.submitter ?? form.querySelector('button[type="submit"]');
        form.dataset.exportBusy = "true";
        if (submitter) {
            submitter.disabled = true;
            submitter.setAttribute("aria-busy", "true");
        }

        try {
            const response = await fetch(form.action, {
                method: form.method || "POST",
                body: new FormData(form),
                headers: { "X-Requested-With": "XMLHttpRequest" }
            });
            const contentType = response.headers.get("Content-Type") || "";
            if (!response.ok || !contentType.includes("spreadsheetml")) {
                throw new Error(
                    response.redirected
                        ? "Oturumunuz sona ermiş olabilir. Lütfen tekrar giriş yapınız."
                        : "Excel dosyası oluşturulamadı.");
            }

            const blob = await response.blob();
            if (blob.size === 0) {
                throw new Error("Oluşturulan Excel dosyası boş.");
            }

            const downloadUrl = URL.createObjectURL(blob);
            const link = document.createElement("a");
            link.href = downloadUrl;
            link.download = getFileName(response);
            link.hidden = true;
            document.body.appendChild(link);
            link.click();
            link.remove();
            window.setTimeout(() => URL.revokeObjectURL(downloadUrl), 1000);
        } catch (error) {
            console.error(error);
            window.genericPopup?.fail(error.message || "Excel dosyası indirilemedi.");
        } finally {
            delete form.dataset.exportBusy;
            if (submitter) {
                submitter.disabled = false;
                submitter.removeAttribute("aria-busy");
            }
        }
    });
})();