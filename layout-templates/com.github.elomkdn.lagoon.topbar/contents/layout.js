// Lagoon top bar: full width, with floating applets. On the left, the launcher (App Grid if
// installed, else Plasma's), the virtual desktops and the global menu; in the middle, Teal
// Pill, which comes with Lagoon; on the right, the system tray and the clock.
var has = function (type) { return knownWidgetTypes.indexOf(type) >= 0; };

var panel = new Panel
panel.location = "top"
panel.height = 34
panel.lengthMode = "fill"
panel.floating = false
panel.floatingApplets = true

if (has("dev.xarbit.appgrid")) {
    var grid = panel.addWidget("dev.xarbit.appgrid")
    grid.currentConfigGroup = ["General"]
    grid.writeConfig("icon", "lagoon-launcher")
    grid.writeConfig("gridColumns", 6)
    grid.writeConfig("overrideRadius", true)
    grid.writeConfig("cornerRadius", 15)
    grid.writeConfig("systemFavorites", "suspend,hibernate,reboot,shutdown")
    grid.currentConfigGroup = ["Shortcuts"]
    grid.writeConfig("global", "Alt+F1")
} else {
    var launcher = panel.addWidget("org.kde.plasma.kickoff")
    launcher.currentConfigGroup = ["General"]
    launcher.writeConfig("icon", "lagoon-launcher")
    launcher.currentConfigGroup = ["Shortcuts"]
    launcher.writeConfig("global", "Alt+F1")
}

panel.addWidget("org.kde.plasma.pager")
panel.addWidget("org.kde.plasma.marginsseparator")
panel.addWidget("org.kde.plasma.appmenu")
panel.addWidget("org.kde.plasma.panelspacer")
if (has("com.github.elomkdn.tealpill")) {
    panel.addWidget("com.github.elomkdn.tealpill")
}
panel.addWidget("org.kde.plasma.panelspacer")

// the tray: Bluetooth, battery, brightness, network and sound in sight, the rest in its popup
var tray = panel.addWidget("org.kde.plasma.systemtray")
tray.currentConfigGroup = ["General"]
// Teal Pill already shows what is playing
tray.writeConfig("hiddenItems", "org.kde.plasma.mediacontroller")
tray.writeConfig("shownItems", "org.kde.plasma.bluetooth,org.kde.plasma.battery,org.kde.plasma.brightness,org.kde.plasma.networkmanagement,org.kde.plasma.volume")

var clock = panel.addWidget("org.kde.plasma.digitalclock")
clock.currentConfigGroup = ["Appearance"]
clock.writeConfig("dateDisplayFormat", "BesideTime")
clock.writeConfig("dateFormat", "custom")
clock.writeConfig("customDateFormat", "dddd dd MMM")
clock.writeConfig("autoFontAndSize", false)
clock.writeConfig("fontFamily", "Inter")
clock.writeConfig("fontSize", 9)
clock.writeConfig("fontStyleName", "Regular")
clock.writeConfig("fontWeight", 400)
