import { Gtk } from "ags/gtk3"

let settingsWindow: Gtk.ApplicationWindow | null = null

export function registerSettingsWindow(window: Gtk.ApplicationWindow) {
  settingsWindow = window
}

export function showSettingsWindow() {
  settingsWindow?.present()
}

export function toggleSettingsWindow() {
  if (!settingsWindow) return

  if (settingsWindow.visible) {
    settingsWindow.hide()
  } else {
    settingsWindow.present()
  }
}
