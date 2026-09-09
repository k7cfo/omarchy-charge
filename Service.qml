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
  property string statusBuf: ""
  property string applyBuf: ""
  property string profileBuf: ""
  property string profilesBuf: ""

  readonly property string ctl: Model.pluginFilePath(Qt.resolvedUrl("scripts/charge-ctl"))
  readonly property string boundedRun: Model.pluginFilePath(Qt.resolvedUrl("scripts/bounded-run"))
  readonly property string omarchyBin: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/bin"
  readonly property string omarchyShell: omarchyBin + "/omarchy-shell"
  readonly property string powerprofilesList: omarchyBin + "/omarchy-powerprofiles-list"
  readonly property string powerprofilesSet: omarchyBin + "/omarchy-powerprofiles-set"
  readonly property int helperCap: Model.MAX_HELPER_CHARS
  readonly property var helperEnvironment: {
    var env = {
      "HOME": String(Quickshell.env("HOME") || ""),
      "PATH": "/usr/bin:/usr/local/sbin",
      "LC_ALL": "C",
      "CHARGE_CONSERVE_END": String(root.conserveEnd)
    }
    var stateHome = String(Quickshell.env("XDG_STATE_HOME") || "")
    if (stateHome !== "") env.XDG_STATE_HOME = stateHome
    return env
  }

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

  function takeChunk(proc, field, chunk, killer) {
    root[field] += chunk
    if (root[field].length > root.helperCap) {
      proc.signal(15)
      killer.start()
      root[field] = ""
    }
  }

  function refreshStatus() {
    if (statusProc.running) return
    root.statusBuf = ""
    statusProc.command = [root.boundedRun, root.ctl, "status", "--json"]
    statusProc.running = true
  }

  function refreshProfiles() {
    if (!profilesProc.running) {
      root.profilesBuf = ""
      profilesProc.running = true
    }
  }

  function apply(mode) {
    if (applyProc.running) return
    root.applyBuf = ""
    applyProc.command = [root.boundedRun, root.ctl, mode === "full" ? "full" : "conserve"]
    applyProc.running = true
  }

  function applyProfile(name) {
    if (!name || profileProc.running) return
    if (!Model.isProfileName(name)) return
    root.profileBuf = ""
    profileProc.command = [root.boundedRun, root.powerprofilesSet, "autodetect", name]
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
    clearEnvironment: true
    environment: root.helperEnvironment
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.takeChunk(statusProc, "statusBuf", chunk, statusKill) }
    }
    stderr: SplitParser { splitMarker: ""; onRead: function() {} }
    onExited: {
      root.status = Model.parseStatus(root.statusBuf)
      root.statusBuf = ""
      root.maybeFinishFull()
    }
    Component.onDestruction: { if (statusProc.running) statusProc.signal(15) }
  }

  Timer { id: statusKill; interval: 2000; repeat: false; onTriggered: { if (statusProc.running) statusProc.signal(9) } }

  Process {
    id: applyProc
    clearEnvironment: true
    environment: root.helperEnvironment
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.takeChunk(applyProc, "applyBuf", chunk, applyKill) }
    }
    stderr: SplitParser { splitMarker: ""; onRead: function() {} }
    onExited: {
      root.applyBuf = ""
      root.refreshStatus()
    }
    Component.onDestruction: { if (applyProc.running) applyProc.signal(15) }
  }

  Timer { id: applyKill; interval: 2000; repeat: false; onTriggered: { if (applyProc.running) applyProc.signal(9) } }

  Process {
    id: profileProc
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.takeChunk(profileProc, "profileBuf", chunk, profileKill) }
    }
    stderr: SplitParser { splitMarker: ""; onRead: function() {} }
    onExited: {
      root.profileBuf = ""
      root.refreshProfiles()
    }
    Component.onDestruction: { if (profileProc.running) profileProc.signal(15) }
  }

  Timer { id: profileKill; interval: 2000; repeat: false; onTriggered: { if (profileProc.running) profileProc.signal(9) } }

  Process {
    id: profilesProc
    command: [root.boundedRun, root.powerprofilesList, "--active-state"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.takeChunk(profilesProc, "profilesBuf", chunk, profilesKill) }
    }
    stderr: SplitParser { splitMarker: ""; onRead: function() {} }
    onExited: {
      var parsed = Model.parseProfiles(root.profilesBuf)
      root.profilesBuf = ""
      if (parsed.profiles.length === 0) return
      root.profiles = parsed.profiles
      root.activeProfile = parsed.active
      prompt.profiles = parsed.profiles
      prompt.activeProfile = parsed.active
    }
    Component.onDestruction: { if (profilesProc.running) profilesProc.signal(15) }
  }

  Timer { id: profilesKill; interval: 2000; repeat: false; onTriggered: { if (profilesProc.running) profilesProc.signal(9) } }

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
