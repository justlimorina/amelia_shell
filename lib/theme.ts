import app from "ags/gtk3/app"

function rgba(hex: string, alpha: number) {
  const value = hex.slice(1)
  const red = parseInt(value.slice(0, 2), 16)
  const green = parseInt(value.slice(2, 4), 16)
  const blue = parseInt(value.slice(4, 6), 16)
  return `rgba(${red}, ${green}, ${blue}, ${alpha})`
}

function onColor(hex: string) {
  const value = hex.slice(1)
  const channels = [0, 2, 4].map((offset) => {
    const channel = parseInt(value.slice(offset, offset + 2), 16) / 255
    return channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
  })
  const luminance = channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
  return luminance > 0.38 ? "#1b1b1f" : "#f4eff4"
}

// These overrides are registered after the shell's base stylesheet so changes
// made in Settings take effect immediately without replacing the base theme.
export function applyAccentColor(color: string) {
  if (!/^#[0-9a-fA-F]{6}$/.test(color)) return
  const foreground = onColor(color)
  const container = rgba(color, 0.18)
  const outline = rgba(color, 0.5)

  app.apply_css(`
    .quicksettings-card .qs-pod.active,
    .quicksettings-card .qs-subview-toggle.active,
    .quicksettings-card .auth-action-btn.primary,
    .media-ctrl-btn.primary,
    .option-pill-btn.active,
    .action-btn,
    .capture-mode-btn.active,
    .capture-trigger-btn,
    .cal-day-cell.today {
      background-color: ${color};
    }
    .quicksettings-card .qs-pod.active .pod-title,
    .quicksettings-card .qs-pod.active .pod-subtitle,
    .quicksettings-card .qs-pod.active .pod-icon,
    .quicksettings-card .qs-subview-toggle.active label,
    .quicksettings-card .auth-action-btn.primary label,
    .media-ctrl-btn.primary .ctrl-icon,
    .option-pill-btn.active label,
    .action-btn label,
    .action-btn .btn-icon,
    .capture-mode-btn.active .mode-icon,
    .capture-mode-btn.active .mode-label,
    .capture-trigger-btn .trigger-icon,
    .cal-day-cell.today .day-num {
      color: ${foreground};
    }
    .quicksettings-card .qs-user-avatar,
    .quicksettings-card .qs-connecting-badge,
    .quicksettings-card .qs-list-item.active .list-title,
    .launcher-search-box .search-icon,
    .calculator-result-card .calc-answer,
    .app-pin-indicator,
    .settings-card .shortcut-key,
    .settings-card .about-logo,
    .settings-card .about-version,
    .cal-month-label,
    .cal-notifications-header .notif-clear-btn,
    .notif-action-btn label,
    .qs-device-action-badge,
    .media-art-icon,
    .launcher-action-card .action-icon {
      color: ${color};
    }
    .quicksettings-card .qs-device-action-badge,
    .quicksettings-card .qs-connecting-badge,
    .quicksettings-card .qs-list-item.active,
    .app-grid-tile.selected,
    .settings-card .settings-nav-btn.active,
    .calculator-result-card {
      background-color: ${container};
    }
    .settings-nav-btn.active .nav-label,
    .settings-nav-btn.active .nav-icon {
      color: ${color};
    }
    .launcher-search-box:focus-within {
      border-color: ${color};
    }
    .launcher-search-box entry {
      caret-color: ${color};
    }
    .launcher-action-card {
      background-color: ${container};
      border-color: ${outline};
    }
    .launcher-action-card:hover {
      background-color: ${rgba(color, 0.28)};
      border-color: ${color};
    }
    .cal-day-cell.today {
      border-color: ${color};
    }
    .cal-day-cell.selected {
      border-color: ${color};
      background-color: ${color};
    }
    .cal-day-cell.selected .day-num {
      color: ${foreground};
    }
    .media-progress-box scale highlight,
    .media-progress-box scale slider {
      background-color: ${color};
    }
    .qs-slider-row scale highlight,
    .qs-slider-row scale slider {
      background-color: ${color};
    }
    .quicksettings-card scale highlight,
    .quicksettings-card scale slider {
      background-color: ${color};
    }
  `)
}

export function applyCornerRadius(radius: number) {
  if (!Number.isFinite(radius)) return
  const value = Math.round(Math.max(12, Math.min(36, radius)))
  app.apply_css(`
    .quicksettings-card,
    .calendar-card,
    .launcher-card { border-radius: ${value}px; }
    .qs-power-card { border-radius: ${Math.round(value * 0.7)}px; }
  `)
}
