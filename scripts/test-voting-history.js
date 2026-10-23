// Run with: node scripts/test-voting-history.js
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const scriptPath = path.join(__dirname, "../src/YKBAfife/wwwroot/js/voting-history.js");
const source = fs.readFileSync(scriptPath, "utf8");
const tick = () => new Promise(setImmediate);

class Events {
    constructor() { this.listeners = new Map(); this.attributes = new Map(); }
    addEventListener(name, callback) { this.listeners.set(name, callback); }
    dispatch(name, target = this) { return this.listeners.get(name)?.({ target }); }
    setAttribute(name, value) { this.attributes.set(name, value); }
    removeAttribute(name) { this.attributes.delete(name); }
}

function card(values, selected = 0) {
    const candidate = new Events();
    const isSelect = Array.isArray(values[0]);
    candidate.tagName = isSelect ? "SELECT" : "INPUT";
    candidate.options = isSelect ? values.map(([value, voted]) => ({ value, dataset: { hasVote: String(voted) } })) : [];
    candidate.dataset = isSelect ? {} : { hasVote: String(values[1]) };
    candidate.selectedIndex = selected;
    Object.defineProperty(candidate, "selectedOptions", { get: () => [candidate.options[candidate.selectedIndex]] });
    Object.defineProperty(candidate, "value", { get: () => isSelect ? candidate.options[candidate.selectedIndex].value : values[0] });
    candidate.closest = (selector) => selector === "[data-vote-candidate]" ? candidate : null;
    const button = { disabled: false, hasAttribute: () => false };
    const result = { candidate, button, querySelector: (selector) => selector === "[data-vote-candidate]" ? candidate : button };
    button.closest = (selector) => selector === "[data-vote-card]" ? result : button;
    return result;
}

function runtime(initialPlay = "play-a", initialJury = "jury-a") {
    const play = Object.assign(new Events(), { value: initialPlay });
    const jury = Object.assign(new Events(), { value: initialJury });
    const results = new Events();
    const screens = new Map();
    results.cards = [];
    let html = "";
    Object.defineProperty(results, "innerHTML", {
        get: () => html,
        set(value) {
            html = value;
            const screen = screens.get(value);
            results.scope = screen ? { dataset: { playId: screen.play, juryId: screen.jury } } : null;
            results.cards = screen?.cards || [];
            results.bulk = screen ? { disabled: true, hasAttribute: (name) => name === "data-reset-all-votes" } : null;
            if (results.bulk) results.bulk.closest = () => results.bulk;
        }
    });
    results.querySelector = (selector) => selector === "[data-voting-history-scope]" ? results.scope : results.bulk;
    results.querySelectorAll = (selector) => selector === "[data-vote-card]" ? results.cards : results.cards.map((item) => item.candidate);
    const requests = [];
    const questions = [], successes = [], failures = [];
    const page = {
        querySelector(selector) {
            if (selector === "[name='PlayId']") return play;
            if (selector === "[name='JuryId']") return jury;
            if (selector === "[data-voting-history-results]") return results;
            return { value: "csrf-test-token" };
        }
    };
    vm.runInNewContext(source, {
        document: { querySelector: () => page }, URLSearchParams, AbortController,
        window: { genericPopup: {
            question: (message, callback) => questions.push({ message, callback }),
            success: (message) => successes.push(message), fail: (message) => failures.push(message)
        } },
        fetch: (url, options = {}) => new Promise((resolve) => requests.push({ url, options, resolve }))
    }, { filename: scriptPath });
    return {
        play, jury, results, requests, questions, successes, failures,
        screen: (key, cards, screenPlay = play.value, screenJury = jury.value) => screens.set(key, { cards, play: screenPlay, jury: screenJury }),
        respond: async (index, key, ok = true) => { requests[index].resolve({ ok, text: async () => key, json: async () => key }); await tick(); }
    };
}

