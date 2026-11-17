import QtQuick

// Bare on/off switch: a track with a sliding knob and no label.
Item {
  id: root

  property bool checked: false
  property bool busy: false

  // Off when the surrounding row owns the click, as in Toggle.
  property bool interactive: true
  property bool hasCursor: false

  property bool cursorRing: interactive
  property int cursorPad: Theme.space(6)
  property bool rounded: Theme.cornerRadius > 0
  property color foreground: Theme.foreground
  property color accent: Theme.accent

  signal toggled()

  readonly property bool hot: hasCursor || mouse.containsMouse
  readonly property int pad: cursorRing ? cursorPad : 0

  property int trackHeight: Math.max(22, Math.round(Theme.spacing.controlHeight * 0.55))
  property int trackWidth: Math.round(trackHeight * 1.9)
  property int knobSize: Math.max(6, Math.round(trackHeight * 0.72))
  property int knobInset: Math.max(1, Math.round((trackHeight - knobSize) / 2))

  implicitWidth: trackWidth + pad * 2
  implicitHeight: trackHeight + pad * 2

  Rectangle {
    anchors.fill: parent
    visible: root.cursorRing && root.hot
    color: "transparent"
    radius: Theme.cornerRadius
    border.width: Theme.hoverBorderWidth
    border.color: Theme.hoverBorderFor(root.foreground, root.accent)
  }

  Rectangle {
    id: track
    width: root.trackWidth
    height: root.trackHeight
    anchors.centerIn: parent
    radius: root.rounded ? height / 2 : 0
    color: root.checked
      ? Theme.selectedFillFor(root.foreground, root.accent)
      : Theme.normalFillFor(root.foreground, root.accent)
    border.width: Math.max(1, root.checked ? Theme.selectedBorderWidth : Theme.normalBorderWidth)
    border.color: root.checked
      ? Theme.selectedBorderFor(root.foreground, root.accent)
      : Theme.normalBorderFor(root.foreground, root.accent)

    Behavior on color { ColorAnimation { duration: Theme.duration(120) } }

    Rectangle {
      width: root.knobSize
      height: root.knobSize
      radius: root.rounded ? height / 2 : 0
      x: root.checked ? track.width - width - root.knobInset : root.knobInset
      anchors.verticalCenter: parent.verticalCenter
      color: root.checked
        ? Theme.selectedStateColor(root.foreground, root.accent)
        : Qt.darker(root.foreground, 1.25)

      Behavior on x { NumberAnimation { duration: Theme.duration(120); easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: Theme.duration(120) } }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    enabled: root.interactive
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (!root.busy) root.toggled()
  }
}
