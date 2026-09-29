import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { createState, createBinding, With } from "ags"
import { execAsync } from "ags/process"
import Apps from "gi://AstalApps"
import { themeMode, togglePinApp, isAppPinned, pinnedApps } from "../lib/settings"
import { loc } from "../lib/i18n"
import { evaluateSafeMath } from "../lib/calculator"

export default function Launcher() {
  const { BOTTOM, LEFT } = Astal.WindowAnchor
  const appsService = new Apps.Apps()

  const [query, setQuery] = createState("")
  const [calcResult, setCalcResult] = createState<string | null>(null)
  const [selectedIndex, setSelectedIndex] = createState(0)

  let searchEntryWidget: Gtk.Entry | null = null

  const handleSearchChange = (text: string) => {
    setQuery(text)
    setSelectedIndex(0)

    // Evaluate math safely without eval or new Function
    const res = evaluateSafeMath(text)
    setCalcResult(res)
  }

  // Filtered applications list
  const filteredApps = query((q) => {
    const trimmed = q.trim()
    if (!trimmed) {
      return appsService.list.slice(0, 30)
    }
    // If command or URL, don't show fuzzy app results unless standard search
    if (trimmed.startsWith(">") || isUrl(trimmed)) {
      return []
    }
    return appsService.fuzzy_query(trimmed).slice(0, 25)
  })

  function isUrl(text: string): boolean {
    const trimmed = text.trim()
    if (/^https?:\/\//i.test(trimmed)) return true
    if (/^[a-zA-Z0-9-]+\.(com|org|net|io|edu|gov|vn|dev|me|ai)(\/.*)?$/i.test(trimmed)) return true
    return false
  }

  const launchApp = (appItem: Apps.Application) => {
    appItem.launch()
    app.toggle_window("launcher")
  }

  const runTerminalCommand = (cmd: string) => {
    const cleanCmd = cmd.startsWith(">") ? cmd.slice(1).trim() : cmd.trim()
    if (!cleanCmd) return
    execAsync(["ptyxis", "--", "bash", "-c", `${cleanCmd}; exec bash`]).catch(() => {
      execAsync(cleanCmd).catch(console.error)
    })
    app.toggle_window("launcher")
  }

  const openWebUrl = (url: string) => {
    let cleanUrl = url.trim()
    if (!/^https?:\/\//i.test(cleanUrl)) {
      cleanUrl = `https://${cleanUrl}`
    }
    execAsync(["xdg-open", cleanUrl]).catch(console.error)
    app.toggle_window("launcher")
  }

  const handleEntryActivate = () => {
    const q = query().trim()

    // 1. Terminal command
    if (q.startsWith(">")) {
      runTerminalCommand(q)
      return
    }

    // 2. Web URL
    if (isUrl(q)) {
      openWebUrl(q)
      return
    }

    // 3. Calculator result
    if (calcResult() !== null) {
      app.toggle_window("launcher")
      return
    }

    // 4. Selected or first application
    const currentList = filteredApps.peek()
    if (currentList.length > 0) {
      const idx = Math.min(Math.max(selectedIndex(), 0), currentList.length - 1)
      launchApp(currentList[idx])
    }
  }

  const handleWindowKeyPress = (_: any, event: Gdk.Event) => {
    const [, keyval] = event.get_keyval()
    const currentList = filteredApps.peek()

    if (keyval === Gdk.KEY_Escape) {
      app.toggle_window("launcher")
      return true
    }

    if (currentList.length > 0) {
      if (keyval === Gdk.KEY_Down) {
        setSelectedIndex((cur) => Math.min(cur + 5, currentList.length - 1))
        return true
      }
      if (keyval === Gdk.KEY_Up) {
        setSelectedIndex((cur) => Math.max(cur - 5, 0))
        return true
      }
      if (keyval === Gdk.KEY_Tab) {
        setSelectedIndex((cur) => (cur + 1) % currentList.length)
        return true
      }
    }

    return false
  }

  return (
    <window
      name="launcher"
      class="LauncherWindow"
      anchor={BOTTOM | LEFT}
      exclusivity={Astal.Exclusivity.NONE}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.ON_DEMAND}
      marginBottom={8}
      marginLeft={12}
      visible={false}
      application={app}
      onKeyPressEvent={handleWindowKeyPress}
      setup={(win) => {
        win.connect("notify::visible", () => {
          if (win.visible) {
            setQuery("")
            setCalcResult(null)
            setSelectedIndex(0)
            if (searchEntryWidget) {
              searchEntryWidget.text = ""
              searchEntryWidget.grab_focus()
            }
          }
        })
      }}
    >
      <box class={themeMode((m) => `launcher-card ${m === "light" ? "light-theme" : ""}`)} vertical>
        {/* Top Search Bar */}
        <box class="launcher-search-box" valign={Gtk.Align.CENTER}>
          <icon icon="system-search-symbolic" class="search-icon" />
          <entry
            hexpand
            placeholderText={loc("searchPlaceholder")}
            text={query}
            setup={(self) => {
              searchEntryWidget = self
            }}
            onChanged={(entry) => handleSearchChange(entry.text)}
            onActivate={handleEntryActivate}
          />
          <button
            class="qs-icon-btn"
            tooltipText={loc("clearSearch")}
            visible={query((q) => Boolean(q.trim()))}
            onClicked={() => {
              if (searchEntryWidget) searchEntryWidget.text = ""
              handleSearchChange("")
            }}
          >
            <icon icon="edit-clear-symbolic" class="btn-icon" />
          </button>
        </box>

        {/* Calculator Evaluation Result Card */}
        <box
          class="calculator-result-card"
          vertical
          visible={calcResult((res) => res !== null)}
        >
          <label label={query((q) => `${q} =`)} class="calc-query" xalign={0} />
          <label label={calcResult((res) => res || "")} class="calc-answer" xalign={0} />
        </box>

        {/* Extended: Terminal Run Command Action Card */}
        <With value={query}>
          {(q) =>
            q.trim().startsWith(">") ? (
              <button
                class="launcher-action-card"
                onClicked={() => runTerminalCommand(q)}
              >
                <box valign={Gtk.Align.CENTER}>
                  <icon icon="utilities-terminal-symbolic" class="action-icon" />
                  <box vertical hexpand>
                    <label label={`Run: ${q.slice(1).trim() || "..."}`} class="action-title" xalign={0} />
                    <label label="Execute in Ptyxis terminal" class="action-subtitle" xalign={0} />
                  </box>
                  <icon icon="go-next-symbolic" class="btn-icon" />
                </box>
              </button>
            ) : isUrl(q) ? (
              <button
                class="launcher-action-card"
                onClicked={() => openWebUrl(q)}
              >
                <box valign={Gtk.Align.CENTER}>
                  <icon icon="web-browser-symbolic" class="action-icon" />
                  <box vertical hexpand>
                    <label label={`Open: ${q.trim()}`} class="action-title" xalign={0} />
                    <label label="Open website in default browser" class="action-subtitle" xalign={0} />
                  </box>
                  <icon icon="go-next-symbolic" class="btn-icon" />
                </box>
              </button>
            ) : (
              <box />
            )
          }
        </With>

        {/* Scrollable Apps Grid */}
        <scrollable class="launcher-apps-scroll" vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER} hexpand vexpand>
          <box vertical spacing={6}>
            <With value={filteredApps}>
              {(appList) => {
                // Group into rows of 5 columns
                const rows: { app: Apps.Application; globalIndex: number }[][] = []
                for (let i = 0; i < appList.length; i += 5) {
                  const slice = appList.slice(i, i + 5).map((app, offset) => ({
                    app,
                    globalIndex: i + offset,
                  }))
                  rows.push(slice)
                }

                return (
                  <box vertical spacing={6}>
                    {rows.map((row) => (
                      <box spacing={6} homogeneous>
                        {row.map(({ app: appItem, globalIndex }) => (
                          <button
                            class={selectedIndex((sIdx) =>
                              `app-grid-tile ${sIdx === globalIndex ? "selected" : ""}`
                            )}
                            tooltipText={`${appItem.name}\n(Right-click to pin/unpin)`}
                            onClicked={() => launchApp(appItem)}
                            onButtonPressEvent={(_, event) => {
                              const [, button] = event.get_button()
                              if (button === 3) {
                                togglePinApp({
                                  name: appItem.name,
                                  icon: appItem.icon_name || "application-x-executable",
                                  cmd: appItem.executable || appItem.entry || appItem.name.toLowerCase(),
                                })
                                return true
                              }
                              return false
                            }}
                          >
                            <box vertical halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
                              <icon
                                icon={appItem.icon_name || "application-x-executable"}
                                class="grid-app-icon"
                              />
                              <label
                                label={appItem.name}
                                class="grid-app-label"
                                maxWidthChars={11}
                                ellipsize={3}
                              />
                              <With value={pinnedApps}>
                                {(pList) => {
                                  const pinned = pList.some(
                                    (p) =>
                                      p.name === appItem.name ||
                                      p.cmd === (appItem.executable || appItem.entry)
                                  )
                                  return pinned ? (
                                    <icon icon="starred-symbolic" class="app-pin-indicator" tooltipText="Pinned to Shelf" />
                                  ) : (
                                    <box />
                                  )
                                }}
                              </With>
                            </box>
                          </button>
                        ))}
                      </box>
                    ))}
                  </box>
                )
              }}
            </With>
          </box>
        </scrollable>
      </box>
    </window>
  )
}
