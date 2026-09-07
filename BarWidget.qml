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
  readonly property int conserveEnd: Model.conserveEndFromSettings(root.settings)
  readonly property string ctl: Model.pluginFilePath(Qt.resolvedUrl("scripts/charge-ctl"))
  readonly property bool supported: status.supported
  readonly property string mode: status.mode === "full" ? "full" : "conserve"
  readonly property string label: Model.capLabel(mode, conserveEnd) + "%"
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false


  function ctlCommand(args) {
    return ["env", "CHARGE_CONSERVE_END=" + String(root.conserveEnd)].concat(args)
  }

  function refresh() {
    if (statusProc.running) return
    statusProc.command = root.ctlCommand([root.ctl, "status", "--json"])
    statusProc.running = true
  }

  function prompt() {
    Quickshell.execDetached(["omarchy-shell", "k7cfo.charge", "prompt"])
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
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.status = Model.parseStatus(text)
    }
  }

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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    tooltipText: root.supported
      ? (root.mode === "full"
        ? "Charging to 100%. Click for ask-on-plug. Right-click for the wizard."
        : "Holding at " + root.conserveEnd + "%. Click for ask-on-plug. Right-click for the wizard.")
      : "No charge-threshold battery"
    onPressed: function(b) {
      if (!root.supported) return
      if (b === Qt.RightButton) root.prompt()
      else root.togglePanel()
    }
  }
}
