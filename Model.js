function clampPercent(n) {
  n = Number(n)
  if (!isFinite(n)) return 0
  return Math.max(0, Math.min(100, Math.round(n)))
}

function clampInt(n, min, max, fallback) {
  n = Number(n)
  if (!isFinite(n)) return fallback
  n = Math.round(n)
  if (n < min) return min
  if (n > max) return max
  return n
}

function conserveEndFromSettings(settings) {
  return clampInt(settings && settings.conserveEnd, 50, 95, 80)
}

function conserveStart(end) {
  end = clampPercent(end)
  return Math.max(0, end - 5)
}

function fullStart(end) {
  return conserveStart(end)
}

function modeFromEnd(end, conserveEnd) {
  return clampPercent(end) >= 99 ? "full" : "conserve"
}

function capLabel(mode, conserveEnd) {
  return mode === "full" ? "100" : String(conserveEndFromSettings({ conserveEnd: conserveEnd }))
}

function parseStatus(raw) {
  var empty = {
    supported: false,
    writable: false,
    ac: false,
    capacity: 0,
    start: 0,
    end: 0,
    mode: "unknown",
    battery: "",
    error: ""
  }
  var text = String(raw || "").trim()
  if (!text) return empty
  try {
    var data = JSON.parse(text)
    return {
      supported: !!data.supported,
      writable: !!data.writable,
      ac: !!data.ac,
      capacity: clampPercent(data.capacity),
      start: clampPercent(data.start),
      end: clampPercent(data.end),
      mode: data.mode === "full" ? "full" : (data.mode === "conserve" ? "conserve" : "unknown"),
      battery: String(data.battery || ""),
      error: String(data.error || "")
    }
  } catch (e) {
    empty.error = "invalid-json"
    return empty
  }
}

function shouldPrompt(opts) {
  opts = opts || {}
  if (!opts.supported) return false
  if (!opts.promptOnConnect) return false
  if (opts.onBattery) return false
  if (!opts.wasOnBattery) return false
  if (opts.sessionPrompted) return false
  if (opts.mode === "full") return false
  return true
}

function defaultTimeoutMs(settings) {
  return clampInt(settings && settings.promptTimeoutSec, 5, 120, 20) * 1000
}

function pluginFilePath(resolvedUrl) {
  var s = String(resolvedUrl || "")
  if (s.indexOf("file://") === 0) s = s.substring(7)
  if (s.charAt(s.length - 1) === "/") s = s.substring(0, s.length - 1)
  return s
}

function settingsFromConfig(config, pluginId) {
  var found = {}
  function consider(entry) {
    if (!entry || String(entry.id || "") !== String(pluginId || "")) return
    var next = {}
    var key
    for (key in found) next[key] = found[key]
    for (key in entry) {
      if (entry[key] !== undefined) next[key] = entry[key]
    }
    found = next
  }
  if (config && config.bar && config.bar.layout) {
    var sections = ["left", "center", "right"]
    for (var i = 0; i < sections.length; i++) {
      var list = config.bar.layout[sections[i]] || []
      for (var j = 0; j < list.length; j++) consider(list[j])
    }
  }
  var plugins = config && config.plugins ? config.plugins : []
  for (var k = 0; k < plugins.length; k++) consider(plugins[k])
  return found
}

if (typeof module !== "undefined") {
  module.exports = {
    clampPercent: clampPercent,
    clampInt: clampInt,
    conserveEndFromSettings: conserveEndFromSettings,
    conserveStart: conserveStart,
    fullStart: fullStart,
    modeFromEnd: modeFromEnd,
    capLabel: capLabel,
    parseStatus: parseStatus,
    shouldPrompt: shouldPrompt,
    defaultTimeoutMs: defaultTimeoutMs,
    pluginFilePath: pluginFilePath,
    settingsFromConfig: settingsFromConfig
  }
}
