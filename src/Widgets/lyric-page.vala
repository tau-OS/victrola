/*
 * Copyright 2022-2025 Fyra Labs
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
    public class LyricPage : He.Bin {
        Application app = (Application) GLib.Application.get_default ();
        public Gtk.Window window { get; construct; }
        LyricsFetcher fetcher;
        string current_lyric;
        Gtk.TextView view;
        Gtk.ScrolledWindow scrolled;
        Gtk.Label no_lyrics_label;
        public string last_title;
        public string last_artist;
        private int64 last_position;
        private bool was_paused;
        public Song? cur_song { get; set; }

        public LyricPage (Gtk.Window window) {
            Object (
                    window : window
            );
            last_title = "";
            last_artist = "";
            last_position = 0;
            was_paused = false;
        }

        construct {
            var player = app.player;
            var main_window = (MainWindow) window;

            fetcher = new LyricsFetcher ();

            // Create back button (only visible in non-folded/desktop view)
            var back_button = new He.Button ("", "");
            back_button.icon_name = "go-previous-symbolic";
            back_button.is_iconic = true;
            back_button.add_css_class ("media-toggle-button");
            back_button.margin_start = 12;
            back_button.margin_top = 12;
            back_button.halign = Gtk.Align.START;
            back_button.clicked.connect (() => {
                main_window.play_bar.lyrics_btn.active = false;
            });
            // Bind visibility to album.folded - show button when NOT folded (desktop)
            main_window.album.bind_property ("folded", back_button, "visible", BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);

            view = new Gtk.TextView () {
                editable = false,
                wrap_mode = Gtk.WrapMode.WORD,
                vexpand = true,
                cursor_visible = false,
                top_margin = 12,
                left_margin = 12,
                right_margin = 12
            };
            view.add_css_class ("view-lyric");
            view.remove_css_class ("view");

            scrolled = new Gtk.ScrolledWindow ();
            scrolled.set_child (view);

            no_lyrics_label = new Gtk.Label (_("No Lyrics")) {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER,
                vexpand = true,
                hexpand = true
            };
            no_lyrics_label.add_css_class ("dim-label");
            no_lyrics_label.add_css_class ("title-1");

            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            main_box.vexpand = main_box.hexpand = true;
            main_box.append (back_button);
            main_box.append (scrolled);
            main_box.append (no_lyrics_label);

            this.child = main_box;
            this.vexpand = this.hexpand = true;

            // Initially show the no lyrics label
            scrolled.visible = false;
            no_lyrics_label.visible = true;
        }

        private async void update_lyric() {
            try {
                clean_text_buffer();
        
                warning ("Fetching lyrics for title: '%s', artist: '%s'", cur_song.title, cur_song.artist);
                var lyrics = yield fetcher.fetch_lyrics(cur_song.title, cur_song.artist);
                
                if (lyrics == "" || lyrics == null) {
                    warning ("No lyrics found");
                    scrolled.visible = false;
                    no_lyrics_label.visible = true;
                    return;
                }
        
                warning ("Got lyrics object!");
                current_lyric = lyrics;
                clean_text_buffer();
                insert_text(lyrics);
                show_lyrics();
            } catch (Error e) {
                warning("Unexpected error while fetching lyrics: %s", e.message);
                scrolled.visible = false;
                no_lyrics_label.visible = true;
            }
        }

        private void insert_text (string? text) {
            Gtk.TextIter text_start;
            Gtk.TextIter text_end;

            view.buffer.get_start_iter (out text_start);
            view.buffer.insert (ref text_start, text, -1);
            view.buffer.get_end_iter (out text_end);
        }

        private void clean_text_buffer () {
            Gtk.TextIter start;
            Gtk.TextIter end;
            view.buffer.get_start_iter (out start);
            view.buffer.get_end_iter (out end);
            view.buffer.delete (ref start, ref end);
        }

        private void show_lyrics () {
            scrolled.get_vadjustment ().set_value (0);
            scrolled.visible = true;
            no_lyrics_label.visible = false;
        }

        public void update_cur_song (Song song) {
            cur_song = song;
            // Automatically fetch lyrics when song changes
            update_lyric.begin ();
        }
    }
}
