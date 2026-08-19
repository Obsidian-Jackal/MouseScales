namespace MouseScales {
    /** Matches Adaptive vs Constant (libinput flat) labels. */
    public enum AccelProfileKind {
        ADAPTIVE,
        CONSTANT;

        public string label() {
            switch (this) {
            case AccelProfileKind.ADAPTIVE:
                return "Adaptive";
            case AccelProfileKind.CONSTANT:
                return "Constant";
            }
            assert_not_reached();
        }

        public static AccelProfileKind from_enabled_slots(int[] slots) {
            if (slots.length >= 2 && slots[1] != 0) {
                return AccelProfileKind.CONSTANT;
            }
            return AccelProfileKind.ADAPTIVE;
        }
    }

    /**
     * Talks to xinput for listing devices and applying Accel Speed, profile, and Coordinate Transformation Matrix.
     * The matrix uses sx/sy on the diagonal; the homogeneous weight stays 1.
     */
    public class PointerControl : Object {
        public static bool session_is_x11(out string? detail) {
            detail = null;
            var kind = SessionDetect.session_kind();
            if (kind == SessionKind.WAYLAND) {
                detail = "This control needs an X11 session (Coordinate Transformation Matrix).";
                return false;
            }
            if (Environment.get_variable("DISPLAY") == null
                || Environment.get_variable("DISPLAY").length == 0) {
                detail = "DISPLAY is not set; cannot talk to X.";
                return false;
            }
            return true;
        }

        public static bool xinput_available() {
            return Environment.find_program_in_path("xinput") != null;
        }

        /**
         * Real attached pointing devices from `xinput list`
         * (skips virtual core and XTEST entries).
         */
        public static string[] list_device_names() throws Error {
            string standard_output;
            string standard_error;
            int exit_status;
            Process.spawn_command_line_sync(
                "xinput list",
                out standard_output,
                out standard_error,
                out exit_status
            );
            if (exit_status != 0) {
                throw new IOError.FAILED(
                    "xinput list failed: %s".printf(standard_error.strip())
                );
            }

            var names = new GenericArray<string>();
            foreach (var line in standard_output.split("\n")) {
                if (!("slave" in line && "pointer" in line)) {
                    continue;
                }
                if ("XTEST" in line) {
                    continue;
                }
                var marker = "↳ ";
                var marker_index = line.index_of(marker);
                if (marker_index < 0) {
                    continue;
                }
                var after_marker = line.substring(marker_index + marker.length);
                var id_index = after_marker.index_of("id=");
                if (id_index < 0) {
                    continue;
                }
                var device_name = after_marker.substring(0, id_index).strip();
                if (device_name.length > 0) {
                    names.add(device_name);
                }
            }
            return names.data;
        }

        public static string? preferred_device_name(string[] names) {
            foreach (var name in names) {
                var lower = name.down();
                if ("mouse" in lower && !("touchpad" in lower) && !("controller" in lower)) {
                    return name;
                }
            }
            return names.length > 0 ? names[0] : null;
        }

        public static double percent_to_accel(double percent) {
            return (percent / 50.0) - 1.0;
        }

        public static double accel_to_percent(double accel) {
            return (accel + 1.0) * 50.0;
        }

        public static void read_current_settings(
            string device_name,
            out double accel,
            out double scale,
            out AccelProfileKind profile,
            out int profile_slot_count
        ) throws Error {
            accel = 0.0;
            scale = 1.0;
            profile = AccelProfileKind.ADAPTIVE;
            profile_slot_count = 2;

            var device_id = resolve_device_id(device_name);
            string standard_output;
            string standard_error;
            int exit_status;
            string[] argv = { "xinput", "list-props", device_id.to_string() };
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
                throw new IOError.FAILED(
                    "Could not read properties for:\n%s".printf(device_name)
                );
            }

            bool found_accel = false;
            bool found_scale = false;
            foreach (var line in standard_output.split("\n")) {
                var stripped = line.strip();
                if (stripped.has_prefix("libinput Accel Speed ")
                    && !("Default" in stripped)
                    && !("Profile" in stripped)) {
                    var value_text = property_value_text(stripped);
                    double parsed_accel;
                    if (double.try_parse(value_text, out parsed_accel)) {
                        accel = parsed_accel;
                        found_accel = true;
                    }
                } else if (
                    stripped.has_prefix("libinput Accel Profile Enabled ")
                    && !("Default" in stripped)
                ) {
                    var slots = parse_int_list(property_value_text(stripped));
                    if (slots.length > 0) {
                        profile_slot_count = slots.length;
                        profile = AccelProfileKind.from_enabled_slots(slots);
                    }
                } else if (stripped.has_prefix("Coordinate Transformation Matrix")) {
                    var value_text = property_value_text(stripped);
                    var parts = value_text.split(",");
                    if (parts.length >= 1) {
                        double parsed_sx;
                        if (double.try_parse(parts[0].strip(), out parsed_sx)) {
                            scale = parsed_sx;
                            found_scale = true;
                        }
                    }
                }
            }

            if (!found_accel && !found_scale) {
                throw new IOError.FAILED(
                    "No Accel Speed or Coordinate Transformation Matrix values on:\n%s".printf(device_name)
                );
            }
        }

        static int[] parse_int_list(string text) {
            var values = new GenericArray<int>();
            foreach (var part in text.split(",")) {
                int number;
                if (int.try_parse(part.strip(), out number)) {
                    values.add(number);
                }
            }
            return values.data;
        }

        static string property_value_text(string line) {
            var colon = line.index_of(":");
            if (colon < 0) {
                return "";
            }
            return line.substring(colon + 1).strip();
        }

        public static int resolve_device_id(string device_name) throws Error {
            string standard_output;
            string standard_error;
            int exit_status;
            string[] argv = { "xinput", "list", "--id-only", device_name };
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
                throw new IOError.FAILED(
                    "Could not find device:\n%s".printf(device_name)
                );
            }
            var text = standard_output.strip();
            int device_id;
            if (!int.try_parse(text, out device_id)) {
                throw new IOError.FAILED("Unexpected xinput id: %s".printf(text));
            }
            return device_id;
        }

        public static void apply_settings(
            string device_name,
            double accel,
            double scale,
            AccelProfileKind profile,
            int profile_slot_count
        ) throws Error {
            var device_id = resolve_device_id(device_name);
            var id_text = device_id.to_string();
            var accel_text = "%.2f".printf(accel);
            var scale_text = "%.1f".printf(scale);
            var slot_count = profile_slot_count < 2 ? 2 : profile_slot_count;

            var profile_argv = new GenericArray<string>();
            profile_argv.add("xinput");
            profile_argv.add("set-prop");
            profile_argv.add(id_text);
            profile_argv.add("libinput Accel Profile Enabled");
            for (int index = 0; index < slot_count; index++) {
                int bit = 0;
                if (profile == AccelProfileKind.ADAPTIVE && index == 0) {
                    bit = 1;
                } else if (profile == AccelProfileKind.CONSTANT && index == 1) {
                    bit = 1;
                }
                profile_argv.add(bit.to_string());
            }
            run_xinput(profile_argv.data);

            run_xinput({
                "xinput", "set-prop", id_text, "libinput Accel Speed", accel_text
            });

            // Coordinate Transformation Matrix: sx 0 0 | 0 sy 0 | 0 0 1
            run_xinput({
                "xinput", "set-prop", id_text, "Coordinate Transformation Matrix",
                scale_text, "0", "0", "0", scale_text, "0", "0", "0", "1"
            });
        }

        static void run_xinput(string[] argv) throws Error {
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
            if (exit_status != 0) {
                var message = standard_error.strip();
                if (message.length == 0) {
                    message = "xinput command failed";
                }
                throw new IOError.FAILED(message);
            }
        }
    }
}
