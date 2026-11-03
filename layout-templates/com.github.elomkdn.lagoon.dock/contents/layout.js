// Lagoon dock: a floating, opaque dock at the bottom, fitted to its icons, that steps aside
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
panel.opacity = "opaque"

var tasks = panel.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("launchers", "applications:systemsettings.desktop,applications:com.shellyorg.shelly.desktop,applications:org.kde.konsole.desktop,preferred://browser,preferred://filemanager,applications:spotify.desktop")
