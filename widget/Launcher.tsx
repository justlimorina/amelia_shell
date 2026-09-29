import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { createState, createBinding, With } from "ags"
import { execAsync } from "ags/process"
import Apps from "gi://AstalApps"
import GLib from "gi://GLib"
import { themeMode, togglePinApp, isAppPinned, pinnedApps } from "../lib/settings"
import { loc, t } from "../lib/i18n"
import { evaluateSafeMath } from "../lib/calculator"

export default function Launcher() {
  const { BOTTOM, LEFT } = Astal.WindowAnchor
  const appsService = new Apps.Apps()

  const [query, setQuery] = createState("")
  const [calcResult, setCalcResult] = createState<string | null>(null)
  const [selectedIndex, setSelectedIndex] = createState(0)
  const [fileMatches, setFileMatches] = createState<string[]>([])
  const [searchedFileTerm, setSearchedFileTerm] = createState("")
  const [isSearchingFiles, setIsSearchingFiles] = createState(false)
  const [fileSearchError, setFileSearchError] = createState<string | null>(null)

  let searchEntryWidget: Gtk.Entry | null = null

  const handleSearchChange = (text: string) => {
    setQuery(text)
    setSelectedIndex(0)
    setFileMatches([])
    setSearchedFileTerm("")
    setFileSearchError(null)

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
    if (trimmed.startsWith(">") || trimmed.startsWith("?") || isUrl(trimmed)) {
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

  const searchFiles = async (text: string) => {
    const term = text.trim().replace(/^\?\s*/, "")
    if (!term || isSearchingFiles()) return
    setIsSearchingFiles(true)
    setFileSearchError(null)
    setFileMatches([])
    setSearchedFileTerm("")
    const home = GLib.get_home_dir()
    const filePattern = `*${term.replace(/[\\*?\[\]]/g, "\\$&")}*`
    try {
      const out = await execAsync([
        "find", home, "-maxdepth", "5", "-type", "d",
        "(", "-name", ".cache", "-o", "-name", ".local", "-o", "-name", "node_modules", "-o", "-name", ".config", ")",
        "-prune", "-o", "-type", "f", "-iname", filePattern, "-print",
      ])
      if (query().trim().replace(/^\?\s*/, "") !== term) return
      setFileMatches(out.split("\n").map((path) => path.trim()).filter(Boolean).slice(0, 12))
      setSearchedFileTerm(term)
    } catch (err) {
      console.error("File search failed:", err)
      setFileSearchError(t("fileSearchFailed"))
    } finally {
      setIsSearchingFiles(false)
    }
  }

  const openFile = (path: string) => {
    execAsync(["gio", "open", path]).then(() => {
      app.toggle_window("launcher")
    }).catch((err) => {
      console.error("Could not open file:", err)
      setFileSearchError(t("fileOpenFailed"))
    })
  }

  const handleEntryActivate = () => {
    const q = query().trim()

    // 1. Terminal command
    if (q.startsWith(">")) {
      runTerminalCommand(q)
      return
    }

    if (q.startsWith("?")) {
      void searchFiles(q)
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
      if (keyval === Gdk.KEY_Right) {
        setSelectedIndex((cur) => Math.min(cur + 1, currentList.length - 1))
        return true
      }
      if (keyval === Gdk.KEY_Left) {
        setSelectedIndex((cur) => Math.max(cur - 1, 0))
        return true
      }
      if (keyval === Gdk.KEY_Tab) {
        setSelectedIndex((cur) => (cur + 1) % currentList.length)
        return true
      }
    }

    return false
  }

  const win = (
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
    >
      <box class={themeMode((m) => `launcher-card ${m === "light" ? "light-theme" : ""}`)} vertical>
        {/* Top Search Bar */}
        <box class="launcher-search-box" valign={Gtk.Align.CENTER}>
          <icon icon="system-search-symbolic" class="search-icon" />
          <entry
            hexpand
            placeholderText={loc("searchPlaceholder")}
            text={query}
            $={(self) => {
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

        {/* Search local files with the ? prefix, for example: ? report */}
        <With value={query}>
          {(q) => q.trim().startsWith("?") ? (
            <box class="launcher-file-search" vertical spacing={6}>
              <button class="launcher-action-card" onClicked={() => void searchFiles(query())} sensitive={isSearchingFiles((s) => !s)}>
                <box valign={Gtk.Align.CENTER}>
                  <icon icon="system-search-symbolic" class="action-icon" />
                  <box vertical hexpand>
                    <label label={isSearchingFiles((searching) => searching ? t("searchingFiles") : t("searchFiles"))} class="action-title" xalign={0} />
                    <label label={q.trim().slice(1).trim() || t("fileSearchHint")} class="action-subtitle" xalign={0} />
                  </box>
                  <icon icon="go-next-symbolic" class="btn-icon" />
                </box>
              </button>
              <With value={fileSearchError}>
                {(err) => err ? <label label={err} class="action-subtitle" xalign={0} /> : <box />}
              </With>
              <With value={fileMatches}>
                {(matches) => matches.length ? (
                  <box vertical spacing={4}>
                    {matches.map((path) => (
                      <button class="launcher-file-result" onClicked={() => openFile(path)}>
                        <box vertical>
                          <label label={path.split("/").pop() || path} class="action-title" xalign={0} ellipsize={3} />
                          <label label={path} class="action-subtitle" xalign={0} ellipsize={3} />
                        </box>
                      </button>
                    ))}
                  </box>
                ) : <box />}
              </With>
              <With value={searchedFileTerm}>
                {(searched) => searched === q.trim().replace(/^\?\s*/, "") && !fileMatches().length && !fileSearchError()
                  ? <label label={loc("noFilesFound")} class="action-subtitle" xalign={0} />
                  : <box />}
              </With>
            </box>
          ) : <box />}
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
  ) as Astal.Window

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

  return win
}
