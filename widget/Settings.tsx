import app from "ags/gtk3/app"
import { Gtk } from "ags/gtk3"
import { createState, With } from "ags"
import { execAsync } from "ags/process"
import {
  language,
  setLanguage,
  themeMode,
  setThemeMode,
  accentColor,
  setAccentColor,
  clock24h,
  setClock24h,
  shelfHeight,
  setShelfHeight,
  cornerRadius,
  setCornerRadius,
  pinnedApps,
  togglePinApp,
} from "../lib/settings"
import { loc } from "../lib/i18n"
import { applyAccentColor, applyCornerRadius } from "../lib/theme"

type SettingsTab = "general" | "appearance" | "shelf" | "shortcuts" | "about"

export default function Settings() {
  const [activeTab, setActiveTab] = createState<SettingsTab>("general")

  const accentPalettes = [
    { name: "Google Blue", hex: "#a8c7fa" },
    { name: "Emerald Mint", hex: "#7adaa2" },
    { name: "Sunset Rose", hex: "#ffb3b8" },
    { name: "Amber Gold", hex: "#ffd966" },
    { name: "Iris Lavender", hex: "#d0bcff" },
  ]

  const shortcutsList = [
    { key: "Super / Super+Space", desc: "Toggle App Launcher" },
    { key: "Super + A", desc: "Toggle Quick Settings" },
    { key: "Super + C", desc: "Toggle Calendar & Notifications" },
    { key: "Print / Super+Shift+S", desc: "Launch Screen Capture Tool" },
    { key: "Super + Return / Super+T", desc: "Open Terminal (Ptyxis)" },
    { key: "Super + Q / Alt+F4", desc: "Close Focused Window" },
    { key: "Super + Up", desc: "Toggle Maximize Window" },
    { key: "Super + Left / Right", desc: "Snap Window to Left / Right" },
    { key: "Alt + Tab", desc: "Switch Applications" },
  ]

  return (
    <Gtk.ApplicationWindow
      name="settings"
      title={loc("configTitle")}
      iconName="preferences-system-symbolic"
      class="SettingsWindow"
      decorated={true}
      resizable={true}
      defaultWidth={900}
      defaultHeight={640}
      visible={false}
      application={app}
      $={(self) => {
        self.connect("delete-event", () => {
          self.visible = false
          return true
        })
      }}
    >
      <box class={themeMode((m) => `settings-card ${m === "light" ? "light-theme" : ""}`)} vertical>
        {/* Main Body: Left Navigation Sidebar & Right Content */}
        <box class="settings-body" spacing={16} hexpand vexpand>
          {/* Left Navigation Rail */}
          <box class="settings-nav-sidebar" vertical spacing={4}>
            <button
              class={activeTab((t) => `settings-nav-btn ${t === "general" ? "active" : ""}`)}
              onClicked={() => setActiveTab("general")}
            >
              <box valign={Gtk.Align.CENTER} spacing={10}>
                <icon icon="preferences-system-symbolic" class="nav-icon" />
                <label label={loc("tabGeneral")} class="nav-label" />
              </box>
            </button>

            <button
              class={activeTab((t) => `settings-nav-btn ${t === "appearance" ? "active" : ""}`)}
              onClicked={() => setActiveTab("appearance")}
            >
              <box valign={Gtk.Align.CENTER} spacing={10}>
                <icon icon="weather-clear-night-symbolic" class="nav-icon" />
                <label label={loc("tabAppearance")} class="nav-label" />
              </box>
            </button>

            <button
              class={activeTab((t) => `settings-nav-btn ${t === "shelf" ? "active" : ""}`)}
              onClicked={() => setActiveTab("shelf")}
            >
              <box valign={Gtk.Align.CENTER} spacing={10}>
                <icon icon="view-app-grid-symbolic" class="nav-icon" />
                <label label={loc("tabShelf")} class="nav-label" />
              </box>
            </button>

            <button
              class={activeTab((t) => `settings-nav-btn ${t === "shortcuts" ? "active" : ""}`)}
              onClicked={() => setActiveTab("shortcuts")}
            >
              <box valign={Gtk.Align.CENTER} spacing={10}>
                <icon icon="input-keyboard-symbolic" class="nav-icon" />
                <label label={loc("tabShortcuts")} class="nav-label" />
              </box>
            </button>

            <button
              class={activeTab((t) => `settings-nav-btn ${t === "about" ? "active" : ""}`)}
              onClicked={() => setActiveTab("about")}
            >
              <box valign={Gtk.Align.CENTER} spacing={10}>
                <icon icon="help-about-symbolic" class="nav-icon" />
                <label label={loc("tabAbout")} class="nav-label" />
              </box>
            </button>
          </box>

          {/* Right Content Pane */}
          <scrollable
            class="settings-content-pane"
            vscroll={Gtk.PolicyType.AUTOMATIC}
            hscroll={Gtk.PolicyType.NEVER}
            hexpand
            vexpand
          >
            <box vertical hexpand>
            <With value={activeTab}>
              {(tab) => {
                if (tab === "general") {
                  return (
                    <box vertical spacing={16}>
                      {/* Language Selection */}
                      <box class="settings-section-card" vertical spacing={8}>
                        <label label={loc("languageSetting")} class="setting-heading" xalign={0} />
                        <label label={loc("languageDesc")} class="setting-subtext" xalign={0} />
                        <box spacing={10} css="margin-top: 8px;">
                          <button
                            class={language((l) => `option-pill-btn ${l === "en" ? "active" : ""}`)}
                            onClicked={() => setLanguage("en")}
                          >
                            <label label="English (US) ✓" />
                          </button>
                          <button
                            class={language((l) => `option-pill-btn ${l === "vi" ? "active" : ""}`)}
                            onClicked={() => setLanguage("vi")}
                          >
                            <label label="Tiếng Việt ✓" />
                          </button>
                        </box>
                      </box>

                      {/* Time format */}
                      <box class="settings-section-card" vertical spacing={8}>
                        <label label={loc("clockFormatSetting")} class="setting-heading" xalign={0} />
                        <label label={loc("clockFormatDesc")} class="setting-subtext" xalign={0} />
                        <box spacing={10} css="margin-top: 8px;">
                          <button
                            class={clock24h((c) => `option-pill-btn ${c ? "active" : ""}`)}
                            onClicked={() => setClock24h(true)}
                          >
                            <label label="24-Hour (14:30)" />
                          </button>
                          <button
                            class={clock24h((c) => `option-pill-btn ${!c ? "active" : ""}`)}
                            onClicked={() => setClock24h(false)}
                          >
                            <label label="12-Hour (2:30 PM)" />
                          </button>
                        </box>
                      </box>

                      {/* System Settings Shortcut */}
                      <box class="settings-section-card" vertical spacing={8}>
                        <label label="System Settings" class="setting-heading" xalign={0} />
                        <label label="Open native Linux / GNOME Settings panel" class="setting-subtext" xalign={0} />
                        <button
                          class="action-btn"
                          onClicked={() => execAsync("gnome-control-center").catch(console.error)}
                          css="margin-top: 8px;"
                        >
                          <box spacing={8} valign={Gtk.Align.CENTER}>
                            <icon icon="preferences-system-symbolic" class="btn-icon" />
                            <label label={loc("systemSettingsBtn")} />
                          </box>
                        </button>
                      </box>

                    </box>
                  )
                }

                if (tab === "appearance") {
                  return (
                    <box vertical spacing={16}>
                      {/* Theme mode */}
                      <box class="settings-section-card" vertical spacing={8}>
                        <label label={loc("themeModeSetting")} class="setting-heading" xalign={0} />
                        <label label={loc("themeModeDesc")} class="setting-subtext" xalign={0} />
                        <box spacing={10} css="margin-top: 8px;">
                          <button
                            class={themeMode((m) => `option-pill-btn ${m === "dark" ? "active" : ""}`)}
                            onClicked={() => setThemeMode("dark")}
                          >
                            <box spacing={6} valign={Gtk.Align.CENTER}>
                              <icon icon="weather-clear-night-symbolic" class="btn-icon" />
                              <label label="Dark Theme" />
                            </box>
                          </button>
                          <button
                            class={themeMode((m) => `option-pill-btn ${m === "light" ? "active" : ""}`)}
                            onClicked={() => setThemeMode("light")}
                          >
                            <box spacing={6} valign={Gtk.Align.CENTER}>
                              <icon icon="weather-clear-symbolic" class="btn-icon" />
                              <label label="Light Theme" />
                            </box>
                          </button>
                        </box>
                      </box>

                      {/* Accent Palette */}
                      <box class="settings-section-card" vertical spacing={8}>
                        <label label={loc("accentColorSetting")} class="setting-heading" xalign={0} />
                        <label label={loc("accentColorDesc")} class="setting-subtext" xalign={0} />
                        <box spacing={8} css="margin-top: 8px;">
                          {accentPalettes.map((p) => (
                            <button
                              class={accentColor((c) => `accent-color-chip ${c === p.hex ? "selected" : ""}`)}
                              css={`background-color: ${p.hex};`}
                              tooltipText={p.name}
                              onClicked={() => {
                                setAccentColor(p.hex)
                                applyAccentColor(p.hex)
                              }}
                            />
                          ))}
                        </box>
                      </box>

                      <box class="settings-section-card" vertical spacing={8}>
                        <label label={loc("cornerRadiusSetting")} class="setting-heading" xalign={0} />
                        <label label={loc("cornerRadiusDesc")} class="setting-subtext" xalign={0} />
                        <box spacing={8} css="margin-top: 8px;">
                          {[16, 24, 28, 32].map((radius) => (
                            <button
                              class={cornerRadius((current) => `option-pill-btn ${current === radius ? "active" : ""}`)}
                              onClicked={() => {
                                setCornerRadius(radius)
                                applyCornerRadius(radius)
                              }}
                            >
                              <label label={`${radius}px`} />
                            </button>
                          ))}
                        </box>
                      </box>
                    </box>
                  )
                }

                if (tab === "shelf") {
                  return (
                    <box vertical spacing={16}>
                      <box class="settings-section-card" vertical spacing={8}>
                        <label label={loc("shelfHeightSetting")} class="setting-heading" xalign={0} />
                        <label label={loc("shelfHeightDesc")} class="setting-subtext" xalign={0} />
                        <box spacing={10} css="margin-top: 8px;">
                          <button
                            class={shelfHeight((h) => `option-pill-btn ${h === 48 ? "active" : ""}`)}
                            onClicked={() => setShelfHeight(48)}
                          >
                            <label label="Compact (48px)" />
                          </button>
                          <button
                            class={shelfHeight((h) => `option-pill-btn ${h === 56 ? "active" : ""}`)}
                            onClicked={() => setShelfHeight(56)}
                          >
                            <label label="Default (56px)" />
                          </button>
                          <button
                            class={shelfHeight((h) => `option-pill-btn ${h === 64 ? "active" : ""}`)}
                            onClicked={() => setShelfHeight(64)}
                          >
                            <label label="Comfortable (64px)" />
                          </button>
                        </box>
                      </box>

                      {/* Pinned Applications Management */}
                      <box class="settings-section-card" vertical spacing={8}>
                        <label label="Pinned Applications" class="setting-heading" xalign={0} />
                        <label label="Manage applications pinned to the bottom shelf" class="setting-subtext" xalign={0} />
                        <box vertical spacing={6} css="margin-top: 8px;">
                          <With value={pinnedApps}>
                            {(apps) =>
                              apps.length > 0 ? (
                                <box vertical spacing={6}>
                                  {apps.map((appItem) => (
                                    <centerbox class="qs-list-item" valign={Gtk.Align.CENTER}>
                                      <box $type="start" valign={Gtk.Align.CENTER} spacing={8}>
                                        <icon icon={appItem.icon} class="list-icon" />
                                        <label label={appItem.name} class="list-title" />
                                      </box>
                                      <box $type="center" />
                                      <button
                                        class="qs-icon-btn"
                                        valign={Gtk.Align.CENTER}
                                        $type="end"
                                        tooltipText="Unpin from Shelf"
                                        onClicked={() => togglePinApp(appItem)}
                                      >
                                        <icon icon="window-close-symbolic" class="btn-icon" />
                                      </button>
                                    </centerbox>
                                  ))}
                                </box>
                              ) : (
                                <label label="No pinned applications" class="cal-date-sub" xalign={0} />
                              )
                            }
                          </With>
                        </box>
                      </box>
                    </box>
                  )
                }

                if (tab === "shortcuts") {
                  return (
                    <scrollable class="qs-subview-scroll" vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER}>
                      <box vertical spacing={8}>
                        {shortcutsList.map((s) => (
                          <box class="shortcut-row" valign={Gtk.Align.CENTER}>
                            <label label={s.key} class="shortcut-key" $type="start" xalign={0} />
                            <box $type="center" />
                            <label label={s.desc} class="shortcut-desc" $type="end" xalign={1} />
                          </box>
                        ))}
                      </box>
                    </scrollable>
                  )
                }

                // About tab
                return (
                  <box class="settings-section-card" vertical spacing={12} valign={Gtk.Align.CENTER}>
                    <icon icon="computer-symbolic" class="about-logo" halign={Gtk.Align.CENTER} />
                    <label label="Amelia Shell" class="about-title" halign={Gtk.Align.CENTER} />
                    <label label="Version 0.3.0" class="about-version" halign={Gtk.Align.CENTER} />
                    <label
                      label="A ChromeOS-inspired Material Design 3 Wayland Shell built with Astal and GTK3."
                      class="setting-subtext"
                      halign={Gtk.Align.CENTER}
                    />
                    <box spacing={8} halign={Gtk.Align.CENTER} css="margin-top: 10px;">
                      <button
                        class="action-btn"
                        onClicked={() => execAsync(`ptyxis -- bash -c "fastfetch; exec bash"`).catch(console.error)}
                      >
                        <box spacing={6} valign={Gtk.Align.CENTER}>
                          <icon icon="utilities-terminal-symbolic" class="btn-icon" />
                          <label label={loc("openSystemInfo")} />
                        </box>
                      </button>
                    </box>
                  </box>
                )
              }}
            </With>
            </box>
          </scrollable>
        </box>
      </box>
    </Gtk.ApplicationWindow>
  )
}
