import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { createPoll } from "ags/time"
import { execAsync } from "ags/process"
import { createBinding } from "ags"
import Network from "gi://AstalNetwork"
import Battery from "gi://AstalBattery"
import Wp from "gi://AstalWp"

export default function Shelf(gdkmonitor: Gdk.Monitor) {
  const { BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

  // System services
  const network = Network.get_default()
  const battery = Battery.get_default()
  const wp = Wp.get_default()

  // Real-time time & date polls
  const timeStr = createPoll("", 1000, "date +'%H:%M'")
  const dateStr = createPoll("", 60000, "date +'%a, %d/%m'")

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
    { name: "Settings", icon: "org.gnome.Settings", cmd: "gnome-control-center" },
  ]

  return (
    <window
      name={`shelf-${gdkmonitor.get_model() || "default"}`}
      class="Shelf"
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
            tooltipText="Launcher"
            onClicked={() => app.toggle_window("launcher")}
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
              onClicked={() => execAsync(appDef.cmd).catch(console.error)}
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
            tooltipText="Quick Settings"
            onClicked={() => app.toggle_window("quicksettings")}
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
            tooltipText="Calendar & Notifications"
            onClicked={() => app.toggle_window("calendar")}
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
