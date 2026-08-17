(() => {
    const normalize = (input) => {
        const normalizedValue = input.value.replace(/\D/g, "").slice(0, 5);
        if (input.value !== normalizedValue) input.value = normalizedValue;
    };

    const validate = (input) => {
        input.setCustomValidity("");
        let message = "";

        if (input.value === "") {
            message = "Bilet ücreti boş olamaz.";
        } else if (!/^\d{1,5}$/.test(input.value)) {
            message = "Bilet ücreti en fazla 5 basamaklı tam sayı olmalıdır.";
        } else if (Number(input.value) === 0) {
            message = "Bilet ücreti 0'dan büyük olmalıdır.";
        } else if (Number(input.value) === Number(input.dataset.originalTicketFee)) {
            message = "Bilet ücreti mevcut değerle aynı olamaz.";
        }
        return message;
    };

    document.addEventListener("input", (event) => {
        const input = event.target.closest("[data-ticket-fee-input]");
        if (!input) return;
        normalize(input);
        validate(input);
    });

    document.addEventListener("submit", (event) => {
        const form = event.target.closest("[data-ticket-fee-form]");
        if (!form) return;
        const input = form.querySelector("[data-ticket-fee-input]");
        if (!input) return;
        normalize(input);
        const message = validate(input);
        if (!message) return;

        event.preventDefault();
        event.stopImmediatePropagation();
        if (window.genericPopup) {
            window.genericPopup.fail(message);
        }
    });
})();
