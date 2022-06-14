namespace Victrola {

    public const string ACTION_WIN = "win.";

    enum SearchType {
        ALL,
        ARTIST,
        TITLE
    }

    [GtkTemplate (ui = "/co/tauos/Victrola/window.ui")]
    public class Window : He.ApplicationWindow {
        [GtkChild]
        private unowned Gtk.Box content_box;
        [GtkChild]
        private unowned Gtk.ListView list_view;
        [GtkChild]
        public unowned Gtk.ToggleButton search_btn;
        [GtkChild]
        private unowned Gtk.SearchEntry search_entry;
        [GtkChild]
        public unowned Gtk.ProgressBar scale;

        private string _search_text = "";
        private string _search_property = "";
        private SearchType _search_type = SearchType.ALL;
        private PlayBar play_bar;

        public Window (Application app) {
            Object (application: app);
            this.icon_name = app.application_id;

            search_btn.toggled.connect (() => {
                if (search_btn.active)
                    search_entry.grab_focus ();
                update_song_filter ();
            });
            search_entry.search_changed.connect (on_search_text_changed);

            play_bar = new PlayBar ();
            content_box.append (play_bar);
            action_set_enabled (ACTION_APP + ACTION_PREV, false);
            action_set_enabled (ACTION_APP + ACTION_PLAY, false);
            action_set_enabled (ACTION_APP + ACTION_NEXT, false);

            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((item) => {
                item.child = new SongEntry ();
            });
            factory.bind.connect (on_bind_item);
            list_view.factory = factory;
            list_view.model = new Gtk.NoSelection (app.song_list);
            list_view.activate.connect ((index) => {
                app.current_item = (int) index;
            });
            app.song_changed.connect (on_song_changed);
            app.index_changed.connect (on_index_changed);
        }

        private async void on_bind_item (Gtk.ListItem item) {
            var app = (Application) application;
            var entry = (SongEntry) item.child;
            var song = (Song) item.item;
            entry.playing = item.position == app.current_item;
            entry.update (song);
            var saved_pos = item.position;
            if (saved_pos != item.position) {
                Idle.add (() => {
                    app.song_list.items_changed (saved_pos, 0, 0);
                    return false;
                });
            }
        }

        private void on_index_changed (int index, uint size) {
            action_set_enabled (ACTION_APP + ACTION_PREV, index > 0);
            action_set_enabled (ACTION_APP + ACTION_NEXT, index < (int) size - 1);
            scroll_to_item (index);
        }

        private void on_search_text_changed () {
            string text = search_entry.text;
            if (text.ascii_ncasecmp ("artist=", 7) == 0) {
                _search_property = text.substring (7);
                _search_type = SearchType.ARTIST;
            } else if (text.ascii_ncasecmp ("title=", 6) == 0) {
                _search_property = text.substring (6);
                _search_type = SearchType.TITLE;
            } else {
                _search_type = SearchType.ALL;
            }
            _search_text = text;
            update_song_filter ();
        }

        private void on_song_changed (Song song) {
            update_song_info (song);
            action_set_enabled (ACTION_APP + ACTION_PLAY, true);
        }

        private void scroll_to_item (int index) {
            list_view.activate_action ("list.scroll-to-item", "u", index);
        }

        private static string simple_html_encode (string text) {
            return text.replace ("&", "&amp;").replace ("<",  "&lt;").replace (">", "&gt;");
        }

        private void update_song_info (Song song) {
            var artist_text = simple_html_encode (song.artist);
            play_bar.description = (@"$(artist_text)");
            play_bar.title = song.title;
            this.title = song.artist == UNKNOWN_ARTIST ? song.title : @"$(song.artist) - $(song.title)";
        }

        private void update_song_filter () {
            var app = (Application) application;
            if (search_btn.active && _search_text.length > 0) {
                app.song_list.filter = new Gtk.CustomFilter ((obj) => {
                    var song = (Song) obj;
                    switch (_search_type) {
                        case SearchType.ARTIST:
                            return song.artist == _search_property;
                        case SearchType.TITLE:
                            return song.title == _search_property;
                        default:
                            return _search_text.match_string (song.artist, false)
                                || _search_text.match_string (song.title, false);
                    }
                });
            } else {
                app.song_list.set_filter (null);
            }
            if (!app.find_current_item ()) {
                app.index_changed (app.current_item, app.song_list.get_n_items ());
            }
        }
    }

    public static async void save_data_to_file (File file, Bytes data) {
        try {
            var stream = yield file.create_async (FileCreateFlags.NONE);
            yield stream.write_bytes_async (data);
            yield stream.close_async ();
        } catch (Error e) {
        }
    }
}
