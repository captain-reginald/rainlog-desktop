import QtQuick

// The shared button: label, optional glyph, tooltip, and the kit's
// press/hover/focus/selected states. Borderless at rest unless `bordered` is
// set. All metrics come from Theme, so the plugin and the desktop client draw
// the same control.
Item {
  id: root

  property string text: ""
  property string iconText: ""
  property string tooltipText: ""

  property bool selected: false
  property bool active: false
  property bool bordered: false
  property bool focusable: false

  property color foreground: Theme.foreground
  property color accent: Theme.accent
  property string fontFamily: Theme.font.family
  property real fontSize: Theme.font.body
  property real iconSize: Theme.font.icon

  property real horizontalPadding: Theme.spacing.controlPaddingX
  property real verticalPadding: Theme.spacing.controlPaddingY

  signal clicked()
  signal hovered(bool isHovered)

  activeFocusOnTab: focusable
  Keys.onReturnPressed: if (focusable) root.clicked()
  Keys.onEnterPressed: if (focusable) root.clicked()
  Keys.onSpacePressed: if (focusable) root.clicked()

  // Reserve the widest border any state paints so hover/focus never reflows
  // neighbouring controls.
  readonly property int reservedBorder: Math.max(1,
    Theme.normalBorderWidth, Theme.hoverBorderWidth,
    Theme.focusBorderWidth, Theme.selectedBorderWidth)

  readonly property bool hot: mouse.containsMouse
  readonly property bool focusRing: focusable && activeFocus

  readonly property color fill: mouse.pressed ? Theme.pressedFillFor(root.foreground, root.accent)
    : focusRing ? Theme.focusFillFor(root.foreground, root.accent)
    : hot ? Theme.hoverFillFor(root.foreground, root.accent)
    : selected ? Theme.selectedFillFor(root.foreground, root.accent)
    : active ? Theme.selectedFillFor(root.foreground, root.accent)
    : "transparent"

  readonly property color borderTint: focusRing ? Theme.focusBorderFor(root.foreground, root.accent)
    : hot ? Theme.hoverBorderFor(root.foreground, root.accent)
    : (selected && Theme.selectedBorderWidth > 0) ? Theme.selectedBorderFor(root.foreground, root.accent)
    : bordered ? Theme.normalBorderFor(root.foreground, root.accent)
    : Qt.rgba(0, 0, 0, 0)

  implicitWidth: row.implicitWidth + horizontalPadding * 2 + reservedBorder * 2
  implicitHeight: row.implicitHeight + verticalPadding * 2 + reservedBorder * 2

  Rectangle {
    id: background
    anchors.fill: parent
    radius: Theme.cornerRadius
    color: root.fill
    border.width: root.reservedBorder
    border.color: root.borderTint

    Behavior on color { ColorAnimation { duration: Theme.duration(120) } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Theme.spacing.controlGap

    Text {
      id: iconGlyph
      visible: root.iconText !== ""
      text: root.iconText
      color: root.selected ? Theme.selectedStateColor(root.foreground, root.accent) : root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.iconSize
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: label
      visible: root.text !== ""
      text: root.text
      color: root.selected ? Theme.selectedStateColor(root.foreground, root.accent) : root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      font.bold: root.selected
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Held down, the button gives a little so a click is felt as well as seen.
  scale: mouse.pressed ? 0.97 : 1
  Behavior on scale {
    NumberAnimation {
      duration: Theme.duration(160)
      easing.type: Easing.Bezier
      easing.bezierCurve: Theme.easeOut
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    scale: 1 / root.scale
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (root.focusable) root.forceActiveFocus()
      root.clicked()
    }
  }

  Tooltip {
    hovered: mouse.containsMouse
    label: root.tooltipText
  }

  HoverHandler {
    onHoveredChanged: root.hovered(hovered)
  }
}
