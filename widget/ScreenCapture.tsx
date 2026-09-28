import app from "ags/gtk3/app"
import { Astal, Gtk } from "ags/gtk3"
import { createState } from "ags"
import { execAsync } from "ags/process"

type CaptureMode = "selection" | "screen" | "window"

export default function ScreenCapture() {
  const { BOTTOM } = Astal.WindowAnchor
  const [mode, setMode] = createState<CaptureMode>("selection")

  const takeScreenshot = () => {
    // 1. Immediately hide the capture UI so it doesn't appear in the screenshot
    const win = app.get_window("screencapture")
    if (win) win.visible = false

    const currentMode = mode()

    // 2. Prepare destination path in ~/Pictures/Screenshots
    const script = `
      DIR="$HOME/Pictures/Screenshots"
      mkdir -p "$DIR"
      FILE="$DIR/Screenshot from $(date +'%Y-%m-%d %H-%M-%S').png"

      if [ "${currentMode}" = "selection" ]; then
        GEOM=$(slurp) || exit 0
        grim -g "$GEOM" "$FILE"
      elif [ "${currentMode}" = "window" ]; then
        GEOM=$(slurp -s "#00000000" -B "#ffffff18") || exit 0
        grim -g "$GEOM" "$FILE"
      else
        # Full screen mode
        grim "$FILE"
      fi

      if [ -f "$FILE" ]; then
        wl-copy < "$FILE" 2>/dev/null || true
        notify-send -a "Screen Capture" -i "$FILE" "Screenshot Captured" "Saved to Screenshots and copied to clipboard."
      fi
    `

    // Small delay for smooth dismissal before freeze/slurp
    setTimeout(() => {
      execAsync(["bash", "-c", script]).catch(console.error)
    }, 120)
  }

  return (
    <window
      name="screencapture"
      class="ScreenCaptureWindow"
      anchor={BOTTOM}
      exclusivity={Astal.Exclusivity.NONE}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.ON_DEMAND}
      marginBottom={76}
      visible={false}
      application={app}
    >
      <box class="screencapture-pill" valign={Gtk.Align.CENTER}>
        {/* Mode Selector Segment: Selection, Screen, Window */}
        <box class="capture-mode-segment" valign={Gtk.Align.CENTER}>
          {/* Mode 1: Selection */}
          <button
            class={mode((m) => `capture-mode-btn ${m === "selection" ? "active" : ""}`)}
            tooltipText="Selection"
            onClicked={() => setMode("selection")}
          >
            <box valign={Gtk.Align.CENTER}>
              <icon icon="edit-select-all-symbolic" class="mode-icon" />
              <label label="Selection" class="mode-label" />
            </box>
          </button>

          {/* Mode 2: Screen */}
          <button
            class={mode((m) => `capture-mode-btn ${m === "screen" ? "active" : ""}`)}
            tooltipText="Screen"
            onClicked={() => setMode("screen")}
          >
            <box valign={Gtk.Align.CENTER}>
              <icon icon="video-display-symbolic" class="mode-icon" />
              <label label="Screen" class="mode-label" />
            </box>
          </button>

          {/* Mode 3: Window */}
          <button
            class={mode((m) => `capture-mode-btn ${m === "window" ? "active" : ""}`)}
            tooltipText="Window"
            onClicked={() => setMode("window")}
          >
            <box valign={Gtk.Align.CENTER}>
              <icon icon="window-maximize-symbolic" class="mode-icon" />
              <label label="Window" class="mode-label" />
            </box>
          </button>
        </box>

        {/* Capture Trigger Button */}
        <button
          class="capture-trigger-btn"
          tooltipText="Take Screenshot"
          onClicked={takeScreenshot}
          valign={Gtk.Align.CENTER}
        >
          <icon icon="camera-photo-symbolic" class="trigger-icon" />
        </button>

        {/* Close Button */}
        <button
          class="capture-close-btn"
          tooltipText="Close"
          onClicked={() => {
            const win = app.get_window("screencapture")
            if (win) win.visible = false
          }}
          valign={Gtk.Align.CENTER}
        >
          <icon icon="window-close-symbolic" class="close-icon" />
        </button>
      </box>
    </window>
  )
}
