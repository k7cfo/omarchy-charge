import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "k7cfo.charge"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int conserveEnd: Model.conserveEndFromSettings(root.settings)
  readonly property bool promptOnConnect: Model.promptOnConnectFromSettings(root.settings)
  readonly property string capText: hostWidget && hostWidget.label ? hostWidget.label : (conserveEnd + "%")
  readonly property string modeText: hostWidget && hostWidget.mode === "full"
    ? "Charging to 100%"
    : ("Holding at " + conserveEnd + "%")
  readonly property string omarchyShell: (Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy") + "/bin/omarchy-shell"


  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setPromptOnConnect(enabled) {
    persistSettings({ promptOnConnect: enabled === true })
  }

  function runWizard() {
    root.close()
    Quickshell.execDetached([root.omarchyShell, "k7cfo.charge", "prompt"])
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.runWizard()
      onTextKey: function(t) {
        if (t === "a" || t === "A") root.setPromptOnConnect(!root.promptOnConnect)
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "Charge limit"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.modeText + " · cap " + root.capText
          color: root.contentForeground
          opacity: 0.78
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Toggle {
          width: parent.width
          label: "Ask when plugging in"
          description: "Cap first, then power profile. Uncheck to skip the card."
          checked: root.promptOnConnect
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.setPromptOnConnect(!root.promptOnConnect)
        }

        Button {
          width: parent.width
          text: "Choose cap and profile"
          leftAlign: true
          fontFamily: root.contentFontFamily
          foreground: root.contentForeground
          bordered: true
          onClicked: root.runWizard()
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: "A asks on plug · Enter runs the wizard · Esc closes"
          color: root.contentForeground
          opacity: 0.5
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
