import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { createPoll } from "ags/time"
import { execAsync } from "ags/process"
import { createBinding } from "ags"
import Network from "gi://AstalNetwork"
import Battery from "gi://AstalBattery"
import Wp from "gi://AstalWp"
import { toggleExclusive } from "../lib/window_manager"
import { loc } from "../lib/i18n"
import { clock24h, themeMode, language } from "../lib/settings"

export default function Shelf(gdkmonitor: Gdk.Monitor) {
  const { BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

  // System services
  const network = Network.get_default()
  const battery = Battery.get_default()
  const wp = Wp.get_default()

  // Real-time time & date polls reacting to settings
  const timeStr = createPoll("", 1000, () => {
    const d = new Date()
    const is24 = clock24h()
    const hours = is24 ? String(d.getHours()).padStart(2, "0") : String(d.getHours() % 12 || 12)
    const minutes = String(d.getMinutes()).padStart(2, "0")
    const ampm = is24 ? "" : (d.getHours() >= 12 ? " PM" : " AM")
    return `${hours}:${minutes}${ampm}`
  })

  const dateStr = createPoll("", 10000, () => {
    const lang = language()
    const locale = lang === "vi" ? "vi-VN" : "en-US"
    return new Date().toLocaleDateString(locale, {
      weekday: "short",
      day: "numeric",
      month: "numeric",
    })
  })

  // Network reactive icon
  const wifiIcon = createBinding(network, "primary")((primary) => {
    if (primary === Network.Primary.WIFI && network.wifi) {
      return network.wifi.icon_name || "network-wireless-symbolic"
    }
    if (primary === Network.Primary.WIRED) {
      return "network-wired-symbolic"
    }
    return "network-wireless-offline-symbolic"
  })

  // Audio volume icon
  const volumeIcon = createBinding(wp.audio, "default_speaker")((speaker) => {
    if (!speaker || speaker.mute) return "audio-volume-muted-symbolic"
    const vol = speaker.volume
    if (vol <= 0.01) return "audio-volume-muted-symbolic"
    if (vol < 0.33) return "audio-volume-low-symbolic"
    if (vol < 0.66) return "audio-volume-medium-symbolic"
    return "audio-volume-high-symbolic"
  })

  // Battery icon & percentage
  const batteryPercent = createBinding(battery, "percentage")((pct) => `${Math.round(pct * 100)}%`)
  const batteryIcon = createBinding(battery, "icon_name")

  // Pinned Apps definitions
  const pinnedApps = [
    { name: "Terminal", icon: "org.gnome.Ptyxis", cmd: "ptyxis" },
    { name: "Browser", icon: "google-chrome", cmd: "google-chrome || chromium || firefox" },
    { name: "Files", icon: "org.gnome.Nautilus", cmd: "nautilus" },
    { name: "Amelia Settings", icon: "emblem-system-symbolic", cmd: "settings" },
  ]

  const handleAppClick = (cmd: string) => {
    if (cmd === "settings") {
      toggleExclusive("settings")
    } else {
      execAsync(cmd).catch(console.error)
    }
  }

  return (
    <window
      name={`shelf-${gdkmonitor.get_model() || "default"}`}
      class={themeMode((m) => `Shelf ${m === "light" ? "light-theme" : ""}`)}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={BOTTOM | LEFT | RIGHT}
      application={app}
    >
      <centerbox class="shelf-box">
        {/* Left: App Launcher button */}
        <box $type="start" halign={Gtk.Align.START} valign={Gtk.Align.CENTER}>
          <button
            class="shelf-launcher-btn"
            tooltipText={loc("launcherTooltip")}
            onClicked={() => toggleExclusive("launcher")}
            valign={Gtk.Align.CENTER}
          >
            <icon icon="view-app-grid-symbolic" class="launcher-icon" />
          </button>
        </box>

        {/* Center: Pinned application icons */}
        <box $type="center" halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
          {pinnedApps.map((appDef) => (
            <button
              class="shelf-app-item"
              tooltipText={appDef.name}
              onClicked={() => handleAppClick(appDef.cmd)}
              valign={Gtk.Align.CENTER}
            >
              <icon icon={appDef.icon} class="app-icon" />
            </button>
          ))}
        </box>

        {/* Right: ChromeOS Status Area Pills */}
        <box $type="end" halign={Gtk.Align.END} valign={Gtk.Align.CENTER}>
          {/* Status Tray Pill (Wi-Fi, Volume, Battery) */}
          <button
            class="shelf-pill"
            tooltipText={loc("quickSettingsTooltip")}
            onClicked={() => toggleExclusive("quicksettings")}
            valign={Gtk.Align.CENTER}
          >
            <box valign={Gtk.Align.CENTER}>
              <icon icon={wifiIcon} class="pill-icon" />
              <icon icon={volumeIcon} class="pill-icon" />
              <icon icon={batteryIcon} class="pill-icon" />
              <label label={batteryPercent} class="pill-label" />
            </box>
          </button>

          {/* Date & Time Pill */}
          <button
            class="shelf-pill"
            tooltipText={loc("calendarTooltip")}
            onClicked={() => toggleExclusive("calendar")}
            valign={Gtk.Align.CENTER}
          >
            <box valign={Gtk.Align.CENTER}>
              <label label={timeStr} class="pill-label" />
              <label label={dateStr} class="pill-sublabel" />
            </box>
          </button>
        </box>
      </centerbox>
    </window>
  )
}
