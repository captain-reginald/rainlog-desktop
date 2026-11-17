import QtQuick
import RainLog

// Desktop host: a small frameless window whose body is the same card the
// Omarchy plugin shows. The only host-specific chrome is a slim strip with
// the settings and minimize/close controls above the card header, so the app
// keeps working on GNOME, KDE, Cinnamon, and Windows, where a plugin cannot.
Window {
  id: window

  visible: true
  title: qsTr("Rain Log")
  flags: Qt.Window | Qt.FramelessWindowHint
  color: Theme.cornerRadius > 0 ? "transparent" : Theme.popupsBackground

  width: Config.windowWidth
  // A sensible first paint; the window then follows the card's measured
  // height through one coalesced update after the layout settles. A user
  // resize pins the current height instead of fighting the measurement.
  property bool userSized: Config.windowHeight > 0
  property int pinnedHeight: Config.windowHeight > 0 ? Config.windowHeight : 0
  property int targetWindowHeight: 490
  readonly property int fittedHeight: Math.max(120, titleBar.height + content.naturalHeight)
  readonly property bool autoFitAllowed: Host.screenshotMode
    || (Config.windowHeight <= 0 && !window.userSized)
  height: !Host.screenshotMode && Config.windowHeight > 0
    ? Config.windowHeight
    : (window.userSized ? window.pinnedHeight : window.targetWindowHeight)
  minimumWidth: 400
  minimumHeight: 180

  // Layouts only report their implicit heights after a polish pass and may do
  // so more than once. Coalesce those updates and apply one final size.
  function scheduleAutoFit() {
    if (!window.autoFitAllowed)
      return
    autoFitTimer.restart()
  }
  function syncTheme() {
    Theme.load(ThemeSource.colorsToml, ThemeSource.shellToml, ThemeSource.userShellToml)
    Theme.cornerRadius = ThemeSource.cornerRadius
    Theme.fontFamilyOverride = ThemeSource.fontFamily
  }

  Component.onCompleted: {
    syncTheme()

    // A view can be forced for screenshots and manual checks.
    var view = Host.startupView
    if (view === "settings") content.settingsMode = true
    else if (view === "history") content.historyMode = true
    window.scheduleAutoFit()
  }

  Connections {
    target: content
    function onNaturalHeightChanged() { window.scheduleAutoFit() }
  }

  Timer {
    id: autoFitTimer
    interval: 32
    repeat: false
    onTriggered: {
      if (window.autoFitAllowed && window.targetWindowHeight !== window.fittedHeight) {
        window.targetWindowHeight = window.fittedHeight
        Host.requestWindowResize(window.width, window.fittedHeight)
      }
    }
  }

  onHeightChanged: {
    if (window.userSized && window.pinnedHeight !== window.height)
      window.pinnedHeight = window.height
  }

  Timer {
    interval: 120
    running: true
    onTriggered: {
      if (Config.windowX >= 0 && Config.windowY >= 0) {
        window.x = Config.windowX
        window.y = Config.windowY
      }
      content.forceActiveFocus()
    }
  }

  onClosing: {
    // Screenshot runs quit immediately after grabbing the frame; they must not
    // overwrite the geometry the real window saved.
    if (Host.screenshotMode)
      return
    Config.setWindowGeometry(x, y,
                             window.userSized ? window.width : Config.windowWidth,
                             window.userSized ? window.height : 0)
    Store.save()
    // The event loop is about to stop; write the settings now instead of
    // waiting for the debounce timer.
    Config.flush()
  }

  Connections {
    target: ThemeSource
    function onTextsChanged() { window.syncTheme() }
    function onCornerRadiusChanged() { Theme.cornerRadius = ThemeSource.cornerRadius }
  }

  Connections {
    target: Host
    function onRaiseRequested() {
      window.showNormal()
      window.raise()
      window.requestActivate()
    }
  }

  Shortcut {
    sequences: ["Ctrl+W", "Ctrl+Q"]
    onActivated: window.close()
  }

  Rectangle {
    id: card
    anchors.fill: parent
    color: Theme.popupsBackground
    radius: Theme.cornerRadius
    border.width: 2
    border.color: Theme.popupsBorder

    // Window controls sit above the card header, the way a regular title bar
    // does. The empty part of the strip drags the window; the app name is in
    // the card header below.
    Item {
      id: titleBar
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.topMargin: 2
      anchors.leftMargin: 2
      anchors.rightMargin: 2
      height: Math.max(26, titleControls.implicitHeight + Theme.space(4))

      MouseArea {
        anchors.fill: parent
        onPressed: window.startSystemMove()
      }

      Row {
        id: titleControls
        anchors.right: parent.right
        anchors.rightMargin: Theme.space(4)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space(2)

        Button {
          text: "⚙"
          tooltipText: "Settings"
          verticalPadding: Theme.space(2)
          horizontalPadding: Theme.space(8)
          selected: content.settingsMode
          onClicked: {
            content.historyMode = false
            content.settingsMode = !content.settingsMode
            content.forceActiveFocus()
          }
        }

        Button {
          text: "—"
          tooltipText: "Minimize"
          verticalPadding: Theme.space(2)
          horizontalPadding: Theme.space(8)
          onClicked: window.showMinimized()
        }

        Button {
          text: "✕"
          tooltipText: "Close"
          verticalPadding: Theme.space(2)
          horizontalPadding: Theme.space(8)
          onClicked: window.close()
        }
      }
    }

    RainLogContent {
      id: content
      anchors.fill: parent
      anchors.topMargin: 2 + titleBar.height
      anchors.leftMargin: 2
      anchors.rightMargin: 2
      anchors.bottomMargin: 2
      contentPadding: Theme.spacing.popupPadding
      onMoveRequested: window.startSystemMove()
    }
  }

  // Frameless windows need their own resize handles.
  MouseArea {
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 5
    cursorShape: Qt.SizeHorCursor
    onPressed: { window.userSized = true; window.pinnedHeight = window.height; window.startSystemResize(Qt.LeftEdge) }
  }

  MouseArea {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: 5
    cursorShape: Qt.SizeHorCursor
    onPressed: { window.userSized = true; window.pinnedHeight = window.height; window.startSystemResize(Qt.RightEdge) }
  }

  MouseArea {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 5
    cursorShape: Qt.SizeVerCursor
    onPressed: { window.userSized = true; window.pinnedHeight = window.height; window.startSystemResize(Qt.TopEdge) }
  }

  MouseArea {
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 5
    cursorShape: Qt.SizeVerCursor
    onPressed: { window.userSized = true; window.pinnedHeight = window.height; window.startSystemResize(Qt.BottomEdge) }
  }

  MouseArea {
    anchors.left: parent.left
    anchors.top: parent.top
    width: 8
    height: 8
    cursorShape: Qt.SizeFDiagCursor
    onPressed: { window.userSized = true; window.pinnedHeight = window.height; window.startSystemResize(Qt.TopLeftCorner) }
  }

  MouseArea {
    anchors.right: parent.right
    anchors.top: parent.top
    width: 8
    height: 8
    cursorShape: Qt.SizeBDiagCursor
    onPressed: { window.userSized = true; window.pinnedHeight = window.height; window.startSystemResize(Qt.TopRightCorner) }
  }

  MouseArea {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    width: 8
    height: 8
    cursorShape: Qt.SizeBDiagCursor
    onPressed: { window.userSized = true; window.pinnedHeight = window.height; window.startSystemResize(Qt.BottomLeftCorner) }
  }

  MouseArea {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: 8
    height: 8
    cursorShape: Qt.SizeFDiagCursor
    onPressed: { window.userSized = true; window.pinnedHeight = window.height; window.startSystemResize(Qt.BottomRightCorner) }
  }
}
