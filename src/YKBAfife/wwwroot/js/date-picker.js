(() => {
    const pad = (value) => String(value).padStart(2, "0");
    const toIso = (date) => date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
    const toDisplay = (date) => pad(date.getDate()) + " / " + pad(date.getMonth() + 1) + " / " + date.getFullYear();
    const parseIso = (value) => {
        const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value || "");
        if (!match) return null;
        const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
        return Number.isNaN(date.getTime()) ? null : date;
    };
    const isSameDay = (left, right) => left && right &&
        left.getFullYear() === right.getFullYear() &&
        left.getMonth() === right.getMonth() &&
        left.getDate() === right.getDate();

    const enhanceTimeSelect = (select) => {
        if (!select.parentElement || !select.options.length) return null;
        const list = document.createElement("div");
        list.className = "application-calendar-time-options";
        list.dataset.timeOptions = "";
        list.setAttribute("role", "listbox");
        list.setAttribute("aria-label", select.getAttribute("aria-label") || "Saat seçimi");
        list.setAttribute("aria-orientation", "vertical");
        const buttons = Array.from(select.options, (option) => {
            const button = document.createElement("button");
            button.type = "button";
            button.className = "application-calendar-time-option";
            button.dataset.timeOption = option.value;
            button.textContent = option.textContent;
            button.disabled = option.disabled;
            button.setAttribute("role", "option");
            list.append(button);
            return button;
        });
        const enabledButtons = buttons.filter((button) => !button.disabled);
        const selectedButton = () => enabledButtons.find((button) => button.dataset.timeOption === select.value);
        const sync = () => {
            const selected = selectedButton();
            const tabStop = selected || enabledButtons[0];
            for (const button of buttons) {
                const isSelected = button === selected;
                button.classList.toggle("is-selected", isSelected);
                button.setAttribute("aria-selected", String(isSelected));
                button.tabIndex = button === tabStop ? 0 : -1;
            }
        };
        const scrollToButton = (button, center = false) => {
            if (!button || !list.clientHeight) return;
            const top = button.getBoundingClientRect().top - list.getBoundingClientRect().top + list.scrollTop;
            if (center) {
                list.scrollTop = Math.max(0, top - (list.clientHeight - button.offsetHeight) / 2);
            } else if (top < list.scrollTop) {
                list.scrollTop = top;
            } else if (top + button.offsetHeight > list.scrollTop + list.clientHeight) {
                list.scrollTop = top + button.offsetHeight - list.clientHeight;
            }
        };
        const choose = (button) => {
            if (!button || button.disabled) return;
            select.value = button.dataset.timeOption;
            select.dispatchEvent(new Event("change", { bubbles: true }));
            sync();
            button.focus({ preventScroll: true });
            scrollToButton(button);
        };
        list.addEventListener("click", (event) => choose(event.target.closest("[data-time-option]")));
        list.addEventListener("keydown", (event) => {
            const button = event.target.closest("[data-time-option]");
            const index = enabledButtons.indexOf(button);
            if (index < 0) return;
            let nextIndex;
            if (event.key === "ArrowUp") nextIndex = Math.max(0, index - 1);
            else if (event.key === "ArrowDown") nextIndex = Math.min(enabledButtons.length - 1, index + 1);
            else if (event.key === "Home") nextIndex = 0;
            else if (event.key === "End") nextIndex = enabledButtons.length - 1;
            else return;
            event.preventDefault();
            choose(enabledButtons[nextIndex]);
        });
        sync();
        select.parentElement.append(list);
        select.hidden = true;
        return { sync, centerSelected: () => scrollToButton(selectedButton(), true) };
    };

    const initializeDatePicker = (picker) => {
        if (picker.dataset.datePickerInitialized === "true") return;
        const display = picker.querySelector("[data-date-display]");
        const value = picker.querySelector("[data-date-value]");
        const trigger = picker.querySelector("[data-date-trigger]");
        const panel = picker.querySelector("[data-date-panel]");
        const title = picker.querySelector("[data-calendar-title]");
        const monthTitle = title?.querySelector("[data-calendar-month]");
        const yearSelect = title?.querySelector("[data-calendar-year]");
        const days = picker.querySelector("[data-calendar-days]");
        const apply = picker.querySelector("[data-calendar-apply]");
        const clear = picker.querySelector("[data-calendar-clear]");
        const timeValue = picker.querySelector("[data-time-value]");
        const hourSelect = picker.querySelector("[data-calendar-hour]");
        const minuteSelect = picker.querySelector("[data-calendar-minute]");
        const timeTitle = picker.querySelector("[data-calendar-time-title]");
        const includesTime = Boolean(timeValue && hourSelect && minuteSelect);
        const timeOptions = new Map();
        if (!display || !value || !trigger || !panel || !title || !days || !apply) return;
        picker.dataset.datePickerInitialized = "true";
        const updateTimeTitle = () => {
            timeOptions.forEach((options) => options.sync());
            if (includesTime && timeTitle) {
                timeTitle.textContent = `${hourSelect.value || "--"}:${minuteSelect.value || "--"}`;
            }
        };
        const resetTimeSelection = () => {
            if (!includesTime) return;
            const time = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(timeValue.value || "");
            hourSelect.value = time ? time[1] : "";
            minuteSelect.value = time ? time[2] : "";
            updateTimeTitle();
        };
        if (includesTime) {
            for (const select of [hourSelect, minuteSelect]) {
                const options = enhanceTimeSelect(select);
                if (options) timeOptions.set(select, options);
                select.addEventListener("change", updateTimeTitle);
            }
        }
        const page = picker.closest(".admin-main") || document.querySelector(".admin-main") || document.body;
        const clearPageExtension = () => window.requestAnimationFrame(() => {
            if (page.querySelector(".application-date-field.is-open")) return;
            page.classList.remove("has-open-date-picker-extension");
            page.style.removeProperty("--date-picker-page-extension");
        });
        const extendPageForCalendar = () => window.requestAnimationFrame(() => {
            page.classList.remove("has-open-date-picker-extension");
            page.style.removeProperty("--date-picker-page-extension");
            window.requestAnimationFrame(() => {
                if (panel.hidden) return;
                const calendarBottom = panel.getBoundingClientRect().bottom + window.scrollY;
                const targetBottom = calendarBottom + 40;
                const viewportBottom = window.scrollY + window.innerHeight;
                if (targetBottom <= viewportBottom) return;

                const pageBottom = page.getBoundingClientRect().bottom + window.scrollY;
                const extension = Math.max(0, Math.ceil(targetBottom - pageBottom));
                if (extension === 0) return;
                page.style.setProperty("--date-picker-page-extension", `${extension}px`);
                page.classList.add("has-open-date-picker-extension");
            });
        });

        let selectedDate = parseIso(value.value);
        let pendingDate = selectedDate ? new Date(selectedDate) : null;
        let visibleMonth = pendingDate
            ? new Date(pendingDate.getFullYear(), pendingDate.getMonth(), 1)
            : new Date(new Date().getFullYear(), new Date().getMonth(), 1);

        const render = () => {
            if (monthTitle && yearSelect) {
                monthTitle.textContent = visibleMonth.toLocaleDateString("tr-TR", { month: "long" });
                const year = visibleMonth.getFullYear();
                const firstYear = Math.min(1900, year);
                const lastYear = Math.max(new Date().getFullYear() + 20, year);
                if (yearSelect.dataset.firstYear !== String(firstYear) || yearSelect.dataset.lastYear !== String(lastYear)) {
                    yearSelect.replaceChildren();
                    for (let optionYear = firstYear; optionYear <= lastYear; optionYear += 1) {
                        const option = document.createElement("option");
                        option.value = String(optionYear);
                        option.textContent = String(optionYear);
                        yearSelect.append(option);
                    }
                    yearSelect.dataset.firstYear = String(firstYear);
                    yearSelect.dataset.lastYear = String(lastYear);
                }
                yearSelect.value = String(year);
            } else {
                title.textContent = visibleMonth.toLocaleDateString("tr-TR", { month: "long", year: "numeric" });
            }
            days.replaceChildren();
            const firstDay = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth(), 1);
            const mondayOffset = (firstDay.getDay() + 6) % 7;
            const gridStart = new Date(firstDay);
            gridStart.setDate(firstDay.getDate() - mondayOffset);
            const today = new Date();

            for (let index = 0; index < 42; index += 1) {
                const date = new Date(gridStart);
                date.setDate(gridStart.getDate() + index);
                const button = document.createElement("button");
                button.type = "button";
                button.className = "application-calendar-day";
                button.textContent = pad(date.getDate());
                button.dataset.date = toIso(date);
                button.setAttribute("role", "gridcell");
                button.setAttribute("aria-label", date.toLocaleDateString("tr-TR", {
                    day: "numeric", month: "long", year: "numeric"
                }));
                button.setAttribute("aria-selected", String(isSameDay(date, pendingDate)));
                button.classList.toggle("is-outside", date.getMonth() !== visibleMonth.getMonth());
                button.classList.toggle("is-selected", isSameDay(date, pendingDate));
                button.classList.toggle("is-today", isSameDay(date, today));
                days.append(button);
            }
        };

        const close = () => {
            panel.hidden = true;
            picker.classList.remove("is-open");
            trigger.setAttribute("aria-expanded", "false");
            clearPageExtension();
        };

        const open = () => {
            selectedDate = parseIso(value.value);
            pendingDate = selectedDate ? new Date(selectedDate) : null;
            resetTimeSelection();
            const base = pendingDate || new Date();
            visibleMonth = new Date(base.getFullYear(), base.getMonth(), 1);
            render();
            panel.hidden = false;
            picker.classList.add("is-open");
            trigger.setAttribute("aria-expanded", "true");
            if (includesTime) {
                window.requestAnimationFrame(() => {
                    for (const select of [hourSelect, minuteSelect]) {
                        const options = timeOptions.get(select);
                        if (options) {
                            options.centerSelected();
                            continue;
                        }
                        const option = select.options?.[select.selectedIndex];
                        if (option?.offsetHeight) {
                            select.scrollTop = Math.max(0,
                                select.selectedIndex * option.offsetHeight - (select.clientHeight - option.offsetHeight) / 2);
                        }
                    }
                });
            }
            extendPageForCalendar();
        };

        window.addEventListener("resize", () => {
            if (!panel.hidden) extendPageForCalendar();
        });

        const toggle = () => panel.hidden ? open() : close();
        trigger.addEventListener("click", toggle);
        display.addEventListener("click", toggle);

        yearSelect?.addEventListener("change", () => {
            const year = Number(yearSelect.value);
            if (!Number.isInteger(year) || year < 1 || year > 9999) return;
            visibleMonth.setFullYear(year);
            render();
        });

        panel.addEventListener("click", (event) => {
            const day = event.target.closest("[data-date]");
            if (day) {
                pendingDate = parseIso(day.dataset.date);
                if (pendingDate) {
                    visibleMonth = new Date(pendingDate.getFullYear(), pendingDate.getMonth(), 1);
                    render();
                }
                return;
            }

            const action = event.target.closest("[data-calendar-action]")?.dataset.calendarAction;
            if (!action) return;
            const monthDelta = action === "prev-month" ? -1 : action === "next-month" ? 1 : 0;
            const yearDelta = action === "prev-year" ? -1 : action === "next-year" ? 1 : 0;
            visibleMonth = new Date(
                visibleMonth.getFullYear() + yearDelta,
                visibleMonth.getMonth() + monthDelta,
                1);
            render();
        });

        apply.addEventListener("click", () => {
            if (!pendingDate) {
                window.genericPopup?.fail("Lütfen bir tarih seçiniz.");
                return;
            }
            if (includesTime && Boolean(hourSelect.value) !== Boolean(minuteSelect.value)) {
                window.genericPopup?.fail("Saat ve dakikayı birlikte seçiniz.");
                return;
            }
            selectedDate = new Date(pendingDate);
            value.value = toIso(selectedDate);
            if (includesTime) {
                timeValue.value = hourSelect.value && minuteSelect.value
                    ? `${hourSelect.value}:${minuteSelect.value}` : "";
            }
            display.value = toDisplay(selectedDate) + (includesTime && timeValue.value ? ` ${timeValue.value}` : "");
            value.dispatchEvent(new Event("change", { bubbles: true }));
            if (includesTime) timeValue.dispatchEvent(new Event("change", { bubbles: true }));
            close();
            trigger.focus({ preventScroll: true });
        });

        clear?.addEventListener("click", () => {
            selectedDate = null;
            pendingDate = null;
            value.value = "";
            display.value = "";
            if (includesTime) {
                timeValue.value = "";
                resetTimeSelection();
            }
            value.dispatchEvent(new Event("change", { bubbles: true }));
            if (includesTime) timeValue.dispatchEvent(new Event("change", { bubbles: true }));
            close();
            trigger.focus({ preventScroll: true });
        });

        document.addEventListener("click", (event) => {
            if (!panel.hidden && !event.composedPath().includes(picker)) close();
        });
        document.addEventListener("keydown", (event) => {
            if (event.key === "Escape" && !panel.hidden) {
                close();
                trigger.focus({ preventScroll: true });
            }
        });
    };

    const initializeDatePickers = (root = document) => {
        const pickers = Array.from(root.querySelectorAll("[data-date-picker]"));
        if (root.matches?.("[data-date-picker]")) pickers.unshift(root);
        pickers.forEach(initializeDatePicker);
    };

    window.initializeDatePickers = initializeDatePickers;
    initializeDatePickers();
})();
