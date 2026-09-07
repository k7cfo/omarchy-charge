import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool wasOnBattery: true
  property bool sessionPrompted: false
  property bool ready: false
  property var status: Model.parseStatus("")
  property int conserveEnd: 80
  property bool promptOnConnect: true
  property var profiles: []
  property string activeProfile: ""

  readonly property string ctl: Model.pluginFilePath(Qt.resolvedUrl("scripts/charge-ctl"))

  function loadSettings() {
    var settings = {}
    if (shell && shell.shellConfig)
      settings = Model.settingsFromConfig(shell.shellConfig, "k7cfo.charge")
    root.conserveEnd = Model.conserveEndFromSettings(settings)
    root.promptOnConnect = Model.promptOnConnectFromSettings(settings)
    prompt.timeoutMs = Model.defaultTimeoutMs(settings)
    prompt.conserveEnd = root.conserveEnd
    prompt.promptOnConnect = root.promptOnConnect
    return settings
  }

  function persistPromptOnConnect(enabled) {
    var settings = loadSettings()
    settings.promptOnConnect = enabled === true
    settings.id = "k7cfo.charge"
    root.promptOnConnect = settings.promptOnConnect
    prompt.promptOnConnect = root.promptOnConnect
    if (shell && typeof shell.updateEntryInline === "function")
      shell.updateEntryInline("k7cfo.charge", settings)
  }

  function persistSkipFromPrompt() {
    persistPromptOnConnect(!prompt.skipAsk)
  }

  function ctlCommand(args) {
    return ["env", "CHARGE_CONSERVE_END=" + String(root.conserveEnd)].concat(args)
  }

  function refreshStatus() {
    if (statusProc.running) return
    statusProc.command = root.ctlCommand([root.ctl, "status", "--json"])
    statusProc.running = true
  }

  function refreshProfiles() {
    if (!profilesProc.running) profilesProc.running = true
  }

  function apply(mode) {
    if (applyProc.running) return
    applyProc.command = root.ctlCommand([root.ctl, mode === "full" ? "full" : "conserve"])
    applyProc.running = true
  }

  function applyProfile(name) {
    if (!name || profileProc.running) return
    profileProc.command = ["omarchy-powerprofiles-set", "autodetect", name]
    profileProc.running = true
  }

  function showPrompt() {
    loadSettings()
    refreshProfiles()
    prompt.capacity = root.status.capacity
    prompt.writable = root.status.writable
    prompt.errorText = root.status.error
    prompt.profiles = root.profiles
    prompt.activeProfile = root.activeProfile
    prompt.openPrompt()
  }

  function onPowerChanged() {
    var onBattery = !!UPower.onBattery
    var settings = loadSettings()
    var ask = Model.promptOnConnectFromSettings(settings)
    if (onBattery) {
      root.sessionPrompted = false
      if (prompt.opened) prompt.finishWithoutProfile()
      if (root.status.mode === "full") root.apply("conserve")
    } else if (Model.shouldPrompt({
      supported: root.status.supported,
      promptOnConnect: ask,
      onBattery: onBattery,
      wasOnBattery: root.wasOnBattery,
      sessionPrompted: root.sessionPrompted,
      mode: root.status.mode
    })) {
      root.sessionPrompted = true
      root.showPrompt()
    }
    root.wasOnBattery = onBattery
    root.refreshStatus()
    root.refreshProfiles()
  }

  function maybeFinishFull() {
    if (UPower.onBattery) return
    if (root.status.mode !== "full") return
    if (Model.clampPercent(root.status.capacity) >= 99) root.apply("conserve")
  }

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.status = Model.parseStatus(text)
        root.maybeFinishFull()
      }
    }
  }

  Process {
    id: applyProc
    stdout: StdioCollector { waitForEnd: true }
    onExited: root.refreshStatus()
  }

  Process {
    id: profileProc
    stdout: StdioCollector { waitForEnd: true }
    onExited: root.refreshProfiles()
  }

  Process {
    id: profilesProc
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseProfiles(text)
        if (parsed.profiles.length === 0) return
        root.profiles = parsed.profiles
        root.activeProfile = parsed.active
        prompt.profiles = parsed.profiles
        prompt.activeProfile = parsed.active
      }
    }
  }

  IpcHandler {
    target: "k7cfo.charge"

    function prompt(): string {
      root.sessionPrompted = true
      root.showPrompt()
      return "ok"
    }

    function conserve(): string {
      root.apply("conserve")
      return "ok"
    }

    function full(): string {
      root.apply("full")
      return "ok"
    }

    function ping(): string { return "ok" }
  }

  Prompt {
    id: prompt
    onChargeChosen: function(mode) { root.apply(mode) }
    onProfileChosen: function(name) { root.applyProfile(name) }
    onClosed: root.persistSkipFromPrompt()
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() {
      if (!root.ready) return
      debounce.restart()
    }
  }

  Timer {
    id: debounce
    interval: 600
    repeat: false
    onTriggered: root.onPowerChanged()
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.refreshStatus()
      root.refreshProfiles()
    }
  }

  Component.onCompleted: {
    loadSettings()
    root.wasOnBattery = !!UPower.onBattery
    root.refreshStatus()
    root.refreshProfiles()
    Qt.callLater(function() { root.ready = true })
  }
}
