import QtQuick
import QtQuick.Layouts
import RainLog
import "../model/Model.js" as Model

// The shared Rain Log card. Hosts supply:
//   * Theme, Store and Config through the module's singletons,
//   * optional `settingsExtra` content (the plugin injects its Bar section),
//   * optional `headerTrailing` content (the desktop client injects its
//     minimize/close buttons).
// Everything else — main page, rolling totals, calendar, history entry, data
// path setting — is identical in every host.
Item {
  id: root

  property bool historyMode: false
  property bool settingsMode: false
  property bool editingCustom: false
  property int contentPadding: Theme.spacing.popupPadding
  property Component settingsExtra: null
  property Component headerTrailing: null

  // Escape returns to the main page, then asks the host to dismiss itself.
  signal closeRequested()
  // Raised when the user drags the empty part of the header. The plugin
  // ignores it; the desktop window moves itself.
  signal moveRequested()

  readonly property var entries: Store.entries
  readonly property string dataPath: Config.dataPath
  readonly property int customDays: Config.customDays

  readonly property int bottomPad: historyMode || settingsMode ? 0 : Theme.space(6)

  // Height the card wants for the view currently showing. The desktop host
  // uses this only for its initial window size, so a resized window stays
  // resized.
  readonly property int naturalHeight: headerRow.implicitHeight + Theme.space(12)
    + contentColumn.implicitHeight + bottomPad + contentPadding * 2 + 4

  focus: true
  Keys.onEscapePressed: {
    if (root.settingsMode) { root.settingsMode = false; return }
    if (root.historyMode) { root.historyMode = false; return }
    root.closeRequested()
  }

  // -------------------------------------------------------------- windows
  function todayKey() { return Model.dateKey(new Date()) }

  function adjustOffset(key, delta) {
    if (key === "24") root.off24 = Math.max(0, root.off24 + delta)
    else if (key === "72") root.off72 = Math.max(0, root.off72 + delta)
    else if (key === "week") root.offWeek = Math.max(0, root.offWeek + delta)
    else if (key === "month") root.offMonth = Math.max(0, root.offMonth + delta)
    else if (key === "season") root.offSeason = Math.max(0, root.offSeason + delta)
    else if (key === "custom") root.offCustom = Math.max(0, root.offCustom + delta)
  }

  property int off24: 0
  property int off72: 0
  property int offWeek: 0
  property int offMonth: 0
  property int offSeason: 0
  property int offCustom: 0

  function sumWindowDays(n, offset) {
    var today = new Date()
    today.setHours(12, 0, 0, 0)
    var end = Model.addDays(today, -offset * n)
    var start = Model.addDays(end, -(n - 1))
    return Model.sumEntries(root.entries, start, end)
  }

  function monthWindow(offset) {
    var ref = new Date()
    ref.setDate(1)
    ref.setMonth(ref.getMonth() - offset)
    var start = new Date(ref.getFullYear(), ref.getMonth(), 1, 12)
    var end = new Date(ref.getFullYear(), ref.getMonth() + 1, 0, 12)
    return { start: start, end: end }
  }

  function seasonWindow(offset) {
    var ref = new Date()
    ref.setMonth(ref.getMonth() - offset * 3)
    var start = Model.seasonStart(ref)
    var end = new Date(start.getTime())
    end.setMonth(end.getMonth() + 3)
    end.setDate(end.getDate() - 1)
    end.setHours(12, 0, 0, 0)
    return { start: start, end: end, name: Model.seasonName(start) }
  }

  readonly property int total24: sumWindowDays(1, off24)
  readonly property int total72: sumWindowDays(3, off72)
  readonly property int totalWeek: sumWindowDays(7, offWeek)
  readonly property int totalCustom: sumWindowDays(root.customDays, offCustom)

  readonly property var monthWin: monthWindow(offMonth)
  readonly property int totalMonth: Model.sumEntries(root.entries, monthWin.start, monthWin.end)

  readonly property var seasonWin: seasonWindow(offSeason)
  readonly property int totalSeason: Model.sumEntries(root.entries, seasonWin.start, seasonWin.end)

  function setEntry(key, tenths) {
    Store.setEntry(key, tenths)
  }

  function recentRainySlots() {
    var keys = Object.keys(root.entries).filter(function(k) { return (root.entries[k] || 0) > 0 })
    keys.sort()
    keys.reverse()
    var out = []
    for (var i = 0; i < 5; i++) {
      if (i < keys.length) out.push({ date: keys[i], amount: root.entries[keys[i]] })
      else out.push(null)
    }
    return out
  }

  function monthName(d) {
    var names = ["January", "February", "March", "April", "May", "June", "July",
                 "August", "September", "October", "November", "December"]
    return names[d.getMonth()]
  }

  // Daily total for the calendar: one decimal place, or "-" when that day has
  // no recorded rainfall.
  function dayAmount(key) {
    var v = root.entries[key]
    if (v === undefined || v === null) return "-"
    return Model.tenthsToInches(v)
  }

  // Date label for a single-day window: offset 0 is today, higher offsets step
  // backwards one day at a time.
  function dayLabel(offset) {
    var d = new Date()
    d.setHours(12, 0, 0, 0)
    d = Model.addDays(d, -offset)
    return root.monthName(d) + " " + d.getDate() + ", " + d.getFullYear()
  }

  function calendarCells() {
    var cells = []
    var first = new Date(root.viewYear, root.viewMonth, 1).getDay()
    var dim = new Date(root.viewYear, root.viewMonth + 1, 0).getDate()
    for (var i = 0; i < first; i++) cells.push(null)
    for (var d = 1; d <= dim; d++) cells.push(new Date(root.viewYear, root.viewMonth, d))
    while (cells.length < 42) cells.push(null)
    return cells
  }

  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()
  property string selectedHistoryDate: Model.dateKey(new Date())

  // ---------------------------------------------------------------- layout
  Item {
    id: inner
    anchors.fill: parent
    anchors.margins: root.contentPadding

    // The empty part of the header is the window's drag handle. Declared
    // before the row so the buttons stay clickable on top.
    MouseArea {
      id: dragArea
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: headerRow.height
      onPressed: root.moveRequested()
    }

    RowLayout {
      id: headerRow
      width: parent.width
      spacing: Theme.space(8)

      Text {
        textFormat: Text.PlainText
        text: "Rain Log"
        color: Theme.foreground
        font.family: Theme.font.family
        font.pixelSize: Theme.font.title
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
      }

      Button {
        text: "⚙"
        tooltipText: "Settings"
        Layout.alignment: Qt.AlignVCenter
        onClicked: {
          root.historyMode = false
          root.settingsMode = !root.settingsMode
        }
      }

      Item { Layout.fillWidth: true }

      Button {
        text: "Edit History"
        visible: !root.historyMode && !root.settingsMode
        // Sit the label flush with the content edge so the gap after it
        // matches the padding before the title.
        horizontalPadding: 0
        Layout.alignment: Qt.AlignVCenter
        onClicked: {
          root.settingsMode = false
          root.historyMode = true
        }
      }

      Button {
        text: "Back"
        visible: root.historyMode
        horizontalPadding: 0
        Layout.alignment: Qt.AlignVCenter
        onClicked: root.historyMode = false
      }

      Loader {
        id: trailingLoader
        visible: root.headerTrailing !== null
        sourceComponent: root.headerTrailing
        Layout.alignment: Qt.AlignVCenter
      }
    }

    Flickable {
      id: flick
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: headerRow.bottom
      anchors.topMargin: Theme.space(12)
      anchors.bottom: parent.bottom
      contentWidth: width
      contentHeight: contentColumn.implicitHeight + root.bottomPad
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: contentColumn
        width: flick.width
        spacing: Theme.space(12)

        // Main view ------------------------------------------------------
        Column {
          id: mainColumn
          visible: !root.historyMode && !root.settingsMode
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Theme.space(10)
          spacing: Theme.space(12)

          // Today's entry. Only today is editable here; older days are edited
          // from the calendar.
          RowLayout {
            id: todayRow
            width: parent.width
            spacing: Theme.space(8)

            Text {
              textFormat: Text.PlainText
              text: "Today (tenths of an inch)"
              color: Theme.foreground
              font.family: Theme.font.family
              font.pixelSize: Theme.font.bodySmall
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              elide: Text.ElideRight
            }

            TextField {
              id: todayField
              Layout.preferredWidth: Theme.space(90)
              Layout.alignment: Qt.AlignVCenter
              text: root.entries[root.todayKey()] !== undefined ? String(root.entries[root.todayKey()]) : ""
              placeholderText: "0"
              onEditingFinished: {
                var v = parseInt(text, 10)
                root.setEntry(root.todayKey(), isNaN(v) ? 0 : v)
              }
            }
          }

          // Rolling totals, each with its own backward/forward scroll.
          Column {
            id: totalsColumn
            width: parent.width
            spacing: Theme.space(6)

            Repeater {
              model: ["24", "72", "week", "month", "season", "custom"]

              delegate: RowLayout {
                id: totalRow
                width: totalsColumn.width
                spacing: Theme.space(6)

                readonly property string key: modelData
                readonly property int off: key === "24" ? root.off24
                  : key === "72" ? root.off72
                  : key === "week" ? root.offWeek
                  : key === "month" ? root.offMonth
                  : key === "season" ? root.offSeason
                  : root.offCustom
                readonly property int total: key === "24" ? root.total24
                  : key === "72" ? root.total72
                  : key === "week" ? root.totalWeek
                  : key === "month" ? root.totalMonth
                  : key === "season" ? root.totalSeason
                  : root.totalCustom
                readonly property string label: key === "24" ? "24 hours"
                  : key === "72" ? "72 hours"
                  : key === "week" ? "Week"
                  : key === "month" ? "Month"
                  : key === "season" ? "Season"
                  : "Custom (" + root.customDays + "d)"
                readonly property string windowName: {
                  if (key === "24") return root.dayLabel(root.off24)
                  if (key === "month") return root.monthName(root.monthWin.start) + " " + root.monthWin.start.getFullYear()
                  if (key === "season") return root.seasonWin.name + " " + root.seasonWin.start.getFullYear()
                  return ""
                }

                Button {
                  text: "◀"
                  tooltipText: "Earlier"
                  Layout.alignment: Qt.AlignVCenter
                  onClicked: root.adjustOffset(key, 1)
                }

                Column {
                  Layout.alignment: Qt.AlignVCenter
                  spacing: 0

                  // The custom interval keeps its own editor: the pencil (and
                  // the day field while it is open) sit immediately after the
                  // label they edit, not beside the total.
                  RowLayout {
                    spacing: Theme.space(2)

                    Text {
                      textFormat: Text.PlainText
                      text: totalRow.label
                      color: Theme.foreground
                      font.family: Theme.font.family
                      font.pixelSize: Theme.font.bodySmall
                      font.bold: true
                      Layout.alignment: Qt.AlignVCenter
                      elide: Text.ElideRight
                    }

                    Button {
                      text: "✎"
                      tooltipText: "Set custom range"
                      visible: totalRow.key === "custom"
                      horizontalPadding: Theme.space(2)
                      Layout.alignment: Qt.AlignVCenter
                      onClicked: root.editingCustom = !root.editingCustom
                    }

                    TextField {
                      id: customDaysField
                      visible: totalRow.key === "custom" && root.editingCustom
                      Layout.preferredWidth: Theme.space(70)
                      Layout.alignment: Qt.AlignVCenter
                      text: String(root.customDays)
                      placeholderText: "14"
                      onEditingFinished: {
                        var v = parseInt(text, 10)
                        if (!isNaN(v) && v > 0) Config.customDays = v
                        root.editingCustom = false
                      }
                    }
                  }

                  Text {
                    visible: text !== ""
                    textFormat: Text.PlainText
                    text: totalRow.windowName
                    color: Theme.foreground
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.caption
                  }
                }

                // Forward scroll stays with the interval it changes; the inch
                // reading has no controls beside it.
                Button {
                  text: "▶"
                  tooltipText: "Later"
                  enabled: off > 0
                  Layout.alignment: Qt.AlignVCenter
                  onClicked: root.adjustOffset(key, -1)
                }

                Item { Layout.fillWidth: true }

                Text {
                  textFormat: Text.PlainText
                  text: Model.tenthsToInches(total) + " in"
                  color: Theme.foreground
                  font.family: Theme.font.family
                  font.pixelSize: Theme.font.bodySmall
                  font.bold: true
                  // Match the inset the arrow glyphs get from their button
                  // padding on the left edge.
                  Layout.rightMargin: Theme.spacing.controlPaddingX + Theme.space(8)
                  Layout.alignment: Qt.AlignVCenter
                }
              }
            }
          }

          // Recent rainy days ---------------------------------------------
          Text {
            id: recentLabel
            textFormat: Text.PlainText
            text: "Recent rainy days"
            color: Theme.foreground
            font.family: Theme.font.family
            font.pixelSize: Theme.font.bodySmall
            font.bold: true
          }

          Column {
            id: recentColumn
            width: parent.width
            spacing: Theme.space(4)

            Repeater {
              model: root.recentRainySlots()

              delegate: RowLayout {
                width: recentColumn.width
                spacing: Theme.space(8)

                // Indent the rows under the "Recent rainy days" heading.
                Item { Layout.preferredWidth: Theme.space(12) }

                Text {
                  textFormat: Text.PlainText
                  text: modelData ? modelData.date : "--no data--"
                  color: Theme.foreground
                  font.family: Theme.font.family
                  font.pixelSize: Theme.font.caption
                  Layout.preferredWidth: Theme.space(120)
                  elide: Text.ElideRight
                }
                Text {
                  textFormat: Text.PlainText
                  text: modelData ? (Model.tenthsToInches(modelData.amount) + " in") : ""
                  color: Theme.foreground
                  font.family: Theme.font.family
                  font.pixelSize: Theme.font.caption
                  // Share the totals' value column: right-aligned with the same
                  // inset used by the interval totals above.
                  Layout.fillWidth: true
                  Layout.rightMargin: Theme.spacing.controlPaddingX + Theme.space(8)
                  horizontalAlignment: Text.AlignRight
                }
              }
            }
          }
        }

        // Settings view ---------------------------------------------------
        Column {
          id: settingsColumn
          visible: root.settingsMode
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Theme.space(10)
          spacing: Theme.space(10)

          Text {
            textFormat: Text.PlainText
            text: "Settings"
            color: Theme.foreground
            font.family: Theme.font.family
            font.pixelSize: Theme.font.bodySmall
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: "Data file path"
            color: Theme.foreground
            font.family: Theme.font.family
            font.pixelSize: Theme.font.caption
          }

          TextField {
            id: pathField
            width: parent.width
            text: root.dataPath
            onEditingFinished: {
              var p = text.trim()
              if (p !== "") Config.dataPath = p
            }
          }

          Loader {
            id: settingsExtraLoader
            width: parent.width
            visible: root.settingsExtra !== null
            sourceComponent: root.settingsExtra
          }

          Button {
            text: "Back"
            // Align the label with the "Settings" heading instead of being
            // inset by the button's own control padding.
            horizontalPadding: 0
            onClicked: root.settingsMode = false
          }
        }

        // History view ----------------------------------------------------
        Column {
          id: historyColumn
          visible: root.historyMode
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: 0
          spacing: Theme.space(8)

          RowLayout {
            id: historyHeader
            width: parent.width
            spacing: Theme.space(8)

            Button {
              text: "◀"
              tooltipText: "Previous month"
              Layout.alignment: Qt.AlignVCenter
              onClicked: {
                if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear -= 1 }
                else root.viewMonth -= 1
              }
            }
            Text {
              textFormat: Text.PlainText
              text: root.monthName(new Date(root.viewYear, root.viewMonth, 1)) + " " + root.viewYear
              color: Theme.foreground
              font.family: Theme.font.family
              font.pixelSize: Theme.font.bodySmall
              font.bold: true
              Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true }
            Button {
              text: "▶"
              tooltipText: "Next month"
              Layout.alignment: Qt.AlignVCenter
              onClicked: {
                if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear += 1 }
                else root.viewMonth += 1
              }
            }
          }

          Grid {
            id: calendarGrid
            columns: 7
            columnSpacing: Theme.space(4)
            rowSpacing: Theme.space(4)
            width: parent.width
            height: 6 * Theme.space(40) + 5 * Theme.space(4)

            Repeater {
              model: root.calendarCells()

              delegate: Rectangle {
                width: (calendarGrid.width - 6 * calendarGrid.columnSpacing) / 7
                height: Theme.space(40)
                color: modelData && Model.dateKey(modelData) === root.selectedHistoryDate ? Theme.accent : "transparent"
                border.color: Theme.popupsBorder
                border.width: 1
                radius: 4

                Column {
                  anchors.centerIn: parent
                  spacing: 0

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: modelData ? modelData.getDate() : ""
                    color: modelData ? Theme.foreground : "transparent"
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.caption
                  }

                  // Daily total: "n.n" formatted to one decimal, or "-" when
                  // nothing was recorded that day.
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: modelData ? root.dayAmount(Model.dateKey(modelData)) : ""
                    color: !modelData ? "transparent"
                      : (Model.dateKey(modelData) === root.selectedHistoryDate ? Theme.foreground : Theme.muted)
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.caption
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  enabled: modelData !== null
                  onClicked: {
                    if (modelData) root.selectedHistoryDate = Model.dateKey(modelData)
                  }
                }
              }
            }
          }

          RowLayout {
            id: historyInputRow
            width: parent.width
            spacing: Theme.space(8)

            Text {
              textFormat: Text.PlainText
              text: root.selectedHistoryDate
              color: Theme.foreground
              font.family: Theme.font.family
              font.pixelSize: Theme.font.bodySmall
              Layout.alignment: Qt.AlignVCenter
            }
            TextField {
              id: historyField
              Layout.preferredWidth: Theme.space(90)
              Layout.alignment: Qt.AlignVCenter
              text: root.entries[root.selectedHistoryDate] !== undefined ? String(root.entries[root.selectedHistoryDate]) : ""
              placeholderText: "0"
              onEditingFinished: {
                var v = parseInt(text, 10)
                root.setEntry(root.selectedHistoryDate, isNaN(v) ? 0 : v)
              }
            }
            Text {
              textFormat: Text.PlainText
              text: "(tenths)"
              color: Theme.foreground
              font.family: Theme.font.family
              font.pixelSize: Theme.font.caption
              Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true }
          }
        }
      }
    }
  }
}
