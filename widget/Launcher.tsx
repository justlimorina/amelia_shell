import app from "ags/gtk3/app"
import { Astal, Gtk, Gdk } from "ags/gtk3"
import { createState, createBinding, With } from "ags"
import Apps from "gi://AstalApps"
import { themeMode } from "../lib/settings"
import { loc } from "../lib/i18n"

export default function Launcher() {
  const { BOTTOM, LEFT } = Astal.WindowAnchor
  const appsService = new Apps.Apps()

  const [query, setQuery] = createState("")
  const [calcResult, setCalcResult] = createState<string | null>(null)

  // Safe arithmetic evaluator for instant search calculator
  const evaluateMath = (text: string) => {
    const clean = text.trim()
    // Match only numbers, basic operators, parens
    if (/^[0-9\s\+\-\*\/\(\)\.\^\%]+$/.test(clean) && /[0-9]/.test(clean) && /[\+\-\*\/]/.test(clean)) {
      try {
        // Safe evaluation without access to globals
        const fn = new Function(`"use strict"; return (${clean});`)
        const res = fn()
        if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
          setCalcResult(String(res))
          return
        }
      } catch (_) {}
    }
    setCalcResult(null)
  }

  const handleSearchChange = (text: string) => {
    setQuery(text)
    evaluateMath(text)
  }

  // Filtered applications list
  const filteredApps = query((q) => {
    if (!q.trim()) {
      return appsService.list.slice(0, 30)
    }
    return appsService.fuzzy_query(q).slice(0, 25)
  })

  const launchApp = (appItem: Apps.Application) => {
    appItem.launch()
    app.toggle_window("launcher")
  }

  const handleEntryActivate = () => {
    const currentList = filteredApps.peek()
    if (currentList.length > 0) {
      launchApp(currentList[0])
    }
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
    >
      <box class={themeMode((m) => `launcher-card ${m === "light" ? "light-theme" : ""}`)} vertical>
        {/* Top Search Bar */}
        <box class="launcher-search-box" valign={Gtk.Align.CENTER}>
          <icon icon="system-search-symbolic" class="search-icon" />
          <entry
            hexpand
            placeholderText={loc("searchPlaceholder")}
            text={query}
            onChanged={(entry) => handleSearchChange(entry.text)}
            onActivate={handleEntryActivate}
          />
          <button
            class="qs-icon-btn"
            tooltipText={loc("clearSearch")}
            visible={query((q) => Boolean(q.trim()))}
            onClicked={() => handleSearchChange("")}
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

        {/* Scrollable Apps Grid */}
        <scrollable class="launcher-apps-scroll" vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER} hexpand vexpand>
          <box vertical spacing={6}>
            <With value={filteredApps}>
              {(appList) => {
                // Group into rows of 5 columns
                const rows: Apps.Application[][] = []
                for (let i = 0; i < appList.length; i += 5) {
                  rows.push(appList.slice(i, i + 5))
                }

                return (
                  <box vertical spacing={6}>
                    {rows.map((row) => (
                      <box spacing={6} homogeneous>
                        {row.map((appItem) => (
                          <button
                            class="app-grid-tile"
                            tooltipText={appItem.name}
                            onClicked={() => launchApp(appItem)}
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
