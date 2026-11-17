import QtQuick

// Labeled toggle row: title + optional description on the left, a switch on
// the right. Clicking anywhere on the row emits clicked(); consumers flip
// `checked` in response.
Rectangle {
  id: root

  property string label: ""
  property string description: ""
  property bool checked: false
  property bool hasCursor: false

  property bool rounded: Theme.cornerRadius > 0

  property color foreground: Theme.foreground
  property color accent: Theme.accent
  property string fontFamily: Theme.font.family
  property real titleSize: Theme.font.subtitle
  property real descriptionSize: Theme.font.caption

  signal clicked()

  activeFocusOnTab: true
  Keys.onReturnPressed: root.clicked()
  Keys.onEnterPressed: root.clicked()
  Keys.onSpacePressed: root.clicked()

  implicitHeight: Math.max(54, content.implicitHeight + Theme.spacing.huge)
  implicitWidth: Theme.space(240)
  radius: Theme.cornerRadius

  readonly property bool hot: hasCursor || mouse.containsMouse

  color: Theme.controlFill(activeFocus, root.hot, root.foreground, root.accent)
  border.width: Theme.controlBorderWidth(activeFocus, root.hot)
  border.color: Theme.controlBorder(activeFocus, root.hot, root.foreground, root.accent)

  Behavior on color { ColorAnimation { duration: Theme.duration(100) } }

  Row {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: root.border.width + Theme.spacing.rowPaddingX
    anchors.rightMargin: root.border.width + Theme.spacing.rowPaddingX
    spacing: Theme.spacing.rowPaddingX

    Column {
      width: parent.width - track.width - parent.spacing
      spacing: Theme.spacing.xs
      anchors.verticalCenter: parent.verticalCenter

      Text {
        text: root.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.titleSize
        font.bold: true
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        visible: root.description !== ""
        text: root.description
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: root.descriptionSize
        wrapMode: Text.WordWrap
        width: parent.width
      }
    }

    ToggleSwitch {
      id: track
      checked: root.checked
      rounded: root.rounded
      foreground: root.foreground
      accent: root.accent
      interactive: false
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
