#!/usr/bin/env python3
"""Un faux lecteur de musique sur le bus de session, pour les captures : un morceau, en lecture."""
import sys
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

XML = """<node>
<interface name="org.mpris.MediaPlayer2">
  <method name="Raise"/><method name="Quit"/>
  <property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
  <property name="HasTrackList" type="b" access="read"/><property name="Identity" type="s" access="read"/>
  <property name="DesktopEntry" type="s" access="read"/>
  <property name="SupportedUriSchemes" type="as" access="read"/><property name="SupportedMimeTypes" type="as" access="read"/>
</interface>
<interface name="org.mpris.MediaPlayer2.Player">
  <method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/><method name="Stop"/><method name="Play"/>
  <method name="Seek"><arg type="x" direction="in"/></method>
  <method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>
  <signal name="Seeked"><arg type="x"/></signal>
  <property name="PlaybackStatus" type="s" access="read"/><property name="LoopStatus" type="s" access="readwrite"/>
  <property name="Rate" type="d" access="readwrite"/><property name="Shuffle" type="b" access="readwrite"/>
  <property name="Metadata" type="a{sv}" access="read"/><property name="Volume" type="d" access="readwrite"/>
  <property name="Position" type="x" access="read"/><property name="MinimumRate" type="d" access="read"/>
  <property name="MaximumRate" type="d" access="read"/><property name="CanGoNext" type="b" access="read"/>
  <property name="CanGoPrevious" type="b" access="read"/><property name="CanPlay" type="b" access="read"/>
  <property name="CanPause" type="b" access="read"/><property name="CanSeek" type="b" access="read"/>
  <property name="CanControl" type="b" access="read"/>
</interface></node>"""
cover = sys.argv[1]
V = GLib.Variant
PROPS = {
    "CanQuit": V("b", False), "CanRaise": V("b", True), "HasTrackList": V("b", False), "Identity": V("s", "Elisa"),
    "DesktopEntry": V("s", "org.kde.elisa"), "SupportedUriSchemes": V("as", []), "SupportedMimeTypes": V("as", []),
    "PlaybackStatus": V("s", "Playing"), "LoopStatus": V("s", "None"), "Rate": V("d", 1.0), "Shuffle": V("b", False),
    "Metadata": V("a{sv}", {"mpris:trackid": V("o", "/org/mpris/MediaPlayer2/Track/1"), "mpris:length": V("x", 213_000_000),
                            "mpris:artUrl": V("s", "file://" + cover), "xesam:title": V("s", "Teal Waves"),
                            "xesam:artist": V("as", ["Lagoon"]), "xesam:album": V("s", "Mocha")}),
    "Volume": V("d", 0.8), "Position": V("x", 99_000_000), "MinimumRate": V("d", 1.0), "MaximumRate": V("d", 1.0),
    "CanGoNext": V("b", True), "CanGoPrevious": V("b", True), "CanPlay": V("b", True), "CanPause": V("b", True),
    "CanSeek": V("b", True), "CanControl": V("b", True),
}
node = Gio.DBusNodeInfo.new_for_xml(XML)

def on_bus(connection, name):
    for interface in node.interfaces:
        connection.register_object("/org/mpris/MediaPlayer2", interface, lambda *a: a[-1].return_value(None),
                                   lambda c, s, p, i, prop: PROPS[prop], lambda *a: True)

Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2.elisa", Gio.BusNameOwnerFlags.NONE, on_bus, None, None)
GLib.MainLoop().run()
