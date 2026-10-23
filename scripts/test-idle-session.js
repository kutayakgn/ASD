// Run with: node scripts/test-idle-session.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const scriptPath = path.join(__dirname, "../src/YKBAfife/wwwroot/js/idle-session.js");
const source = fs.readFileSync(scriptPath, "utf8");
const tick = () => new Promise(setImmediate);
const lifetime = 600_000;

function browser({ hostPresent = true, token = "csrf", sessionId = "session-a", expiresAt = lifetime,
    stored = null, visibility = "visible", broadcast = true, initialNow = 0 } = {}) {
    let elapsed = initialNow;
    let nextTimer = 1;
    const timers = new Map(), requests = [], responses = [], redirects = [], published = [];
    const documentListeners = new Map(), windowListeners = new Map(), storage = new Map();
    let reloads = 0, channel;
    const storageKey = `AfifeAdmin.Idle.${sessionId}`;
    if (stored) storage.set(storageKey, JSON.stringify(stored));
    const document = {
        visibilityState: visibility,
        querySelector: () => hostPresent ? {
            dataset: { sessionId, expiresAt: String(expiresAt), serverNow: String(initialNow) },
            querySelector: () => token === null ? null : { value: token }
        } : null,
        addEventListener: (event, callback) => documentListeners.set(event, callback)
    };
    class Channel {
        constructor(name) { if (!broadcast) throw new Error("Unavailable"); this.name = name; channel = this; }
        postMessage(value) { published.push(value); }
    }
    vm.runInNewContext(source, {
        document, URLSearchParams, Number, JSON, Math,
        window: { addEventListener: (event, callback) => windowListeners.set(event, callback) },
        location: { pathname: "/juriler", search: "?page=2", replace: (url) => redirects.push(url), reload: () => reloads++ },
        performance: { now: () => elapsed },
        BroadcastChannel: Channel,
        localStorage: { getItem: (key) => storage.get(key) ?? null, setItem: (key, value) => storage.set(key, value) },
        setTimeout(callback, delay) { const id = nextTimer++; timers.set(id, { at: elapsed + Math.max(0, delay), callback }); return id; },
        clearTimeout: (id) => timers.delete(id),
        fetch: async (url, options) => {
            requests.push({ url, options, time: elapsed });
            if (responses.length) return responses.shift()();
            const age = Number(options.body.get("elapsedMilliseconds"));
            return { status: 200, ok: true, json: async () => ({ sessionId, expiresAt: elapsed - age + lifetime, serverNow: elapsed }) };
        }
    }, { filename: scriptPath });
    return {
        requests, responses, redirects, published, timers, storage, storageKey,
        get reloads() { return reloads; },
        get now() { return elapsed; },
        async advance(amount) {
            const target = elapsed + amount;
            for (;;) {
                const due = [...timers].filter(([, timer]) => timer.at <= target).sort((a, b) => a[1].at - b[1].at || a[0] - b[0])[0];
                if (!due) break;
                elapsed = due[1].at;
                timers.delete(due[0]);
                due[1].callback();
                await tick();
            }
            elapsed = target;
            await tick();
        },
        async event(name, trusted = true) { documentListeners.get(name)?.({ isTrusted: trusted }); await tick(); },
        async visibility(value) { document.visibilityState = value; documentListeners.get("visibilitychange")?.({ isTrusted: true }); await tick(); },
        async pageshow() { windowListeners.get("pageshow")?.({ isTrusted: true }); await tick(); },
        async storageEvent(value, key = storageKey) { windowListeners.get("storage")?.({ key, newValue: JSON.stringify(value) }); await tick(); },
        async broadcast(value) { channel?.onmessage?.({ data: value }); await tick(); },
        deadline: () => JSON.parse(storage.get(storageKey) || "null")?.expiresAt
    };
}

async function backgroundNeverSendsAndExpiresExactlyAtTenMinutes() {
    const tab = browser();
    assert.equal(tab.requests.length, 0);
    await tab.advance(300_000);
    await tab.visibility("hidden");
    await tab.visibility("visible");
    await tab.pageshow();
    await tab.advance(299_999);
    assert.equal(tab.requests.length, 0);
    assert.equal(tab.redirects.length, 0);
    await tab.advance(1);
    assert.deepEqual(tab.redirects, ["/giris-yap?returnUrl=%2Fjuriler%3Fpage%3D2"]);
}

async function syntheticAndHiddenInputCannotRenew() {
    const tab = browser();
    for (const event of ["pointerdown", "keydown", "wheel", "touchstart", "input"]) await tab.event(event, false);
    await tab.visibility("hidden");
    for (const event of ["pointerdown", "keydown", "wheel", "touchstart", "input"]) await tab.event(event, true);
    assert.equal(tab.requests.length, 0);
    await tab.advance(lifetime);
    assert.equal(tab.redirects.length, 1);
}

async function trustedVisibleActivityUsesConfirmedDeadline() {
    for (const event of ["pointerdown", "keydown", "wheel", "touchstart", "input"]) {
        const tab = browser();
        await tab.advance(10_000);
        await tab.event(event);
        assert.equal(tab.requests.length, 1);
        assert.equal(tab.requests[0].url, "/oturum/aktivite");
        const body = tab.requests[0].options.body;
        assert.equal(body.get("sessionId"), "session-a");
        assert.equal(body.get("__RequestVerificationToken"), "csrf");
        assert.equal(body.get("elapsedMilliseconds"), "0");
        assert.equal(tab.deadline(), lifetime + 10_000);
        await tab.advance(lifetime - 1);
        assert.equal(tab.redirects.length, 0);
        await tab.advance(1);
        assert.equal(tab.redirects.length, 1);
    }
}

