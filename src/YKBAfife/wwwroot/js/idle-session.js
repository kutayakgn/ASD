(() => {
    const host = document.querySelector("[data-idle-session]");
    if (!host) return;
    const sessionId = host.dataset.sessionId;
    const token = host.querySelector("input[name='__RequestVerificationToken']")?.value;
    let deadline = Number(host.dataset.expiresAt);
    let serverBase = Number(host.dataset.serverNow);
    let clockBase = performance.now();
    if (!sessionId || !token || !Number.isFinite(deadline) || !Number.isFinite(serverBase)) return;
    const storageKey = `AfifeAdmin.Idle.${sessionId}`;
    const now = () => serverBase + performance.now() - clockBase;
    let expiryTimer;
    let sendTimer;
    let pendingAction = null;
    let lastSent = -Infinity;
    let sending = false;
    let leaving = false;
    let channel;
    try { channel = new BroadcastChannel(storageKey); } catch { /* Optional cross-tab transport. */ }

    const leave = () => {
        if (leaving) return;
        leaving = true;
        clearTimeout(expiryTimer);
        clearTimeout(sendTimer);
        const returnUrl = location.pathname + location.search;
        location.replace(`/giris-yap?returnUrl=${encodeURIComponent(returnUrl)}`);
    };
    const armExpiry = () => {
        clearTimeout(expiryTimer);
        const remaining = deadline - now();
        if (remaining <= 0) { leave(); return; }
        expiryTimer = setTimeout(armExpiry, remaining);
    };
    const adopt = (value) => {
        if (value?.sessionId !== sessionId || !Number.isFinite(value.expiresAt)) return;
        if (value.expiresAt > deadline) deadline = value.expiresAt;
        armExpiry();
    };
    const readShared = () => {
        try { adopt(JSON.parse(localStorage.getItem(storageKey))); } catch { /* Storage can be disabled. */ }
    };
    const publish = () => {
        const value = { sessionId, expiresAt: deadline };
        try { localStorage.setItem(storageKey, JSON.stringify(value)); } catch { /* Cookie remains authoritative. */ }
        channel?.postMessage(value);
    };
    const flush = async () => {
        clearTimeout(sendTimer);
        if (sending || pendingAction === null || leaving) return;
        const action = pendingAction;
        pendingAction = null;
        const age = Math.floor(performance.now() - action);
        if (age < 0 || age > 60_000) return;
        sending = true;
        lastSent = performance.now();
        try {
            const response = await fetch("/oturum/aktivite", {
                method: "POST",
                credentials: "same-origin",
                keepalive: true,
                headers: {
                    "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
                    "X-Requested-With": "XMLHttpRequest"
                },
                body: new URLSearchParams({ sessionId, elapsedMilliseconds: String(age), __RequestVerificationToken: token })
            });
            if (response.status === 401 || response.status === 403) { leave(); return; }
            if (response.status === 400) { location.reload(); return; }
            if (!response.ok) return;
            const value = await response.json();
            if (value.sessionId !== sessionId) { location.reload(); return; }
            if (Number.isFinite(value.serverNow)) {
                // A delayed response must not turn the idle clock backwards.
                serverBase = Math.max(now(), value.serverNow);
                clockBase = performance.now();
            }
            adopt(value);
            publish();
        } catch { /* A failed request never extends the confirmed deadline. */ }
        finally {
            sending = false;
            if (pendingAction !== null && !leaving) schedule();
        }
    };
    const schedule = () => {
        clearTimeout(sendTimer);
        const delay = Math.max(0, 1000 - (performance.now() - lastSent));
        if (deadline - now() < 15_000 || delay === 0) void flush();
        else sendTimer = setTimeout(flush, delay);
    };
    const activity = (event) => {
        if (!event.isTrusted || document.visibilityState !== "visible" || leaving) return;
        readShared();
        if (deadline <= now()) { leave(); return; }
        pendingAction = performance.now();
        schedule();
    };
    ["pointerdown", "keydown", "wheel", "touchstart", "input"].forEach((event) =>
        document.addEventListener(event, activity, { capture: true, passive: true }));
    window.addEventListener("storage", (event) => {
        if (event.key !== storageKey) return;
        try { adopt(JSON.parse(event.newValue)); } catch { /* Ignore unrelated/malformed state. */ }
    });
    if (channel) channel.onmessage = (event) => adopt(event.data);
    window.addEventListener("pageshow", () => { readShared(); armExpiry(); });
    document.addEventListener("visibilitychange", () => {
        if (document.visibilityState === "visible") { readShared(); armExpiry(); }
        else if (pendingAction !== null) void flush();
    });
    readShared();
    publish();
    armExpiry();
})();
