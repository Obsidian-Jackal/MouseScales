namespace MouseScales {
    public class WaylandPointerDevice {
        public string name;
        public string? event_node;
        public string? sys_path;

        public WaylandPointerDevice(string name, string? event_node, string? sys_path) {
            this.name = name;
            this.event_node = event_node;
            this.sys_path = sys_path;
        }
    }

    /**
     * Wayland helpers: list pointers, reported DPI via udev/hwdb,
     * and Hyprland/Sway compositor extras.
     */
    public class WaylandBackend : Object {
        public const string HWDB_FILENAME = "61-mouse-scales-dpi.hwdb";
        public const string HYPR_DROPIN = "mouse-scales.conf";
        public const string SWAY_DROPIN = "mouse-scales";

        public static string config_home() {
            return Environment.get_user_config_dir();
        }

        public static string data_home() {
            return Path.build_filename(Environment.get_user_data_dir(), "mouse-scales");
        }

        public static string staged_hwdb_path() {
            return Path.build_filename(data_home(), HWDB_FILENAME);
        }

        public static string system_hwdb_path() {
            return Path.build_filename("/etc/udev/hwdb.d", HWDB_FILENAME);
        }

        public static string hypr_dropin_path() {
            return Path.build_filename(config_home(), "hypr", HYPR_DROPIN);
        }

        public static string sway_dropin_path() {
            return Path.build_filename(config_home(), "sway", "config.d", SWAY_DROPIN);
        }

        public static string legacy_data_home() {
            return Path.build_filename(Environment.get_user_data_dir(), "mouse-ctm-scale");
        }

        public static string legacy_staged_hwdb_path() {
            return Path.build_filename(legacy_data_home(), "61-mouse-ctm-scale-dpi.hwdb");
        }

        public static string legacy_system_hwdb_path() {
            return "/etc/udev/hwdb.d/61-mouse-ctm-scale-dpi.hwdb";
        }

        public static string legacy_hypr_dropin_path() {
            return Path.build_filename(config_home(), "hypr", "mouse-ctm-scale.conf");
        }

        public static string legacy_sway_dropin_path() {
            return Path.build_filename(config_home(), "sway", "config.d", "mouse-ctm-scale");
        }

        public static WaylandPointerDevice[] list_pointer_devices() throws Error {
            var devices = list_from_proc_input();
            if (devices.length > 0) {
                return devices;
            }
            return list_from_libinput();
        }

        static WaylandPointerDevice[] list_from_proc_input() throws Error {
            string contents;
            try {
                FileUtils.get_contents("/proc/bus/input/devices", out contents);
            } catch (Error err) {
                return {};
            }

            var results = new GenericArray<WaylandPointerDevice>();
            string? current_name = null;
            string? current_event = null;
            string? current_sys = null;
            bool looks_like_pointer = false;

            foreach (var raw_line in contents.split("\n")) {
                var line = raw_line.strip();
                if (line.length == 0) {
                    if (looks_like_pointer && current_name != null && current_name.length > 0) {
                        results.add(
                            new WaylandPointerDevice(current_name, current_event, current_sys)
                        );
                    }
                    current_name = null;
                    current_event = null;
                    current_sys = null;
                    looks_like_pointer = false;
                    continue;
                }
                if (line.has_prefix("N: Name=")) {
                    current_name = line.substring(8).strip();
                    if (current_name.has_prefix("\"") && current_name.has_suffix("\"")) {
                        current_name = current_name.substring(1, current_name.length - 2);
                    }
                } else if (line.has_prefix("S: Sysfs=")) {
                    current_sys = line.substring(9).strip();
                } else if (line.has_prefix("H: Handlers=")) {
                    var handlers = line.substring(12);
                    looks_like_pointer = "mouse" in handlers;
                    foreach (var token in handlers.split(" ")) {
                        if (token.has_prefix("event")) {
                            current_event = token;
                        }
                    }
                }
            }
            if (looks_like_pointer && current_name != null && current_name.length > 0) {
                results.add(new WaylandPointerDevice(current_name, current_event, current_sys));
            }
            return results.data;
        }

        static WaylandPointerDevice[] list_from_libinput() throws Error {
            if (Environment.find_program_in_path("libinput") == null) {
                return {};
            }
            string standard_output;
            string standard_error;
            int exit_status;
            Process.spawn_command_line_sync(
                "libinput list-devices",
                out standard_output,
                out standard_error,
                out exit_status
            );
            if (exit_status != 0) {
                throw new IOError.FAILED(
                    "libinput list-devices failed: %s".printf(standard_error.strip())
                );
            }

            var results = new GenericArray<WaylandPointerDevice>();
            string? name = null;
            string? kernel = null;
            bool is_pointer = false;

            foreach (var raw_line in standard_output.split("\n")) {
                var line = raw_line.strip();
                if (line.has_prefix("Device:")) {
                    if (is_pointer && name != null) {
                        results.add(new WaylandPointerDevice(name, kernel, null));
                    }
                    name = line.substring(7).strip();
                    kernel = null;
                    is_pointer = false;
                } else if (line.has_prefix("Kernel:")) {
                    var path = line.substring(7).strip();
                    kernel = Path.get_basename(path);
                } else if (line.has_prefix("Capabilities:")) {
                    is_pointer = "pointer" in line.down();
                }
            }
            if (is_pointer && name != null) {
                results.add(new WaylandPointerDevice(name, kernel, null));
            }
            return results.data;
        }

        public static int? read_reported_dpi(WaylandPointerDevice device) {
            if (device.event_node == null) {
                return null;
            }
            var node_path = Path.build_filename("/dev/input", device.event_node);
            if (Environment.find_program_in_path("udevadm") == null) {
                return null;
            }
            try {
                string standard_output;
                string standard_error;
                int exit_status;
                string[] argv = {
                    "udevadm", "info", "--query=property", "--name=%s".printf(node_path)
                };
                Process.spawn_sync(
                    null,
                    argv,
                    Environ.get(),
                    SpawnFlags.SEARCH_PATH,
                    null,
                    out standard_output,
                    out standard_error,
                    out exit_status
                );
                if (exit_status != 0) {
                    return null;
                }
                foreach (var line in standard_output.split("\n")) {
                    if (line.has_prefix("MOUSE_DPI=")) {
                        var value = line.substring(10).strip();
                        // Forms: 1600 or 1600@1000
                        var at = value.index_of("@");
                        var dpi_text = at >= 0 ? value.substring(0, at) : value;
                        int dpi;
                        if (int.try_parse(dpi_text, out dpi)) {
                            return dpi;
                        }
                    }
                }
            } catch (Error err) {
                return null;
            }
            return null;
        }

        public static string build_hwdb_snippet(string device_name, int dpi) {
            // libinput hwdb match by device name.
            return """# Generated by mouse-scales — reported DPI for Wayland/libinput
mouse:*:name:%s:*
 MOUSE_DPI=%d
""".printf(device_name, dpi);
        }

        /**
         * Stages hwdb under XDG data, then tries pkexec install into /etc/udev/hwdb.d
         * and refreshes the hwdb. Returns a user-facing status message.
         */
        public static string apply_reported_dpi(string device_name, int dpi) throws Error {
            if (dpi < 100 || dpi > 16000) {
                throw new IOError.FAILED("DPI must be between 100 and 16000.");
            }
            DirUtils.create_with_parents(data_home(), 0700);
            var staged = staged_hwdb_path();
            FileUtils.set_contents(staged, build_hwdb_snippet(device_name, dpi));

            var system_path = system_hwdb_path();
            var script = """#!/bin/bash
set -euo pipefail
install -m 644 %s %s
udevadm hwdb --update
udevadm trigger -c add -c change /dev/input/event* || true
""".printf(shell_single_quote(staged), shell_single_quote(system_path));

            var helper = Path.build_filename(data_home(), "install-hwdb.sh");
            FileUtils.set_contents(helper, script);
            Posix.chmod(helper, 0700);

            string standard_output;
            string standard_error;
            int exit_status;
            string[] argv = { "pkexec", helper };
            try {
                Process.spawn_sync(
                    null,
                    argv,
                    Environ.get(),
                    SpawnFlags.SEARCH_PATH,
                    null,
                    out standard_output,
                    out standard_error,
                    out exit_status
                );
            } catch (Error err) {
                return "Staged %s — install needs admin:\npkexec %s\nThen replug the mouse.".printf(
                    staged,
                    helper
                );
            }

            if (exit_status != 0) {
                var detail = standard_error.strip();
                if (detail.length == 0) {
                    detail = "pkexec/install failed";
                }
                return "Staged %s but install failed (%s).\nRun: pkexec %s\nThen replug the mouse.".printf(
                    staged,
                    detail,
                    helper
                );
            }
            return "Installed reported DPI %d for “%s”.\nReplug the mouse (or log out/in) for libinput to pick it up.".printf(
                dpi,
                device_name
            );
        }

        public static void remove_reported_dpi() throws Error {
            delete_if_exists(staged_hwdb_path());
            delete_if_exists(legacy_staged_hwdb_path());
            delete_if_exists(Path.build_filename(data_home(), "install-hwdb.sh"));
            delete_if_exists(Path.build_filename(legacy_data_home(), "install-hwdb.sh"));

            var system_paths = new GenericArray<string>();
            if (FileUtils.test(system_hwdb_path(), FileTest.EXISTS)) {
                system_paths.add(system_hwdb_path());
            }
            if (FileUtils.test(legacy_system_hwdb_path(), FileTest.EXISTS)) {
                system_paths.add(legacy_system_hwdb_path());
            }
            if (system_paths.length > 0) {
                var helper = Path.build_filename(data_home(), "remove-hwdb.sh");
                DirUtils.create_with_parents(data_home(), 0700);
                var remove_lines = new GenericArray<string>();
                foreach (string system_path in system_paths) {
                    remove_lines.add("rm -f %s".printf(shell_single_quote(system_path)));
                }
                var script = """#!/bin/bash
set -euo pipefail
%s
udevadm hwdb --update
udevadm trigger -c add -c change /dev/input/event* || true
""".printf(string.joinv("\n", remove_lines.data));
                FileUtils.set_contents(helper, script);
                Posix.chmod(helper, 0700);
                try {
                    string standard_output;
                    string standard_error;
                    int exit_status;
                    Process.spawn_sync(
                        null,
                        { "pkexec", helper },
                        Environ.get(),
                        SpawnFlags.SEARCH_PATH,
                        null,
                        out standard_output,
                        out standard_error,
                        out exit_status
                    );
                } catch (Error err) {
                    // Staged removal helper left for the user.
                }
            }
        }

        public static string apply_hyprland(
            string device_name,
            double sensitivity,
            string accel_profile,
            string? custom_curve
        ) throws Error {
            var hypr_dir = Path.build_filename(config_home(), "hypr");
            DirUtils.create_with_parents(hypr_dir, 0755);
            var dropin = hypr_dropin_path();
            var profile_value = accel_profile;
            if (accel_profile == "custom" && custom_curve != null) {
                profile_value = "custom " + custom_curve;
            }

            var body = """# Generated by mouse-scales — source from hyprland.conf:
# source = %s

device {
    name = %s
    sensitivity = %.2f
    accel_profile = %s
}
""".printf(dropin, device_name, sensitivity, profile_value);
            FileUtils.set_contents(dropin, body);
            delete_if_exists(legacy_hypr_dropin_path());

            ensure_hypr_source_line();

            if (Environment.find_program_in_path("hyprctl") != null) {
                // Live apply; exact keyword paths vary by Hyprland version.
                try_spawn(
                    {
                        "hyprctl", "keyword",
                        "device:%s:sensitivity".printf(device_name),
                        "%.2f".printf(sensitivity)
                    }
                );
                try_spawn(
                    {
                        "hyprctl", "keyword",
                        "device:%s:accel_profile".printf(device_name),
                        profile_value
                    }
                );
            }

            return "Wrote %s (ensure it is sourced).\nSensitivity %.2f, profile %s.".printf(
                dropin,
                sensitivity,
                profile_value
            );
        }

        static void ensure_hypr_source_line() throws Error {
            var main_conf = Path.build_filename(config_home(), "hypr", "hyprland.conf");
            var source_line = "source = ./mouse-scales.conf";
            if (!FileUtils.test(main_conf, FileTest.EXISTS)) {
                return;
            }
            string contents;
            FileUtils.get_contents(main_conf, out contents);
            var rewritten = contents.replace("source = ./mouse-ctm-scale.conf", source_line);
            rewritten = rewritten.replace("# mouse-ctm-scale", "# mouse-scales");
            if (rewritten != contents) {
                FileUtils.set_contents(main_conf, rewritten);
                contents = rewritten;
            }
            if ("mouse-scales.conf" in contents) {
                return;
            }
            contents += "\n# mouse-scales\n" + source_line + "\n";
            FileUtils.set_contents(main_conf, contents);
        }

        public static string apply_sway(
            string device_identifier,
            double pointer_accel,
            string accel_profile
        ) throws Error {
            var sway_dir = Path.build_filename(config_home(), "sway", "config.d");
            DirUtils.create_with_parents(sway_dir, 0755);
            var dropin = sway_dropin_path();
            var include_hint = Path.build_filename(config_home(), "sway", "config.d", "*");
            var body = """# Generated by mouse-scales — include from sway config:
# include %s

input "%s" {
    accel_profile %s
    pointer_accel %.2f
}
""".printf(include_hint, device_identifier, accel_profile, pointer_accel);
            FileUtils.set_contents(dropin, body);
            delete_if_exists(legacy_sway_dropin_path());

            if (Environment.find_program_in_path("swaymsg") != null) {
                try_spawn({
                    "swaymsg",
                    "input", device_identifier, "accel_profile", accel_profile
                });
                try_spawn({
                    "swaymsg",
                    "input", device_identifier, "pointer_accel",
                    "%.2f".printf(pointer_accel)
                });
            }

            return "Wrote %s.\npointer_accel %.2f, profile %s.\nReload Sway config if live apply did not stick.".printf(
                dropin,
                pointer_accel,
                accel_profile
            );
        }

        public static string[] list_sway_pointer_identifiers() {
            var ids = new GenericArray<string>();
            if (Environment.find_program_in_path("swaymsg") == null) {
                return {};
            }
            try {
                string standard_output;
                string standard_error;
                int exit_status;
                Process.spawn_command_line_sync(
                    "swaymsg -t get_inputs",
                    out standard_output,
                    out standard_error,
                    out exit_status
                );
                if (exit_status != 0) {
                    return {};
                }
                // JSON-ish: "identifier": "..."
                foreach (var line in standard_output.split("\n")) {
                    var trimmed = line.strip();
                    if (!("\"identifier\"" in trimmed)) {
                        continue;
                    }
                    var start = trimmed.index_of(":");
                    if (start < 0) {
                        continue;
                    }
                    var value = trimmed.substring(start + 1).strip();
                    value = value.replace(",", "").replace("\"", "").strip();
                    if (value.length > 0) {
                        ids.add(value);
                    }
                }
            } catch (Error err) {
                return {};
            }
            return ids.data;
        }

        /** Simple custom curve: step 1.0 with end point = boost (extra scale feel). */
        public static string custom_curve_for_boost(double boost) {
            return "1.0 0.0 %.2f".printf(boost);
        }

        public static void remove_compositor_dropins() throws Error {
            delete_if_exists(hypr_dropin_path());
            delete_if_exists(sway_dropin_path());
            delete_if_exists(legacy_hypr_dropin_path());
            delete_if_exists(legacy_sway_dropin_path());
        }

        public static bool has_wayland_overrides() {
            return FileUtils.test(staged_hwdb_path(), FileTest.EXISTS)
                || FileUtils.test(system_hwdb_path(), FileTest.EXISTS)
                || FileUtils.test(hypr_dropin_path(), FileTest.EXISTS)
                || FileUtils.test(sway_dropin_path(), FileTest.EXISTS)
                || FileUtils.test(legacy_staged_hwdb_path(), FileTest.EXISTS)
                || FileUtils.test(legacy_system_hwdb_path(), FileTest.EXISTS)
                || FileUtils.test(legacy_hypr_dropin_path(), FileTest.EXISTS)
                || FileUtils.test(legacy_sway_dropin_path(), FileTest.EXISTS);
        }

        static void try_spawn(string[] argv) {
            try {
                string standard_output;
                string standard_error;
                int exit_status;
                Process.spawn_sync(
                    null,
                    argv,
                    Environ.get(),
                    SpawnFlags.SEARCH_PATH,
                    null,
                    out standard_output,
                    out standard_error,
                    out exit_status
                );
            } catch (Error err) {
                // Best-effort live apply.
            }
        }

        static void delete_if_exists(string path) throws Error {
            var file = File.new_for_path(path);
            try {
                file.delete();
            } catch (IOError.NOT_FOUND err) {
            }
        }

        static string shell_single_quote(string value) {
            return "'" + value.replace("'", "'\"'\"'") + "'";
        }
    }
}
