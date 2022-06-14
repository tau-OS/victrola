namespace Victrola {

    [GtkTemplate (ui = "/co/tauos/Victrola/preferences.ui")]
    public class PreferencesWindow : He.Window {
        [GtkChild]
        unowned Gtk.Switch dark_btn;
        [GtkChild]
        unowned Gtk.Button music_dir_btn;
        [GtkChild]
        unowned Gtk.Switch pipewire_btn;

        public PreferencesWindow (Application app) {
            var settings = app.settings;

            dark_btn.bind_property ("state", app, "dark_theme", BindingFlags.DEFAULT);
            settings.bind ("dark-theme", dark_btn, "state", SettingsBindFlags.DEFAULT);

            var music_dir = app.get_music_folder ();
            music_dir_btn.label = get_display_name (music_dir);
            music_dir_btn.clicked.connect (() => {
                var chooser = new Gtk.FileChooserNative (null, this,
                                Gtk.FileChooserAction.SELECT_FOLDER, null, null);
                try {
                    chooser.set_file (music_dir);
                } catch (Error e) {
                }
                chooser.modal = true;
                chooser.response.connect ((id) => {
                    if (id == Gtk.ResponseType.ACCEPT) {
                        var dir = chooser.get_file ();
                        if (dir != null && dir != music_dir) {
                            music_dir_btn.label = get_display_name ((!)dir);
                            settings.set_string ("music-dir", ((!)dir).get_uri ());
                            app.reload_song_store ();
                        }
                    }
                });
                chooser.show ();
            });

            settings.bind ("pipewire-sink", pipewire_btn, "state", SettingsBindFlags.GET_NO_CHANGES);
            pipewire_btn.state_set.connect ((state) => {
                app.player.use_pipewire (state);
                app.player.restart ();
                return false;
            });
        }

        private static string get_display_name (File dir) {
            var name = dir.get_basename () ?? "";
            if (name.length == 0 || name == "/")
                name = dir.get_parse_name ();
            return name;
        }
    }
}