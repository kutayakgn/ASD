(() => {
    const validate = (input) => {
        input.setCustomValidity("");
        let message = "";

        if (input.validity.valueMissing || input.value.trim() === "") {
            message = "Bilet ücreti zorunludur.";
        } else if (input.validity.badInput) {
            message = "Geçerli formatta bir bilet ücreti giriniz.";
        } else if (Number(input.value) <= 0 || input.validity.rangeUnderflow) {
            message = "Bilet ücreti 0'dan büyük olmalıdır.";
        } else if (input.validity.stepMismatch) {
            message = "Bilet ücreti en fazla iki ondalık basamak içermelidir.";
        } else if (!input.validity.valid) {
            message = "Geçerli formatta bir bilet ücreti giriniz.";
        }
        return message;
    };

    document.addEventListener("input", (event) => {
        const input = event.target.closest("[data-ticket-fee-input]");
        if (!input) return;
        validate(input);
    });

    document.addEventListener("submit", (event) => {
        const form = event.target.closest("[data-ticket-fee-form]");
        if (!form) return;
        const input = form.querySelector("[data-ticket-fee-input]");
        if (!input) return;
        const message = validate(input);
        if (!message) return;

        event.preventDefault();
        event.stopImmediatePropagation();
        if (window.genericPopup) {
            window.genericPopup.fail(message);
        }
    });
})();
