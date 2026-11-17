.pragma library

function pad(n) { return (n < 10 ? "0" : "") + n }

function dateKey(d) {
  return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
}

function parseDateKey(key) {
  var parts = String(key).split("-")
  if (parts.length !== 3) return null
  var y = parseInt(parts[0], 10)
  var m = parseInt(parts[1], 10) - 1
  var d = parseInt(parts[2], 10)
  if (isNaN(y) || isNaN(m) || isNaN(d)) return null
  return new Date(y, m, d, 12)
}

function addDays(d, n) {
  var r = new Date(d.getTime())
  r.setDate(r.getDate() + n)
  return r
}

function daysBetween(a, b) {
  // a, b Date; returns integer days b - a
  var ms = b.getTime() - a.getTime()
  return Math.round(ms / (24 * 60 * 60 * 1000))
}

function seasonStart(d) {
  var y = d.getFullYear()
  var m = d.getMonth() // 0-based
  // Meteorological seasons
  if (m >= 11 || m <= 1) {
    // winter: Dec 1 (if Dec, same year; if Jan/Feb, previous year Dec 1)
    if (m <= 1) y = y - 1
    return new Date(y, 11, 1)
  }
  if (m >= 2 && m <= 4) return new Date(y, 2, 1)  // spring Mar 1
  if (m >= 5 && m <= 7) return new Date(y, 5, 1)  // summer Jun 1
  return new Date(y, 8, 1) // autumn Sep 1
}

function seasonName(d) {
  var m = d.getMonth()
  if (m >= 11 || m <= 1) return "Winter"
  if (m >= 2 && m <= 4) return "Spring"
  if (m >= 5 && m <= 7) return "Summer"
  return "Autumn"
}

function sumEntries(entries, startDate, endDate) {
  if (!entries) return 0
  var total = 0
  var cursor = new Date(startDate.getTime())
  // normalize to noon
  cursor.setHours(12,0,0,0)
  var end = new Date(endDate.getTime())
  end.setHours(12,0,0,0)
  while (cursor.getTime() <= end.getTime()) {
    var key = dateKey(cursor)
    if (entries[key] !== undefined && entries[key] !== null) {
      var v = parseInt(entries[key], 10)
      if (!isNaN(v)) total += v
    }
    cursor = addDays(cursor, 1)
  }
  return total
}

function tenthsToInches(tenths) {
  var v = (tenths || 0) / 10
  return v.toFixed(1)
}

function recentDays(n) {
  var out = []
  var today = new Date()
  today.setHours(12,0,0,0)
  for (var i = n - 1; i >= 0; i--) {
    var d = addDays(today, -i)
    out.push(dateKey(d))
  }
  return out
}