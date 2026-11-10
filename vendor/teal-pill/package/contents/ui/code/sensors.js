.pragma library

// What uses the camera or the screen, and who, from the output of SENSORS_COMMAND: PipeWire's
// links, then who has a camera open without PipeWire (browsers often do).

var SENSORS_COMMAND = "LC_ALL=C pw-link -l 2>/dev/null; echo ---; LC_ALL=C fuser -v /dev/video* 2>&1";

function read(output) {
    const parts = String(output).split("\n---\n");
    const cameraBy = new Set(), screenBy = new Set();
    let camera = false, screen = false, source = "";
    for (const line of (parts[0] ?? "").split("\n")) {
        if (!/^\s/.test(line)) {
            source = line;
            continue;
        }
        // plasmashell's links are the task manager's window previews
        const consumer = line.match(/\|->\s*(.+?)\s*$/);
        if (!consumer || consumer[1].startsWith("plasmashell:")) {
            continue;
        }
        const name = consumer[1].split(":")[0];
        if (/^(v4l2_input|libcamera_input)/.test(source)) {
            camera = true;
            cameraBy.add(name);
        }
        if (source.startsWith("kwin_wayland:")) {
            screen = true;
            screenBy.add(name);
        }
    }
    // "/dev/video0:  elom  1234 F.... brave"; PipeWire keeps it open a while, after its own users
    for (const line of (parts[1] ?? "").split("\n")) {
        const user = line.match(/\s\d+\s+[A-Za-z.]{5}\s+(\S+)\s*$/);
        if (user !== null && !/^(pipewire|wireplumber)/.test(user[1])) {
            camera = true;
            cameraBy.add(user[1]);
        }
    }
    return { camera: camera, screen: screen, cameraBy: Array.from(cameraBy), screenBy: Array.from(screenBy) };
}
