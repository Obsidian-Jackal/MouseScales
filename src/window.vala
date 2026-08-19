namespace MouseScales {
    public class MainWindow : Gtk.ApplicationWindow {
        Application app;
        Gtk.Label status_label;
        Gtk.Stack session_stack;

        // X11 controls
        Gtk.StringList x11_device_model;
        Gtk.DropDown x11_device_dropdown;
        Gtk.DropDown x11_profile_dropdown;
        Gtk.Scale x11_speed_scale;
        Gtk.Scale x11_extra_scale;
        int profile_slot_count = 2;

        // Wayland controls
        WaylandPointerDevice[] wayland_devices = {};
        Gtk.StringList wayland_device_model;
        Gtk.DropDown wayland_device_dropdown;
        Gtk.SpinButton dpi_spin;
        Gtk.Box compositor_box;
        Gtk.DropDown sway_id_dropdown;
        Gtk.StringList sway_id_model;
        Gtk.Scale compositor_sensitivity;
        Gtk.DropDown compositor_profile_dropdown;
        Gtk.Scale compositor_boost_scale;
        Gtk.Widget compositor_boost_row;

        SessionKind session;
        CompositorKind compositor;

        public MainWindow(Application application) {
            Object(
                application: application,
                title: APP_NAME,
                default_width: 560,
                resizable: true
            );
            this.app = application;
            this.icon_name = APP_ID;
            this.decorated = true;
            this.session = SessionDetect.session_kind();
            this.compositor = SessionDetect.compositor_kind();

            var remove_action = new SimpleAction("remove-startup", null);
            remove_action.activate.connect(this.on_remove_overrides);
            this.add_action(remove_action);

            var root = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

            var top_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8) {
                margin_top = 8,
                margin_start = 12,
                margin_end = 12
            };
            var session_badge = new Gtk.Label(this.session_badge_text()) {
                xalign = 0.0f,
                hexpand = true
            };
            session_badge.add_css_class("dim-label");
            top_bar.append(session_badge);
            var menu_button = new Gtk.MenuButton() {
                icon_name = "open-menu-symbolic",
                tooltip_text = "Menu",
                primary = true,
                menu_model = this.app.build_hamburger_menu()
            };
            top_bar.append(menu_button);
            root.append(top_bar);

            this.session_stack = new Gtk.Stack() {
                hexpand = true,
                vexpand = true
            };
            this.session_stack.add_named(this.build_x11_page(), "x11");
            this.session_stack.add_named(this.build_wayland_page(), "wayland");
            root.append(this.session_stack);

            this.status_label = new Gtk.Label("") {
                wrap = true,
                xalign = 0.0f,
                margin_start = 20,
                margin_end = 20,
                margin_bottom = 16
            };
            this.status_label.add_css_class("dim-label");
            root.append(this.status_label);

            this.child = root;

            if (this.session == SessionKind.WAYLAND) {
                this.session_stack.visible_child_name = "wayland";
                this.populate_wayland_devices();
            } else {
                this.session_stack.visible_child_name = "x11";
                this.populate_x11_devices();
            }
        }

        string session_badge_text() {
            if (this.session == SessionKind.WAYLAND) {
                return "Session: Wayland (%s)".printf(
                    SessionDetect.compositor_label(this.compositor)
                );
            }
            if (this.session == SessionKind.X11) {
                return "Session: X11";
            }
            return "Session: unknown";
        }

        Gtk.Widget build_x11_page() {
            var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 16) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 20,
                margin_end = 20
            };

            var intro = new Gtk.Label(
                "Pointer speed matches the usual desktop range.\nExtra scale can go past that when speed alone is not enough."
            ) {
                wrap = true,
                xalign = 0.0f
            };
            intro.add_css_class("dim-label");
            content.append(intro);

            var device_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            device_box.append(new Gtk.Label("Pointer device") { xalign = 0.0f });
            this.x11_device_model = new Gtk.StringList(null);
            this.x11_device_dropdown = new Gtk.DropDown(this.x11_device_model, null) {
                hexpand = true
            };
            this.x11_device_dropdown.notify["selected"].connect(() => {
                this.sync_x11_from_device();
            });
            device_box.append(this.x11_device_dropdown);
            content.append(device_box);

            var profile_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            profile_box.append(new Gtk.Label("Acceleration") { xalign = 0.0f });
            var profile_model = new Gtk.StringList({
                AccelProfileKind.ADAPTIVE.label(),
                AccelProfileKind.CONSTANT.label()
            });
            this.x11_profile_dropdown = new Gtk.DropDown(profile_model, null);
            profile_box.append(this.x11_profile_dropdown);
            content.append(profile_box);

            var speed_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            speed_box.append(new Gtk.Label("Pointer speed") { xalign = 0.0f });
            this.x11_speed_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1) {
                draw_value = true,
                digits = 0,
                hexpand = true
            };
            speed_box.append(this.x11_speed_scale);
            content.append(speed_box);

            var extra_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            extra_box.append(new Gtk.Label("Extra scale (1.0× … 5.0×)") { xalign = 0.0f });
            this.x11_extra_scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 1.0, 5.0, 0.1) {
                draw_value = true,
                digits = 1,
                hexpand = true
            };
            extra_box.append(this.x11_extra_scale);
            content.append(extra_box);

            var buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8) {
                halign = Gtk.Align.END
            };
            var close_button = new Gtk.Button.with_label("Close");
            close_button.clicked.connect(() => { this.close(); });
            var install_button = new Gtk.Button.with_label("Install + Startup");
            install_button.clicked.connect(this.on_x11_install);
            var apply_button = new Gtk.Button.with_label("Apply");
            apply_button.clicked.connect(this.on_x11_apply);
            buttons.append(close_button);
            buttons.append(install_button);
            buttons.append(apply_button);
            content.append(buttons);
            return content;
        }

        Gtk.Widget build_wayland_page() {
            var content = new Gtk.Box(Gtk.Orientation.VERTICAL, 16) {
                margin_top = 8,
                margin_bottom = 8,
                margin_start = 20,
                margin_end = 20
            };

            var note = new Gtk.Label(SessionDetect.wayland_note_text(this.compositor)) {
                wrap = true,
                xalign = 0.0f
            };
            note.add_css_class("dim-label");
            content.append(note);

            var device_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            device_box.append(new Gtk.Label("Pointer device") { xalign = 0.0f });
            this.wayland_device_model = new Gtk.StringList(null);
            this.wayland_device_dropdown = new Gtk.DropDown(this.wayland_device_model, null);
            this.wayland_device_dropdown.notify["selected"].connect(() => {
                this.sync_wayland_dpi_from_device();
            });
            device_box.append(this.wayland_device_dropdown);
            content.append(device_box);

            var dpi_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            dpi_box.append(new Gtk.Label("Reported DPI (udev / libinput)") { xalign = 0.0f });
            var dpi_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            this.dpi_spin = new Gtk.SpinButton.with_range(100, 16000, 50) {
                value = 800,
                hexpand = true
            };
            var dpi_apply = new Gtk.Button.with_label("Apply DPI");
            dpi_apply.clicked.connect(this.on_apply_dpi);
            dpi_row.append(this.dpi_spin);
            dpi_row.append(dpi_apply);
            dpi_box.append(dpi_row);
            content.append(dpi_box);

            this.compositor_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            content.append(this.compositor_box);
            this.fill_compositor_box();

            var buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8) {
                halign = Gtk.Align.END
            };
            var close_button = new Gtk.Button.with_label("Close");
            close_button.clicked.connect(() => { this.close(); });
            buttons.append(close_button);
            content.append(buttons);
            return content;
        }

        void fill_compositor_box() {
            while (this.compositor_box.get_first_child() != null) {
                this.compositor_box.remove(this.compositor_box.get_first_child());
            }

            if (this.compositor != CompositorKind.HYPRLAND
                && this.compositor != CompositorKind.SWAY) {
                var tip = new Gtk.Label(
                    "No Hyprland/Sway extras on this session. Use Reported DPI and desktop mouse Settings."
                ) {
                    wrap = true,
                    xalign = 0.0f
                };
                tip.add_css_class("dim-label");
                this.compositor_box.append(tip);
                return;
            }

            var title = new Gtk.Label(
                "%s extras".printf(SessionDetect.compositor_label(this.compositor))
            ) {
                xalign = 0.0f
            };
            this.compositor_box.append(title);

            if (this.compositor == CompositorKind.SWAY) {
                var id_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
                id_box.append(new Gtk.Label("Sway input identifier") { xalign = 0.0f });
                this.sway_id_model = new Gtk.StringList(null);
                this.sway_id_dropdown = new Gtk.DropDown(this.sway_id_model, null);
                id_box.append(this.sway_id_dropdown);
                this.compositor_box.append(id_box);
                foreach (var identifier in WaylandBackend.list_sway_pointer_identifiers()) {
                    this.sway_id_model.append(identifier);
                }
                if (this.sway_id_model.get_n_items() > 0) {
                    this.sway_id_dropdown.selected = 0;
                }
            }

            var sens_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            sens_box.append(
                new Gtk.Label(
                    this.compositor == CompositorKind.HYPRLAND
                        ? "Sensitivity (−1…1)"
                        : "pointer_accel (−1…1)"
                ) { xalign = 0.0f }
            );
            this.compositor_sensitivity = new Gtk.Scale.with_range(
                Gtk.Orientation.HORIZONTAL, -1.0, 1.0, 0.05
            ) {
                draw_value = true,
                digits = 2,
                hexpand = true
            };
            this.compositor_sensitivity.set_value(0.0);
            sens_box.append(this.compositor_sensitivity);
            this.compositor_box.append(sens_box);

            var profile_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            profile_box.append(new Gtk.Label("Acceleration profile") { xalign = 0.0f });
            string[] profiles;
            if (this.compositor == CompositorKind.HYPRLAND) {
                profiles = { "Adaptive", "Constant", "Custom boost" };
            } else {
                profiles = { "Adaptive", "Constant" };
            }
            var profile_model = new Gtk.StringList(profiles);
            this.compositor_profile_dropdown = new Gtk.DropDown(profile_model, null);
            this.compositor_profile_dropdown.notify["selected"].connect(() => {
                this.update_boost_row_visibility();
            });
            profile_box.append(this.compositor_profile_dropdown);
            this.compositor_box.append(profile_box);

            var boost_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            boost_box.append(
                new Gtk.Label("Custom boost curve end (1.0× … 5.0×)") { xalign = 0.0f }
            );
            this.compositor_boost_scale = new Gtk.Scale.with_range(
                Gtk.Orientation.HORIZONTAL, 1.0, 5.0, 0.1
            ) {
                draw_value = true,
                digits = 1,
                hexpand = true
            };
            this.compositor_boost_scale.set_value(2.0);
            boost_box.append(this.compositor_boost_scale);
            this.compositor_boost_row = boost_box;
            this.compositor_box.append(boost_box);
            this.update_boost_row_visibility();

            var apply = new Gtk.Button.with_label("Apply compositor settings");
            apply.halign = Gtk.Align.END;
            apply.clicked.connect(this.on_apply_compositor);
            this.compositor_box.append(apply);
        }

        void update_boost_row_visibility() {
            if (this.compositor_boost_row == null || this.compositor_profile_dropdown == null) {
                return;
            }
            bool show = this.compositor == CompositorKind.HYPRLAND
                && this.compositor_profile_dropdown.selected == 2;
            this.compositor_boost_row.visible = show;
        }

        void populate_x11_devices() {
            string? session_detail;
            if (!PointerControl.session_is_x11(out session_detail)) {
                this.set_status(session_detail ?? "Not an X11 session.");
                return;
            }
            if (!PointerControl.xinput_available()) {
                this.set_status("xinput is not installed.");
                return;
            }
            try {
                var names = PointerControl.list_device_names();
                this.x11_device_model.splice(0, this.x11_device_model.get_n_items(), null);
                if (names.length == 0) {
                    this.set_status("No pointing devices found.");
                    return;
                }
                var preferred = PointerControl.preferred_device_name(names);
                uint active_index = 0;
                for (int index = 0; index < names.length; index++) {
                    this.x11_device_model.append(names[index]);
                    if (preferred != null && names[index] == preferred) {
                        active_index = index;
                    }
                }
                this.x11_device_dropdown.selected = active_index;
                this.sync_x11_from_device();
                this.set_status("");
            } catch (Error err) {
                this.set_status(err.message);
            }
        }

        void populate_wayland_devices() {
            try {
                this.wayland_devices = WaylandBackend.list_pointer_devices();
                this.wayland_device_model.splice(0, this.wayland_device_model.get_n_items(), null);
                if (this.wayland_devices.length == 0) {
                    this.set_status("No pointing devices found.");
                    return;
                }
                uint active_index = 0;
                for (int index = 0; index < this.wayland_devices.length; index++) {
                    this.wayland_device_model.append(this.wayland_devices[index].name);
                    var lower = this.wayland_devices[index].name.down();
                    if ("mouse" in lower && !("touchpad" in lower) && !("controller" in lower)) {
                        active_index = index;
                    }
                }
                this.wayland_device_dropdown.selected = active_index;
                this.sync_wayland_dpi_from_device();
                this.set_status("");
            } catch (Error err) {
                this.set_status(err.message);
            }
        }

        void sync_wayland_dpi_from_device() {
            var device = this.selected_wayland_device();
            if (device == null) {
                return;
            }
            var dpi = WaylandBackend.read_reported_dpi(device);
            if (dpi != null) {
                this.dpi_spin.value = dpi;
            }
        }

        WaylandPointerDevice? selected_wayland_device() {
            var selected = this.wayland_device_dropdown.selected;
            if (selected == Gtk.INVALID_LIST_POSITION
                || selected >= this.wayland_devices.length) {
                return null;
            }
            return this.wayland_devices[selected];
        }

        void sync_x11_from_device() {
            var selected = this.x11_device_dropdown.selected;
            if (selected == Gtk.INVALID_LIST_POSITION) {
                return;
            }
            var device_name = this.x11_device_model.get_string(selected);
            if (device_name == null || device_name.length == 0) {
                return;
            }
            try {
                double accel;
                double scale;
                AccelProfileKind profile;
                int slot_count;
                PointerControl.read_current_settings(
                    device_name, out accel, out scale, out profile, out slot_count
                );
                this.profile_slot_count = slot_count;
                this.x11_profile_dropdown.selected =
                    (profile == AccelProfileKind.CONSTANT) ? 1 : 0;
                this.x11_speed_scale.set_value(
                    PointerControl.accel_to_percent(accel).clamp(0, 100)
                );
                this.x11_extra_scale.set_value(scale.clamp(1.0, 5.0));
            } catch (Error err) {
                this.set_status(err.message);
            }
        }

        bool read_x11_selection(
            out string device_name,
            out double accel,
            out double scale,
            out AccelProfileKind profile
        ) {
            profile = (this.x11_profile_dropdown.selected == 1)
                ? AccelProfileKind.CONSTANT
                : AccelProfileKind.ADAPTIVE;
            var selected = this.x11_device_dropdown.selected;
            device_name = (selected == Gtk.INVALID_LIST_POSITION)
                ? ""
                : (this.x11_device_model.get_string(selected) ?? "");
            if (device_name.length == 0) {
                this.set_status("No device selected.");
                accel = 0;
                scale = 1;
                return false;
            }
            accel = PointerControl.percent_to_accel(this.x11_speed_scale.get_value());
            scale = this.x11_extra_scale.get_value();
            return true;
        }

        void on_x11_apply() {
            string device_name;
            double accel;
            double scale;
            AccelProfileKind profile;
            if (!this.read_x11_selection(out device_name, out accel, out scale, out profile)) {
                return;
            }
            try {
                PointerControl.apply_settings(
                    device_name, accel, scale, profile, this.profile_slot_count
                );
                this.set_status("Applied.");
                this.app.send_app_notification(
                    "Applied",
                    "%s, speed %.2f, extra %.1f×".printf(profile.label(), accel, scale)
                );
            } catch (Error err) {
                this.set_status(err.message);
                this.app.send_app_notification("Error", err.message);
            }
        }

        void on_x11_install() {
            string device_name;
            double accel;
            double scale;
            AccelProfileKind profile;
            if (!this.read_x11_selection(out device_name, out accel, out scale, out profile)) {
                return;
            }
            try {
                StartupInstall.install(
                    device_name, accel, scale, profile, this.profile_slot_count
                );
                this.set_status(
                    "Saved for startup:\n%s".printf(StartupInstall.autostart_desktop_path())
                );
                this.app.send_app_notification("Saved for startup", device_name);
            } catch (Error err) {
                this.set_status(err.message);
                this.app.send_app_notification("Error", err.message);
            }
        }

        void on_apply_dpi() {
            var device = this.selected_wayland_device();
            if (device == null) {
                this.set_status("No device selected.");
                return;
            }
            try {
                var message = WaylandBackend.apply_reported_dpi(
                    device.name,
                    (int) this.dpi_spin.value
                );
                this.set_status(message);
                this.app.send_app_notification("Reported DPI", message);
            } catch (Error err) {
                this.set_status(err.message);
                this.app.send_app_notification("Error", err.message);
            }
        }

        void on_apply_compositor() {
            try {
                if (this.compositor == CompositorKind.HYPRLAND) {
                    var device = this.selected_wayland_device();
                    if (device == null) {
                        this.set_status("No device selected.");
                        return;
                    }
                    string profile;
                    string? curve = null;
                    var selected = this.compositor_profile_dropdown.selected;
                    if (selected == 1) {
                        profile = "flat";
                    } else if (selected == 2) {
                        profile = "custom";
                        curve = WaylandBackend.custom_curve_for_boost(
                            this.compositor_boost_scale.get_value()
                        );
                    } else {
                        profile = "adaptive";
                    }
                    var message = WaylandBackend.apply_hyprland(
                        device.name,
                        this.compositor_sensitivity.get_value(),
                        profile,
                        curve
                    );
                    this.set_status(message);
                    this.app.send_app_notification("Hyprland", message);
                    return;
                }

                if (this.compositor == CompositorKind.SWAY) {
                    string identifier = "";
                    if (this.sway_id_dropdown != null
                        && this.sway_id_dropdown.selected != Gtk.INVALID_LIST_POSITION) {
                        identifier = this.sway_id_model.get_string(
                            this.sway_id_dropdown.selected
                        ) ?? "";
                    }
                    if (identifier.length == 0) {
                        var device = this.selected_wayland_device();
                        identifier = device != null ? device.name : "";
                    }
                    if (identifier.length == 0) {
                        this.set_status("No Sway input identifier.");
                        return;
                    }
                    var profile = (this.compositor_profile_dropdown.selected == 1)
                        ? "flat"
                        : "adaptive";
                    var message = WaylandBackend.apply_sway(
                        identifier,
                        this.compositor_sensitivity.get_value(),
                        profile
                    );
                    this.set_status(message);
                    this.app.send_app_notification("Sway", message);
                }
            } catch (Error err) {
                this.set_status(err.message);
                this.app.send_app_notification("Error", err.message);
            }
        }

        void on_remove_overrides() {
            bool x11_installed = StartupInstall.is_installed();
            bool wayland_installed = WaylandBackend.has_wayland_overrides();
            if (!x11_installed && !wayland_installed) {
                this.set_status("No saved startup script or Wayland overrides to remove.");
                this.app.send_app_notification("Nothing to remove", "No saved overrides found.");
                return;
            }

            var dialog = new Gtk.AlertDialog("Remove saved overrides?");
            dialog.set_detail(
                "Deletes X11 startup script/entry and Wayland DPI/compositor drop-ins when present."
            );
            dialog.set_buttons({ "Cancel", "Remove" });
            dialog.set_cancel_button(0);
            dialog.set_default_button(0);
            dialog.choose.begin(this, null, (obj, result) => {
                try {
                    if (dialog.choose.end(result) != 1) {
                        return;
                    }
                    if (x11_installed) {
                        StartupInstall.remove();
                    }
                    if (wayland_installed) {
                        WaylandBackend.remove_reported_dpi();
                        WaylandBackend.remove_compositor_dropins();
                    }
                    this.set_status("Removed saved overrides.");
                    this.app.send_app_notification(
                        "Overrides removed",
                        "Startup script and/or Wayland drop-ins deleted."
                    );
                } catch (Error err) {
                    this.set_status(err.message);
                    this.app.send_app_notification("Error", err.message);
                }
            });
        }

        void set_status(string message) {
            this.status_label.label = message;
        }
    }
}
