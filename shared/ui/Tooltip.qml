import QtQuick
import QtQuick.Controls as QQC

// Small themed tooltip. Inherits Qt Quick Controls' ToolTip purely for its
// placement helper; every visual is replaced with Theme tokens so it matches
// the popup card.
QQC.ToolTip {
  id: root

  property bool hovered: false
  property string label: ""

  visible: hovered && label !== ""
  text: label
  delay: 400
  padding: 0

  background: Rectangle {
    color: Theme.tooltipBackground
    border.width: 1
    border.color: Theme.tooltipBorder
    radius: Theme.cornerRadius
  }

  contentItem: Text {
    text: root.label
    color: Theme.tooltipText
    font.family: Theme.font.family
    font.pixelSize: Theme.font.bodySmall
    leftPadding: Theme.spacing.controlPaddingX
    rightPadding: Theme.spacing.controlPaddingX
    topPadding: Theme.spacing.controlPaddingY
    bottomPadding: Theme.spacing.controlPaddingY
  }
}
