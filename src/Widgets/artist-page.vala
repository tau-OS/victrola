/*
 * Copyright 2025 Fyra Labs
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
    public class ArtistItem : Object {
        public string name { get; set; }
        public uint song_count { get; set; }
        public GenericArray<Song> songs { get; set; }

        public ArtistItem (string artist_name) {
            name = artist_name;
            songs = new GenericArray<Song> ();
            song_count = 0;
        }

        public void add_song (Song song) {
            songs.add (song);
            song_count = songs.length;
        }
    }

    public class ArtistPage : He.Bin {
        private Application app;
        private Gtk.Stack main_stack;
        private Gtk.ListView artist_list_view;
        private Gtk.ListView song_list_view;
        private Gtk.Label header_label;
        private He.Button back_button;
        private ListStore artist_store;
        private ListStore current_artist_songs;
        private ArtistItem? current_artist;

        construct {
            app = (Application) GLib.Application.get_default ();

            artist_store = new ListStore (typeof (ArtistItem));
            current_artist_songs = new ListStore (typeof (Song));

            build_ui ();
            connect_signals ();
            populate_artists ();
        }

        private void build_ui () {
            main_stack = new Gtk.Stack ();
            main_stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            // Artists list page
            var artists_page = build_artists_page ();
            main_stack.add_named (artists_page, "artists");

            // Individual artist page
            var artist_detail_page = build_artist_detail_page ();
            main_stack.add_named (artist_detail_page, "artist-detail");

            main_stack.visible_child_name = "artists";
            this.child = main_stack;
        }

        private Gtk.Widget build_artists_page () {
            var page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Artists list
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((item) => {
                var list_item = (Gtk.ListItem) item;
                var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
                box.margin_top = 8;
                box.margin_bottom = 8;
                box.margin_start = 18;
                box.margin_end = 18;

                var name_label = new Gtk.Label ("");
                name_label.halign = Gtk.Align.START;
                name_label.hexpand = true;
                name_label.add_css_class ("cb-title");

                var count_label = new Gtk.Label ("");
                count_label.halign = Gtk.Align.END;
                count_label.add_css_class ("dim-label");

                box.append (name_label);
                box.append (count_label);

                list_item.child = box;
            });

            factory.bind.connect ((item) => {
                var list_item = (Gtk.ListItem) item;
                var artist_item = (ArtistItem) list_item.item;
                var box = (Gtk.Box) list_item.child;

                var name_label = (Gtk.Label) box.get_first_child ();
                var count_label = (Gtk.Label) box.get_last_child ();

                name_label.label = artist_item.name;
                count_label.label = artist_item.song_count.to_string () + " songs";
            });

            artist_list_view = new Gtk.ListView (new Gtk.NoSelection (artist_store), factory);
            artist_list_view.single_click_activate = true;
            artist_list_view.activate.connect (on_artist_activated);

            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.child = artist_list_view;
            scrolled.vexpand = true;

            page_box.append (scrolled);
            return page_box;
        }

        private Gtk.Widget build_artist_detail_page () {
            var page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Header with back button
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.margin_top = 12;
            header_box.margin_bottom = 12;

            back_button = new He.Button ("", "");
            back_button.icon_name = "go-previous-symbolic";
            back_button.is_iconic = true;
            back_button.clicked.connect (() => {
                main_stack.visible_child_name = "artists";
            });

            header_label = new Gtk.Label ("");
            header_label.add_css_class ("view-subtitle");
            header_label.hexpand = true;
            header_label.halign = Gtk.Align.CENTER;

            header_box.append (back_button);
            header_box.append (header_label);

            page_box.append (header_box);

            // Songs list for selected artist
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((item) => {
                var list_item = (Gtk.ListItem) item;
                list_item.child = new SongEntry ();
            });

            factory.bind.connect ((item) => {
                var list_item = (Gtk.ListItem) item;
                var song = (Song) list_item.item;
                var entry = (SongEntry) list_item.child;

                entry.playing = list_item.position == app.current_item;
                entry.update (song, SortMode.TITLE);
            });

            song_list_view = new Gtk.ListView (new Gtk.NoSelection (current_artist_songs), factory);
            song_list_view.single_click_activate = true;
            song_list_view.activate.connect (on_song_activated);

            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.child = song_list_view;
            scrolled.vexpand = true;

            page_box.append (scrolled);
            return page_box;
        }

        private void connect_signals () {
            app.song_changed.connect (update_playing_indicators);
            app.index_changed.connect (update_playing_indicators);
        }

        private void populate_artists () {
            var artists_map = new HashTable<string, ArtistItem> (str_hash, str_equal);

            // Group songs by artist
            var song_count = app.song_list.get_n_items ();
            for (uint i = 0; i < song_count; i++) {
                var song = (Song) app.song_list.get_item (i);
                var artist_name = song.artist;

                if (artist_name == null || artist_name.length == 0) {
                    artist_name = UNKNOWN_ARTIST;
                }

                ArtistItem? artist_item = artists_map[artist_name];
                if (artist_item == null) {
                    artist_item = new ArtistItem (artist_name);
                    artists_map[artist_name] = artist_item;
                }
                artist_item.add_song (song);
            }

            // Add to store and sort
            var artists_list = new GenericArray<ArtistItem> ();
            artists_map.for_each ((name, artist) => {
                artists_list.add (artist);
            });

            artists_list.sort ((a, b) => {
                return strcmp (a.name, b.name);
            });

            artist_store.splice (0, artist_store.get_n_items (), artists_list.data);
        }

        private void on_artist_activated (uint position) {
            var artist_item = (ArtistItem) artist_store.get_item (position);
            current_artist = artist_item;
            header_label.label = artist_item.name;

            // Clear and populate songs for this artist
            current_artist_songs.remove_all ();
            current_artist_songs.splice (0, 0, artist_item.songs.data);

            main_stack.visible_child_name = "artist-detail";
        }

        private void on_song_activated (uint position) {
            if (current_artist == null)return;

            var song = (Song) current_artist_songs.get_item (position);

            // Find this song's position in the main song list
            var song_count = app.song_list.get_n_items ();
            for (uint i = 0; i < song_count; i++) {
                var main_song = (Song) app.song_list.get_item (i);
                if (main_song.uri == song.uri) {
                    app.current_item = (int) i;
                    break;
                }
            }
        }

        private void update_playing_indicators () {
            // Update playing indicators in both views
            if (artist_list_view.model != null) {
                var count = artist_list_view.model.get_n_items ();
                for (uint i = 0; i < count; i++) {
                    artist_list_view.model.items_changed (i, 0, 0);
                }
            }

            if (song_list_view.model != null) {
                var count = song_list_view.model.get_n_items ();
                for (uint i = 0; i < count; i++) {
                    song_list_view.model.items_changed (i, 0, 0);
                }
            }
        }

        public void refresh () {
            artist_store.remove_all ();
            populate_artists ();
        }
    }
}
