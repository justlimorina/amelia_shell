import app from "ags/gtk3/app"
import style from "./style.scss"
import Shelf from "./widget/Shelf"
import QuickSettings from "./widget/QuickSettings"
import Launcher from "./widget/Launcher"
import ScreenCapture from "./widget/ScreenCapture"
import Calendar from "./widget/Calendar"
import Settings from "./widget/Settings"
import { closeAllPopups } from "./lib/window_manager"
import { accentColor, cornerRadius } from "./lib/settings"
import { applyAccentColor, applyCornerRadius } from "./lib/theme"

app.start({
  instanceName: "ags",
  css: style,
  requestHandler(request, res) {
    const reqStr = Array.isArray(request) ? request.join(" ") : String(request)
    if (reqStr.includes("close-popups") || reqStr.includes("close-all")) {
      closeAllPopups()
      res("ok")
    } else {
      res(`unknown request: ${reqStr}`)
    }
  },
  main() {
    applyAccentColor(accentColor())
    applyCornerRadius(cornerRadius())
    // 1. Create Shelf on all active monitors
    app.get_monitors().forEach((mon) => {
      Shelf(mon)
    })

    // 2. Create singleton overlay windows
    QuickSettings()
    Launcher()
    ScreenCapture()
    Calendar()
    Settings()
  },
})
