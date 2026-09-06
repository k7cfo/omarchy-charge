import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false
  property int capacity: 0
  property int conserveEnd: 80
  property int timeoutMs: 20000
  property int remainingMs: timeoutMs
  property int selectedIndex: 0
  property bool writable: true
  property string errorText: ""

  readonly property string fontFamily: Style.font.menuFamily
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  property int cardWidth: Math.min(Style.space(420), panel.width - Style.gapsOut * 2)

  signal conserveChosen()
  signal fullChosen()
  signal dismissed()

  function openPrompt() {
    selectedIndex = 0
    remainingMs = timeoutMs
    opened = true
    tick.restart()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function closePrompt() {
    tick.stop()
    opened = false
  }

  function chooseConserve() {
    closePrompt()
    root.conserveChosen()
  }

  function chooseFull() {
    closePrompt()
    root.fullChosen()
  }

  function dismiss() {
    closePrompt()
    root.dismissed()
  }

  Timer {
    id: tick
    interval: 100
    repeat: true
    onTriggered: {
      root.remainingMs = Math.max(0, root.remainingMs - interval)
      if (root.remainingMs <= 0) root.chooseConserve()
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
      onClicked: root.chooseConserve()
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
            root.chooseConserve()
            event.accepted = true
          } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            root.selectedIndex = 0
            event.accepted = true
          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            root.selectedIndex = 1
            event.accepted = true
          } else if (event.key === Qt.Key_1 || event.key === Qt.Key_Keypad1 || event.text === "1") {
            root.chooseConserve()
            event.accepted = true
          } else if (event.key === Qt.Key_2 || event.key === Qt.Key_Keypad2 || event.text === "2") {
            root.chooseFull()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (root.selectedIndex === 1) root.chooseFull()
            else root.chooseConserve()
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
          text: "Plugged in"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          width: parent.width
          text: root.writable
            ? ("Battery at " + root.capacity + "%. Press 1 to hold at " + root.conserveEnd + "%, or 2 to fill to 100% for the day.")
            : (root.errorText || "Charge thresholds are not writable. Install the helper once — see the Charge Limit README.")
          color: root.foreground
          opacity: 0.78
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Column {
          id: choiceCol
          width: parent.width
          spacing: Style.space(8)

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
            onClicked: root.chooseConserve()
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
            onClicked: root.chooseFull()
            onHovered: function(h) { if (h) root.selectedIndex = 1 }
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

        Text {
          width: parent.width
          text: "1 keeps " + root.conserveEnd + "% · 2 fills to 100% · Esc is 1"
          color: root.foreground
          opacity: 0.5
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
