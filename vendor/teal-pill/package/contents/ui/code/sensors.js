.pragma library

// What uses the camera or the screen, from the output of SENSORS_COMMAND: PipeWire's links, then
// who has a camera open without PipeWire (browsers often do).

var SENSORS_COMMAND = "LC_ALL=C pw-link -l 2>/dev/null; echo ---; LC_ALL=C fuser -v /dev/video* 2>&1";

function read(output) {
    const parts = String(output).split("\n---\n");
    let camera = false, screen = false, source = "";
    for (const line of (parts[0] ?? "").split("\n")) {
        if (!/^\s/.test(line)) {
            source = line;
            continue;
        }
        // plasmashell's links are the task manager's window previews
        const consumer = line.match(/\|->\s*(\S+)/);
        if (!consumer || consumer[1].startsWith("plasmashell:")) {
            continue;
        }
        camera = camera || /^(v4l2_input|libcamera_input)/.test(source);
        screen = screen || source.startsWith("kwin_wayland:");
    }
    // "/dev/video0:  elom  1234 F.... brave"; PipeWire keeps it open a while, after its own users
    for (const line of (parts[1] ?? "").split("\n")) {
        const user = line.match(/\s\d+\s+[A-Za-z.]{5}\s+(\S+)\s*$/);
        camera = camera || (user !== null && !/^(pipewire|wireplumber)/.test(user[1]));
    }
    return { camera: camera, screen: screen };
}
