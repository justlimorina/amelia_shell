import app from "ags/gtk3/app"

export function toggleExclusive(targetName: string) {
  const popupNames = ["quicksettings", "calendar", "launcher", "settings"]

  const targetWin = app.get_window(targetName)
  const isCurrentlyVisible = targetWin ? targetWin.visible : false

  // 1. Close all other popups
  for (const name of popupNames) {
    if (name !== targetName) {
      const win = app.get_window(name)
      if (win) win.visible = false
    }
  }

  // 2. Toggle target window
  if (targetWin) {
    targetWin.visible = !isCurrentlyVisible
  } else {
    app.toggle_window(targetName)
  }
}

export function closeAllPopups() {
  const popupNames = ["quicksettings", "calendar", "launcher", "screencapture", "settings"]
  for (const name of popupNames) {
    const win = app.get_window(name)
    if (win) win.visible = false
  }
}
