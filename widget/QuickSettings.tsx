import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { createBinding, createState, With } from "ags"
import { execAsync } from "ags/process"
import { createPoll } from "ags/time"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Wp from "gi://AstalWp"
import Notifd from "gi://AstalNotifd"
import Mpris from "gi://AstalMpris"

export default function QuickSettings() {
  const { BOTTOM, RIGHT } = Astal.WindowAnchor

  // System daemons
  const network = Network.get_default()
  const bluetooth = Bluetooth.get_default()
  const wp = Wp.get_default()
  const notifd = Notifd.get_default()
  const mpris = Mpris.get_default()

  // Brightness state (polled via brightnessctl)
  const [brightness, setBrightness] = createState(0.8)
  execAsync("brightnessctl get && brightnessctl max")
    .then((out) => {
      const parts = out.trim().split("\n")
      if (parts.length >= 2) {
        const cur = parseFloat(parts[0])
        const max = parseFloat(parts[1])
        if (max > 0) setBrightness(cur / max)
      }
    })
    .catch(() => {})

  const handleBrightnessChange = (val: number) => {
    setBrightness(val)
    const pct = Math.round(val * 100)
    execAsync(`brightnessctl set ${pct}%`).catch(() => {})
  }

  // Volume bindings
  const speaker = wp.audio.default_speaker
  const volumeVal = speaker ? createBinding(speaker, "volume") : 0.5
  const isMuted = speaker ? createBinding(speaker, "mute") : false

  const handleVolumeChange = (val: number) => {
    if (speaker) {
      speaker.volume = val
      if (val > 0 && speaker.mute) speaker.mute = false
    } else {
      execAsync(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${val}`).catch(() => {})
    }
  }

  // Dark mode state
  const [darkMode, setDarkMode] = createState(true)
  const toggleDarkMode = () => {
    const next = !darkMode()
    setDarkMode(next)
    const scheme = next ? "prefer-dark" : "prefer-light"
    execAsync(`gsettings set org.gnome.desktop.interface color-scheme '${scheme}'`).catch(() => {})
  }

  // Wi-Fi toggle
  const wifiActive = createBinding(network, "primary")((p) => p === Network.Primary.WIFI)
  const wifiSsid = createBinding(network, "wifi")((w) => w?.ssid || "Disconnected")
  const toggleWifi = () => {
    if (network.wifi) {
      network.wifi.enabled = !network.wifi.enabled
    } else {
      execAsync("nmcli radio wifi toggle").catch(() => {})
    }
  }

  // Bluetooth toggle
  const btPowered = createBinding(bluetooth, "is_powered")
  const btDevicesCount = createBinding(bluetooth, "devices")((devs) => devs.length)
  const toggleBluetooth = () => {
    bluetooth.toggle()
  }

  // DND toggle
  const dndActive = createBinding(notifd, "dont_disturb")
  const toggleDnd = () => {
    notifd.dont_disturb = !notifd.dont_disturb
  }

  // Trigger screenshot directly from Quick Settings:
  // Dismisses Quick Settings and opens the floating ScreenCapture pill immediately
  const triggerScreenCapture = () => {
    app.toggle_window("quicksettings")
    // Short timeout to let QS dismiss smoothly before opening the capture pill
    setTimeout(() => {
      const win = app.get_window("screencapture")
      if (win) win.visible = true
      else app.toggle_window("screencapture")
    }, 150)
  }

  // Active MPRIS player
  const activePlayer = createBinding(mpris, "players")((players) => (players.length > 0 ? players[0] : null))

  return (
    <window
      name="quicksettings"
      class="QuickSettingsWindow"
      anchor={BOTTOM | RIGHT}
      exclusivity={Astal.Exclusivity.NONE}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.ON_DEMAND}
      marginBottom={68}
      marginRight={12}
      visible={false}
      application={app}
    >
      <box class="quicksettings-card" vertical>
        {/* Header: User avatar, Lock, Settings, Power */}
        <centerbox class="qs-header">
          <box $type="start" class="qs-user-pill" valign={Gtk.Align.CENTER}>
            <icon icon="avatar-default-symbolic" class="qs-user-avatar" />
            <label label="limorina" class="qs-user-name" />
          </box>

          <box $type="center" />

          <box $type="end" halign={Gtk.Align.END} valign={Gtk.Align.CENTER}>
            <button
              class="qs-icon-btn"
              tooltipText="Lock Screen"
              onClicked={() => execAsync("loginctl lock-session").catch(console.error)}
            >
              <icon icon="system-lock-screen-symbolic" class="btn-icon" />
            </button>
            <button
              class="qs-icon-btn"
              tooltipText="Settings"
              onClicked={() => execAsync("gnome-control-center").catch(console.error)}
            >
              <icon icon="emblem-system-symbolic" class="btn-icon" />
            </button>
            <button
              class="qs-icon-btn"
              tooltipText="Power Off"
              onClicked={() => execAsync("systemctl poweroff").catch(console.error)}
            >
              <icon icon="system-shutdown-symbolic" class="btn-icon" />
            </button>
            <button
              class="qs-icon-btn"
              tooltipText="Collapse"
              onClicked={() => app.toggle_window("quicksettings")}
            >
              <icon icon="go-down-symbolic" class="btn-icon" />
            </button>
          </box>
        </centerbox>

        {/* Feature Pods: 3 columns x 2 rows (Authentic ChromeOS Material Design 3) */}
        <box class="qs-pods-grid" vertical spacing={8}>
          {/* Row 1: Wi-Fi, Bluetooth, DND */}
          <box spacing={8} homogeneous>
            {/* Wi-Fi Pod */}
            <button
              class={wifiActive((act) => `qs-pod ${act ? "active" : ""}`)}
              onClicked={toggleWifi}
            >
              <box valign={Gtk.Align.CENTER}>
                <icon icon="network-wireless-symbolic" class="pod-icon" />
                <box vertical valign={Gtk.Align.CENTER} hexpand>
                  <label label="Wi-Fi" class="pod-title" xalign={0} />
                  <label label={wifiSsid} class="pod-subtitle" xalign={0} maxWidthChars={10} ellipsize={3} />
                </box>
              </box>
            </button>

            {/* Bluetooth Pod */}
            <button
              class={btPowered((act) => `qs-pod ${act ? "active" : ""}`)}
              onClicked={toggleBluetooth}
            >
              <box valign={Gtk.Align.CENTER}>
                <icon icon="bluetooth-active-symbolic" class="pod-icon" />
                <box vertical valign={Gtk.Align.CENTER} hexpand>
                  <label label="Bluetooth" class="pod-title" xalign={0} />
                  <label
                    label={btPowered((act) => (act ? "Enabled" : "Off"))}
                    class="pod-subtitle"
                    xalign={0}
                  />
                </box>
              </box>
            </button>

            {/* Notifications / DND Pod */}
            <button
              class={dndActive((act) => `qs-pod ${act ? "active" : ""}`)}
              onClicked={toggleDnd}
            >
              <box valign={Gtk.Align.CENTER}>
                <icon icon="notifications-disabled-symbolic" class="pod-icon" />
                <box vertical valign={Gtk.Align.CENTER} hexpand>
                  <label label="Do Not Disturb" class="pod-title" xalign={0} />
                  <label
                    label={dndActive((act) => (act ? "Silent" : "Off"))}
                    class="pod-subtitle"
                    xalign={0}
                  />
                </box>
              </box>
            </button>
          </box>

          {/* Row 2: Screen Capture, Dark Theme, Audio Output */}
          <box spacing={8} homogeneous>
            {/* Screen Capture Pod */}
            <button
              class="qs-pod"
              tooltipText="Launch Screenshot Tool"
              onClicked={triggerScreenCapture}
            >
              <box valign={Gtk.Align.CENTER}>
                <icon icon="camera-photo-symbolic" class="pod-icon" />
                <box vertical valign={Gtk.Align.CENTER} hexpand>
                  <label label="Screen Capture" class="pod-title" xalign={0} />
                  <label label="Snipping tool" class="pod-subtitle" xalign={0} />
                </box>
              </box>
            </button>

            {/* Dark Theme Pod */}
            <button
              class={darkMode((act) => `qs-pod ${act ? "active" : ""}`)}
              onClicked={toggleDarkMode}
            >
              <box valign={Gtk.Align.CENTER}>
                <icon icon="weather-clear-night-symbolic" class="pod-icon" />
                <box vertical valign={Gtk.Align.CENTER} hexpand>
                  <label label="Dark Theme" class="pod-title" xalign={0} />
                  <label
                    label={darkMode((act) => (act ? "On" : "Off"))}
                    class="pod-subtitle"
                    xalign={0}
                  />
                </box>
              </box>
            </button>

            {/* Audio Output Pod */}
            <button
              class={isMuted((m) => `qs-pod ${!m ? "active" : ""}`)}
              onClicked={() => {
                if (speaker) speaker.mute = !speaker.mute
                else execAsync("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle").catch(() => {})
              }}
            >
              <box valign={Gtk.Align.CENTER}>
                <icon icon="audio-volume-high-symbolic" class="pod-icon" />
                <box vertical valign={Gtk.Align.CENTER} hexpand>
                  <label label="Audio" class="pod-title" xalign={0} />
                  <label
                    label={isMuted((m) => (m ? "Muted" : "Active"))}
                    class="pod-subtitle"
                    xalign={0}
                  />
                </box>
              </box>
            </button>
          </box>
        </box>

        {/* Sliders: Volume & Brightness with full pill track */}
        <box vertical spacing={4}>
          {/* Volume Slider */}
          <box class="qs-slider-row" valign={Gtk.Align.CENTER}>
            <icon icon="audio-volume-high-symbolic" class="slider-leading-icon" />
            <slider
              hexpand
              min={0}
              max={1}
              step={0.01}
              value={volumeVal}
              onDragged={(s) => handleVolumeChange(s.value)}
            />
            <label
              label={volumeVal((v) => `${Math.round(v * 100)}%`)}
              class="slider-value-label"
              xalign={1}
            />
          </box>

          {/* Brightness Slider */}
          <box class="qs-slider-row" valign={Gtk.Align.CENTER}>
            <icon icon="display-brightness-symbolic" class="slider-leading-icon" />
            <slider
              hexpand
              min={0.05}
              max={1}
              step={0.01}
              value={brightness}
              onDragged={(s) => handleBrightnessChange(s.value)}
            />
            <label
              label={brightness((b) => `${Math.round(b * 100)}%`)}
              class="slider-value-label"
              xalign={1}
            />
          </box>
        </box>

        {/* Media Player Card (if media playing) */}
        <With value={activePlayer}>
          {(p) =>
            p ? (
              <box class="qs-media-card" valign={Gtk.Align.CENTER}>
                <icon icon="audio-x-generic-symbolic" class="media-art" />
                <box vertical hexpand valign={Gtk.Align.CENTER}>
                  <label label={createBinding(p, "title")} class="media-title" xalign={0} ellipsize={3} />
                  <label label={createBinding(p, "artist")} class="media-artist" xalign={0} ellipsize={3} />
                </box>
                <button class="media-ctrl-btn" onClicked={() => p.previous()}>
                  <icon icon="media-skip-backward-symbolic" class="ctrl-icon" />
                </button>
                <button class="media-ctrl-btn" onClicked={() => p.play_pause()}>
                  <icon
                    icon={createBinding(p, "playback_status")((s) =>
                      s === Mpris.PlaybackStatus.PLAYING
                        ? "media-playback-pause-symbolic"
                        : "media-playback-start-symbolic"
                    )}
                    class="ctrl-icon"
                  />
                </button>
                <button class="media-ctrl-btn" onClicked={() => p.next()}>
                  <icon icon="media-skip-forward-symbolic" class="ctrl-icon" />
                </button>
              </box>
            ) : null
          }
        </With>
      </box>
    </window>
  )
}
