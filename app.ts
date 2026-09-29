import app from "ags/gtk3/app"
import style from "./style.scss"
import Shelf from "./widget/Shelf"
import QuickSettings from "./widget/QuickSettings"
import Launcher from "./widget/Launcher"
import ScreenCapture from "./widget/ScreenCapture"
import Calendar from "./widget/Calendar"

app.start({
  instanceName: "ags",
  css: style,
  main() {
    // 1. Create Shelf on all active monitors
    app.get_monitors().forEach((mon) => {
      Shelf(mon)
    })

    // 2. Create singleton overlay windows
    QuickSettings()
    Launcher()
    ScreenCapture()
    Calendar()
  },
})
