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

  function ctlCommand(args) {
    return ["env", "CHARGE_CONSERVE_END=" + String(root.conserveEnd)].concat(args)
  }

  function refresh() {
    if (statusProc.running) return
    statusProc.command = root.ctlCommand([root.ctl, "status", "--json"])
    statusProc.running = true
  }

  function apply(next) {
    if (applyProc.running) return
    applyProc.command = root.ctlCommand([root.ctl, next === "full" ? "full" : "conserve"])
    applyProc.running = true
  }

  function toggleCap() {
    if (!supported) return
    apply(mode === "full" ? "conserve" : "full")
  }

  function prompt() {
    Quickshell.execDetached(["omarchy-shell", "k7cfo.charge", "prompt"])
  }

  visible: supported
  implicitWidth: supported ? button.implicitWidth : 0
  implicitHeight: supported ? button.implicitHeight : 0

  Process {
    id: statusProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.status = Model.parseStatus(text)
    }
  }

  Process {
    id: applyProc
    stdout: StdioCollector { waitForEnd: true }
    onExited: root.refresh()
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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    tooltipText: root.supported
      ? (root.mode === "full"
        ? "Charging to 100%. Click to hold at " + root.conserveEnd + "%."
        : "Holding at " + root.conserveEnd + "%. Click to charge to 100%.")
      : "No charge-threshold battery"
    onPressed: function(b) {
      if (!root.supported) return
      if (b === Qt.RightButton) root.prompt()
      else root.toggleCap()
    }
  }
}
