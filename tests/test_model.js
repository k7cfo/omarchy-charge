const assert = require("assert")
const Model = require("../Model.js")

assert.strictEqual(Model.conserveStart(80), 75)
assert.strictEqual(Model.conserveStart(60), 55)
assert.strictEqual(Model.conserveEndFromSettings({}), 80)
assert.strictEqual(Model.conserveEndFromSettings({ conserveEnd: 60 }), 60)
assert.strictEqual(Model.conserveEndFromSettings({ conserveEnd: 9 }), 50)
assert.strictEqual(Model.modeFromEnd(80, 80), "conserve")
assert.strictEqual(Model.modeFromEnd(100, 80), "full")
assert.strictEqual(Model.capLabel("full", 80), "100")
assert.strictEqual(Model.capLabel("conserve", 80), "80")
assert.strictEqual(Model.barLabel(41, "conserve", 80), "41·80")
assert.strictEqual(Model.barLabel(99, "full", 80), "99·100")
assert.strictEqual(Model.barLabel(-3, "conserve", 60), "0·60")
assert.strictEqual(Model.packPercent(0.41, 10), 41)
assert.strictEqual(Model.packPercent(78, 10), 78)
assert.strictEqual(Model.packPercent(undefined, 41), 41)

assert.strictEqual(Model.defaultTimeoutMs({ promptTimeoutSec: 20 }), 20000)
assert.strictEqual(Model.pluginFilePath("file:///home/base/x/"), "/home/base/x")
assert.strictEqual(Model.promptOnConnectFromSettings({}), true)
assert.strictEqual(Model.promptOnConnectFromSettings({ promptOnConnect: true }), true)
assert.strictEqual(Model.promptOnConnectFromSettings({ promptOnConnect: false }), false)

const parsed = Model.parseStatus('{"supported":true,"writable":true,"ac":false,"capacity":78,"start":75,"end":80,"mode":"conserve","battery":"BAT0","error":""}')
assert.strictEqual(parsed.supported, true)
assert.strictEqual(parsed.capacity, 78)
assert.strictEqual(parsed.mode, "conserve")
assert.strictEqual(Model.parseStatus("nope").error, "invalid-json")

assert.strictEqual(Model.shouldPrompt({
  supported: true,
  promptOnConnect: true,
  onBattery: false,
  wasOnBattery: true,
  sessionPrompted: false,
  mode: "conserve"
}), true)

assert.strictEqual(Model.shouldPrompt({
  supported: true,
  promptOnConnect: true,
  onBattery: false,
  wasOnBattery: false,
  sessionPrompted: false,
  mode: "conserve"
}), false, "boot already on AC must not prompt")

assert.strictEqual(Model.shouldPrompt({
  supported: true,
  promptOnConnect: true,
  onBattery: false,
  wasOnBattery: true,
  sessionPrompted: false,
  mode: "full"
}), false, "already filling to 100 must not prompt")

assert.strictEqual(Model.shouldPrompt({
  supported: true,
  promptOnConnect: false,
  onBattery: false,
  wasOnBattery: true,
  sessionPrompted: false,
  mode: "conserve"
}), false)

const settings = Model.settingsFromConfig({
  bar: { layout: { right: [{ id: "k7cfo.charge", conserveEnd: 80, promptTimeoutSec: 15 }] } },
  plugins: [{ id: "k7cfo.charge" }]
}, "k7cfo.charge")
assert.strictEqual(settings.promptTimeoutSec, 15)

const profiles = Model.parseProfiles("power-saver\t0\nbalanced\t1\nperformance\t0\n")
assert.deepStrictEqual(profiles.profiles, ["power-saver", "balanced", "performance"])
assert.strictEqual(profiles.active, "balanced")
assert.strictEqual(Model.profileTitle("power-saver"), "Power saver")
assert.strictEqual(Model.profileIndex(profiles.profiles, "balanced"), 1)
assert.strictEqual(Model.profileAt(profiles.profiles, 2), "performance")
assert.strictEqual(Model.profileAt(profiles.profiles, 9), "")

assert.strictEqual(Model.plain("<img src=x>BAT0&"), "img src=xBAT0")
assert.strictEqual(Model.plain("ok\n\tname"), "okname")
assert.strictEqual(Model.sanitizeName("BAT0"), "BAT0")
assert.strictEqual(Model.sanitizeName("../etc"), "")
assert.strictEqual(Model.sanitizeName("<BAT0>"), "BAT0")
assert.strictEqual(Model.sanitizeName("BAT/0"), "")
assert.strictEqual(Model.isProfileName("power-saver"), true)
assert.strictEqual(Model.isProfileName("Performance"), false)
assert.strictEqual(Model.isProfileName("-evil"), false)
assert.strictEqual(Model.parseStatus('{"supported":true,"error":"<img src=x>","battery":"../BAT0","mode":"conserve"}').error, "img src=x")
assert.strictEqual(Model.parseStatus('{"supported":true,"error":"","battery":"../BAT0","mode":"conserve"}').battery, "")
assert.strictEqual(Model.parseStatus("x".repeat(Model.MAX_HELPER_CHARS + 1)).error, "invalid-json")
assert.deepStrictEqual(Model.parseProfiles("<img src=x>\t1\nbalanced\t1\n").profiles, ["balanced"])
const many = Array.from({ length: 12 }, (_, i) => "p" + i + "\t0").join("\n")
assert.strictEqual(Model.parseProfiles(many).profiles.length, 8)
assert.deepStrictEqual(Model.parseProfiles("x".repeat(Model.MAX_HELPER_CHARS + 1)).profiles, [])

console.log("ok")
