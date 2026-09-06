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
assert.strictEqual(Model.defaultTimeoutMs({ promptTimeoutSec: 20 }), 20000)
assert.strictEqual(Model.pluginFilePath("file:///home/base/x/"), "/home/base/x")

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

console.log("ok")