async function bulkIncludesHistoricalOptionsAndFreezesIds() {
    const app = runtime();
    const historical = card([["old-vote", true], ["current-no-vote", false]], 1);
    const single = card(["single-vote", true]);
    app.screen("loaded", [historical, single, card([["old-vote", true]])]);
    await app.respond(0, "loaded");
    assert.equal(historical.button.disabled, true);
    assert.equal(app.results.bulk.disabled, false);
    app.results.dispatch("click", app.results.bulk);
    assert.equal(app.questions.length, 1);
    assert.match(app.questions[0].message, /2 oylamayı/);
    historical.candidate.options[0].dataset.hasVote = "false";
    const pending = app.questions[0].callback();
    await tick();
    assert.equal(app.requests[1].options.method, "POST");
    const body = app.requests[1].options.body;
    assert.deepEqual(JSON.parse(body.get("playAwardCategoryIdsJson")), ["old-vote", "single-vote"]);
    assert.equal(body.get("playId"), "play-a");
    assert.equal(body.get("juryId"), "jury-a");
    assert.equal(body.get("__RequestVerificationToken"), "csrf-test-token");
    assert.equal(app.results.bulk.disabled, true);
    assert.equal(single.candidate.disabled, true);
    await app.respond(1, { success: true, message: "Reset complete" });
    app.screen("reset", [card(["single-vote", false])]);
    await app.respond(2, "reset");
    await pending;
    assert.deepEqual(app.successes, ["Reset complete"]);
    assert.equal(app.results.bulk.disabled, true);
}

async function filterChangesCancelOldConfirmations() {
    for (const bulk of [true, false]) {
        const app = runtime();
        const voted = card(["vote-a", true]);
        app.screen("loaded", [voted]);
        await app.respond(0, "loaded");
        app.results.dispatch("click", bulk ? app.results.bulk : voted.button);
        app.jury.value = "jury-b";
        app.jury.dispatch("change");
        await app.questions[0].callback();
        assert.equal(app.requests.filter((request) => request.options.method === "POST").length, 0);
        assert.equal(app.failures.length, 1);
    }
}

async function oldResponsesNeverReplaceNewOrClearedFilters() {
    const app = runtime();
    app.screen("old", [card(["old-vote", true])], "play-a", "jury-a");
    app.jury.value = "jury-b";
    app.jury.dispatch("change");
    app.screen("new", [card(["new-vote", true])], "play-a", "jury-b");
    await app.respond(1, "new");
    await app.respond(0, "old");
    assert.equal(app.results.innerHTML, "new");
    assert.equal(app.results.scope.dataset.juryId, "jury-b");
    app.jury.value = "jury-c";
    app.jury.dispatch("change");
    app.jury.value = "";
    app.jury.dispatch("change");
    await app.respond(2, "old");
    assert.equal(app.results.scope, null);
    assert.equal(app.results.bulk, null);
    assert.equal(app.results.attributes.has("aria-busy"), false);
}

async function singleResetKeepsCapturedSelectedCandidate() {
    const app = runtime();
    const choices = card([["selected", true], ["historical", true]]);
    app.screen("loaded", [choices]);
    await app.respond(0, "loaded");
    app.results.dispatch("click", choices.button);
    choices.candidate.selectedIndex = 1;
    const pending = app.questions[0].callback();
    await tick();
    assert.equal(app.requests[1].options.body.get("playAwardCategoryId"), "selected");
    assert.equal(app.requests[1].options.body.has("playAwardCategoryIdsJson"), false);
    await app.respond(1, { success: false, message: "State changed" }, false);
    await pending;
    assert.deepEqual(app.failures, ["State changed"]);
    assert.equal(choices.button.disabled, false);
    assert.equal(app.results.bulk.disabled, false);
}

async function emptyLoadedScreensCannotPost() {
    const app = runtime();
    app.screen("empty", []);
    await app.respond(0, "empty");
    assert.equal(app.results.bulk.disabled, true);
    app.results.dispatch("click", app.results.bulk);
    assert.equal(app.questions.length, 0);
    vm.runInNewContext(source, { document: { querySelector: () => null } }, { filename: scriptPath });
}

(async () => {
    for (const test of [bulkIncludesHistoricalOptionsAndFreezesIds, filterChangesCancelOldConfirmations,
        oldResponsesNeverReplaceNewOrClearedFilters, singleResetKeepsCapturedSelectedCandidate, emptyLoadedScreensCannotPost]) {
        await test();
        console.log(`PASS ${test.name}`);
    }
    console.log("5 voting-history regression tests passed.");
})().catch((error) => { console.error(error); process.exitCode = 1; });
