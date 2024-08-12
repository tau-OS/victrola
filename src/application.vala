/*
 * Copyright 2022 Fyra Labs
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Victrola {
    public const string ACTION_APP = "app.";
    public const string ACTION_ABOUT = "about";
    public const string ACTION_OPEN = "open";
    public const string ACTION_PLAY = "play";
    public const string ACTION_PREV = "prev";
    public const string ACTION_NEXT = "next";
    public const string ACTION_STOP = "stop";
    public const string ACTION_SEARCH = "search";
    public const string ACTION_SORT = "sort";
    public const string ACTION_QUIT = "quit";

    struct ActionShortKey {
        public weak string name;
        public weak string key;
    }

    public class Application : He.Application {
        private int _current_item = -1;
        private Song? _current_song = null;
        private Gst.Sample? _cover_image = null;
        private GstPlayer _player = new GstPlayer ();
        private Gtk.FilterListModel _song_list = new Gtk.FilterListModel (null, null);
        private SongStore _song_store = new SongStore ();
        private Gtk.FilterListModel _album_list = new Gtk.FilterListModel (null, null);
        private AlbumStore _album_store = new AlbumStore ();
        private Settings _settings = new Settings ("com.fyralabs.Victrola");
        private MprisPlayer? _mpris = null;
        private uint _mpris_id = 0;

        public signal void loading_changed (bool loading, uint size);
        public signal void index_changed (int index, uint size);
        public signal void song_changed (Song song);
        public signal void song_tag_parsed (Song song, Gst.Sample image);

        public SortMode sort_mode {
            get {
                return _song_store.sort_mode;
            }
            set {
                _song_store.sort_mode = value;
                _album_store.sort_mode = value;
            }
        }

        public Application () {
            Object (application_id : "com.fyralabs.Victrola", flags : ApplicationFlags.HANDLES_OPEN);

            ActionEntry[] action_entries = {
                { ACTION_ABOUT, show_about },
                { ACTION_OPEN, on_open },
                { ACTION_PLAY, play_pause },
                { ACTION_PREV, play_previous },
                { ACTION_NEXT, play_next },
                { ACTION_STOP, stop },
                { ACTION_SEARCH, toggle_search },
                { ACTION_QUIT, quit }
            };
            add_action_entries (action_entries, this);

            ActionEntry[] sort_entries = {
                { ACTION_SORT, sort_by, "u", "0" },
                { ACTION_SORT, sort_by, "u", "1" },
                { ACTION_SORT, sort_by, "u", "2" },
                { ACTION_SORT, sort_by, "u", "3" },
                { ACTION_SORT, sort_by, "u", "4" }
            };
            add_action_entries (sort_entries, this);

            ActionShortKey[] action_keys = {
                { ACTION_PLAY, "<primary>p" },
                { ACTION_PREV, "<primary>m" },
                { ACTION_NEXT, "<primary>n" },
                { ACTION_SEARCH, "<primary>f" },
                { ACTION_QUIT, "<primary>q" }
            };
            foreach (var item in action_keys) {
                set_accels_for_action (ACTION_APP + item.name, { item.key });
            }

            _song_list.model = _song_store.store;
            _song_store.sort_mode = (SortMode) (_settings ? .get_uint ("sort-mode") ?? SortMode.TITLE);
            _album_list.model = _album_store.store;
            _album_store.sort_mode = SortMode.ALBUM;

            _player.end_of_stream.connect (() => {
                if (single_loop) {
                    _player.seek (0);
                    _player.play ();
                } else {
                    current_item++;
                }
            });

            _player.tag_parsed.connect (on_tag_parsed);

            var mpris_id = Bus.own_name (BusType.SESSION,
                                         "org.mpris.MediaPlayer2." + application_id,
                                         BusNameOwnerFlags.NONE,
                                         on_bus_acquired,
                                         null, null
            );
            if (mpris_id == 0)
                warning ("Initialize MPRIS session failed\n");
        }

        protected override void startup () {
            Gdk.RGBA accent_color = { 0 };
            accent_color.parse ("#F7812B");
            default_accent_color = He.from_gdk_rgba (accent_color);
            override_accent_color = true;
            default_scheme_variant = He.SchemeVariant.CONTENT;

            resource_base_path = "/com/fyralabs/Victrola";

            base.startup ();

            Bis.init ();

            typeof (InfoPage).ensure ();
            typeof (PlayBar).ensure ();
            typeof (SongEntry).ensure ();

            new MainWindow (this);

            // Must load tag cache after the app register (GLib init), to make sort works
            _song_store.load_tag_cache_async.begin ((obj, res) => {
                _song_store.load_tag_cache_async.end (res);
            });

            _album_store.load_tag_cache_async.begin ((obj, res) => {
                _album_store.load_tag_cache_async.end (res);
            });
        }

        public override void shutdown () {
            if (_mpris_id != 0) {
                Bus.unown_name (_mpris_id);
                _mpris_id = 0;
            }

            _song_store.save_tag_cache_async.begin ((obj, res) => {
                _song_store.save_tag_cache_async.end (res);
            });

            _album_store.save_tag_cache_async.begin ((obj, res) => {
                _album_store.save_tag_cache_async.end (res);
            });

            delete_cover_tmp_file_async.begin ((obj, res) => {
                delete_cover_tmp_file_async.end (res);
            });

            base.shutdown ();
        }

        protected override void activate () {
            active_window?.present ();
        }

        public override void open (File[] files, string hint) {
            load_songs_async.begin (files, (obj, res) => {
                var play_item = load_songs_async.end (res);
                Idle.add (() => {
                    current_item = play_item;
                    if (files.length > 0)
                        _player.play ();
                    return false;
                });
            });

            new MainWindow (this);
        }

        public void on_open () {
            var music_dir = get_music_folder ();
            var chooser = new Gtk.FileChooserNative (null, active_window,
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
                        settings.set_string ("music-dir", ((!) dir).get_uri ());
                        reload_song_store ();
                    }
                }
            });
            chooser.show ();
        }

        public int current_item {
            get {
                return _current_item;
            }
            set {
                var count = _song_list.get_n_items ();
                value = value < count ? value : 0;
                var playing = _current_song != null;
                var song = _song_list.get_item (value) as Song;
                if (song != null && _current_song != song) {
                    _current_song = song;
                    _player.uri = ((!) song).uri;
                    song_changed ((!) song);
                }
                if (_current_item != value) {
                    var old_item = _current_item;
                    _current_item = value;
                    _song_list.items_changed (old_item, 0, 0);
                    _song_list.items_changed (value, 0, 0);
                    index_changed (value, count);
                }
                _player.state = playing ? Gst.State.PLAYING : Gst.State.PAUSED;
            }
        }

        public Song? current_song {
            get {
                return _current_song;
            }
        }

        public GstPlayer player {
            get {
                return _player;
            }
        }

        public Settings settings {
            get {
                return _settings;
            }
        }

        public bool single_loop { get; set; }

        public Gtk.FilterListModel song_list {
            get {
                return _song_list;
            }
        }

        public Gtk.FilterListModel album_list {
            get {
                return _album_list;
            }
        }

        public File get_music_folder () {
            var music_uri = _settings.get_string ("music-dir");
            if (music_uri.length > 0) {
                return File.new_for_uri (music_uri);
            } else {
                var music_path = Environment.get_user_special_dir (UserDirectory.MUSIC);
                return File.new_for_path (music_path);
            }
        }

        public void play_next () {
            current_item = current_item + 1;
        }

        public void play_pause () {
            _player.playing = !_player.playing;
        }

        public void stop () {
            _player.playing = false;
        }

        public void play_previous () {
            current_item = current_item - 1;
        }

        public void sort_by (SimpleAction action, Variant? parameter) {
            sort_mode = (SortMode) (parameter ? .get_uint32 () ?? 2);
            _settings?.set_uint ("sort-mode", sort_mode);

            find_current_item ();
        }

        public void reload_song_store () {
            _song_store.clear ();
            _album_store.clear ();
            _current_item = -1;
            index_changed (-1, 0);
            load_songs_async.begin ({}, (obj, res) => {
                current_item = load_songs_async.end (res);
            });
        }

        public void toggle_search () {
            var win = active_window as MainWindow;
            if (win != null)
                ((!) win).search_btn.active = !((!) win).search_btn.active;
        }

        public bool find_current_item () {
            if (_song_list.get_item (_current_item) == _current_song)
                return false;

            // find current item
            var old_item = _current_item;
            var count = _song_list.get_n_items ();
            _current_item = -1;
            for (var i = 0; i < count; i++) {
                if (_current_song == _song_list.get_item (i)) {
                    _current_item = i;
                    break;
                }
            }
            if (old_item != _current_item) {
                _song_list.items_changed (old_item, 0, 0);
                _song_list.items_changed (_current_item, 0, 0);
                index_changed (_current_item, count);
                return true;
            }
            return false;
        }

        public async int load_songs_async (owned File[]? files) {
            var saved_size = _song_store.size;
            var play_item = _current_item;
            loading_changed (true, saved_size);

            if (saved_size == 0 && files.length == 0) {
#if HAS_TRACKER_SPARQL
                if (_settings.get_boolean ("tracker-mode")) {
                    yield _song_store.add_sparql_async ();
                } else
#endif
                {
                    files.resize (1);
                    files[0] = get_music_folder ();
                }
            }
            if (files.length > 0) {
                yield _song_store.add_files_async (files);
            }

            loading_changed (false, _song_store.size);
            if (saved_size > 0) {
                play_item = (int) saved_size;
            } else if (_current_song != null && _current_song == _song_list.get_item (_current_item)) {
                play_item = _current_item;
            } else {
                var uri = _current_song ? .uri ?? _settings.get_string ("played-uri");
                if (uri.length > 0) {
                    var count = _song_list.get_n_items ();
                    for (var i = 0; i < count; i++) {
                        var song = (Song) _song_list.get_item (i);
                        if (uri == song.uri) {
                            play_item = i;
                            break;
                        }
                    }
                }
            }
            return play_item;
        }

        public void show_about () {
            var about = new He.AboutWindow (
                                            active_window,
                                            "Victrola" + Config.NAME_SUFFIX,
                                            Config.APP_ID,
                                            Config.VERSION,
                                            Config.APP_ID,
                                            "https://github.com/tau-OS/victrola/tree/main/po",
                                            "https://github.com/tau-OS/victrola/issues",
                                            "https://github.com/tau-OS/victrola/",
                                            {},
                                            { "Fyra Labs" },
                                            2023,
                                            He.AboutWindow.Licenses.GPLV3,
                                            He.Colors.ORANGE
            );
            about.present ();
        }

        private void on_bus_acquired (DBusConnection connection, string name) {
            _mpris = new MprisPlayer (this, connection);
            try {
                connection.register_object ("/org/mpris/MediaPlayer2", _mpris);
                connection.register_object ("/org/mpris/MediaPlayer2", new MprisRoot (this));
            } catch (Error e) {
                warning ("Register MPRIS failed: %s\n", e.message);
            }
        }

        private async void on_tag_parsed (string? album, string? artist, string? title, Gst.Sample? image) {
            _cover_image = image;
            if (_current_song != null) {
                var song = (!) current_song;
                song_tag_parsed (song, image);

                string? cover_uri = null;
                if (image != null) {
                    var file = File.new_build_filename (Environment.get_tmp_dir (), application_id + "_" + str_hash (song.cover_uri).to_string ("%x"));
                    yield save_sample_to_file (file, (!) image);
                    yield delete_cover_tmp_file_async ();

                    _cover_tmp_file = file;
                    cover_uri = file.get_uri ();
                }

                if (song == _current_song) {
                    if (cover_uri == null && song.cover_uri != song.uri) {
                        cover_uri = song.cover_uri;
                    }
                    _mpris?.send_meta_data (song, cover_uri);
                }
            }
        }

        public static async void save_sample_to_file (File file, Gst.Sample sample) {
            try {
                var buffer = sample.get_buffer ();
                Gst.MapInfo? info = null;
                if (buffer ? .map (out info, Gst.MapFlags.READ) ?? false) {
                    var stream = yield file.create_async (FileCreateFlags.NONE);

                    yield stream.write_all_async (info?.data, Priority.DEFAULT, null, null);

                    buffer?.unmap ((!) info);
                }
            } catch (Error e) {
            }
        }

        private File? _cover_tmp_file = null;
        private async void delete_cover_tmp_file_async () {
            try {
                if (_cover_tmp_file != null) {
                    yield ((!) _cover_tmp_file).delete_async ();
                    _cover_tmp_file = null;
                }
            } catch (Error e) {
            }
        }
    }
}
