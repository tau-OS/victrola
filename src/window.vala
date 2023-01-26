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
        private unowned Gtk.Box info_box;
        [GtkChild]
        private unowned Gtk.Box infogrid;
        [GtkChild]
        private unowned He.SideBar listgrid;
        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.ListView list_view1;
        [GtkChild]
        private unowned Gtk.ListView list_view2;
        [GtkChild]
        private unowned Gtk.ListView list_view3;
        [GtkChild]
        public unowned Gtk.ToggleButton search_btn;
        [GtkChild]
        private unowned Gtk.Button music_dir_btn;
        [GtkChild]
        private unowned Gtk.SearchEntry search_entry;
        [GtkChild]
        private unowned He.AppBar info_title;

        private string _search_text = "";
        private string _search_property = "";
        private SearchType _search_type = SearchType.ALL;
        private PlayBar play_bar;
        private InfoPage info_page;
        uint num1;
        uint num2;
        uint num3;

        public SortMode sort_mode {
            set {
                switch (value) {
                    case SortMode.ALBUM:
                        list_view1.set_visible (true);
                        list_view2.set_visible (false);
                        list_view3.set_visible (false);
                        num1 = list_view1.get_model ().get_n_items ();
                        search_entry.placeholder_text = num1.to_string() + " " + (_("songs"));
                        break;
                    case SortMode.ARTIST:
                        list_view1.set_visible (false);
                        list_view2.set_visible (true);
                        list_view3.set_visible (false);
                        num2 = list_view2.get_model ().get_n_items ();
                        search_entry.placeholder_text = num2.to_string() + " " + (_("songs"));
                        break;
                    case SortMode.RECENT:
                    case SortMode.SHUFFLE:
                        break;
                    default:
                        list_view1.set_visible (false);
                        list_view2.set_visible (false);
                        list_view3.set_visible (true);
                        num3 = list_view3.get_model ().get_n_items ();
                        search_entry.placeholder_text = num3.to_string() + " " + (_("songs"));
                        break;
                }
            }
        }

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

            app.bind_property ("sort_mode", this, "sort_mode", BindingFlags.DEFAULT);
            sort_mode = app.sort_mode;

            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((item) => {
                item.child = new SongEntry ();
            });
            factory.bind.connect (on_bind_item);
            list_view1.factory = factory;
            list_view1.model = new Gtk.NoSelection (app.song_list);
            list_view1.activate.connect ((index) => {
                app.current_item = (int) index;
                if (album.folded) {
                    album.set_visible_child (infogrid);
                }
            });
            num1 = list_view1.get_model ().get_n_items ();

            var factory2 = new Gtk.SignalListItemFactory ();
            factory2.setup.connect ((item) => {
                item.child = new SongEntry ();
            });
            factory2.bind.connect (on_bind_item);
            list_view2.factory = factory2;
            list_view2.model = new Gtk.NoSelection (app.song_list);
            list_view2.activate.connect ((index) => {
                app.current_item = (int) index;
                if (album.folded) {
                    album.set_visible_child (infogrid);
                }
            });
            num2 = list_view2.get_model ().get_n_items ();

            var factory3 = new Gtk.SignalListItemFactory ();
            factory3.setup.connect ((item) => {
                item.child = new SongEntry ();
            });
            factory3.bind.connect (on_bind_item);
            list_view3.factory = factory3;
            list_view3.model = new Gtk.NoSelection (app.song_list);
            list_view3.activate.connect ((index) => {
                app.current_item = (int) index;
                if (album.folded) {
                    album.set_visible_child (infogrid);
                }
            });
            num3 = list_view3.get_model ().get_n_items ();

            app.song_changed.connect (on_song_changed);
            app.index_changed.connect (on_index_changed);
            app.song_tag_parsed.connect (on_song_tag_parsed);

            Settings settings = new Settings ("co.tauos.Victrola");
            stack.notify["visible-child-name"].connect (() => {
                if (stack.visible_child_name == "album") {
                    app.sort_mode = SortMode.ALBUM;
                    app.find_current_item ();
                    settings?.set_uint ("sort-mode", SortMode.ALBUM);
                } else if (stack.visible_child_name == "artist") {
                    app.sort_mode = SortMode.ARTIST;
                    app.find_current_item ();
                    settings?.set_uint ("sort-mode", SortMode.ARTIST);
                } else if (stack.visible_child_name == "title") {
                    app.sort_mode = SortMode.ALL;
                    app.find_current_item ();
                    settings?.set_uint ("sort-mode", SortMode.ALL);
                }
            });

            app.load_songs_async.begin (null, (obj, res) => {
                var item = app.load_songs_async.end (res);
                if (app.current_song == null) {
                    app.current_item = item;
                    scroll_to_item (item);
                } else {
                    scroll_to_item (item);
                }
            });

            info_title.back_button.clicked.connect (() => {
                if (album.folded) {
                    album.set_visible_child (listgrid);
                }
            });
        }

        private async void on_bind_item (Gtk.ListItem item) {
            var app = (Application) application;
            var entry = (SongEntry) item.child;
            var song = (Song) item.item;
            entry.playing = item.position == app.current_item;
            entry.update (song, app.sort_mode);
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

        private Bis.Animation? fade_animation = null;
        private async void on_song_tag_parsed (Song song, Gst.Sample? image) {
            update_song_info (song);
            
            var app = (Application) application;
            var pixbufs = new Gdk.Pixbuf?[1] {null};

            if (song == app.current_song) {
                Gdk.Paintable? paintable = null;
                if (image != null) {
                    pixbufs[0] = load_clamp_pixbuf_from_sample ((!)image, 300);
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

                var target = new Bis.CallbackAnimationTarget ((value) => {
                    info_page.cover_art.opacity = value;
                });
                fade_animation?.pause ();
                fade_animation = new Bis.TimedAnimation (info_page.cover_art, 0.1, info_page.cover_art.opacity + 0.1, 900, target);
                ((!)fade_animation).done.connect (() => {
                    fade_animation = null;
                });
                fade_animation?.play ();
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
            list_view1.activate_action ("list.scroll-to-item", "u", index);
            list_view2.activate_action ("list.scroll-to-item", "u", index);
            list_view3.activate_action ("list.scroll-to-item", "u", index);
        }

        private static string simple_html_encode (string text) {
            return text.replace ("&", "&amp;").replace ("<",  "&lt;").replace (">", "&gt;");
        }

        private void update_song_info (Song song) {
            info_page.update (song);
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
