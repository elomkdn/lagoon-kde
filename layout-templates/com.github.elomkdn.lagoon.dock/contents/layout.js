// Lagoon dock: a floating, translucent dock at the bottom, fitted to its icons, that steps aside
// when a window covers it.
var panel = new Panel
panel.location = "bottom"
// 72 px: 64 px icons (Plasma rounds them down to 48, 64…) once the panel and task
// margins are taken off
panel.height = 72
panel.alignment = "center"
panel.lengthMode = "fit"
panel.hiding = "dodgewindows"
panel.floating = true
panel.opacity = "translucent"

// the launchers: System Settings, the terminal, the browser and the file manager; Shelly
// (CachyOS's package manager) and Spotify only where they are installed
var launchers = ["applications:systemsettings.desktop"]
if (applicationExists("com.shellyorg.shelly.desktop")) {
    launchers.push("applications:com.shellyorg.shelly.desktop")
}
launchers.push("applications:org.kde.konsole.desktop", "preferred://browser", "preferred://filemanager")
if (applicationExists("spotify.desktop")) {
    launchers.push("applications:spotify.desktop")
}

var tasks = panel.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", launchers.join(","))
