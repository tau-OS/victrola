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
    public class LyricPage : He.Bin {
        Application app = (Application) GLib.Application.get_default ();
        public Gtk.Window window { get; construct; }
        LyricsFetcher fetcher;
        Lyric current_lyric;
        Gtk.TextView view;
        Gtk.ScrolledWindow scrolled;
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

            fetcher = new LyricsFetcher ();

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

            var get_lyrics_button = new He.Button ("", "Fetch Lyrics") {
                halign = Gtk.Align.CENTER,
                is_pill = true,
                margin_bottom = 18
            };

            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            main_box.vexpand = main_box.hexpand = true;
            main_box.append (scrolled);
            main_box.append (get_lyrics_button);

            this.child = main_box;
            this.vexpand = this.hexpand = true;

            get_lyrics_button.clicked.connect (() => {
                update_lyric.begin ();
            });
        }

        private async void update_lyric () {
            ThreadFunc<void*> run = () => {
                var lyric = "";
                bool error = false;
                var r = fetcher.get_lyric (cur_song.title, cur_song.artist);

                if (r != null) {
                    lyric = r.lyric;
                    if (lyric == "") {
                        error = true;
                    }
                    current_lyric = r;
                } else {
                    error = true;
                }

                if (error == true) {
                    clean_text_buffer ();
                    insert_text (_("No lyrics found!"));
                } else {
                    Idle.add (() => {
                        clean_text_buffer ();
                        insert_text (lyric);
                        show_lyrics ();
                        return false;
                    });
                }
                return null;
            };

            try {
                new Thread<void*>.try (null, run);
            } catch (Error e) {
                warning (e.message);
            }
        }

        private void insert_text (string text) {
            Gtk.TextIter text_start;
            Gtk.TextIter text_end;

            view.buffer.get_start_iter (out text_start);
            view.buffer.insert (ref text_start, text, text.length);
            view.buffer.get_end_iter (out text_end);
            view.buffer.apply_tag_by_name ("lyric", text_start, text_end);
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
            scrolled.show ();
        }

        public void update_cur_song (Song song) {
            cur_song = song;
        }
    }
}
