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

var MAX_HELPER_CHARS = 4096
var MAX_LABEL_CHARS = 80
var MAX_NAME_CHARS = 32
var MAX_PROFILES = 8

function plain(value, max) {
  var limit = max === undefined ? MAX_LABEL_CHARS : max
  var s = String(value === undefined || value === null ? "" : value)
  s = s.replace(/[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069]/g, "")
  s = s.replace(/[<>&]/g, "")
  if (s.length > limit) s = s.substring(0, limit)
  return s
}

function sanitizeName(value) {
  var s = plain(value, MAX_NAME_CHARS)
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$/.test(s)) return ""
  if (s === "." || s === "..") return ""
  return s
}

function sanitizeProfileName(value) {
  var s = plain(value, MAX_NAME_CHARS)
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(s)) return ""
  return s
}

function isProfileName(name) {
  return name !== "" && sanitizeProfileName(name) === name
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

function promptOnConnectFromSettings(settings) {
  if (!settings || settings.promptOnConnect === undefined || settings.promptOnConnect === null)
    return true
  return settings.promptOnConnect !== false && settings.promptOnConnect !== "false"
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
  var text = String(raw || "")
  if (text.length > MAX_HELPER_CHARS) {
    empty.error = "invalid-json"
    return empty
  }
  text = text.trim()
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
      battery: sanitizeName(data.battery),
      error: plain(data.error, MAX_LABEL_CHARS)
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

function parseProfiles(raw) {
  var text = String(raw || "")
  if (text.length > MAX_HELPER_CHARS) return { profiles: [], active: "" }
  var lines = text.split("\n")
  var list = []
  var active = ""
  for (var i = 0; i < lines.length; i++) {
    if (list.length >= MAX_PROFILES) break
    var line = String(lines[i] || "").trim()
    if (!line) continue
    var parts = line.split("\t")
    var name = sanitizeProfileName(parts[0])
    if (!name) continue
    list.push(name)
    if (String(parts[1] || "").trim() === "1") active = name
  }
  return { profiles: list, active: active }
}

function profileTitle(name) {
  if (name === "power-saver") return "Power saver"
  if (name === "balanced") return "Balanced"
  if (name === "performance") return "Performance"
  return plain(name, MAX_NAME_CHARS)
}

function profileIcon(name) {
  if (name === "power-saver") return "󰌪"
  if (name === "balanced") return "󰊚"
  if (name === "performance") return "󰓅"
  return "󰂄"
}

function profileIndex(profiles, active) {
  var list = Array.isArray(profiles) ? profiles : []
  var idx = list.indexOf(active)
  if (idx >= 0) return idx
  return 0
}

function profileAt(profiles, index) {
  var list = Array.isArray(profiles) ? profiles : []
  if (index < 0 || index >= list.length) return ""
  return list[index]
}

if (typeof module !== "undefined") {
  module.exports = {
    MAX_HELPER_CHARS: MAX_HELPER_CHARS,
    clampPercent: clampPercent,
    clampInt: clampInt,
    plain: plain,
    sanitizeName: sanitizeName,
    sanitizeProfileName: sanitizeProfileName,
    isProfileName: isProfileName,
    conserveEndFromSettings: conserveEndFromSettings,
    conserveStart: conserveStart,
    fullStart: fullStart,
    modeFromEnd: modeFromEnd,
    capLabel: capLabel,
    promptOnConnectFromSettings: promptOnConnectFromSettings,
    parseStatus: parseStatus,
    shouldPrompt: shouldPrompt,
    defaultTimeoutMs: defaultTimeoutMs,
    pluginFilePath: pluginFilePath,
    settingsFromConfig: settingsFromConfig,
    parseProfiles: parseProfiles,
    profileTitle: profileTitle,
    profileIcon: profileIcon,
    profileIndex: profileIndex,
    profileAt: profileAt
  }
}
