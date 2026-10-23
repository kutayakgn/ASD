// Run with: node scripts/test-edit-password.js
// Exercise the shipped browser script without adding a DOM dependency.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const scriptPath = path.join(__dirname, "../src/YKBAfife/wwwroot/js/edit-password.js");
const source = fs.readFileSync(scriptPath, "utf8");

class FakeElement {
    constructor() {
        this.listeners = new Map();
        this.attributes = new Map();
    }

    addEventListener(type, listener) {
        const listeners = this.listeners.get(type) || [];
        listeners.push(listener);
        this.listeners.set(type, listeners);
    }

    dispatch(type) {
        const event = { type, target: this };
        for (const listener of this.listeners.get(type) || []) listener(event);
    }

    setAttribute(name, value) {
        this.attributes.set(name, String(value));
    }

    getAttribute(name) {
        return this.attributes.get(name) ?? null;
    }
}

function createField({ value = "", type = "password", withForm = true } = {}) {
    const input = Object.assign(new FakeElement(), {
        value,
        defaultValue: "",
        type,
        placeholder: "••••••••",
        form: withForm ? new FakeElement() : null,
    });
    const toggle = Object.assign(new FakeElement(), { disabled: false });
    const field = {
        querySelector(selector) {
            if (selector === "[data-edit-password-input]") return input;
            if (selector === "[data-edit-password-toggle]") return toggle;
            throw new Error(`Unexpected field selector: ${selector}`);
        },
    };
    return { field, input, toggle, form: input.form };
}

function initialize(...fields) {
    const microtasks = [];
    vm.runInNewContext(source, {
        document: {
            querySelectorAll(selector) {
                assert.equal(selector, "[data-edit-password]");
                return fields.map(({ field }) => field);
            },
        },
        queueMicrotask: (callback) => microtasks.push(callback),
    }, { filename: scriptPath });
    return {
        microtasks,
        flushMicrotasks() {
            while (microtasks.length) microtasks.shift()();
        },
    };
}

function assertHidden(toggle) {
    assert.equal(toggle.getAttribute("aria-pressed"), "false");
    assert.equal(toggle.getAttribute("aria-label"), "Yeni şifreyi göster");
}

const tests = [
    ["empty input is masked and its eye is disabled", () => {
        const { field, input, toggle } = createField({ type: "text" });
        initialize({ field });
        assert.equal(input.value, "");
        assert.equal(input.defaultValue, "");
        assert.notEqual(input.value, input.placeholder);
        assert.equal(input.type, "password");
        assert.equal(toggle.disabled, true);
        assertHidden(toggle);
        toggle.dispatch("click");
        assert.equal(input.type, "password");
        assert.equal(input.value, "");
    }],
    ["typing enables the eye and clicking toggles visibility and accessibility labels", () => {
        const fixture = createField();
        initialize(fixture);
        fixture.input.value = "New<password>123!";
        fixture.input.dispatch("input");
        assert.equal(fixture.toggle.disabled, false);
        assertHidden(fixture.toggle);
        fixture.toggle.dispatch("click");
        assert.equal(fixture.input.type, "text");
        assert.equal(fixture.toggle.getAttribute("aria-pressed"), "true");
        assert.equal(fixture.toggle.getAttribute("aria-label"), "Yeni şifreyi gizle");
        assert.equal(fixture.input.value, "New<password>123!");
        fixture.toggle.dispatch("click");
        assert.equal(fixture.input.type, "password");
        assertHidden(fixture.toggle);
    }],
    ["clearing a visible value masks and disables the eye for input and change events", () => {
        for (const event of ["input", "change"]) {
            const fixture = createField({ value: "New password" });
            initialize(fixture);
            assert.equal(fixture.toggle.disabled, false);
            fixture.toggle.dispatch("click");
            assert.equal(fixture.input.type, "text");
            fixture.input.value = "";
            fixture.input.dispatch(event);
            assert.equal(fixture.input.type, "password");
            assert.equal(fixture.toggle.disabled, true);
            assertHidden(fixture.toggle);
        }
    }],
    ["submitting preserves an empty value or the exact new password, never the placeholder", () => {
        const fixture = createField();
        initialize(fixture);
        fixture.form.dispatch("submit");
        assert.equal(fixture.input.value, "");
        assert.notEqual(fixture.input.value, fixture.input.placeholder);
        const password = "  New<password>&123!  ";
        fixture.input.value = password;
        fixture.input.dispatch("input");
        fixture.toggle.dispatch("click");
        fixture.form.dispatch("submit");
        assert.equal(fixture.input.value, password);
        fixture.toggle.dispatch("click");
        assert.equal(fixture.input.type, "password");
        assert.equal(fixture.input.value, password);
        assert.equal(fixture.input.placeholder, "••••••••");
    }],
    ["reset synchronizes after the browser restores the default value", () => {
        const fixture = createField({ value: "New password" });
        const runtime = initialize(fixture);
        fixture.toggle.dispatch("click");
        fixture.form.dispatch("reset");
        assert.equal(runtime.microtasks.length, 1);
        assert.equal(fixture.toggle.disabled, false);
        assert.equal(fixture.input.type, "text");
        // A browser applies the default reset after dispatching the reset event.
        fixture.input.value = fixture.input.defaultValue;
        runtime.flushMicrotasks();
        assert.equal(fixture.input.value, "");
        assert.equal(fixture.input.type, "password");
        assert.equal(fixture.toggle.disabled, true);
        assertHidden(fixture.toggle);
    }],
    ["fields keep independent state and can initialize without a form", () => {
        const first = createField();
        const second = createField({ value: "Second password", withForm: false });
        initialize(first, second);
        second.toggle.dispatch("click");
        assert.equal(second.input.type, "text");
        assert.equal(second.toggle.disabled, false);
        assert.equal(first.input.type, "password");
        assert.equal(first.toggle.disabled, true);
        assertHidden(first.toggle);
    }],
    ["pages without an edit-password wrapper are ignored", () => {
        assert.doesNotThrow(() => initialize());
    }],
    ["incomplete wrappers are ignored without attaching partial handlers", () => {
        for (const missing of ["input", "toggle", "both"]) {
            const input = Object.assign(new FakeElement(), { value: "", type: "password" });
            const toggle = Object.assign(new FakeElement(), { disabled: true });
            const field = {
                querySelector(selector) {
                    if (selector === "[data-edit-password-input]") return missing === "toggle" ? input : null;
                    if (selector === "[data-edit-password-toggle]") return missing === "input" ? toggle : null;
                    throw new Error(`Unexpected field selector: ${selector}`);
                },
            };
            assert.doesNotThrow(() => initialize({ field }));
            assert.equal(input.listeners.size, 0);
            assert.equal(toggle.listeners.size, 0);
            assert.equal(input.value, "");
            assert.equal(input.type, "password");
        }
    }],
];

for (const [name, run] of tests) {
    run();
    console.log(`PASS ${name}`);
}
console.log(`${tests.length} edit-password regression tests passed.`);
