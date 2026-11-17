pragma Singleton
import QtQuick

// Host-agnostic design tokens.
//
// The desktop client feeds this from the installed Omarchy theme (colors.toml
// and shell.toml) when one exists, and otherwise it keeps the bundled defaults
// below. The plugin adapter feeds it from qs.Commons in the same shape, so both
// hosts draw the same UI from the same numbers.
//
// Naming mirrors what the shared UI needs; the derivations are ports of
// qs.Commons.Color and qs.Commons.Style so the result is pixel-identical.
QtObject {
  id: root

  // ------------------------------------------------------------- palette
  property color foreground: "#cacccc"
  property color background: "#101315"
  property color accent: "#cacccc"
  property color urgent: "#a55555"
  property color muted: "#707880"

  // Host-provided values ------------------------------------------------
  // "monospace" follows the fontconfig alias on Linux and the bundled Nerd
  // Font family on Windows.
  property string fontFamilyOverride: ""
  // Hyprland's decoration:rounding when available; 0 on other desktops.
  property int cornerRadius: 0
  property bool reduceMotion: false

  // Parsed theme state ---------------------------------------------------
  property var shellValues: ({})
  property var styleOverrides: ({})
  property var fontOverrides: ({})
  property var spacingOverrides: ({})
  property int fontBaseSize: 12
  property real spacingScale: 1.0
  property bool spacingScaleWithFont: true

  // ------------------------------------------------------------- loading
  function load(colorsRaw, shellRaw, userShellRaw) {
    var palette = parseColors(colorsRaw || "")
    foreground = palette.foreground
    background = palette.background
    accent = palette.accent
    urgent = palette.urgent
    muted = palette.muted

    var themeValues = parseShell(shellRaw || "")
    var userValues = parseShell(userShellRaw || "")
    var merged = {}
    for (var k in themeValues) merged[k] = themeValues[k]
    for (var u in userValues) merged[u] = userValues[u]

    applyShellValues(merged)
    shellValues = merged
  }

  function parseColors(raw) {
    var out = {
      foreground: "#cacccc",
      background: "#101315",
      accent: "#cacccc",
      urgent: "#a55555",
      muted: "#707880"
    }
    var lines = String(raw || "").split("\n")
    var foundAccent = false
    var foundMuted = false
    var loadedForeground = false
    var loadedBackground = false
    var color0 = ""
    var color4 = ""
    var color7 = ""
    var color8 = ""

    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (!match) continue
      var key = match[1]
      var value = match[2]
      if (key === "foreground") { out.foreground = value; loadedForeground = true }
      else if (key === "background") { out.background = value; loadedBackground = true }
      else if (key === "accent") { out.accent = value; foundAccent = true }
      else if (key === "muted") { out.muted = value; foundMuted = true }
      else if (key === "color0") color0 = value
      else if (key === "color4") color4 = value
      else if (key === "color7") color7 = value
      else if (key === "color8") color8 = value
      else if (key === "red" || key === "color1") out.urgent = value
    }

    if (!loadedBackground && color0.length > 0) out.background = color0
    if (!loadedForeground && color7.length > 0) out.foreground = color7
    if (!foundAccent && color4.length > 0) out.accent = color4
    if (!foundMuted) out.muted = color8.length > 0 ? color8 : out.foreground
    return out
  }

  // Same walker qs.Commons.Color uses: quoted strings, bare numbers, width
  // lists, and bare role names, with inline comments tolerated.
  function parseShell(raw) {
    var parsed = {}
    var text = String(raw || "")
    if (!text) return parsed

    var lines = text.split("\n")
    var section = ""
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].replace(/^\s+|\s+$/g, "")
      if (!line || line.charAt(0) === "#") continue
      var sectionMatch = line.match(/^\[([A-Za-z0-9_-]+)\]\s*(#.*)?$/)
      if (sectionMatch) { section = sectionMatch[1]; continue }
      var stringKv = line.match(/^([A-Za-z0-9_-]+)\s*=\s*["']([^"']+)["']\s*(#.*)?$/)
      var numKv = line.match(/^([A-Za-z0-9_-]+)\s*=\s*(-?\d+(?:\.\d+)?)\s*(#.*)?$/)
      var widthKv = line.match(/^([A-Za-z0-9_-]+)\s*=\s*(-?\d+(?:\.\d+)?(?:\s+-?\d+(?:\.\d+)?){1,3})\s*(#.*)?$/)
      var bareKv = line.match(/^([A-Za-z0-9_-]+)\s*=\s*([A-Za-z][A-Za-z0-9_-]*)\s*(#.*)?$/)
      var kv = stringKv || numKv || widthKv || bareKv
      if (!kv || !section) continue
      parsed[section + "." + kv[1]] = kv[2]
    }
    return parsed
  }

  function applyShellValues(values) {
    var fontOut = {}
    var styleOut = {}
    var spacingOut = {}
    var nextBase = 12
    var nextSpacingScale = 1.0
    var nextSpacingScaleWithFont = true

    for (var fullKey in values) {
      var dot = fullKey.indexOf(".")
      if (dot < 0) continue
      var section = fullKey.substr(0, dot)
      var key = fullKey.substr(dot + 1)
      var raw = values[fullKey]

      if (section === "font") {
        var size = parseInt(raw, 10)
        if (!isFinite(size)) continue
        if (key === "base-size") nextBase = size
        else fontOut[key] = size
      } else if (section === "spacing") {
        if (key === "scale-with-font") {
          nextSpacingScaleWithFont = boolToken(raw, nextSpacingScaleWithFont)
        } else {
          var value = parseFloat(raw)
          if (!isFinite(value)) continue
          if (key === "scale") nextSpacingScale = value
          else spacingOut[key] = value
        }
      } else if (section === "controls" || section === "style") {
        styleOut[key] = raw
      }
    }

    if (!isFinite(nextBase) || nextBase < 1) nextBase = 1
    if (!isFinite(nextSpacingScale) || nextSpacingScale < 0) nextSpacingScale = 1.0
    fontBaseSize = nextBase
    spacingScale = nextSpacingScale
    spacingScaleWithFont = nextSpacingScaleWithFont
    fontOverrides = fontOut
    spacingOverrides = spacingOut
    styleOverrides = styleOut
  }

  function boolToken(value, fallback) {
    if (value === undefined || value === null) return fallback
    var s = String(value).replace(/^\s+|\s+$/g, "").toLowerCase()
    if (s === "true" || s === "1" || s === "yes" || s === "on") return true
    if (s === "false" || s === "0" || s === "no" || s === "off") return false
    return fallback
  }

  // ------------------------------------------------------------- helpers
  function clamp(value, min, max) {
    var n = Number(value)
    if (!isFinite(n)) return min
    return Math.max(min, Math.min(max, n))
  }

  function clampAlpha(value) {
    return clamp(value, 0, 1)
  }

  function alpha(color, opacity) {
    var a = clampAlpha(opacity === undefined ? 1 : opacity)
    if (!color) return Qt.rgba(0, 0, 0, a)
    if (typeof color === "string") color = Qt.color(color)
    return Qt.rgba(color.r, color.g, color.b, a)
  }

  function toHex(color) {
    if (!color) return "#000000"
    if (typeof color === "string") return color
    var r = Math.round(clamp(color.r, 0, 1) * 255)
    var g = Math.round(clamp(color.g, 0, 1) * 255)
    var b = Math.round(clamp(color.b, 0, 1) * 255)
    function pad(n) { var h = n.toString(16); return h.length < 2 ? "0" + h : h }
    return "#" + pad(r) + pad(g) + pad(b)
  }

  function colorFromHex(value, fallback) {
    var s = String(value || "").replace(/^\s+|\s+$/g, "")
    var shortHex = s.match(/^#([0-9A-Fa-f]{3})$/)
    if (shortHex) {
      var sh = shortHex[1]
      return Qt.rgba(parseInt(sh.charAt(0) + sh.charAt(0), 16) / 255,
                     parseInt(sh.charAt(1) + sh.charAt(1), 16) / 255,
                     parseInt(sh.charAt(2) + sh.charAt(2), 16) / 255, 1)
    }
    var hex = s.match(/^#([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?$/)
    if (!hex) return fallback
    var h = hex[1]
    return Qt.rgba(parseInt(h.substr(0, 2), 16) / 255,
                   parseInt(h.substr(2, 2), 16) / 255,
                   parseInt(h.substr(4, 2), 16) / 255,
                   hex[2] ? parseInt(hex[2], 16) / 255 : 1)
  }

  // ------------------------------------------------------------- surfaces
  function pick(key, fallback) {
    var value = shellValues[key]
    return (typeof value === "string" && value.length > 0) ? value : fallback
  }

  function pickAlpha(key, fallback) {
    var value = shellValues[key]
    if (typeof value !== "string" || value.length === 0) return fallback
    var n = Number(value)
    return isFinite(n) ? clampAlpha(n) : fallback
  }

  function firstColorToken(value) {
    var parts = String(value || "").replace(/^\s+|\s+$/g, "").split(/\s+/)
    for (var i = 0; i < parts.length; i++) {
      if (!parts[i].match(/^-?\d+(?:\.\d+)?deg$/)) return parts[i]
    }
    return value
  }

  function flatColor(value, fallback) {
    if (value && typeof value === "object" && value.r !== undefined) return value
    var seen = Object.create(null)
    var token = firstColorToken(value)
    var role = String(token || "").replace(/^\s+|\s+$/g, "").toLowerCase()
    while (shellValues[role] && shellValues[role] !== token) {
      if (seen[role]) return fallback
      seen[role] = true
      token = firstColorToken(shellValues[role])
      role = String(token || "").replace(/^\s+|\s+$/g, "").toLowerCase()
    }
    if (role === "foreground" || role === "text") return foreground
    if (role === "accent") return accent
    if (role === "urgent") return urgent
    if (role === "muted") return muted
    if (role === "background") return background
    if (role === "transparent") return Qt.rgba(0, 0, 0, 0)

    var color = colorFromHex(token, token)
    if (typeof color === "string" && color === token && token.charAt(0) !== "#") return fallback
    return color
  }

  function composed(colorKey, alphaKey, colorFallback, alphaFallback) {
    var base = pick(colorKey, toHex(colorFallback))
    return alpha(flatColor(base, colorFallback), pickAlpha(alphaKey, alphaFallback))
  }

  readonly property color popupsBackground: composed("popups.background", "popups.background-alpha", background, 1.0)
  readonly property color popupsText: composed("popups.text", "popups.text-alpha", foreground, 1.0)
  readonly property color popupsBorder: composed("popups.border", "popups.border-alpha", accent, 1.0)
  readonly property color tooltipBackground: composed("tooltip.background", "tooltip.background-alpha", background, 0.97)
  readonly property color tooltipText: composed("tooltip.text", "tooltip.text-alpha", foreground, 1.0)
  readonly property color tooltipBorder: composed("tooltip.border", "tooltip.border-alpha", foreground, 1.0)

  // ------------------------------------------------------- state tokens
  function styleRawNum(key) {
    var value = styleOverrides[key]
    var n = Number(value)
    return isFinite(n) ? n : null
  }

  function styleNum(key, fallback) {
    var n = styleRawNum(key)
    return n === null ? fallback : n
  }

  function styleAlpha(key, fallback) {
    return clampAlpha(styleNum(key, fallback))
  }

  function styleString(key, fallback) {
    var value = styleOverrides[key]
    if (typeof value !== "string") return fallback
    var trimmed = value.replace(/^\s+|\s+$/g, "")
    return trimmed.length > 0 ? trimmed : fallback
  }

  readonly property string normalColorToken: styleString("normal-color", "foreground")
  readonly property string hoverColorToken: styleString("hover-cursor-color", "foreground")
  readonly property string selectedColorToken: styleString("selected-color", "foreground")
  readonly property string pressedColorToken: styleString("pressed-color", hoverColorToken)
  readonly property string focusColorToken: styleString("focus-color", hoverColorToken)
  readonly property string selectionColorToken: styleString("selection-color", "foreground")

  readonly property int normalBorderWidth: Math.max(0, Math.round(styleNum("normal-border-width", 1)))
  readonly property int hoverBorderWidth: Math.max(0, Math.round(styleNum("hover-cursor-border-width", normalBorderWidth)))
  readonly property int selectedBorderWidth: Math.max(0, Math.round(styleNum("selected-border-width", 0)))
  readonly property int focusBorderWidth: Math.max(0, Math.round(styleNum("focus-border-width", hoverBorderWidth)))

  readonly property real normalFillAlpha: styleAlpha("normal-fill-alpha", 0.04)
  readonly property real hoverFillAlpha: styleAlpha("hover-cursor-fill-alpha", 0.08)
  readonly property real selectedFillAlpha: styleAlpha("selected-fill-alpha", 0.18)
  readonly property real pressedFillAlpha: styleAlpha("pressed-fill-alpha", 0.22)
  readonly property real focusFillAlpha: styleAlpha("focus-fill-alpha", hoverFillAlpha)
  readonly property real selectionFillAlpha: styleAlpha("selection-fill-alpha", 0.35)

  readonly property real normalBorderAlpha: styleAlpha("normal-border-alpha", 0.4)
  readonly property real hoverBorderAlpha: styleAlpha("hover-cursor-border-alpha", 0.25)
  readonly property real selectedBorderAlpha: styleAlpha("selected-border-alpha", 1.0)
  readonly property real focusBorderAlpha: styleAlpha("focus-border-alpha", hoverBorderAlpha)

  function resolveStateColor(token, fg, acc, urg, fallback) {
    var base = fallback || fg || foreground
    var s = String(token || "").replace(/^\s+|\s+$/g, "")
    var role = s.toLowerCase()
    if (role === "foreground" || role === "text") return fg || foreground
    if (role === "accent") return acc || accent
    if (role === "urgent") return urg || urgent
    if (role === "background") return background
    if (role === "transparent") return Qt.rgba(0, 0, 0, 0)
    return colorFromHex(s, base)
  }

  function normalStateColor(fg, acc, urg) {
    return resolveStateColor(normalColorToken, fg, acc, urg, fg || foreground)
  }

  function hoverStateColor(fg, acc, urg) {
    return resolveStateColor(hoverColorToken, fg, acc, urg, fg || foreground)
  }

  function selectedStateColor(fg, acc, urg) {
    return resolveStateColor(selectedColorToken, fg, acc, urg, fg || foreground)
  }

  function pressedStateColor(fg, acc, urg) {
    return resolveStateColor(pressedColorToken, fg, acc, urg, hoverStateColor(fg, acc, urg))
  }

  function focusStateColor(fg, acc, urg) {
    var role = String(focusColorToken || "").replace(/^\s+|\s+$/g, "").toLowerCase()
    if (role === "hover" || role === "hover-cursor" || role === "inherit")
      return hoverStateColor(fg, acc, urg)
    return resolveStateColor(focusColorToken, fg, acc, urg, hoverStateColor(fg, acc, urg))
  }

  function selectionStateColor(fg, acc, urg) {
    return resolveStateColor(selectionColorToken, fg, acc, urg, fg || foreground)
  }

  function normalFillFor(fg, acc, urg) { return alpha(normalStateColor(fg, acc, urg), normalFillAlpha) }
  function hoverFillFor(fg, acc, urg) { return alpha(hoverStateColor(fg, acc, urg), hoverFillAlpha) }
  function selectedFillFor(fg, acc, urg) { return alpha(selectedStateColor(fg, acc, urg), selectedFillAlpha) }
  function pressedFillFor(fg, acc, urg) { return alpha(pressedStateColor(fg, acc, urg), pressedFillAlpha) }
  function focusFillFor(fg, acc, urg) { return alpha(focusStateColor(fg, acc, urg), focusFillAlpha) }
  function selectionFillFor(fg, acc, urg) { return alpha(selectionStateColor(fg, acc, urg), selectionFillAlpha) }

  function normalBorderFor(fg, acc, urg) { return alpha(normalStateColor(fg, acc, urg), normalBorderAlpha) }
  function hoverBorderFor(fg, acc, urg) { return alpha(hoverStateColor(fg, acc, urg), hoverBorderAlpha) }
  function selectedBorderFor(fg, acc, urg) { return alpha(selectedStateColor(fg, acc, urg), selectedBorderAlpha) }
  function focusBorderFor(fg, acc, urg) { return alpha(focusStateColor(fg, acc, urg), focusBorderAlpha) }

  function controlFill(focused, hot, fg, acc) {
    if (focused) return focusFillFor(fg, acc)
    if (hot) return hoverFillFor(fg, acc)
    return normalFillFor(fg, acc)
  }

  function controlBorder(focused, hot, fg, acc) {
    if (focused) return focusBorderFor(fg, acc)
    if (hot) return hoverBorderFor(fg, acc)
    return normalBorderFor(fg, acc)
  }

  function controlBorderWidth(focused, hot) {
    if (focused) return focusBorderWidth
    if (hot) return hoverBorderWidth
    return normalBorderWidth
  }

  readonly property color selectionFill: selectionFillFor(foreground, accent, urgent)

  // ------------------------------------------------------------- spacing
  readonly property real fontScale: Math.max(1 / 12, fontBaseSize / 12)
  readonly property real effectiveSpacingScale: spacingScale * (spacingScaleWithFont ? fontScale : 1)

  function spaceReal(px) {
    var n = Number(px)
    if (!isFinite(n) || n <= 0) return 0
    return n * effectiveSpacingScale
  }

  function space(px) {
    var n = spaceReal(px)
    if (n <= 0) return 0
    return Math.max(1, Math.round(n))
  }

  function spacingToken(key, fallback) {
    var value = spacingOverrides[key]
    var n = Number(value)
    return (isFinite(n) && n >= 0) ? Math.round(n) : space(fallback)
  }

  readonly property QtObject spacing: QtObject {
    readonly property real scale: root.effectiveSpacingScale

    readonly property int hairline: root.space(1)
    readonly property int xxs: root.spacingToken("xxs", 2)
    readonly property int xs: root.spacingToken("xs", 3)
    readonly property int sm: root.spacingToken("sm", 4)
    readonly property int md: root.spacingToken("md", 6)
    readonly property int lg: root.spacingToken("lg", 8)
    readonly property int xl: root.spacingToken("xl", 10)
    readonly property int xxl: root.spacingToken("xxl", 12)
    readonly property int xxxl: root.spacingToken("xxxl", 14)
    readonly property int huge: root.spacingToken("huge", 18)

    readonly property int controlGap: root.spacingToken("control-gap", 8)
    readonly property int controlPaddingX: root.spacingToken("control-padding-x", 10)
    readonly property int controlPaddingY: root.spacingToken("control-padding-y", 6)
    readonly property int inputPaddingY: root.spacingToken("input-padding-y", 7)
    readonly property int controlHeight: root.spacingToken("control-height", 28)
    readonly property int popupRowHeight: root.spacingToken("popup-row-height", 28)
    readonly property int dropdownWidth: root.spacingToken("dropdown-width", 240)
    readonly property int rowGap: root.spacingToken("row-gap", 8)
    readonly property int rowPaddingX: root.spacingToken("row-padding-x", 12)
    readonly property int labelGap: root.spacingToken("label-gap", 4)
    readonly property int panelGap: root.spacingToken("panel-gap", 14)
    readonly property int panelPadding: root.spacingToken("panel-padding", 18)
    readonly property int popupPadding: root.spacingToken("popup-padding", 14)
  }

  // ---------------------------------------------------------- typography
  readonly property string fontFamily: fontFamilyOverride.length > 0 ? fontFamilyOverride : "monospace"

  function fontPx(mult) {
    return Math.max(1, Math.round(fontBaseSize * mult))
  }

  function fontToken(key, fallback) {
    var value = fontOverrides[key]
    var n = Number(value)
    return (isFinite(n) && n > 0) ? Math.round(n) : fallback
  }

  readonly property QtObject font: QtObject {
    readonly property string family: root.fontFamily
    readonly property int baseSize: root.fontBaseSize

    readonly property int caption: root.fontToken("caption", root.fontPx(0.833))
    readonly property int bodySmall: root.fontToken("body-small", root.fontPx(0.917))
    readonly property int body: root.fontToken("body", root.fontPx(1.0))
    readonly property int subtitle: root.fontToken("subtitle", root.fontPx(1.083))
    readonly property int title: root.fontToken("title", root.fontPx(1.167))
    readonly property int heading: root.fontToken("heading", root.fontPx(1.333))
    readonly property int display: root.fontToken("display", root.fontPx(2.0))
    readonly property int displayLarge: root.fontToken("display-large", root.fontPx(2.333))

    readonly property int iconSmall: root.fontToken("icon-small", bodySmall)
    readonly property int icon: root.fontToken("icon", title)
    readonly property int iconLarge: root.fontToken("icon-large", root.fontPx(1.5))
  }

  function duration(ms) {
    return reduceMotion ? 0 : ms
  }

  readonly property var easeOut: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]
}
