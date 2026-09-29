import { language } from "./settings"

export const translations = {
  en: {
    // Quick Settings
    wifi: "Wi-Fi",
    bluetooth: "Bluetooth",
    airplaneMode: "Airplane Mode",
    screenCapture: "Screen Capture",
    snippingTool: "Snipping tool",
    darkTheme: "Dark Theme",
    doNotDisturb: "Do Not Disturb",
    volume: "Volume",
    brightness: "Brightness",
    connected: "Connected",
    disconnected: "Disconnected",
    on: "On",
    off: "Off",
    silent: "Silent",
    back: "Back",
    wifiNetworks: "Wi-Fi Networks",
    btDevices: "Bluetooth Devices",
    scanningWifi: "Scanning Wi-Fi networks...",
    scanningBt: "Scanning Bluetooth devices...",
    noBtDevices: "No devices found",
    scan: "Scan",
    mute: "Mute / Unmute",
    lock: "Lock Screen",
    settings: "Settings",
    powerOff: "Power Off",
    collapse: "Collapse",
    paired: "Paired",
    disconnect: "Disconnect",
    connect: "Connect",

    // Launcher
    searchPlaceholder: "Search your apps, calculate...",
    clearSearch: "Clear search",
    calcQuery: "Calculation",

    // Calendar
    calendarTitle: "Calendar & Notifications",
    notifications: "Notifications",
    clearAll: "Clear All",
    noNotifications: "No new notifications",
    today: "Today",
    prevMonth: "Previous month",
    nextMonth: "Next month",

    // Shelf
    launcherTooltip: "Launcher",
    quickSettingsTooltip: "Quick Settings",
    calendarTooltip: "Calendar & Notifications",

    // Screen Capture
    selection: "Selection",
    screen: "Screen",
    window: "Window",
    takeScreenshot: "Take Screenshot",
    close: "Close",

    // Settings Window
    configTitle: "Amelia Shell Configuration",
    tabGeneral: "General",
    tabAppearance: "Appearance",
    tabShelf: "Shelf & Bar",
    tabShortcuts: "Shortcuts",
    tabAbout: "About",
    languageSetting: "Language",
    languageDesc: "Choose interface language for Amelia Shell",
    clockFormatSetting: "Clock Format",
    clockFormatDesc: "Use 24-hour time format in shelf and calendar",
    themeModeSetting: "Theme Mode",
    themeModeDesc: "Switch between Dark and Light color schemes",
    accentColorSetting: "Accent Color",
    accentColorDesc: "Choose Material You accent palette",
    shelfHeightSetting: "Shelf Height",
    shelfHeightDesc: "Adjust bottom taskbar height (pixels)",
    systemSettingsBtn: "Open System Settings",
    author: "Developer",
    version: "Version",
    runningOn: "Running on",
    waylandCompositor: "Wayland Compositor (Labwc)",
    openSystemInfo: "System Information",
  },
  vi: {
    // Quick Settings
    wifi: "Wi-Fi",
    bluetooth: "Bluetooth",
    airplaneMode: "Chế độ máy bay",
    screenCapture: "Chụp ảnh",
    snippingTool: "Công cụ cắt ảnh",
    darkTheme: "Giao diện tối",
    doNotDisturb: "Không làm phiền",
    volume: "Âm lượng",
    brightness: "Độ sáng",
    connected: "Đã kết nối",
    disconnected: "Chưa kết nối",
    on: "Bật",
    off: "Tắt",
    silent: "Im lặng",
    back: "Quay lại",
    wifiNetworks: "Mạng Wi-Fi",
    btDevices: "Thiết bị Bluetooth",
    scanningWifi: "Đang quét mạng Wi-Fi...",
    scanningBt: "Đang quét thiết bị Bluetooth...",
    noBtDevices: "Không tìm thấy thiết bị nào",
    scan: "Quét",
    mute: "Bật/Tắt âm",
    lock: "Khóa màn hình",
    settings: "Cài đặt",
    powerOff: "Tắt nguồn",
    collapse: "Thu gọn",
    paired: "Đã ghép nối",
    disconnect: "Ngắt",
    connect: "Kết nối",

    // Launcher
    searchPlaceholder: "Tìm ứng dụng, tính toán...",
    clearSearch: "Xóa tìm kiếm",
    calcQuery: "Phép tính",

    // Calendar
    calendarTitle: "Lịch & Trung tâm thông báo",
    notifications: "Thông báo",
    clearAll: "Xóa tất cả",
    noNotifications: "Không có thông báo mới",
    today: "Hôm nay",
    prevMonth: "Tháng trước",
    nextMonth: "Tháng sau",

    // Shelf
    launcherTooltip: "Trình khởi chạy",
    quickSettingsTooltip: "Cài đặt nhanh",
    calendarTooltip: "Lịch & Thông báo",

    // Screen Capture
    selection: "Vùng chọn",
    screen: "Toàn màn hình",
    window: "Cửa sổ",
    takeScreenshot: "Chụp màn hình",
    close: "Đóng",

    // Settings Window
    configTitle: "Cấu hình Amelia Shell",
    tabGeneral: "Chung",
    tabAppearance: "Giao diện",
    tabShelf: "Thanh tác vụ",
    tabShortcuts: "Phím tắt",
    tabAbout: "Giới thiệu",
    languageSetting: "Ngôn ngữ",
    languageDesc: "Chọn ngôn ngữ hiển thị cho Amelia Shell",
    clockFormatSetting: "Định dạng đồng hồ",
    clockFormatDesc: "Sử dụng định dạng 24 giờ trên thanh taskbar và lịch",
    themeModeSetting: "Chế độ giao diện",
    themeModeDesc: "Chuyển đổi giữa giao diện Sáng và Tối",
    accentColorSetting: "Màu chủ đạo",
    accentColorDesc: "Chọn bảng màu Material You",
    shelfHeightSetting: "Chiều cao thanh Shelf",
    shelfHeightDesc: "Điều chỉnh chiều cao thanh taskbar (pixel)",
    systemSettingsBtn: "Mở Cài đặt hệ thống",
    author: "Tác giả",
    version: "Phiên bản",
    runningOn: "Chạy trên",
    waylandCompositor: "Wayland Compositor (Labwc)",
    openSystemInfo: "Thông tin hệ thống",
  },
}

export type TranslationKey = keyof typeof translations.en

export function t(key: TranslationKey): string {
  const currentLang = language()
  const dict = translations[currentLang] || translations.en
  return dict[key] || translations.en[key] || key
}

export function loc(key: TranslationKey) {
  return language((lang) => {
    const dict = translations[lang] || translations.en
    return dict[key] || translations.en[key] || key
  })
}
