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

    [GtkTemplate (ui = "/com/fyralabs/Victrola/window.ui")]
    public class MainWindow : He.ApplicationWindow {
        [GtkChild]
        public unowned Bis.Album album;
        [GtkChild]
        private unowned Gtk.Box info_box;
        [GtkChild]
        private unowned Gtk.Box lyrics_box;
        [GtkChild]
        public unowned Gtk.Box infogrid;
        [GtkChild]
        private unowned He.SideBar listgrid;
        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.Stack infostack;
        [GtkChild]
        private unowned Gtk.ListView list_view3;
        [GtkChild]
        public unowned Gtk.ToggleButton search_btn;
        [GtkChild]
        public unowned Gtk.ToggleButton lyrics_btn;
        [GtkChild]
        private unowned Gtk.MenuButton menu_btn;
        [GtkChild]
        private unowned Gtk.SearchEntry search_entry;
        [GtkChild]
        private unowned He.AppBar info_title;
        [GtkChild]
        private unowned Gtk.Box info_box_mobile;
        [GtkChild]
        public unowned Gtk.Overlay about_overlay;
        [GtkChild]
        public unowned He.Bin infobin;
        [GtkChild]
        public unowned He.Bin mobile_infobin;

        private string _search_text = "";
        private string _search_property = "";
        private SearchType _search_type = SearchType.ALL;
        private PlayBar play_bar;
        private PlayBarMobile play_bar_mobile;
        private InfoPage info_page;
        private LyricPage lyric_page;
        private ArtistPage artist_page;
        private AlbumPage album_page;
    private int all_songs_highlight = -1;
    private bool suppress_scroll = false;
    private HashTable<int, SongEntry> song_entries;
        uint num3;        public SortMode sort_mode {
            set {
                switch (value) {
                case SortMode.ALBUM:
                    list_view3.set_visible (false);
                    search_entry.placeholder_text = "Search albums...";
                    break;
                case SortMode.ARTIST:
                    list_view3.set_visible (false);
                    search_entry.placeholder_text = "Search artists...";
                    break;
                case SortMode.RECENT:
                case SortMode.SHUFFLE:
                    break;
                default:
                    list_view3.set_visible (true);
                    num3 = list_view3.get_model ().get_n_items ();
                    search_entry.placeholder_text = num3.to_string () + " " + (_("songs"));
                    break;
                }
            }
        }

        public MainWindow (Application app) {
            Object (
                    application: app
            );
            this.icon_name = app.application_id;

            song_entries = new HashTable<int, SongEntry> (direct_hash, direct_equal);

            menu_btn.get_popover ().has_arrow = false;

            var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            theme.add_resource_path ("/com/fyralabs/Victrola/");

            search_btn.toggled.connect (() => {
                if (search_btn.active)
                    search_entry.grab_focus ();
                update_song_filter ();
            });
            search_entry.search_changed.connect (on_search_text_changed);

            play_bar = new PlayBar ();
            play_bar_mobile = new PlayBarMobile ();
            info_page = new InfoPage ();
            info_box.append (info_page);
            info_box.append (play_bar);

            info_box_mobile.append (play_bar_mobile);

            lyric_page = new LyricPage (this);
            lyrics_box.append (lyric_page);

            // Initialize new pages
            artist_page = new ArtistPage ();
            album_page = new AlbumPage ();

            // Add new pages to stack
            stack.add_titled (artist_page, "artist", _("Artists"));
            stack.get_page (artist_page).icon_name = "system-users-symbolic";
            stack.add_titled (album_page, "album", _("Albums"));
            stack.get_page (album_page).icon_name = "media-optical-cd-audio-symbolic";

            lyrics_btn.toggled.connect (() => {
                if (lyrics_btn.active) {
                    infostack.set_visible_child_name ("lyrics");
                } else {
                    infostack.set_visible_child_name ("info");
                }
            });

            action_set_enabled (ACTION_APP + ACTION_PREV, false);
            action_set_enabled (ACTION_APP + ACTION_PLAY, false);
            action_set_enabled (ACTION_APP + ACTION_NEXT, false);

            app.bind_property ("sort_mode", this, "sort_mode", BindingFlags.DEFAULT);
            sort_mode = app.sort_mode;

            // Setup only the remaining list view for "All Songs"
            var factory3 = new Gtk.SignalListItemFactory ();
            factory3.setup.connect ((item) => {
                ((Gtk.ListItem) item).child = new SongEntry ();
            });
            factory3.bind.connect (on_bind_item);
            factory3.unbind.connect ((item) => {
                var list_item = (Gtk.ListItem) item;
                var entry = (SongEntry) list_item.child;
                entry.playing = false;
                song_entries.remove ((int) list_item.position);
            });
            list_view3.factory = factory3;
            list_view3.model = new Gtk.NoSelection (app.song_list);
            
            list_view3.activate.connect ((index) => {
                suppress_scroll = true;
                app.play_item ((int) index);
                Idle.add (() => {
                    suppress_scroll = false;
                    return false;
                });
            });
            num3 = list_view3.get_model ().get_n_items ();

            app.song_changed.connect (on_song_changed);
            app.index_changed.connect (on_index_changed);
            app.song_tag_parsed.connect (on_song_tag_parsed);
            refresh_all_songs_highlight (app.current_item);

            Settings settings = new Settings ("com.fyralabs.Victrola");
            stack.notify["visible-child-name"].connect (() => {
                if (stack.visible_child_name == "album") {
                    album_page.refresh ();
                    app.sort_mode = SortMode.ALBUM;
                    app.find_current_item ();
                    settings?.set_uint ("sort-mode", SortMode.ALBUM);
                    album_page.update_playing_indicators ();
                } else if (stack.visible_child_name == "artist") {
                    artist_page.refresh ();
                    app.sort_mode = SortMode.ARTIST;
                    app.find_current_item ();
                    settings?.set_uint ("sort-mode", SortMode.ARTIST);
                    artist_page.update_playing_indicators ();
                } else if (stack.visible_child_name == "title") {
                    app.sort_mode = SortMode.ALL;
                    app.find_current_item ();
                    settings?.set_uint ("sort-mode", SortMode.ALL);
                    artist_page.update_playing_indicators ();
                    album_page.update_playing_indicators ();
                    refresh_all_songs_highlight (app.current_item);
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

                // Refresh the new pages when songs are loaded
                artist_page.refresh ();
                album_page.refresh ();
            });

            info_title.back_button.clicked.connect (() => {
                if (album.folded) {
                    album.set_visible_child (listgrid);
                }
            });

            listgrid.remove_css_class ("sidebar-view");

            album.notify["folded"].connect (() => {
                if (album.folded) {
                    info_box.remove_css_class ("side-pane");
                } else {
                    info_box.add_css_class ("side-pane");
                }
            });

            infobin.content_color_override = true;
            mobile_infobin.content_color_override = true;
        }

        private void on_bind_item (Gtk.SignalListItemFactory factory, Object item) {
            var app = (Application) application;
            var list_item = (Gtk.ListItem) item;
            if (!(list_item.item is Song))
                return;
            var song = (Song) list_item.item;
            var entry = (SongEntry) list_item.child;
            var is_playing = app.is_current_song (song);
            entry.playing = is_playing;
            entry.update (song, app.sort_mode);
            
            // Store reference to this entry
            song_entries.set ((int) list_item.position, entry);
        }

        private void on_index_changed (int index, uint size) {
            var app = (Application) application;
            action_set_enabled (ACTION_APP + ACTION_PREV, index > 0);
            action_set_enabled (ACTION_APP + ACTION_NEXT, index < (int) size - 1);
            if (!suppress_scroll)
                scroll_to_item (index);
            refresh_all_songs_highlight (index);
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
            lyric_page.update_cur_song (song);
            action_set_enabled (ACTION_APP + ACTION_PLAY, true);
            var app = (Application) application;
            refresh_all_songs_highlight (app.current_item);
            artist_page.update_playing_indicators ();
            album_page.update_playing_indicators ();
        }

        private He.Animation? fade_animation = null;
        private async void on_song_tag_parsed (Song song, Gst.Sample? image) {
            update_song_info (song);

            var app = (Application) application;
            var pixbufs = new Gdk.Pixbuf ? [1] { null };

            if (app.is_current_song (song)) {
                Gdk.Paintable? paintable = null;
                if (image != null) {
                    pixbufs[0] = load_clamp_pixbuf_from_sample ((!) image, 300);
                }

                if (pixbufs[0] != null) {
                    paintable = Gdk.Texture.for_pixbuf ((!) pixbufs[0]);
                }

                accent_set.begin ((!) pixbufs[0].scale_simple (128, 128, Gdk.InterpType.NEAREST));

                var art = update_cover_paintable (info_page.cover_art, paintable);
                info_page.cover_art.paintable = art;
                play_bar_mobile.cover_art.paintable = art;
                print ("Update cover\n");
                var blur = update_blur_paintable (info_page.cover_blur, paintable);
                info_page.cover_blur.paintable = blur;
                play_bar_mobile.cover_blur.paintable = art;
                print ("Update blur\n");

                var target = new He.CallbackAnimationTarget ((value) => {
                    info_page.cover_art.opacity = value;
                    play_bar_mobile.cover_art.opacity = value;
                });
                fade_animation?.pause ();

                fade_animation = new He.TimedAnimation (info_page.cover_art, 0.1,
                                                        info_page.cover_art.opacity + 0.1,
                                                        900,
                                                        target);
                ((!) fade_animation).done.connect (() => {
                    fade_animation = null;
                });
                fade_animation?.play ();
            }
        }

        private void refresh_all_songs_highlight (int index) {
            var app = (Application) application;
            if (app.song_list == null)
                return;

            // Turn off the old highlight
            if (all_songs_highlight >= 0 && all_songs_highlight != index) {
                var old_entry = song_entries.get (all_songs_highlight);
                if (old_entry != null) {
                    old_entry.playing = false;
                }
            }

            all_songs_highlight = index;

            // Turn on the new highlight
            if (index >= 0) {
                var new_entry = song_entries.get (index);
                if (new_entry != null) {
                    new_entry.playing = true;
                }
            }
            
            // Scroll to the item if not suppressing
            if (!suppress_scroll && index >= 0 && index < (int) app.song_list.get_n_items ()) {
                scroll_to_item (index);
            }
        }

        public static Gdk.Texture? update_cover_paintable (Gtk.Widget widget, Gdk.Paintable paintable) {
            var snapshot = new Gtk.Snapshot ();
            var rect = (!) Graphene.Rect ().init (0, 0, 256, 256);
            var rounded = (!) Gsk.RoundedRect ().init_from_rect (rect, 6);
            snapshot.push_rounded_clip (rounded);
            paintable.snapshot (snapshot, 256, 256);
            snapshot.pop ();
            var node = snapshot.free_to_node ();
            if (node is Gsk.RenderNode) {
                return widget.get_native () ? .get_renderer () ? .render_texture ((!) node, rect);
            }
            return null;
        }
        private static Gdk.Texture? update_blur_paintable (Gtk.Widget widget, Gdk.Paintable paintable) {
            var snapshot = new Gtk.Snapshot ();
            var rect = (!) Graphene.Rect ().init (0, 0, 256, 256);
            var rounded = (!) Gsk.RoundedRect ().init_from_rect (rect, 6);
            snapshot.push_rounded_clip (rounded);
            paintable.snapshot (snapshot, 256, 256);
            snapshot.pop ();
            var node = snapshot.free_to_node ();
            if (node is Gsk.RenderNode) {
                return widget.get_native () ? .get_renderer () ? .render_texture ((!) node, rect);
            }
            return null;
        }

        public static Gdk.Pixbuf? load_clamp_pixbuf_from_sample (Gst.Sample sample, int size) {
            var buffer = sample.get_buffer ();
            Gst.MapInfo? info = null;

            if (buffer ? .map (out info, Gst.MapFlags.READ) ?? false) {
                var bytes = new Bytes.static (info ? .data);
                var stream = new MemoryInputStream.from_bytes (bytes);
                try {
                    var pixbuf = new Gdk.Pixbuf.from_stream (stream);
                    var width = pixbuf.width; var height = pixbuf.height;
                    if (size > 0 && width > size && height > size) {
                        var scale = width > height ? (size / (double) height) : (size / (double) width);
                        var dx = (int) (width * scale + 0.5); var dy = (int) (height * scale + 0.5);
                        var newbuf = pixbuf.scale_simple (dx, dy, Gdk.InterpType.TILES);
                        if (newbuf != null)
                            return ((!) newbuf);
                        buffer?.unmap ((!) info);
                    }
                } catch (Error e) {
                    try {
                        var pixbuf = new Gdk.Pixbuf.from_resource ("/com/fyralabs/Victrola/cover.png");
                        var width = pixbuf.width; var height = pixbuf.height;
                        if (size > 0 && width > size && height > size) {
                            var scale = width > height ? (size / (double) height) : (size / (double) width);
                            var dx = (int) (width * scale + 0.5); var dy = (int) (height * scale + 0.5);
                            var newbuf = pixbuf.scale_simple (dx, dy, Gdk.InterpType.TILES);
                            if (newbuf != null)
                                return ((!) newbuf);
                            buffer?.unmap ((!) info);
                        }
                    } catch (Error e2) {
                        print ("Failed to load pixbuf from resource: %s\n", e2.message);
                    }
                }
            }
            return null;
        }
        public static Gdk.Pixbuf? load_clamp_pixbuf_from_uri (string uri, int size) {
            try {
                var pixbuf = new Gdk.Pixbuf.from_file (uri);
                var width = pixbuf.width; var height = pixbuf.height;
                if (size > 0 && width > size && height > size) {
                    var scale = width > height ? (size / (double) height) : (size / (double) width);
                    var dx = (int) (width * scale + 0.5); var dy = (int) (height * scale + 0.5);
                    var newbuf = pixbuf.scale_simple (dx, dy, Gdk.InterpType.TILES);
                    if (newbuf != null)
                        return ((!) newbuf);
                }
            } catch (Error e) {
                try {
                    var pixbuf = new Gdk.Pixbuf.from_resource ("/com/fyralabs/Victrola/cover.png");
                    var width = pixbuf.width; var height = pixbuf.height;
                    if (size > 0 && width > size && height > size) {
                        var scale = width > height ? (size / (double) height) : (size / (double) width);
                        var dx = (int) (width * scale + 0.5); var dy = (int) (height * scale + 0.5);
                        var newbuf = pixbuf.scale_simple (dx, dy, Gdk.InterpType.TILES);
                        if (newbuf != null)
                            return ((!) newbuf);
                    }
                } catch (Error e2) {
                    print ("Failed to load pixbuf from resource: %s\n", e2.message);
                }
            }
            return null;
        }

        private void scroll_to_item (int index) {
            list_view3.activate_action ("list.scroll-to-item", "u", index);
        }

        private void update_song_info (Song song) {
            info_page.update (song);
            play_bar_mobile.update (song);
            lyric_page.update_cur_song (song);
        }

        public async void accent_set (Gdk.Pixbuf? pixbuf) {
            var loop = new MainLoop ();
            He.Ensor.accent_from_pixels_async.begin (pixbuf.get_pixels_with_length (), pixbuf.get_has_alpha (), (obj, res) => {
                GLib.Array<int> result = He.Ensor.accent_from_pixels_async.end (res);
                int top = result.index (0);

                if (top != 0) {
                    Gdk.RGBA accent_color = { 0 };
                    accent_color.parse (He.hexcode_argb (top));
                    infobin.content_source_color = { accent_color.red, accent_color.green, accent_color.blue };
                    mobile_infobin.content_source_color = { accent_color.red, accent_color.green, accent_color.blue };
                } else {
                    Gdk.RGBA accent_color = { 0 };
                    accent_color.parse ("#f99e5c");
                    infobin.content_source_color = { accent_color.red, accent_color.green, accent_color.blue };
                    mobile_infobin.content_source_color = { accent_color.red, accent_color.green, accent_color.blue };
                }
                loop.quit ();
            });
            loop.run ();
        }

        private void update_song_filter () {
            var app = (Application) application;
            if (search_btn.active && _search_text.length > 0) {
                app.song_list.filter = new Gtk.CustomFilter ((obj) => {
                    var song = (Song) obj;
                    switch (_search_type) {
                        case SearchType.ARTIST :
                            return song.artist == _search_property;
                        case SearchType.TITLE :
                            return song.title == _search_property;
                            default :
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