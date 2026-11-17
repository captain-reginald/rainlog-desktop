import QtQuick

// Single-line input with the kit's focus, hover, and selection styling.
// Built on TextInput directly (not Qt Quick Controls) so the desktop client
// and the plugin render identical pixels.
Rectangle {
  id: root

  property alias text: input.text
  property alias input: input
  property string placeholderText: ""

  property string fontFamily: Theme.font.family
  property real fontSize: Theme.font.body
  property color foreground: Theme.foreground
  property color accent: Theme.accent

  property real horizontalPadding: Theme.spacing.controlPaddingX
  property real verticalPadding: Theme.spacing.inputPaddingY
  property int borderThickness: Math.max(1, Theme.normalBorderWidth)

  // Kept for API parity with the shell control; the plugin drives it from its
  // panel cursor, the desktop client leaves it false.
  property bool hasCursor: false

  signal editingFinished()

  readonly property bool hot: hover.hovered || root.hasCursor
  readonly property bool focused: input.activeFocus

  implicitWidth: Theme.space(140)
  implicitHeight: input.implicitHeight + verticalPadding * 2 + borderThickness * 2

  radius: Theme.cornerRadius
  color: Theme.controlFill(root.focused, root.hot, root.foreground, root.accent)
  border.width: borderThickness
  border.color: Theme.controlBorder(root.focused, root.hot, root.foreground, root.accent)

  Behavior on color { ColorAnimation { duration: Theme.duration(100) } }

  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: root.horizontalPadding + root.borderThickness
    anchors.rightMargin: root.horizontalPadding + root.borderThickness
    anchors.topMargin: root.verticalPadding + root.borderThickness
    anchors.bottomMargin: root.verticalPadding + root.borderThickness
    verticalAlignment: TextInput.AlignVCenter

    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    color: root.foreground
    selectionColor: Theme.selectionFillFor(root.foreground, root.accent)
    selectedTextColor: root.foreground

    clip: true
    selectByMouse: true

    onAccepted: root.editingFinished()
    onActiveFocusChanged: if (!activeFocus) root.editingFinished()

    Keys.onEscapePressed: function(event) {
      input.focus = false
      event.accepted = true
    }
  }

  Text {
    visible: input.text.length === 0
    text: root.placeholderText
    color: Qt.darker(root.foreground, 1.6)
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    anchors.left: input.left
    anchors.right: input.right
    anchors.verticalCenter: parent.verticalCenter
    elide: Text.ElideRight
  }

  HoverHandler {
    id: hover
  }
}
