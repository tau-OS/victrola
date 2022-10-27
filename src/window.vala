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
    public const string ACTION_WIN = "win.";

    enum SearchType {
        ALL,
        ARTIST,
        TITLE
    }

    [GtkTemplate (ui = "/co/tauos/Victrola/window.ui")]
    public class MainWindow : He.ApplicationWindow {
        [GtkChild]
        public unowned Bis.Album album;
        [GtkChild]
        private unowned Gtk.Box content_box;
        [GtkChild]
        private unowned Gtk.Box info_box;
        [GtkChild]
        private unowned Gtk.ListView list_view;
        [GtkChild]
        public unowned Gtk.ToggleButton search_btn;
        [GtkChild]
        private unowned Gtk.Button music_dir_btn;
        [GtkChild]
        private unowned Gtk.SearchEntry search_entry;

        private string _search_text = "";
        private string _search_property = "";
        private SearchType _search_type = SearchType.ALL;
        private PlayBar play_bar;
        private InfoPage info_page;

        public MainWindow (Application app) {
            Object (application: app);
            this.icon_name = app.application_id;

            search_btn.toggled.connect (() => {
                if (search_btn.active)
                    search_entry.grab_focus ();
                update_song_filter ();
            });
            search_entry.search_changed.connect (on_search_text_changed);

            var music_dir = app.get_music_folder ();
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
                            app.settings.set_string ("music-dir", ((!)dir).get_uri ());
                            app.reload_song_store ();
                        }
                    }
                });
                chooser.show ();
            });

            play_bar = new PlayBar ();
            info_page = new InfoPage ();
            info_box.append (info_page);
            info_box.append (play_bar);

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
            uint num = list_view.get_model ().get_n_items ();
            search_entry.placeholder_text = num.to_string() + " " + (_("songs"));
            app.song_changed.connect (on_song_changed);
            app.index_changed.connect (on_index_changed);
            app.song_tag_parsed.connect (on_song_tag_parsed);
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

        private async void on_song_tag_parsed (Song song, Gst.Sample? image) {
            update_song_info (song);
            
            var app = (Application) application;
            var pixbufs = new Gdk.Pixbuf?[1] {null};

            if (song == app.current_song) {
                Gdk.Paintable? paintable = null;
                if (image != null) {
                    pixbufs[0] = load_clamp_pixbuf_from_sample ((!)image, 280);
                }

                if (pixbufs[0] != null) {
                    paintable = Gdk.Texture.for_pixbuf ((!)pixbufs[0]);
                }

                var art = update_cover_paintable (song, info_page.cover_art, paintable);
                info_page.cover_art.paintable = art;
                print ("Update cover\n");
                var blur = update_blur_paintable (song, info_page.cover_blur, paintable);
                info_page.cover_blur.paintable = blur;
                print ("Update blur\n");
            }
        }

        private static Gdk.Texture? update_cover_paintable (Song song, Gtk.Widget widget, Gdk.Paintable paintable) {
            var snapshot = new Gtk.Snapshot ();
            var rect = (!)Graphene.Rect ().init (0, 0, 300, 300);
            var rounded = (!)Gsk.RoundedRect ().init_from_rect (rect, 18);
            snapshot.push_rounded_clip (rounded);
            paintable.snapshot (snapshot, 300, 300);
            snapshot.pop ();
            var node = snapshot.free_to_node ();
            if (node is Gsk.RenderNode) {
                return widget.get_native ()?.get_renderer ()?.render_texture ((!)node, rect);
            }
            return null;
        }
        private static Gdk.Texture? update_blur_paintable (Song song, Gtk.Widget widget, Gdk.Paintable paintable) {
            var snapshot = new Gtk.Snapshot ();
            var rect = (!)Graphene.Rect ().init (0, 0, 300, 300);
            var rounded = (!)Gsk.RoundedRect ().init_from_rect (rect, 18);
            snapshot.push_rounded_clip (rounded);
            paintable.snapshot (snapshot, 300, 300);
            snapshot.pop ();
            var node = snapshot.free_to_node ();
            if (node is Gsk.RenderNode) {
                return widget.get_native ()?.get_renderer ()?.render_texture ((!)node, rect);
            }
            return null;
        }

        public static Gdk.Pixbuf? load_clamp_pixbuf_from_sample (Gst.Sample sample, int size) {
            var buffer = sample.get_buffer ();
            Gst.MapInfo? info = null;

            if (buffer?.map (out info, Gst.MapFlags.READ) ?? false) {
                var bytes = new Bytes.static (info?.data);
                var stream = new MemoryInputStream.from_bytes (bytes);
                try {
                    var pixbuf = new Gdk.Pixbuf.from_stream (stream);
                    var width = pixbuf.width; var height = pixbuf.height;
                    if (size > 0 && width > size && height > size) {
                        var scale = width > height ? (size / (double) height) : (size / (double) width);
                        var dx = (int) (width * scale + 0.5); var dy = (int) (height * scale + 0.5);
                        var newbuf = pixbuf.scale_simple (dx, dy, Gdk.InterpType.TILES);
                        if (newbuf != null)
                            return ((!)newbuf);
                        buffer?.unmap((!) info);
                    }
                } catch (Error e) {
                    // w/e lol lmao even
                }
            }
            return null;
        }

        private void scroll_to_item (int index) {
            list_view.activate_action ("list.scroll-to-item", "u", index);
        }

        private static string simple_html_encode (string text) {
            return text.replace ("&", "&amp;").replace ("<",  "&lt;").replace (">", "&gt;");
        }

        private void update_song_info (Song song) {
            var artist_text = simple_html_encode (song.artist);
            album.notify["folded"].connect (() => {
                if (album.folded) {
                    play_bar.description = (@"$(artist_text)");
                    play_bar.title = song.title;
                } else {
                    play_bar.description = "";
                    play_bar.title = "";
                }
            });
            info_page.update (song);
            this.title = song.artist == UNKNOWN_ARTIST ? song.title : @"$(song.artist) - $(song.title)";
            uint num = list_view.get_model ().get_n_items ();
            search_entry.placeholder_text = num.to_string() + " " + (_("songs"));
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
