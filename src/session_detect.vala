namespace MouseScales {
    public enum SessionKind {
        X11,
        WAYLAND,
        UNKNOWN
    }

    public enum CompositorKind {
        NONE,
        HYPRLAND,
        SWAY,
        OTHER
    }

    public class SessionDetect : Object {
        public static SessionKind session_kind() {
            var session_type = Environment.get_variable("XDG_SESSION_TYPE");
            if (session_type == null) {
                if (Environment.get_variable("WAYLAND_DISPLAY") != null) {
                    return SessionKind.WAYLAND;
                }
                if (Environment.get_variable("DISPLAY") != null) {
                    return SessionKind.X11;
                }
                return SessionKind.UNKNOWN;
            }
            var lowered = session_type.down();
            if (lowered == "wayland") {
                return SessionKind.WAYLAND;
            }
            if (lowered == "x11") {
                return SessionKind.X11;
            }
            return SessionKind.UNKNOWN;
        }

        public static CompositorKind compositor_kind() {
            var desktop = Environment.get_variable("XDG_CURRENT_DESKTOP") ?? "";
            var session_desktop = Environment.get_variable("XDG_SESSION_DESKTOP") ?? "";
            var combined = (desktop + ":" + session_desktop).down();

            if ("hyprland" in combined
                || Environment.find_program_in_path("hyprctl") != null
                    && Environment.get_variable("HYPRLAND_INSTANCE_SIGNATURE") != null) {
                return CompositorKind.HYPRLAND;
            }
            if ("sway" in combined
                || Environment.get_variable("SWAYSOCK") != null) {
                return CompositorKind.SWAY;
            }
            if (session_kind() == SessionKind.WAYLAND) {
                return CompositorKind.OTHER;
            }
            return CompositorKind.NONE;
        }

        public static string compositor_label(CompositorKind kind) {
            switch (kind) {
            case CompositorKind.HYPRLAND:
                return "Hyprland";
            case CompositorKind.SWAY:
                return "Sway";
            case CompositorKind.OTHER:
                return "Wayland (other)";
            case CompositorKind.NONE:
                return "None";
            }
            assert_not_reached();
        }

        /** Optional note shown on the Wayland page. */
        public static string wayland_note_text(CompositorKind compositor) {
            var lines = new GenericArray<string>();
            lines.add("Wayland has no portable extra scale like X11 Coordinate Transformation Matrix.");
            lines.add("Desktop Settings Accel Speed still tops out around −1…1.");
            lines.add("Reported DPI (udev) can make many mice feel faster after a replug.");
            if (compositor == CompositorKind.HYPRLAND || compositor == CompositorKind.SWAY) {
                lines.add(
                    "This session looks like %s — compositor extras below can raise feel further.".printf(
                        compositor_label(compositor)
                    )
                );
            } else {
                lines.add(
                    "Tiling compositors such as Hyprland/Sway may expose sensitivity or custom accel outside generic desktop Settings."
                );
            }
            return string.joinv("\n", lines.data);
        }
    }
}