async function trailingThrottleCarriesRealActionAge() {
    const tab = browser();
    await tab.event("pointerdown");
    await tab.advance(100);
    await tab.event("keydown");
    assert.equal(tab.requests.length, 1);
    await tab.advance(899);
    assert.equal(tab.requests.length, 1);
    await tab.advance(1);
    assert.equal(tab.requests.length, 2);
    assert.equal(tab.requests[1].options.body.get("elapsedMilliseconds"), "900");
    assert.equal(tab.deadline(), lifetime + 100); // Not 10 minutes after the trailing timer fired.
    await tab.advance(lifetime - 900);
    assert.equal(tab.redirects.length, 1);
}

async function pendingRealActionFlushesOnHideWithoutNewActivity() {
    const tab = browser();
    await tab.event("pointerdown");
    await tab.advance(100);
    await tab.event("input");
    await tab.advance(100);
    await tab.visibility("hidden");
    assert.equal(tab.requests.length, 2);
    assert.equal(tab.requests[1].options.body.get("elapsedMilliseconds"), "100");
    assert.equal(tab.deadline(), lifetime + 100);
    await tab.event("keydown");
    assert.equal(tab.requests.length, 2);
}

async function failuresNeverExtendAndAuthFailuresLeave() {
    const failed = browser();
    failed.responses.push(async () => ({ status: 503, ok: false }));
    await failed.advance(1000);
    await failed.event("input");
    assert.equal(failed.deadline(), lifetime);
    await failed.advance(lifetime - 1000);
    assert.equal(failed.redirects.length, 1);
    const offline = browser();
    offline.responses.push(async () => { throw new Error("Network unavailable"); });
    await offline.event("input");
    assert.equal(offline.deadline(), lifetime);
    await offline.advance(lifetime);
    assert.equal(offline.redirects.length, 1);
    for (const status of [401, 403]) {
        const tab = browser();
        tab.responses.push(async () => ({ status, ok: false }));
        await tab.event("keydown");
        await tab.event("input");
        assert.equal(tab.redirects.length, 1);
        assert.equal(tab.requests.length, 1);
    }
    for (const response of [{ status: 400, ok: false },
        { status: 200, ok: true, json: async () => ({ sessionId: "new-login", expiresAt: lifetime * 2 }) }]) {
        const tab = browser();
        tab.responses.push(async () => response);
        await tab.event("input");
        assert.equal(tab.reloads, 1);
        assert.equal(tab.deadline(), lifetime);
    }
}

async function delayedServerResponsesCannotMoveTheIdleClockBackwards() {
    const tab = browser();
    let complete;
    tab.responses.push(() => new Promise((resolve) => { complete = resolve; }));
    await tab.advance(1000);
    await tab.event("input");
    await tab.advance(60_000);
    // Server handled the real input at t=1000; only its response was delayed.
    complete({ status: 200, ok: true, json: async () => ({ sessionId: "session-a", serverNow: 1000, expiresAt: lifetime + 1000 }) });
    await tick();
    await tab.advance(lifetime - 60_000);
    assert.equal(tab.now, lifetime + 1000);
    assert.equal(tab.redirects.length, 1, "Response latency must not add to the confirmed inactivity deadline.");
}

async function crossTabDeadlinesNeverSendActivityOrCrossSessionIds() {
    const tab = browser();
    await tab.storageEvent({ sessionId: "other-session", expiresAt: lifetime * 3 });
    await tab.broadcast({ sessionId: "other-session", expiresAt: lifetime * 3 });
    await tab.storageEvent({ sessionId: "session-a", expiresAt: lifetime * 2 }, "unrelated-key");
    await tab.broadcast({ sessionId: "session-a", expiresAt: lifetime + 300_000 });
    await tab.storageEvent({ sessionId: "session-a", expiresAt: 100 }); // An older tab cannot shorten a newer confirmation.
    await tab.advance(lifetime);
    assert.equal(tab.redirects.length, 0);
    assert.equal(tab.requests.length, 0);
    await tab.advance(300_000);
    assert.equal(tab.redirects.length, 1);
    const restored = browser({ stored: { sessionId: "session-a", expiresAt: lifetime + 1000 }, broadcast: false });
    await restored.advance(lifetime);
    assert.equal(restored.redirects.length, 0);
    await restored.advance(1000);
    assert.equal(restored.redirects.length, 1);
}

async function missingOrInvalidHostsAreHarmless() {
    for (const options of [{ hostPresent: false }, { token: null }, { sessionId: "" }, { expiresAt: NaN }]) {
        const tab = browser(options);
        assert.equal(tab.requests.length, 0);
        assert.equal(tab.timers.size, 0);
    }
}

(async () => {
    const tests = [backgroundNeverSendsAndExpiresExactlyAtTenMinutes, syntheticAndHiddenInputCannotRenew,
        trustedVisibleActivityUsesConfirmedDeadline, trailingThrottleCarriesRealActionAge,
        pendingRealActionFlushesOnHideWithoutNewActivity, failuresNeverExtendAndAuthFailuresLeave,
        delayedServerResponsesCannotMoveTheIdleClockBackwards,
        crossTabDeadlinesNeverSendActivityOrCrossSessionIds, missingOrInvalidHostsAreHarmless];
    for (const test of tests) { await test(); console.log(`PASS ${test.name}`); }
    console.log(`${tests.length} idle-session browser regression tests passed.`);
})().catch((error) => { console.error(error); process.exitCode = 1; });
