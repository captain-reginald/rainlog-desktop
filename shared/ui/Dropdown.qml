import QtQuick
import QtQuick.Controls as QQC

// Themed single-select dropdown. The trigger paints the kit's focus chrome and
// the popup uses the popup-card palette, matching the plugin's control.
Item {
  id: root

  property string label: ""
  property string value: ""
  property var options: []

  property color foreground: Theme.popupsText
  property color background: Theme.popupsBackground
  property color popupBorder: Theme.popupsBorder
  property color accent: Theme.accent
  property string fontFamily: Theme.font.family
  property int rowHeight: Theme.spacing.controlHeight
  property int popupRowHeight: Theme.spacing.popupRowHeight
  property bool showLabel: true
  property bool hasCursor: false

  readonly property bool popupOpen: popup.opened

  function open() { popup.open() }
  function close() { popup.close() }
  function toggle() { popup.opened ? popup.close() : popup.open() }

  signal changed(string value)

  function optionValue(option) {
    return (option && typeof option === "object") ? String(option.value) : String(option)
  }

  function optionLabel(option) {
    return (option && typeof option === "object") ? String(option.label) : String(option)
  }

  function currentLabel() {
    for (var i = 0; i < options.length; i++) {
      if (optionValue(options[i]) === value) return optionLabel(options[i])
    }
    return value
  }

  implicitWidth: Theme.spacing.dropdownWidth
  implicitHeight: (showLabel && label !== "" ? labelText.implicitHeight + Theme.spacing.labelGap : 0) + rowHeight

  Column {
    anchors.fill: parent
    spacing: Theme.spacing.labelGap

    Text {
      id: labelText
      visible: root.showLabel && root.label !== ""
      text: root.label
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Theme.font.caption
      font.bold: true
    }

    Rectangle {
      id: trigger
      width: parent.width
      height: root.rowHeight
      radius: Theme.cornerRadius

      readonly property bool focused: trigger.activeFocus
      readonly property bool hot: triggerHover.hovered || root.hasCursor

      color: Theme.controlFill(trigger.focused, trigger.hot, root.foreground, root.accent)
      border.width: Theme.controlBorderWidth(trigger.focused, trigger.hot)
      border.color: Theme.controlBorder(trigger.focused, trigger.hot, root.foreground, root.accent)

      activeFocusOnTab: true

      HoverHandler {
        id: triggerHover
      }

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
            || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
          popup.opened ? popup.close() : popup.open()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape && popup.opened) {
          popup.close()
          event.accepted = true
        }
      }

      Text {
        anchors.left: parent.left
        anchors.right: chevron.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: trigger.border.width + Theme.spacing.controlPaddingX
        anchors.rightMargin: trigger.border.width + Theme.spacing.md
        text: root.currentLabel()
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
        elide: Text.ElideRight
      }

      Text {
        id: chevron
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: trigger.border.width + Theme.spacing.controlGap
        text: "󰅀"
        color: Qt.darker(root.foreground, 1.2)
        font.family: root.fontFamily
        font.pixelSize: Theme.font.body
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          trigger.forceActiveFocus()
          popup.opened ? popup.close() : popup.open()
        }
      }

      QQC.Popup {
        id: popup
        x: 0
        y: trigger.height + Theme.spacing.xxs
        closePolicy: QQC.Popup.CloseOnPressOutsideParent | QQC.Popup.CloseOnEscape
        width: trigger.width
        implicitHeight: Math.min(root.options.length * root.popupRowHeight
                                   + Math.max(0, root.options.length - 1) * Theme.spacing.labelGap,
                                 root.popupRowHeight * 8 + 7 * Theme.spacing.labelGap)
                        + topPadding + bottomPadding
        padding: Theme.spacing.hairline
        leftPadding: Theme.spacing.hairline * 2
        rightPadding: Theme.spacing.hairline * 2
        topPadding: Theme.spacing.hairline * 2
        bottomPadding: Theme.spacing.hairline * 2
        focus: true

        background: Rectangle {
          color: root.background
          radius: Theme.cornerRadius
          border.width: Math.max(1, Theme.normalBorderWidth)
          border.color: root.popupBorder
        }

        onOpened: {
          optionList.currentIndex = Math.max(0, optionList.indexOfValue(root.value))
          optionList.forceActiveFocus()
        }

        contentItem: ListView {
          id: optionList
          spacing: Theme.spacing.labelGap

          Keys.priority: Keys.BeforeItem
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              popup.close()
              event.accepted = true
            } else if (event.key === Qt.Key_Down || event.text === "j") {
              optionList.currentIndex = Math.min(root.options.length - 1, optionList.currentIndex + 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up || event.text === "k") {
              optionList.currentIndex = Math.max(0, optionList.currentIndex - 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              optionList.selectCurrent()
              event.accepted = true
            }
          }

          implicitHeight: contentHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.options
          currentIndex: -1

          function indexOfValue(v) {
            for (var i = 0; i < root.options.length; i++)
              if (root.optionValue(root.options[i]) === v) return i
            return -1
          }

          function selectCurrent() {
            if (currentIndex < 0 || currentIndex >= root.options.length) return
            var v = root.optionValue(root.options[currentIndex])
            root.value = v
            root.changed(v)
            popup.close()
          }

          delegate: Rectangle {
            required property var modelData
            required property int index

            width: optionList.width
            height: root.popupRowHeight
            color: index === optionList.currentIndex
              ? Theme.hoverFillFor(root.foreground, root.accent)
              : "transparent"

            Text {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Theme.spacing.controlPaddingX
              anchors.rightMargin: Theme.spacing.controlPaddingX
              text: root.optionLabel(modelData)
              color: index === optionList.currentIndex
                ? Theme.hoverStateColor(root.foreground, root.accent)
                : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Theme.font.body
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onPositionChanged: optionList.currentIndex = parent.index
              onClicked: optionList.selectCurrent()
            }
          }
        }
      }
    }
  }
}
