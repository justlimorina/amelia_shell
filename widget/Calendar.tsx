import app from "ags/gtk3/app"
import { Astal, Gtk } from "ags/gtk3"
import { createState, createBinding, With } from "ags"
import { createPoll } from "ags/time"
import Notifd from "gi://AstalNotifd"

export default function Calendar() {
  const { BOTTOM, RIGHT } = Astal.WindowAnchor
  const notifd = Notifd.get_default()

  // Real-time date formatted
  const fullDateStr = createPoll("", 1000, "date +'%A, %d %B %Y'")
  const timeNowStr = createPoll("", 1000, "date +'%H:%M'")

  // Calendar month/year navigation state
  const today = new Date()
  const [viewDate, setViewDate] = createState({
    year: today.getFullYear(),
    month: today.getMonth(), // 0-indexed
  })

  const prevMonth = () => {
    const cur = viewDate()
    if (cur.month === 0) {
      setViewDate({ year: cur.year - 1, month: 11 })
    } else {
      setViewDate({ year: cur.year, month: cur.month - 1 })
    }
  }

  const nextMonth = () => {
    const cur = viewDate()
    if (cur.month === 11) {
      setViewDate({ year: cur.year + 1, month: 0 })
    } else {
      setViewDate({ year: cur.year, month: cur.month + 1 })
    }
  }

  const resetToday = () => {
    const now = new Date()
    setViewDate({ year: now.getFullYear(), month: now.getMonth() })
  }

  const monthNames = [
    "Tháng 1", "Tháng 2", "Tháng 3", "Tháng 4", "Tháng 5", "Tháng 6",
    "Tháng 7", "Tháng 8", "Tháng 9", "Tháng 10", "Tháng 11", "Tháng 12"
  ]
  const weekDays = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

  // Notifications
  const notificationsList = createBinding(notifd, "notifications")

  return (
    <window
      name="calendar"
      class="CalendarWindow"
      anchor={BOTTOM | RIGHT}
      exclusivity={Astal.Exclusivity.NONE}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.ON_DEMAND}
      marginBottom={8}
      marginRight={12}
      visible={false}
      application={app}
    >
      <box class="calendar-card" vertical>
        {/* Header Pill: Full Date & Clock */}
        <box class="calendar-header-pill" vertical>
          <centerbox>
            <label label={fullDateStr} class="cal-date-big" $type="start" xalign={0} />
            <box $type="center" />
            <label label={timeNowStr} class="cal-date-big" $type="end" xalign={1} />
          </centerbox>
          <label label="Lịch & Trung tâm thông báo" class="cal-date-sub" xalign={0} />
        </box>

        {/* Month Navigation */}
        <centerbox class="calendar-nav-row" valign={Gtk.Align.CENTER}>
          <label
            label={viewDate((d) => `${monthNames[d.month]} ${d.year}`)}
            class="cal-month-label"
            $type="start"
            xalign={0}
          />
          <box $type="center" />
          <box $type="end" spacing={4} valign={Gtk.Align.CENTER}>
            <button class="qs-icon-btn" tooltipText="Tháng trước" onClicked={prevMonth}>
              <icon icon="go-previous-symbolic" class="btn-icon" />
            </button>
            <button class="qs-icon-btn" tooltipText="Hôm nay" onClicked={resetToday}>
              <icon icon="appointment-soon-symbolic" class="btn-icon" />
            </button>
            <button class="qs-icon-btn" tooltipText="Tháng sau" onClicked={nextMonth}>
              <icon icon="go-next-symbolic" class="btn-icon" />
            </button>
          </box>
        </centerbox>

        {/* Weekday Names Header */}
        <box spacing={2} homogeneous>
          {weekDays.map((day) => (
            <label label={day} class="cal-weekday-label" halign={Gtk.Align.CENTER} />
          ))}
        </box>

        {/* Calendar Day Grid Matrix */}
        <With value={viewDate}>
          {(vd) => {
            const firstDay = new Date(vd.year, vd.month, 1)
            // In Vietnam/Europe, week starts on Monday (1). Sunday is 0.
            let startDayIndex = firstDay.getDay() - 1
            if (startDayIndex === -1) startDayIndex = 6

            const daysInMonth = new Date(vd.year, vd.month + 1, 0).getDate()
            const daysInPrevMonth = new Date(vd.year, vd.month, 0).getDate()

            const cells: { num: number; currentMonth: boolean; isToday: boolean }[] = []

            // Previous month trailing days
            for (let i = startDayIndex - 1; i >= 0; i--) {
              cells.push({
                num: daysInPrevMonth - i,
                currentMonth: false,
                isToday: false,
              })
            }

            // Current month days
            const realToday = new Date()
            for (let d = 1; d <= daysInMonth; d++) {
              const isToday =
                realToday.getFullYear() === vd.year &&
                realToday.getMonth() === vd.month &&
                realToday.getDate() === d
              cells.push({ num: d, currentMonth: true, isToday })
            }

            // Next month leading days to complete 35 or 42 cells
            const totalCells = cells.length > 35 ? 42 : 35
            const nextDays = totalCells - cells.length
            for (let n = 1; n <= nextDays; n++) {
              cells.push({ num: n, currentMonth: false, isToday: false })
            }

            // Group into 7 columns per row
            const rows: typeof cells[] = []
            for (let i = 0; i < cells.length; i += 7) {
              rows.push(cells.slice(i, i + 7))
            }

            return (
              <box vertical spacing={2}>
                {rows.map((row) => (
                  <box spacing={2} homogeneous>
                    {row.map((c) => (
                      <button
                        class={`cal-day-cell ${c.isToday ? "today" : ""} ${
                          !c.currentMonth ? "other-month" : ""
                        }`}
                        halign={Gtk.Align.CENTER}
                        valign={Gtk.Align.CENTER}
                      >
                        <label label={String(c.num)} class="day-num" />
                      </button>
                    ))}
                  </box>
                ))}
              </box>
            )
          }}
        </With>

        {/* Notifications Section */}
        <box class="cal-notifications-header" valign={Gtk.Align.CENTER}>
          <label label="Thông báo" class="notif-section-title" hexpand xalign={0} />
          <With value={notificationsList}>
            {(notifs) =>
              notifs.length > 0 ? (
                <button
                  class="notif-clear-btn"
                  onClicked={() => {
                    for (const n of notifs) n.dismiss()
                  }}
                >
                  <label label="Xóa tất cả" />
                </button>
              ) : (
                <box />
              )
            }
          </With>
        </box>

        {/* Notification list */}
        <scrollable class="qs-subview-scroll" vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER}>
          <box vertical spacing={4}>
            <With value={notificationsList}>
              {(notifs) =>
                notifs.length > 0 ? (
                  <box vertical spacing={4}>
                    {notifs.map((n) => (
                      <box class="notif-item" vertical>
                        <centerbox>
                          <label label={n.summary} class="notif-title" $type="start" xalign={0} ellipsize={3} />
                          <box $type="center" />
                          <button class="qs-icon-btn" onClicked={() => n.dismiss()} $type="end">
                            <icon icon="window-close-symbolic" class="btn-icon" />
                          </button>
                        </centerbox>
                        {n.body ? <label label={n.body} class="notif-body" xalign={0} wrap /> : <box />}
                      </box>
                    ))}
                  </box>
                ) : (
                  <label
                    label="Không có thông báo mới"
                    class="cal-date-sub"
                    xalign={0.5}
                    margin={12}
                  />
                )
              }
            </With>
          </box>
        </scrollable>
      </box>
    </window>
  )
}
