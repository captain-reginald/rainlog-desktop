import QtQuick

// Small-caps-style label that introduces a panel section.
Text {
  id: root

  property color foreground: Theme.foreground
  property string fontFamily: Theme.font.family
  property real fontSize: Theme.font.caption

  textFormat: Text.PlainText
  color: Qt.darker(foreground, 1.4)
  font.family: fontFamily
  font.pixelSize: fontSize
  font.bold: true

  // Reserve the glyph overshoot so a header at the top of a clipping list is
  // never beheaded by the clip.
  topPadding: Math.ceil(fontSize * 0.15)
}
