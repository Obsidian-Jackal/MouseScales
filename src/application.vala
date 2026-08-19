namespace MouseScales {
    public const string APP_ID = "org.obsidian_jackal.MouseScales";
    public const string APP_NAME = "Mouse Scales";
    public const string APP_VERSION = "0.1.0";

    public class Application : Gtk.Application {
        public Application() {
            Object(
                application_id: APP_ID,
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        protected override void startup() {
            base.startup();
            Gtk.Window.set_default_icon_name(APP_ID);

            var about_action = new SimpleAction("about", null);
            about_action.activate.connect(this.on_about);
            this.add_action(about_action);

            var quit_action = new SimpleAction("quit", null);
            quit_action.activate.connect(this.quit);
            this.add_action(quit_action);
            this.set_accels_for_action("app.quit", { "<primary>q" });

            // Exported for panel global-menu applets (Cinnamon, etc.).
            this.set_menubar(this.build_menubar());
        }

        protected override void activate() {
            var existing = this.active_window;
            if (existing != null) {
                existing.present();
                return;
            }

            var window = new MainWindow(this);
            window.present();
        }

        /**
         * Same items as the header hamburger, as an application menubar model
         * so global menu integrations can pick them up.
         */
        public MenuModel build_menubar() {
            var menubar = new Menu();
            menubar.append_submenu("Options", this.build_app_menu_section());
            return menubar;
        }

        public MenuModel build_hamburger_menu() {
            return this.build_app_menu_section();
        }

        Menu build_app_menu_section() {
            var menu = new Menu();
            menu.append("Remove Saved Overrides", "win.remove-startup");
            menu.append("About Mouse Scales", "app.about");
            menu.append("Quit", "app.quit");
            return menu;
        }

        void on_about() {
            var about = new Gtk.AboutDialog() {
                transient_for = this.active_window,
                modal = true,
                program_name = APP_NAME,
                logo_icon_name = APP_ID,
                version = APP_VERSION,
                comments = "Can set pointer speed and extra scale on X11, plus reported DPI and Hyprland/Sway extras on Wayland.",
                website = "https://github.com/Obsidian-Jackal/MouseScales",
                copyright = "Copyright © 2026 Obsidian Jackal",
                license_type = Gtk.License.BSD_3,
                authors = { "Obsidian Jackal" }
            };
            about.present();
        }

        public void send_app_notification(string title, string body) {
            var notification = new Notification(title);
            notification.set_body(body);
            notification.set_icon(new ThemedIcon(APP_ID));
            this.send_notification("mouse-scales", notification);
        }
    }
}
