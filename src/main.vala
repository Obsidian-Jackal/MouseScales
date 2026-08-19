/**
 * Mouse Scales — GTK4 UI for pointer speed on X11 (libinput + Coordinate Transformation Matrix) and
 * Wayland (reported DPI via udev, optional Hyprland/Sway extras).
 */
int main(string[] argv) {
    var application = new MouseScales.Application();
    return application.run(argv);
}
