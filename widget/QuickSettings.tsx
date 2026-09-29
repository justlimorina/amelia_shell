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

// Unescape helper for nmcli terse mode (where colons in values are escaped as \:)
function parseNmcliTerse(line: string): string[] {
  const parts: string[] = []
  let current = ""
  let escaped = false
  for (let i = 0; i < line.length; i++) {
    const ch = line[i]
    if (escaped) {
      current += ch
      escaped = false
    } else if (ch === "\\") {
      escaped = true
    } else if (ch === ":") {
      parts.push(current)
      current = ""
    } else {
      current += ch
    }
  }
  parts.push(current)
  return parts
}

function formatTime(sec: number): string {
  if (!sec || isNaN(sec) || sec <= 0) return "0:00"
  const m = Math.floor(sec / 60)
  const s = Math.floor(sec % 60)
  return `${m}:${s < 10 ? "0" : ""}${s}`
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

  // Power options confirmation
  const [showPowerConfirm, setShowPowerConfirm] = createState(false)

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

  const [isWifiToggling, setIsWifiToggling] = createState(false)
  const toggleWifi = async () => {
    if (isWifiToggling()) return
    setIsWifiToggling(true)
    try {
      if (network.wifi && network.wifi.enabled) {
        await execAsync("nmcli radio wifi off")
      } else {
        await execAsync("nmcli radio wifi on")
      }
    } catch (_) {
    } finally {
      setIsWifiToggling(false)
    }
  }

  const [wifiNetworks, setWifiNetworks] = createState<WifiNetwork[]>([])
  const [isWifiScanning, setIsWifiScanning] = createState(false)
  const [connectingSsid, setConnectingSsid] = createState<string | null>(null)
  const [wifiError, setWifiError] = createState<string | null>(null)

  // Wi-Fi Password prompt state
  const [wifiAuthPrompt, setWifiAuthPrompt] = createState<{ ssid: string; secured: boolean } | null>(null)
  const [wifiPassword, setWifiPassword] = createState("")
  const [showPasswordText, setShowPasswordText] = createState(false)
  const [isAuthConnecting, setIsAuthConnecting] = createState(false)

  const scanWifi = async () => {
    if (isWifiScanning()) return
    setIsWifiScanning(true)
    setWifiError(null)
    try {
      await execAsync("nmcli device wifi rescan").catch(() => {})
      const out = await execAsync("nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list")
      const lines = out.trim().split("\n")
      const map = new Map<string, WifiNetwork>()

      for (const line of lines) {
        if (!line.trim()) continue
        const parts = parseNmcliTerse(line)
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
    } catch (err: any) {
      setWifiError("Failed to scan Wi-Fi networks.")
    } finally {
      setIsWifiScanning(false)
    }
  }

  const handleNetworkClick = async (netItem: WifiNetwork) => {
    if (connectingSsid() || isAuthConnecting()) return
    setWifiError(null)

    if (netItem.inUse) return // Already connected

    // Try direct connection first (in case password already saved in NetworkManager)
    setConnectingSsid(netItem.ssid)
    try {
      await execAsync(["nmcli", "device", "wifi", "connect", netItem.ssid])
      setConnectingSsid(null)
      await scanWifi()
    } catch (err: any) {
      setConnectingSsid(null)
      const errStr = String(err?.message || err)
      // If network is secured and secrets are required, prompt for password
      if (netItem.secured && (errStr.includes("Secrets were required") || errStr.includes("No secrets") || errStr.includes("password"))) {
        setWifiPassword("")
        setWifiAuthPrompt({ ssid: netItem.ssid, secured: true })
      } else {
        setWifiError(`Could not connect to "${netItem.ssid}".`)
      }
    }
  }

  const submitWifiPassword = async () => {
    if (!wifiAuthPrompt() || isAuthConnecting()) return
    const ssid = wifiAuthPrompt()!.ssid
    const pwd = wifiPassword()

    setIsAuthConnecting(true)
    setWifiError(null)
    try {
      await execAsync(["nmcli", "device", "wifi", "connect", ssid, "password", pwd])
      setWifiAuthPrompt(null)
      setWifiPassword("")
      await scanWifi()
    } catch (err: any) {
      setWifiError("Incorrect password or connection failed.")
    } finally {
      setIsAuthConnecting(false)
    }
  }

  // Bluetooth toggle & detailed devices list
  const btPowered = createBinding(bluetooth, "is_powered")
  const btStatusText = btPowered((p) => (p ? t("on") : t("off")))
  const [isBtToggling, setIsBtToggling] = createState(false)

  const toggleBluetooth = async () => {
    if (isBtToggling()) return
    setIsBtToggling(true)
    try {
      const next = !bluetooth.is_powered
      if (next) {
        await execAsync(
          "busctl --user set-property org.gnome.SettingsDaemon.Rfkill /org/gnome/SettingsDaemon/Rfkill org.gnome.SettingsDaemon.Rfkill BluetoothAirplaneMode b false"
        ).catch(() => {})
        await execAsync("bluetoothctl power on")
      } else {
        await execAsync("bluetoothctl power off")
      }
    } catch (_) {
    } finally {
      setIsBtToggling(false)
    }
  }

  const [btDevices, setBtDevices] = createState<BtDeviceItem[]>([])
  const [isBtScanning, setIsBtScanning] = createState(false)
  const [connectingBtAddress, setConnectingBtAddress] = createState<string | null>(null)
  const [btError, setBtError] = createState<string | null>(null)

  const scanBt = async () => {
    if (isBtScanning()) return
    setIsBtScanning(true)
    setBtError(null)
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
      setBtError("Failed to discover Bluetooth devices.")
    } finally {
      setIsBtScanning(false)
    }
  }

  const toggleBtDevice = async (dev: BtDeviceItem) => {
    if (connectingBtAddress()) return
    setConnectingBtAddress(dev.address)
    setBtError(null)
    try {
      if (dev.connected) {
        await execAsync(`bluetoothctl disconnect ${dev.address}`)
      } else {
        await execAsync(`bluetoothctl connect ${dev.address}`)
      }
      await scanBt()
    } catch (err: any) {
      setBtError(`Failed to ${dev.connected ? "disconnect" : "connect"} "${dev.name}".`)
    } finally {
      setConnectingBtAddress(null)
    }
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
                    <box $type="start" valign={Gtk.Align.CENTER} spacing={8}>
                      <button
                        class="qs-icon-btn"
                        valign={Gtk.Align.CENTER}
                        onClicked={() => {
                          setWifiError(null)
                          setWifiAuthPrompt(null)
                          setCurrentView("main")
                        }}
                        tooltipText={loc("back")}
                      >
                        <icon icon="go-previous-symbolic" class="btn-icon" />
                      </button>
                      <label label={loc("wifiNetworks")} class="qs-subview-title" valign={Gtk.Align.CENTER} />
                    </box>
                    <box $type="center" />
                    <box $type="end" valign={Gtk.Align.CENTER} spacing={8}>
                      <button
                        class="qs-icon-btn"
                        valign={Gtk.Align.CENTER}
                        tooltipText={isWifiScanning() ? "Scanning..." : loc("scan")}
                        onClicked={scanWifi}
                        sensitive={isWifiScanning((s) => !s)}
                      >
                        <icon icon="view-refresh-symbolic" class="btn-icon" />
                      </button>
                      <button
                        class={wifiActive((act) => `qs-subview-toggle ${act ? "active" : ""}`)}
                        valign={Gtk.Align.CENTER}
                        onClicked={toggleWifi}
                        sensitive={isWifiToggling((t) => !t)}
                      >
                        <label label={wifiActive((act) => (act ? t("on") : t("off")))} />
                      </button>
                    </box>
                  </centerbox>

                  {/* Error Banner */}
                  <With value={wifiError}>
                    {(err) =>
                      err ? (
                        <centerbox class="qs-error-banner" valign={Gtk.Align.CENTER}>
                          <box $type="start" valign={Gtk.Align.CENTER}>
                            <icon icon="dialog-error-symbolic" class="error-icon" />
                            <label label={err} class="error-text" xalign={0} wrap />
                          </box>
                          <box $type="center" />
                          <button
                            class="error-close-btn"
                            $type="end"
                            onClicked={() => setWifiError(null)}
                          >
                            <icon icon="window-close-symbolic" class="btn-icon" />
                          </button>
                        </centerbox>
                      ) : (
                        <box />
                      )
                    }
                  </With>

                  {/* Wi-Fi Password Input Card */}
                  <With value={wifiAuthPrompt}>
                    {(prompt) =>
                      prompt ? (
                        <box class="qs-auth-card" vertical>
                          <label label={`Enter password for "${prompt.ssid}":`} class="auth-title" xalign={0} />
                          <box class="auth-entry-box" valign={Gtk.Align.CENTER} spacing={6}>
                            <entry
                              hexpand
                              visibility={showPasswordText}
                              text={wifiPassword}
                              placeholderText="Password"
                              onChanged={(e) => setWifiPassword(e.text)}
                              onActivate={submitWifiPassword}
                            />
                            <button
                              class="qs-icon-btn"
                              onClicked={() => setShowPasswordText(!showPasswordText())}
                              tooltipText="Toggle visibility"
                            >
                              <icon
                                icon={showPasswordText((v) =>
                                  v ? "view-conceal-symbolic" : "view-reveal-symbolic"
                                )}
                                class="btn-icon"
                              />
                            </button>
                          </box>
                          <box class="auth-btn-row" spacing={8} halign={Gtk.Align.END}>
                            <button
                              class="auth-action-btn cancel"
                              onClicked={() => {
                                setWifiAuthPrompt(null)
                                setWifiPassword("")
                              }}
                            >
                              <label label={t("cancel")} />
                            </button>
                            <button
                              class="auth-action-btn primary"
                              onClicked={submitWifiPassword}
                              sensitive={isAuthConnecting((c) => !c)}
                            >
                              <label label={isAuthConnecting((c) => (c ? "Connecting..." : t("connect")))} />
                            </button>
                          </box>
                        </box>
                      ) : (
                        <box />
                      )
                    }
                  </With>

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

                                const isConnectingThis = connectingSsid((s) => s === net.ssid)

                                return (
                                  <button
                                    class={`qs-list-item ${net.inUse ? "active" : ""}`}
                                    onClicked={() => handleNetworkClick(net)}
                                  >
                                    <centerbox valign={Gtk.Align.CENTER}>
                                      <box $type="start" valign={Gtk.Align.CENTER}>
                                        <icon icon={signalIcon} class="list-icon" />
                                        <box vertical valign={Gtk.Align.CENTER}>
                                          <label label={net.ssid} class="list-title" xalign={0} />
                                          <label
                                            label={
                                              net.inUse
                                                ? t("connected")
                                                : `${net.signal}%`
                                            }
                                            class="list-subtitle"
                                            xalign={0}
                                          />
                                        </box>
                                      </box>
                                      <box $type="center" />
                                      <box $type="end" valign={Gtk.Align.CENTER} spacing={6}>
                                        <With value={isConnectingThis}>
                                          {(isConn) =>
                                            isConn ? (
                                              <label label="Connecting..." class="qs-connecting-badge" />
                                            ) : (
                                              <box />
                                            )
                                          }
                                        </With>
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
                              label={isWifiScanning((s) => (s ? loc("scanningWifi") : "No Wi-Fi networks found."))}
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
                    <box $type="start" valign={Gtk.Align.CENTER} spacing={8}>
                      <button
                        class="qs-icon-btn"
                        valign={Gtk.Align.CENTER}
                        onClicked={() => {
                          setBtError(null)
                          setCurrentView("main")
                        }}
                        tooltipText={loc("back")}
                      >
                        <icon icon="go-previous-symbolic" class="btn-icon" />
                      </button>
                      <label label={loc("btDevices")} class="qs-subview-title" valign={Gtk.Align.CENTER} />
                    </box>
                    <box $type="center" />
                    <box $type="end" valign={Gtk.Align.CENTER} spacing={8}>
                      <button
                        class="qs-icon-btn"
                        valign={Gtk.Align.CENTER}
                        tooltipText={isBtScanning() ? "Scanning..." : loc("scan")}
                        onClicked={scanBt}
                        sensitive={isBtScanning((s) => !s)}
                      >
                        <icon icon="view-refresh-symbolic" class="btn-icon" />
                      </button>
                      <button
                        class={btPowered((p) => `qs-subview-toggle ${p ? "active" : ""}`)}
                        valign={Gtk.Align.CENTER}
                        onClicked={toggleBluetooth}
                        sensitive={isBtToggling((t) => !t)}
                      >
                        <label label={btPowered((p) => (p ? t("on") : t("off")))} />
                      </button>
                    </box>
                  </centerbox>

                  {/* Bluetooth Error Banner */}
                  <With value={btError}>
                    {(err) =>
                      err ? (
                        <centerbox class="qs-error-banner" valign={Gtk.Align.CENTER}>
                          <box $type="start" valign={Gtk.Align.CENTER}>
                            <icon icon="dialog-error-symbolic" class="error-icon" />
                            <label label={err} class="error-text" xalign={0} wrap />
                          </box>
                          <box $type="center" />
                          <button
                            class="error-close-btn"
                            $type="end"
                            onClicked={() => setBtError(null)}
                          >
                            <icon icon="window-close-symbolic" class="btn-icon" />
                          </button>
                        </centerbox>
                      ) : (
                        <box />
                      )
                    }
                  </With>

                  {/* Bluetooth Devices List */}
                  <scrollable class="qs-subview-scroll" vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER}>
                    <box vertical spacing={4}>
                      <With value={btDevices}>
                        {(devices) =>
                          devices.length > 0 ? (
                            <box vertical spacing={4}>
                              {devices.map((dev) => {
                                const isConnectingThis = connectingBtAddress((addr) => addr === dev.address)
                                return (
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
                                      <box $type="end" valign={Gtk.Align.CENTER} spacing={6}>
                                        <With value={isConnectingThis}>
                                          {(isConn) =>
                                            isConn ? (
                                              <label label="Connecting..." class="qs-connecting-badge" />
                                            ) : (
                                              <label
                                                label={dev.connected ? t("disconnect") : t("connect")}
                                                class="qs-device-action-badge"
                                              />
                                            )
                                          }
                                        </With>
                                      </box>
                                    </centerbox>
                                  </button>
                                )
                              })}
                            </box>
                          ) : (
                            <label
                              label={isBtScanning((s) => (s ? "Scanning for Bluetooth devices..." : t("noBtDevices")))}
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

                  <box $type="end" halign={Gtk.Align.END} valign={Gtk.Align.CENTER} spacing={6}>
                    <button
                      class="qs-icon-btn"
                      valign={Gtk.Align.CENTER}
                      tooltipText={loc("lock")}
                      onClicked={() => execAsync("loginctl lock-session").catch(console.error)}
                    >
                      <icon icon="system-lock-screen-symbolic" class="btn-icon" />
                    </button>
                    <button
                      class="qs-icon-btn"
                      valign={Gtk.Align.CENTER}
                      tooltipText={loc("settings")}
                      onClicked={openAmeliaSettings}
                    >
                      <icon icon="emblem-system-symbolic" class="btn-icon" />
                    </button>
                    <button
                      class="qs-icon-btn"
                      valign={Gtk.Align.CENTER}
                      tooltipText={loc("powerOff")}
                      onClicked={() => setShowPowerConfirm(!showPowerConfirm())}
                    >
                      <icon icon="system-shutdown-symbolic" class="btn-icon" />
                    </button>
                    <button
                      class="qs-icon-btn"
                      valign={Gtk.Align.CENTER}
                      tooltipText={loc("collapse")}
                      onClicked={() => app.toggle_window("quicksettings")}
                    >
                      <icon icon="go-down-symbolic" class="btn-icon" />
                    </button>
                  </box>
                </centerbox>

                {/* Power Confirmation Dialog / Options */}
                <With value={showPowerConfirm}>
                  {(show) =>
                    show ? (
                      <box class="qs-power-card" vertical>
                        <centerbox>
                          <label label="Power Options" class="power-heading" $type="start" xalign={0} />
                          <box $type="center" />
                          <button
                            class="qs-icon-btn"
                            $type="end"
                            onClicked={() => setShowPowerConfirm(false)}
                            tooltipText="Close"
                          >
                            <icon icon="window-close-symbolic" class="btn-icon" />
                          </button>
                        </centerbox>
                        <label label="Choose an action for your current session:" class="power-subtext" xalign={0} />
                        <box spacing={8} homogeneous>
                          <button
                            class="power-opt-btn danger"
                            onClicked={() => {
                              setShowPowerConfirm(false)
                              execAsync("systemctl poweroff").catch(console.error)
                            }}
                          >
                            <box vertical halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                              <icon icon="system-shutdown-symbolic" class="power-btn-icon" />
                              <label label="Shut Down" class="power-btn-label" />
                            </box>
                          </button>
                          <button
                            class="power-opt-btn danger"
                            onClicked={() => {
                              setShowPowerConfirm(false)
                              execAsync("systemctl reboot").catch(console.error)
                            }}
                          >
                            <box vertical halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                              <icon icon="system-reboot-symbolic" class="power-btn-icon" />
                              <label label="Restart" class="power-btn-label" />
                            </box>
                          </button>
                          <button
                            class="power-opt-btn"
                            onClicked={() => {
                              setShowPowerConfirm(false)
                              execAsync("systemctl suspend").catch(console.error)
                            }}
                          >
                            <box vertical halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                              <icon icon="system-suspend-symbolic" class="power-btn-icon" />
                              <label label="Suspend" class="power-btn-label" />
                            </box>
                          </button>
                          <button
                            class="power-opt-btn"
                            onClicked={() => {
                              setShowPowerConfirm(false)
                              execAsync("loginctl terminate-user $USER").catch(console.error)
                            }}
                          >
                            <box vertical halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                              <icon icon="system-log-out-symbolic" class="power-btn-icon" />
                              <label label="Log Out" class="power-btn-label" />
                            </box>
                          </button>
                        </box>
                      </box>
                    ) : (
                      <box />
                    )
                  }
                </With>

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
                          <label label={wifiSsid} class="pod-subtitle" xalign={0} maxWidthChars={14} ellipsize={3} />
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
                          <label label={loc("airplaneMode")} class="pod-title" xalign={0} ellipsize={3} />
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
                      <box class="qs-media-card" vertical>
                        <centerbox valign={Gtk.Align.CENTER}>
                          <box $type="start" valign={Gtk.Align.CENTER}>
                            <box
                              class="media-art"
                              css={createBinding(p, "art_url")((u) => (u ? `background-image: url('${u}');` : ""))}
                              valign={Gtk.Align.CENTER}
                            >
                              <icon
                                icon="audio-x-generic-symbolic"
                                class="media-art-icon"
                                visible={createBinding(p, "art_url")((u) => !u)}
                              />
                            </box>
                            <box vertical valign={Gtk.Align.CENTER} hexpand>
                              <label label={createBinding(p, "title")} class="media-title" xalign={0} ellipsize={3} />
                              <label label={createBinding(p, "artist")} class="media-artist" xalign={0} ellipsize={3} />
                            </box>
                          </box>

                          <box $type="center" />

                          <box $type="end" valign={Gtk.Align.CENTER} spacing={4}>
                            <button
                              class="media-ctrl-btn"
                              onClicked={() => p.previous()}
                              tooltipText="Previous"
                            >
                              <icon icon="media-skip-backward-symbolic" class="ctrl-icon" />
                            </button>
                            <button
                              class="media-ctrl-btn primary"
                              onClicked={() => p.play_pause()}
                              tooltipText="Play / Pause"
                            >
                              <icon
                                icon={createBinding(p, "playback_status")((s) =>
                                  s === Mpris.PlaybackStatus.PLAYING
                                    ? "media-playback-pause-symbolic"
                                    : "media-playback-start-symbolic"
                                )}
                                class="ctrl-icon"
                              />
                            </button>
                            <button
                              class="media-ctrl-btn"
                              onClicked={() => p.next()}
                              tooltipText="Next"
                            >
                              <icon icon="media-skip-forward-symbolic" class="ctrl-icon" />
                            </button>
                          </box>
                        </centerbox>

                        {/* Track Progress Bar & Time Labels */}
                        <box class="media-progress-box" vertical spacing={2}>
                          <slider
                            hexpand
                            min={0}
                            max={createBinding(p, "length")((len) => (len && len > 0 ? len : 1))}
                            value={createBinding(p, "position")}
                            onDragged={(s) => p.set_position(s.value)}
                          />
                          <centerbox>
                            <label
                              label={createBinding(p, "position")((pos) => formatTime(pos))}
                              class="media-time-label"
                              $type="start"
                              xalign={0}
                            />
                            <box $type="center" />
                            <label
                              label={createBinding(p, "length")((len) => formatTime(len))}
                              class="media-time-label"
                              $type="end"
                              xalign={1}
                            />
                          </centerbox>
                        </box>
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
