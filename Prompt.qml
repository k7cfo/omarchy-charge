import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property bool opened: false
  property string step: "charge"
  property int capacity: 0
  property int conserveEnd: 80
  property int timeoutMs: 20000
  property int remainingMs: timeoutMs
  property int selectedIndex: 0
  property bool writable: true
  property bool skipAsk: false
  property bool promptOnConnect: true
  property string errorText: ""
  property var profiles: []
  property string activeProfile: ""

  readonly property string fontFamily: Style.font.menuFamily
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int cardWidth: Math.min(Style.space(420), panel.width - Style.gapsOut * 2)
  readonly property bool onCharge: step === "charge"
  readonly property int choiceCount: onCharge ? 2 : Math.max(1, profiles.length)

  signal chargeChosen(string mode)
  signal profileChosen(string name)
  signal closed()

  function openPrompt() {
    step = "charge"
    selectedIndex = 0
    skipAsk = !promptOnConnect
    remainingMs = timeoutMs
    opened = true
    tick.restart()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function closePrompt() {
    tick.stop()
    opened = false
    root.closed()
  }

  function restartTimer() {
    remainingMs = timeoutMs
    tick.restart()
  }

  function finishWithoutProfile() {
    tick.stop()
    opened = false
    root.closed()
  }

  function chooseCharge(mode) {
    root.chargeChosen(mode === "full" ? "full" : "conserve")
    if (!profiles || profiles.length === 0) {
      finishWithoutProfile()
      return
    }
    step = "profile"
    selectedIndex = Model.profileIndex(profiles, activeProfile)
    restartTimer()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function chooseProfileAt(index) {
    var name = Model.profileAt(profiles, index)
    tick.stop()
    opened = false
    if (name) root.profileChosen(name)
    root.closed()
  }

  function onEscape() {
    if (onCharge) chooseCharge("conserve")
    else finishWithoutProfile()
  }

  function onTimeout() {
    if (onCharge) chooseCharge("conserve")
    else finishWithoutProfile()
  }

  function onActivate() {
    if (onCharge) chooseCharge(selectedIndex === 1 ? "full" : "conserve")
    else chooseProfileAt(selectedIndex)
  }

  Timer {
    id: tick
    interval: 100
    repeat: true
    onTriggered: {
      root.remainingMs = Math.max(0, root.remainingMs - interval)
      if (root.remainingMs <= 0) root.onTimeout()
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "k7cfo-charge"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.onEscape()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: card.borderTop + root.contentMargin + column.implicitHeight + root.contentMargin + card.borderBottom
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            root.onEscape()
            event.accepted = true
          } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            root.selectedIndex = Math.min(root.choiceCount - 1, root.selectedIndex + 1)
            event.accepted = true
          } else if (event.key === Qt.Key_D || event.text === "d" || event.text === "D") {
            root.skipAsk = !root.skipAsk
            event.accepted = true
          } else if (event.key === Qt.Key_1 || event.key === Qt.Key_Keypad1 || event.text === "1") {
            if (root.onCharge) root.chooseCharge("conserve")
            else root.chooseProfileAt(0)
            event.accepted = true
          } else if (event.key === Qt.Key_2 || event.key === Qt.Key_Keypad2 || event.text === "2") {
            if (root.onCharge) root.chooseCharge("full")
            else root.chooseProfileAt(1)
            event.accepted = true
          } else if (event.key === Qt.Key_3 || event.key === Qt.Key_Keypad3 || event.text === "3") {
            if (!root.onCharge) root.chooseProfileAt(2)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.onActivate()
            event.accepted = true
          }
        }
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        anchors.topMargin: card.contentTopInset
        spacing: Style.space(14)

        Text {
          width: parent.width
          text: root.onCharge ? "Plugged in" : "Power profile"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          width: parent.width
          text: root.onCharge
            ? (root.writable
              ? ("Battery at " + root.capacity + "%. Press 1 to hold at " + root.conserveEnd + "%, or 2 to fill to 100% for the day.")
              : (root.errorText || "Charge thresholds are not writable. Install the helper once — see the Charge Limit README."))
            : "Then pick how hard the machine should run on AC."
          color: root.foreground
          opacity: 0.78
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.onCharge

          Button {
            width: parent.width
            iconText: "1"
            text: "Hold " + root.conserveEnd + "%"
            leftAlign: true
            fontFamily: root.fontFamily
            foreground: root.foreground
            bordered: true
            selected: root.selectedIndex === 0
            enabled: root.writable
            onClicked: root.chooseCharge("conserve")
            onHovered: function(h) { if (h) root.selectedIndex = 0 }
          }

          Button {
            width: parent.width
            iconText: "2"
            text: "Charge to 100%"
            leftAlign: true
            fontFamily: root.fontFamily
            foreground: root.foreground
            bordered: true
            selected: root.selectedIndex === 1
            enabled: root.writable
            onClicked: root.chooseCharge("full")
            onHovered: function(h) { if (h) root.selectedIndex = 1 }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: !root.onCharge

          Repeater {
            model: root.profiles

            Button {
              required property var modelData
              required property int index
              width: parent.width
              iconText: String(index + 1)
              text: Model.profileTitle(String(modelData))
              leftAlign: true
              fontFamily: root.fontFamily
              foreground: root.foreground
              bordered: true
              selected: root.selectedIndex === index
              onClicked: root.chooseProfileAt(index)
              onHovered: function(h) { if (h) root.selectedIndex = index }
            }
          }
        }

        Item {
          width: parent.width
          implicitHeight: Style.space(6)

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Util.alpha(root.foreground, 0.12)
          }

          Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            radius: height / 2
            color: Color.accent
            width: parent.width * (root.timeoutMs > 0 ? root.remainingMs / root.timeoutMs : 0)
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(10)

          Text {
            text: "Don't ask when plugging in"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - skipSwitch.width - parent.spacing
            wrapMode: Text.WordWrap
          }

          ToggleSwitch {
            id: skipSwitch
            checked: root.skipAsk
            foreground: root.foreground
            anchors.verticalCenter: parent.verticalCenter
            onToggled: root.skipAsk = !root.skipAsk
          }
        }

        Text {
          width: parent.width
          text: root.onCharge
            ? ("1 keeps " + root.conserveEnd + "% · 2 fills to 100% · D skips next time · Esc is 1")
            : "1–3 picks a profile · Esc keeps the current one · D skips next time"
          color: root.foreground
          opacity: 0.5
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
