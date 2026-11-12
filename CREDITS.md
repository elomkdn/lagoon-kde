# Credits

Lagoon is a derivative work. It is distributed under the
[GPL-3.0-or-later](LICENSE), which is compatible with the licenses of every
component below.

| Component | Used for | Author | License |
|---|---|---|---|
| [CachyOS Nord KDE](https://github.com/CachyOS/CachyOS-Nord-KDE) | Origin of the Plasma theme (`plasma/desktoptheme/Lagoon`): its panels, popups and widgets, recolored and reshaped | CachyOS, Dharam Dhurandhar | GPL-3.0-or-later |
| [Catppuccin KDE](https://github.com/catppuccin/kde) | Mocha Teal color scheme, Catppuccin Mocha Classic window decoration (`vendor/catppuccin-kde`) | Catppuccin | MIT |
| [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) v6.5 | GTK theme (`vendor/adw-gtk3`): the libadwaita look for GTK 3 and GTK 4 apps, recolored by `gtk/build-gtk.py` | lassekongo83 | LGPL-2.1 |
| [MacTahoe KDE](https://github.com/vinceliuice/MacTahoe-kde) | Slider and switch widgets (`plasma/desktoptheme/Lagoon/widgets/`), with round knobs; the splash screen (`plasma/look-and-feel/Lagoon/contents/splash/Splash.qml`) is based on its splash | Vince Liuice | GPL-3.0 / LGPL-3.0 |
| [KvLibadwaita](https://github.com/GabePoel/KvLibadwaita) | Base of the Kvantum style (`vendor/kvlibadwaita`), itself based on [Colloid KDE](https://github.com/vinceliuice/Colloid-kde) by Vince Liuice | GabePoel, Vince Liuice | GPL-3.0 |
| [CachyOS Settings](https://github.com/CachyOS/CachyOS-Settings) | CachyOS logo on the wallpaper and the splash screen (`wallpapers/cachyos-logo.svg`) | CachyOS | GPL-1.0-only |
| [Teal](https://github.com/elomkdn/teal-icons) | The icon theme, included in the release archive (from a clone, downloaded from its release); made from Adwair (kusaida) and Papirus (Papirus Development Team) | Elom, kusaida, Papirus Development Team | GPL-3.0 |
| [Teal Pill](https://github.com/elomkdn/teal-pill) | The top bar's music island, included (`vendor/teal-pill`, a copy of its repository's `package/` and `po/`); itself based on PlasMusic Toolbar by Claudio Catterina | Elom, Claudio Catterina | GPL-3.0-or-later |
| [Catppuccin palette](https://github.com/catppuccin/palette) | Mocha colors | Catppuccin | MIT |
| [Catppuccin cursors](https://github.com/catppuccin/cursors) v2.0.0 | Mocha Teal cursors, included unmodified (`vendor/catppuccin-cursors`) as a separate work, based on Volantes Cursors by Alexey Varfolomeev | Catppuccin | GPL-2.0 |

The wallpaper (`wallpapers/make-wallpaper.py`) is an original drawing inspired by
the official CachyOS wallpaper. Because it contains the CachyOS logo, whose package
declares GPL-1.0-only (not compatible with GPL-3.0), the generated images that
contain the logo (wallpaper, splash screen logo) are distributed separately under
GPL-1.0-only, as an aggregate with the rest of the theme. The CachyOS name and logo are trademarks of the CachyOS project.

The Catppuccin cursors are GPL-2.0: they are included unmodified, as a separate work
aggregated with the theme, under their own license (`LICENSE` in their archive).

## Recommended, not included

These are not redistributed; install them from your distribution:

| Component | Why | License |
|---|---|---|
| [Kvantum](https://github.com/tsujan/Kvantum) | Optional application style engine for the Kvantum style | GPL-3.0-or-later |
| [Klassy](https://github.com/paulmcauley/klassy) | Optional rounded window decoration; only its configuration is included (`extras/klassy/klassyrc`) | GPL-2.0 / GPL-3.0 / LGPL-2.1 / MIT (per file) |