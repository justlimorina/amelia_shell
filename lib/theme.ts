import app from "ags/gtk3/app"

// These overrides are registered after the shell's base stylesheet so changes
// made in Settings take effect immediately without replacing the base theme.
export function applyAccentColor(color: string) {
  if (!/^#[0-9a-fA-F]{6}$/.test(color)) return

  app.apply_css(`
    .quicksettings-card .qs-pod.active,
    .option-pill-btn.active,
    .cal-day-cell.selected,
    .media-ctrl-btn.primary {
      background-color: ${color};
    }
    .quicksettings-card .qs-pod.active .pod-title,
    .quicksettings-card .qs-pod.active .pod-subtitle,
    .quicksettings-card .qs-pod.active .pod-icon,
    .option-pill-btn.active label,
    .cal-day-cell.selected .day-num {
      color: #062e6f;
    }
  `)
}

export function applyCornerRadius(radius: number) {
  if (!Number.isFinite(radius)) return
  const value = Math.round(Math.max(12, Math.min(36, radius)))
  app.apply_css(`
    .quicksettings-card,
    .calendar-card,
    .launcher-card,
    .settings-card { border-radius: ${value}px; }
    .qs-power-card { border-radius: ${Math.round(value * 0.7)}px; }
  `)
}
