import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "k7cfo.charge"

  property var status: Model.parseStatus("")
  property string statusBuf: ""
  readonly property int conserveEnd: Model.conserveEndFromSettings(root.settings)
  readonly property string ctl: Model.pluginFilePath(Qt.resolvedUrl("scripts/charge-ctl"))
  readonly property string boundedRun: Model.pluginFilePath(Qt.resolvedUrl("scripts/bounded-run"))
  readonly property string omarchyBin: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/bin"
  readonly property string omarchyShell: omarchyBin + "/omarchy-shell"
  readonly property int helperCap: Model.MAX_HELPER_CHARS
  readonly property bool supported: status.supported
  readonly property string mode: status.mode === "full" ? "full" : "conserve"
  readonly property int packPercent: Model.packPercent(UPower.displayDevice ? UPower.displayDevice.percentage : undefined, status.capacity)
  readonly property string label: Model.capLabel(mode, conserveEnd) + "%"
  readonly property string barText: Model.barLabel(root.packPercent, mode, conserveEnd)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
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


  function refresh() {
    if (statusProc.running) return
    root.statusBuf = ""
    statusProc.command = [root.boundedRun, root.ctl, "status", "--json"]
    statusProc.running = true
  }

  function prompt() {
    Quickshell.execDetached([root.omarchyShell, "k7cfo.charge", "prompt"])
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  visible: supported
  implicitWidth: supported ? button.implicitWidth : 0
  implicitHeight: supported ? button.implicitHeight : 0

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: statusProc
    clearEnvironment: true
    environment: root.helperEnvironment
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) {
        root.statusBuf += chunk
        if (root.statusBuf.length > root.helperCap) {
          statusProc.signal(15)
          statusKill.start()
          root.statusBuf = ""
        }
      }
    }
    stderr: SplitParser { splitMarker: ""; onRead: function() {} }
    onExited: {
      root.status = Model.parseStatus(root.statusBuf)
      root.statusBuf = ""
    }
    Component.onDestruction: { if (statusProc.running) statusProc.signal(15) }
  }

  Timer { id: statusKill; interval: 2000; repeat: false; onTriggered: { if (statusProc.running) statusProc.signal(9) } }

  Timer {
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() { root.refresh() }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.barText
    labelVisible: !root.vertical
    hasVisualContent: true
    fontSize: Style.bar.iconFont
    horizontalMargin: 8.75
    fixedHeight: root.vertical ? Style.bar.iconSlot * 2 : -1
    tooltipText: Model.plain(root.supported
      ? (root.mode === "full"
        ? (root.packPercent + "%, charging to 100%. Click for ask-on-plug. Right-click for the wizard.")
        : (root.packPercent + "%, holding at " + root.conserveEnd + "%. Click for ask-on-plug. Right-click for the wizard."))
      : "No charge-threshold battery")
    onPressed: function(b) {
      if (!root.supported) return
      if (b === Qt.RightButton) root.prompt()
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Text {
        width: parent.width
        height: Style.bar.iconSlot
        textFormat: Text.PlainText
        text: String(root.packPercent)
        color: button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      Text {
        width: parent.width
        height: Style.bar.iconSlot
        textFormat: Text.PlainText
        text: Model.capLabel(root.mode, root.conserveEnd)
        color: button.foreground
        opacity: 0.7
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}
