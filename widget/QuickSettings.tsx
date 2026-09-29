import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { createBinding, createState, With } from "ags"
import { execAsync } from "ags/process"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Wp from "gi://AstalWp"
import Notifd from "gi://AstalNotifd"
import Mpris from "gi://AstalMpris"
import { themeMode, setThemeMode } from "../lib/settings"
import { loc, t } from "../lib/i18n"
import { toggleExclusive } from "../lib/window_manager"

interface WifiNetwork {
  inUse: boolean
  ssid: string
  signal: number
  secured: boolean
}

interface BtDeviceItem {
  address: string
  name: string
  connected: boolean
}

export default function QuickSettings() {
  const { BOTTOM, RIGHT } = Astal.WindowAnchor

  // System daemons
  const network = Network.get_default()
  const bluetooth = Bluetooth.get_default()
  const wp = Wp.get_default()
  const notifd = Notifd.get_default()
  const mpris = Mpris.get_default()

  // Navigation state: "main" | "wifi" | "bluetooth"
  const [currentView, setCurrentView] = createState<"main" | "wifi" | "bluetooth">("main")

  // Brightness state
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

  const toggleMute = () => {
    if (speaker) {
      speaker.mute = !speaker.mute
    } else {
      execAsync("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle").catch(() => {})
    }
  }

  // Dark mode toggle
  const toggleDarkMode = () => {
    const next = themeMode() === "dark" ? "light" : "dark"
    setThemeMode(next)
    const scheme = next === "dark" ? "prefer-dark" : "prefer-light"
    const gtkTheme = next === "dark" ? "Adwaita-dark" : "Adwaita"
    execAsync(`gsettings set org.gnome.desktop.interface color-scheme '${scheme}'`).catch(() => {})
    execAsync(`gsettings set org.gnome.desktop.interface gtk-theme '${gtkTheme}'`).catch(() => {})
  }

  // Airplane mode state
  const [airplaneMode, setAirplaneMode] = createState(false)
  const toggleAirplaneMode = async () => {
    const next = !airplaneMode()
    setAirplaneMode(next)
    if (next) {
      await execAsync("nmcli radio all off").catch(() => {})
      await execAsync("bluetoothctl power off").catch(() => {})
    } else {
      await execAsync("nmcli radio all on").catch(() => {})
      await execAsync("nmcli radio wifi on").catch(() => {})
    }
  }

  // Wi-Fi toggle & detailed networks list
  const wifiActive = createBinding(network, "primary")((p) => p === Network.Primary.WIFI)
  const wifiSsid = createBinding(network, "wifi")((w) => w?.ssid || t("disconnected"))

  const toggleWifi = async () => {
    if (network.wifi && network.wifi.enabled) {
      await execAsync("nmcli radio wifi off").catch(() => {})
    } else {
      await execAsync("nmcli radio wifi on").catch(() => {})
    }
  }

  const [wifiNetworks, setWifiNetworks] = createState<WifiNetwork[]>([])
  const [isWifiScanning, setIsWifiScanning] = createState(false)

  const scanWifi = async () => {
    setIsWifiScanning(true)
    try {
      await execAsync("nmcli device wifi rescan").catch(() => {})
      const out = await execAsync("nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list")
      const lines = out.trim().split("\n")
      const map = new Map<string, WifiNetwork>()

      for (const line of lines) {
        if (!line.trim()) continue
        const parts = line.split(":")
        if (parts.length >= 3) {
          const inUse = parts[0].trim() === "*"
          const ssid = parts[1].trim()
          if (!ssid) continue
          const signal = parseInt(parts[2], 10) || 0
          const security = parts[3] ? parts[3].trim() : ""
          const secured = security.length > 0 && security !== "--"

          if (!map.has(ssid) || (map.get(ssid)!.signal < signal && !map.get(ssid)!.inUse)) {
            map.set(ssid, { inUse, ssid, signal, secured })
          }
        }
      }
      setWifiNetworks(Array.from(map.values()))
    } catch (_) {
    } finally {
      setIsWifiScanning(false)
    }
  }

  const connectWifi = (netItem: WifiNetwork) => {
    execAsync(["nmcli", "device", "wifi", "connect", netItem.ssid])
      .then(() => scanWifi())
      .catch((err) => console.error("Wi-Fi connect failed:", err))
  }

  // Bluetooth toggle & detailed devices list
  const btPowered = createBinding(bluetooth, "is_powered")
  const btStatusText = btPowered((p) => (p ? t("on") : t("off")))

  const toggleBluetooth = async () => {
    const next = !bluetooth.is_powered
    if (next) {
      await execAsync(
        "busctl --user set-property org.gnome.SettingsDaemon.Rfkill /org/gnome/SettingsDaemon/Rfkill org.gnome.SettingsDaemon.Rfkill BluetoothAirplaneMode b false"
      ).catch(() => {})
      await execAsync("bluetoothctl power on").catch(() => {})
    } else {
      await execAsync("bluetoothctl power off").catch(() => {})
    }
  }

  const [btDevices, setBtDevices] = createState<BtDeviceItem[]>([])
  const [isBtScanning, setIsBtScanning] = createState(false)

  const scanBt = async () => {
    setIsBtScanning(true)
    try {
      const out = await execAsync("bluetoothctl devices")
      const lines = out.trim().split("\n")
      const list: BtDeviceItem[] = []

      for (const line of lines) {
        if (!line.trim()) continue
        const match = line.match(/^Device\s+([0-9A-Fa-f:]+)\s+(.+)$/)
        if (match) {
          const address = match[1]
          const name = match[2]
          const info = await execAsync(`bluetoothctl info ${address}`).catch(() => "")
          const connected = /Connected:\s*yes/i.test(info)
          list.push({ address, name, connected })
        }
      }
      setBtDevices(list)
    } catch (_) {
    } finally {
      setIsBtScanning(false)
    }
  }

  const toggleBtDevice = async (dev: BtDeviceItem) => {
    if (dev.connected) {
      await execAsync(`bluetoothctl disconnect ${dev.address}`).catch(console.error)
    } else {
      await execAsync(`bluetoothctl connect ${dev.address}`).catch(console.error)
    }
    await scanBt()
  }

  // DND toggle
  const dndActive = createBinding(notifd, "dont_disturb")
  const toggleDnd = () => {
    notifd.dont_disturb = !notifd.dont_disturb
  }

  // Screen capture trigger
  const triggerScreenCapture = () => {
    app.toggle_window("quicksettings")
    setTimeout(() => {
      const win = app.get_window("screencapture")
      if (win) win.visible = true
      else app.toggle_window("screencapture")
    }, 120)
  }

  // Open Amelia Shell Configuration
  const openAmeliaSettings = () => {
    app.toggle_window("quicksettings")
    setTimeout(() => {
      const win = app.get_window("settings")
      if (win) win.visible = true
      else app.toggle_window("settings")
    }, 100)
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
      marginBottom={8}
      marginRight={12}
      visible={false}
      application={app}
    >
      <box class={themeMode((m) => `quicksettings-card ${m === "light" ? "light-theme" : ""}`)} vertical>
        <With value={currentView}>
          {(view) => {
            if (view === "wifi") {
              return (
                <box vertical>
                  {/* Wi-Fi Subview Header */}
                  <centerbox class="qs-subview-header" valign={Gtk.Align.CENTER}>
                    <box $type="start" valign={Gtk.Align.CENTER}>
                      <button class="qs-icon-btn" onClicked={() => setCurrentView("main")} tooltipText={loc("back")}>
                        <icon icon="go-previous-symbolic" class="btn-icon" />
                      </button>
                      <label label={loc("wifiNetworks")} class="qs-subview-title" />
                    </box>
                    <box $type="center" />
                    <box $type="end" valign={Gtk.Align.CENTER} spacing={6}>
                      <button
                        class="qs-icon-btn"
                        tooltipText={loc("scan")}
                        onClicked={scanWifi}
                      >
                        <icon icon="view-refresh-symbolic" class="btn-icon" />
                      </button>
                      <button
                        class={wifiActive((act) => `qs-pod ${act ? "active" : ""}`)}
                        onClicked={toggleWifi}
                      >
                        <label label={wifiActive((act) => (act ? t("on") : t("off")))} />
                      </button>
                    </box>
                  </centerbox>

                  {/* Wi-Fi Networks List */}
                  <scrollable class="qs-subview-scroll" vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER}>
                    <box vertical spacing={4}>
                      <With value={wifiNetworks}>
                        {(networks) =>
                          networks.length > 0 ? (
                            <box vertical spacing={4}>
                              {networks.map((net) => {
                                const signalIcon =
                                  net.signal >= 75
                                    ? "network-wireless-signal-excellent-symbolic"
                                    : net.signal >= 50
                                    ? "network-wireless-signal-good-symbolic"
                                    : net.signal >= 25
                                    ? "network-wireless-signal-ok-symbolic"
                                    : "network-wireless-signal-weak-symbolic"

                                return (
                                  <button
                                    class={`qs-list-item ${net.inUse ? "active" : ""}`}
                                    onClicked={() => connectWifi(net)}
                                  >
                                    <centerbox valign={Gtk.Align.CENTER}>
                                      <box $type="start" valign={Gtk.Align.CENTER}>
                                        <icon icon={signalIcon} class="list-icon" />
                                        <box vertical valign={Gtk.Align.CENTER}>
                                          <label label={net.ssid} class="list-title" xalign={0} />
                                          <label
                                            label={net.inUse ? t("connected") : `${net.signal}%`}
                                            class="list-subtitle"
                                            xalign={0}
                                          />
                                        </box>
                                      </box>
                                      <box $type="center" />
                                      <box $type="end" valign={Gtk.Align.CENTER}>
                                        {net.secured ? (
                                          <icon icon="network-wireless-encrypted-symbolic" class="list-icon" />
                                        ) : (
                                          <box />
                                        )}
                                      </box>
                                    </centerbox>
                                  </button>
                                )
                              })}
                            </box>
                          ) : (
                            <label
                              label={loc("scanningWifi")}
                              class="cal-date-sub"
                              xalign={0.5}
                              margin={20}
                            />
                          )
                        }
                      </With>
                    </box>
                  </scrollable>
                </box>
              )
            }

            if (view === "bluetooth") {
              return (
                <box vertical>
                  {/* Bluetooth Subview Header */}
                  <centerbox class="qs-subview-header" valign={Gtk.Align.CENTER}>
                    <box $type="start" valign={Gtk.Align.CENTER}>
                      <button class="qs-icon-btn" onClicked={() => setCurrentView("main")} tooltipText={loc("back")}>
                        <icon icon="go-previous-symbolic" class="btn-icon" />
                      </button>
                      <label label={loc("btDevices")} class="qs-subview-title" />
                    </box>
                    <box $type="center" />
                    <box $type="end" valign={Gtk.Align.CENTER} spacing={6}>
                      <button
                        class="qs-icon-btn"
                        tooltipText={loc("scan")}
                        onClicked={scanBt}
                      >
                        <icon icon="view-refresh-symbolic" class="btn-icon" />
                      </button>
                      <button
                        class={btPowered((p) => `qs-pod ${p ? "active" : ""}`)}
                        onClicked={toggleBluetooth}
                      >
                        <label label={btPowered((p) => (p ? t("on") : t("off")))} />
                      </button>
                    </box>
                  </centerbox>

                  {/* Bluetooth Devices List */}
                  <scrollable class="qs-subview-scroll" vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER}>
                    <box vertical spacing={4}>
                      <With value={btDevices}>
                        {(devices) =>
                          devices.length > 0 ? (
                            <box vertical spacing={4}>
                              {devices.map((dev) => (
                                <button
                                  class={`qs-list-item ${dev.connected ? "active" : ""}`}
                                  onClicked={() => toggleBtDevice(dev)}
                                >
                                  <centerbox valign={Gtk.Align.CENTER}>
                                    <box $type="start" valign={Gtk.Align.CENTER}>
                                      <icon icon="bluetooth-active-symbolic" class="list-icon" />
                                      <box vertical valign={Gtk.Align.CENTER}>
                                        <label label={dev.name} class="list-title" xalign={0} />
                                        <label
                                          label={dev.connected ? t("connected") : t("paired")}
                                          class="list-subtitle"
                                          xalign={0}
                                        />
                                      </box>
                                    </box>
                                    <box $type="center" />
                                    <box $type="end" valign={Gtk.Align.CENTER}>
                                      <label
                                        label={dev.connected ? t("disconnect") : t("connect")}
                                        class="notif-clear-btn"
                                      />
                                    </box>
                                  </centerbox>
                                </button>
                              ))}
                            </box>
                          ) : (
                            <label
                              label={t("noBtDevices")}
                              class="cal-date-sub"
                              xalign={0.5}
                              margin={20}
                            />
                          )
                        }
                      </With>
                    </box>
                  </scrollable>
                </box>
              )
            }

            // Main Quick Settings View
            return (
              <box vertical>
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
                      tooltipText={loc("lock")}
                      onClicked={() => execAsync("loginctl lock-session").catch(console.error)}
                    >
                      <icon icon="system-lock-screen-symbolic" class="btn-icon" />
                    </button>
                    <button
                      class="qs-icon-btn"
                      tooltipText={loc("settings")}
                      onClicked={openAmeliaSettings}
                    >
                      <icon icon="emblem-system-symbolic" class="btn-icon" />
                    </button>
                    <button
                      class="qs-icon-btn"
                      tooltipText={loc("powerOff")}
                      onClicked={() => execAsync("systemctl poweroff").catch(console.error)}
                    >
                      <icon icon="system-shutdown-symbolic" class="btn-icon" />
                    </button>
                    <button
                      class="qs-icon-btn"
                      tooltipText={loc("collapse")}
                      onClicked={() => app.toggle_window("quicksettings")}
                    >
                      <icon icon="go-down-symbolic" class="btn-icon" />
                    </button>
                  </box>
                </centerbox>

                {/* Feature Pods: 3 columns x 2 rows */}
                <box class="qs-pods-grid" vertical spacing={8}>
                  {/* Row 1: Wi-Fi, Bluetooth, Airplane Mode */}
                  <box spacing={8} homogeneous>
                    {/* Wi-Fi Pod with Submenu Chevron */}
                    <button
                      class={wifiActive((act) => `qs-pod ${act ? "active" : ""}`)}
                      onClicked={() => {
                        scanWifi()
                        setCurrentView("wifi")
                      }}
                    >
                      <box valign={Gtk.Align.CENTER}>
                        <icon icon="network-wireless-symbolic" class="pod-icon" />
                        <box vertical valign={Gtk.Align.CENTER} hexpand>
                          <label label={loc("wifi")} class="pod-title" xalign={0} />
                          <label label={wifiSsid} class="pod-subtitle" xalign={0} maxWidthChars={8} ellipsize={3} />
                        </box>
                        <icon icon="go-next-symbolic" class="pod-chevron" />
                      </box>
                    </button>

                    {/* Bluetooth Pod with Submenu Chevron */}
                    <button
                      class={btPowered((act) => `qs-pod ${act ? "active" : ""}`)}
                      onClicked={() => {
                        scanBt()
                        setCurrentView("bluetooth")
                      }}
                    >
                      <box valign={Gtk.Align.CENTER}>
                        <icon icon="bluetooth-active-symbolic" class="pod-icon" />
                        <box vertical valign={Gtk.Align.CENTER} hexpand>
                          <label label={loc("bluetooth")} class="pod-title" xalign={0} />
                          <label label={btStatusText} class="pod-subtitle" xalign={0} />
                        </box>
                        <icon icon="go-next-symbolic" class="pod-chevron" />
                      </box>
                    </button>

                    {/* Airplane Mode Pod */}
                    <button
                      class={airplaneMode((act) => `qs-pod ${act ? "active" : ""}`)}
                      onClicked={toggleAirplaneMode}
                    >
                      <box valign={Gtk.Align.CENTER}>
                        <icon icon="airplane-mode-symbolic" class="pod-icon" />
                        <box vertical valign={Gtk.Align.CENTER} hexpand>
                          <label label={loc("airplaneMode")} class="pod-title" xalign={0} maxWidthChars={10} ellipsize={3} />
                          <label label={airplaneMode((act) => (act ? t("on") : t("off")))} class="pod-subtitle" xalign={0} />
                        </box>
                      </box>
                    </button>
                  </box>

                  {/* Row 2: Screen Capture, Dark Theme, Do Not Disturb */}
                  <box spacing={8} homogeneous>
                    {/* Screen Capture Pod */}
                    <button
                      class="qs-pod"
                      tooltipText={loc("snippingTool")}
                      onClicked={triggerScreenCapture}
                    >
                      <box valign={Gtk.Align.CENTER}>
                        <icon icon="camera-photo-symbolic" class="pod-icon" />
                        <box vertical valign={Gtk.Align.CENTER} hexpand>
                          <label label={loc("screenCapture")} class="pod-title" xalign={0} />
                          <label label={loc("snippingTool")} class="pod-subtitle" xalign={0} />
                        </box>
                      </box>
                    </button>

                    {/* Dark Theme Pod */}
                    <button
                      class={themeMode((m) => `qs-pod ${m === "dark" ? "active" : ""}`)}
                      onClicked={toggleDarkMode}
                    >
                      <box valign={Gtk.Align.CENTER}>
                        <icon icon="weather-clear-night-symbolic" class="pod-icon" />
                        <box vertical valign={Gtk.Align.CENTER} hexpand>
                          <label label={loc("darkTheme")} class="pod-title" xalign={0} />
                          <label label={themeMode((m) => (m === "dark" ? t("on") : t("off")))} class="pod-subtitle" xalign={0} />
                        </box>
                      </box>
                    </button>

                    {/* Do Not Disturb Pod */}
                    <button
                      class={dndActive((act) => `qs-pod ${act ? "active" : ""}`)}
                      onClicked={toggleDnd}
                    >
                      <box valign={Gtk.Align.CENTER}>
                        <icon icon="notifications-disabled-symbolic" class="pod-icon" />
                        <box vertical valign={Gtk.Align.CENTER} hexpand>
                          <label label={loc("doNotDisturb")} class="pod-title" xalign={0} />
                          <label label={dndActive((act) => (act ? t("silent") : t("off")))} class="pod-subtitle" xalign={0} />
                        </box>
                      </box>
                    </button>
                  </box>
                </box>

                {/* Sliders: Volume & Brightness with clickable mute */}
                <box vertical spacing={4}>
                  {/* Volume Slider with Mute Button */}
                  <box class="qs-slider-row" valign={Gtk.Align.CENTER}>
                    <button class="slider-mute-btn" onClicked={toggleMute} tooltipText={loc("mute")}>
                      <icon
                        icon={isMuted((m) =>
                          m ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                        )}
                        class="slider-leading-icon"
                      />
                    </button>
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

                {/* Media Player Card */}
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
            )
          }}
        </With>
      </box>
    </window>
  )
}
