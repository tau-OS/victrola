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
    public class AlbumItem : Object {
        public string name { get; set; }
        public string artist { get; set; }
        public uint song_count { get; set; }
        public GenericArray<Song> songs { get; set; }
        public string? cover_uri { get; set; }

        public AlbumItem (string album_name, string album_artist) {
            name = album_name;
            artist = album_artist;
            songs = new GenericArray<Song> ();
            song_count = 0;
            cover_uri = null;
        }

        public void add_song (Song song) {
            songs.add (song);
            song_count = songs.length;

            // Use the first song's cover as album cover
            if (cover_uri == null && song.cover_uri != null) {
                cover_uri = song.cover_uri;
            }
        }
    }

    public class AlbumPage : He.Bin {
        private Application app;
        private Gtk.Stack main_stack;
        private Gtk.GridView album_grid_view;
        private Gtk.ListView song_list_view;
        private Gtk.Label header_label;
        private Gtk.Label artist_label;
        private He.Button back_button;
        private Gtk.Image album_cover;
        private ListStore album_store;
        private ListStore current_album_songs;
        private AlbumItem? current_album;

        construct {
            app = (Application) GLib.Application.get_default ();

            album_store = new ListStore (typeof (AlbumItem));
            current_album_songs = new ListStore (typeof (Song));

            build_ui ();
            connect_signals ();
            populate_albums ();
        }

        private void build_ui () {
            main_stack = new Gtk.Stack ();
            main_stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            // Albums grid page
            var albums_page = build_albums_page ();
            main_stack.add_named (albums_page, "albums");

            // Individual album page
            var album_detail_page = build_album_detail_page ();
            main_stack.add_named (album_detail_page, "album-detail");

            main_stack.visible_child_name = "albums";
            this.child = main_stack;
        }

        private Gtk.Widget build_albums_page () {
            var page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Albums grid
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((item) => {
                var list_item = (Gtk.ListItem) item;
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
                box.add_css_class ("mini-content-block");

                var cover_image = new Gtk.Image ();
                cover_image.pixel_size = 160;
                cover_image.halign = Gtk.Align.CENTER;

                var album_label = new Gtk.Label ("");
                album_label.halign = Gtk.Align.CENTER;
                album_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
                album_label.max_width_chars = 20;
                album_label.add_css_class ("cb-title");

                var artist_label = new Gtk.Label ("");
                artist_label.halign = Gtk.Align.CENTER;
                artist_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
                artist_label.max_width_chars = 20;
                artist_label.add_css_class ("cb-subtitle");

                var count_label = new Gtk.Label ("");
                count_label.halign = Gtk.Align.CENTER;
                count_label.add_css_class ("caption");

                box.append (cover_image);
                box.append (album_label);
                box.append (artist_label);
                box.append (count_label);

                list_item.child = box;
            });

            factory.bind.connect ((item) => {
                var list_item = (Gtk.ListItem) item;
                var album_item = (AlbumItem) list_item.item;
                var box = (Gtk.Box) list_item.child;

                var cover_image = (Gtk.Image) box.get_first_child ();
                var album_label = (Gtk.Label) box.get_first_child ().get_next_sibling ();
                var artist_label = (Gtk.Label) album_label.get_next_sibling ();
                var count_label = (Gtk.Label) artist_label.get_next_sibling ();

                album_label.label = album_item.name;
                artist_label.label = album_item.artist;
                count_label.label = album_item.song_count.to_string () + " songs";

                // Load album cover
                if (album_item.cover_uri != null) {
                    load_album_cover_async.begin (album_item.cover_uri, cover_image);
                } else {
                    cover_image.icon_name = "folder-music-symbolic";
                }
            });

            album_grid_view = new Gtk.GridView (new Gtk.NoSelection (album_store), factory);
            album_grid_view.max_columns = 6;
            album_grid_view.min_columns = 2;
            album_grid_view.single_click_activate = true;
            album_grid_view.activate.connect (on_album_activated);
            album_grid_view.add_css_class ("content-grid");

            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.child = album_grid_view;
            scrolled.vexpand = true;

            page_box.append (scrolled);
            return page_box;
        }

        private Gtk.Widget build_album_detail_page () {
            var page_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Header with back button and album info
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            header_box.margin_top = 12;
            header_box.margin_bottom = 12;

            back_button = new He.Button ("", "");
            back_button.icon_name = "go-previous-symbolic";
            back_button.is_iconic = true;
            back_button.clicked.connect (() => {
                main_stack.visible_child_name = "albums";
            });

            var info_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            info_box.hexpand = true;
            info_box.halign = Gtk.Align.START;

            album_cover = new Gtk.Image ();
            album_cover.pixel_size = 64;

            var text_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            header_label = new Gtk.Label ("");
            header_label.add_css_class ("view-subtitle");
            header_label.halign = Gtk.Align.START;

            artist_label = new Gtk.Label ("");
            artist_label.add_css_class ("cb-title");
            artist_label.halign = Gtk.Align.START;

            text_box.append (header_label);
            text_box.append (artist_label);

            info_box.append (album_cover);
            info_box.append (text_box);

            header_box.append (back_button);
            header_box.append (info_box);

            page_box.append (header_box);

            // Songs list for selected album
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
                entry.update (song, SortMode.ALBUM);
            });

            song_list_view = new Gtk.ListView (new Gtk.NoSelection (current_album_songs), factory);
            song_list_view.single_click_activate = true;
            song_list_view.activate.connect (on_song_activated);
            song_list_view.add_css_class ("content-list");

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

        private void populate_albums () {
            var albums_map = new HashTable<string, AlbumItem> (str_hash, str_equal);

            // Group songs by album
            var song_count = app.song_list.get_n_items ();
            for (uint i = 0; i < song_count; i++) {
                var song = (Song) app.song_list.get_item (i);
                var album_name = song.album;
                var artist_name = song.artist;

                if (album_name == null || album_name.length == 0) {
                    album_name = UNKNOWN_ALBUM;
                }
                if (artist_name == null || artist_name.length == 0) {
                    artist_name = UNKNOWN_ARTIST;
                }

                // Create unique key combining album and artist
                var key = album_name + " - " + artist_name;
                AlbumItem? album_item = albums_map[key];
                if (album_item == null) {
                    album_item = new AlbumItem (album_name, artist_name);
                    albums_map[key] = album_item;
                }
                album_item.add_song (song);
            }

            // Add to store and sort
            var albums_list = new GenericArray<AlbumItem> ();
            albums_map.for_each ((key, album) => {
                albums_list.add (album);
            });

            albums_list.sort ((a, b) => {
                int result = strcmp (a.name, b.name);
                if (result == 0) {
                    result = strcmp (a.artist, b.artist);
                }
                return result;
            });

            album_store.splice (0, album_store.get_n_items (), albums_list.data);
        }

        private async void load_album_cover_async (string uri, Gtk.Image image) {
            var file = File.new_for_uri (uri);
            if (file.is_native ()) {
                var tags = parse_gst_tags (file);
                if (tags != null) {
                    var sample = GstPlayer.parse_image_from_tag_list (tags);
                    if (sample != null) {
                        var pixbuf = MainWindow.load_clamp_pixbuf_from_sample (sample, 160);
                        if (pixbuf != null) {
                            var paintable = Gdk.Texture.for_pixbuf (pixbuf);
                            var art = MainWindow.update_cover_paintable (image, paintable);
                            if (art != null) {
                                image.paintable = art;
                            } else {
                                image.paintable = paintable;
                            }
                            return;
                        }
                    }
                }
            }
            image.icon_name = "folder-music-symbolic";
        }

        private void on_album_activated (uint position) {
            var album_item = (AlbumItem) album_store.get_item (position);
            current_album = album_item;
            header_label.label = album_item.name;
            artist_label.label = album_item.artist;

            // Load album cover for detail view
            if (album_item.cover_uri != null) {
                load_album_cover_async.begin (album_item.cover_uri, album_cover);
            } else {
                album_cover.icon_name = "folder-music-symbolic";
            }

            // Clear and populate songs for this album, sorted by track number
            current_album_songs.remove_all ();

            // Sort songs by track number
            var sorted_songs = new GenericArray<Song> ();
            for (uint i = 0; i < album_item.songs.length; i++) {
                sorted_songs.add (album_item.songs[i]);
            }
            sorted_songs.sort ((a, b) => {
                if (a.track != UNKNOWN_TRACK && b.track != UNKNOWN_TRACK) {
                    return a.track - b.track;
                }
                return strcmp (a.title, b.title);
            });

            current_album_songs.splice (0, 0, sorted_songs.data);
            main_stack.visible_child_name = "album-detail";
        }

        private void on_song_activated (uint position) {
            if (current_album == null)return;

            var song = (Song) current_album_songs.get_item (position);

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
            if (album_grid_view.model != null) {
                var count = album_grid_view.model.get_n_items ();
                for (uint i = 0; i < count; i++) {
                    album_grid_view.model.items_changed (i, 0, 0);
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
            album_store.remove_all ();
            populate_albums ();
        }
    }
}