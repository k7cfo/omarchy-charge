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

  readonly property string ctl: Model.pluginFilePath(Qt.resolvedUrl("scripts/charge-ctl"))

  function loadSettings() {
    var settings = {}
    if (shell && shell.shellConfig)
      settings = Model.settingsFromConfig(shell.shellConfig, "k7cfo.charge")
    root.conserveEnd = Model.conserveEndFromSettings(settings)
    prompt.timeoutMs = Model.defaultTimeoutMs(settings)
    prompt.conserveEnd = root.conserveEnd
    return settings
  }

  function ctlCommand(args) {
    return ["env", "CHARGE_CONSERVE_END=" + String(root.conserveEnd)].concat(args)
  }

  function refreshStatus() {
    if (statusProc.running) return
    statusProc.command = root.ctlCommand([root.ctl, "status", "--json"])
    statusProc.running = true
  }

  function apply(mode) {
    if (applyProc.running) return
    applyProc.command = root.ctlCommand([root.ctl, mode === "full" ? "full" : "conserve"])
    applyProc.running = true
  }

  function showPrompt() {
    loadSettings()
    prompt.capacity = root.status.capacity
    prompt.writable = root.status.writable
    prompt.errorText = root.status.error
    prompt.openPrompt()
  }

  function onPowerChanged() {
    var onBattery = !!UPower.onBattery
    var settings = loadSettings()
    var promptOnConnect = settings.promptOnConnect !== false
    if (onBattery) {
      root.sessionPrompted = false
      prompt.closePrompt()
      if (root.status.mode === "full") root.apply("conserve")
    } else if (Model.shouldPrompt({
      supported: root.status.supported,
      promptOnConnect: promptOnConnect,
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
    onConserveChosen: root.apply("conserve")
    onFullChosen: root.apply("full")
    onDismissed: root.apply("conserve")
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
    onTriggered: root.refreshStatus()
  }

  Component.onCompleted: {
    loadSettings()
    root.wasOnBattery = !!UPower.onBattery
    root.refreshStatus()
    Qt.callLater(function() { root.ready = true })
  }
}
