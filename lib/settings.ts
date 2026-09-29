import { createState } from "ags"
import GLib from "gi://GLib"
import Gio from "gi://Gio"

export interface AmeliaConfig {
  language: "en" | "vi"
  themeMode: "dark" | "light"
  accentColor: string
  clock24h: boolean
  shelfHeight: number
  cornerRadius: number
}

const DEFAULT_CONFIG: AmeliaConfig = {
  language: "en", // English by default
  themeMode: "dark",
  accentColor: "#a8c7fa",
  clock24h: true,
  shelfHeight: 56,
  cornerRadius: 28,
}

const CONFIG_DIR = GLib.build_filenamev([GLib.get_user_config_dir(), "amelia"])
const CONFIG_PATH = GLib.build_filenamev([CONFIG_DIR, "settings.json"])

function loadInitialConfig(): AmeliaConfig {
  try {
    const file = Gio.File.new_for_path(CONFIG_PATH)
    if (file.query_exists(null)) {
      const [, contents] = file.load_contents(null)
      const parsed = JSON.parse(new TextDecoder("utf-8").decode(contents))
      return { ...DEFAULT_CONFIG, ...parsed }
    }
  } catch (err) {
    console.error("Failed to load settings.json, using defaults:", err)
  }
  return DEFAULT_CONFIG
}

function saveConfigToFile(cfg: AmeliaConfig) {
  try {
    const dir = Gio.File.new_for_path(CONFIG_DIR)
    if (!dir.query_exists(null)) {
      dir.make_directory_with_parents(null)
    }
    const file = Gio.File.new_for_path(CONFIG_PATH)
    const jsonStr = JSON.stringify(cfg, null, 2)
    file.replace_contents(
      jsonStr,
      null,
      false,
      Gio.FileCreateFlags.REPLACE_DESTINATION,
      null
    )
  } catch (err) {
    console.error("Failed to save settings.json:", err)
  }
}

const initial = loadInitialConfig()

// Reactive state values
export const [language, setLanguageState] = createState<"en" | "vi">(initial.language)
export const [themeMode, setThemeModeState] = createState<"dark" | "light">(initial.themeMode)
export const [accentColor, setAccentColorState] = createState<string>(initial.accentColor)
export const [clock24h, setClock24hState] = createState<boolean>(initial.clock24h)
export const [shelfHeight, setShelfHeightState] = createState<number>(initial.shelfHeight)
export const [cornerRadius, setCornerRadiusState] = createState<number>(initial.cornerRadius)

function persistCurrent() {
  saveConfigToFile({
    language: language(),
    themeMode: themeMode(),
    accentColor: accentColor(),
    clock24h: clock24h(),
    shelfHeight: shelfHeight(),
    cornerRadius: cornerRadius(),
  })
}

export function setLanguage(lang: "en" | "vi") {
  setLanguageState(lang)
  persistCurrent()
}

export function setThemeMode(mode: "dark" | "light") {
  setThemeModeState(mode)
  persistCurrent()
}

export function setAccentColor(color: string) {
  setAccentColorState(color)
  persistCurrent()
}

export function setClock24h(val: boolean) {
  setClock24hState(val)
  persistCurrent()
}

export function setShelfHeight(val: number) {
  setShelfHeightState(val)
  persistCurrent()
}

export function setCornerRadius(val: number) {
  setCornerRadiusState(val)
  persistCurrent()
}
