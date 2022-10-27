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
    public class InfoPage : He.Bin {
        Application app = (Application) GLib.Application.get_default ();
        Gtk.Label start_duration;
        Gtk.Label end_duration;
        Gtk.Label song_title;
        Gtk.Label song_artist;
        Gtk.Scale scale;
        public Gtk.Image cover_art;
        public Gtk.Image cover_blur;

        private int _position = 0;
        public double position {
            get { return _position; }
            set {
                if (_position != (int) value) {
                    _position = (int) value;
                    this.start_duration.label = format_time (_position);
                    scale.set_value (value);
                }
            }
        }

        private int _duration = 1;
        public double duration {
            get { return _duration; }
            set {
                _duration = (int) (value);
                this.end_duration.label = format_time (_duration);
                scale.set_range (0, _duration);
            }
        }

        construct {
            var player = app.player;

            cover_art = new Gtk.Image ();
            cover_art.width_request = 300;
            cover_art.height_request = 300;
            cover_art.halign = Gtk.Align.CENTER;
            cover_art.valign = Gtk.Align.CENTER;

            cover_blur = new Gtk.Image ();
            cover_blur.width_request = 300;
            cover_blur.height_request = 300;
            cover_blur.add_css_class ("cover-art");

            var cover_box  = new Gtk.Overlay ();
            cover_box.add_overlay (cover_art);
            cover_box.set_child (cover_blur);

            var bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            scale = new Gtk.Scale (Gtk.Orientation.HORIZONTAL, null);
            scale.width_request = 330;
            scale.halign = Gtk.Align.CENTER;
            scale.set_range (0, _duration);

            var song_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            song_box.margin_top = 24;
            song_title = new Gtk.Label ("");
            song_title.add_css_class ("cb-title");
            song_artist = new Gtk.Label ("");
            song_artist.add_css_class ("cb-subtitle");
            song_box.append (song_title);
            song_box.append (song_artist);

            var duration_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            duration_box.homogeneous = true;
            duration_box.margin_start = duration_box.margin_end = 18;
            duration_box.width_request = 300;
            duration_box.halign = Gtk.Align.CENTER;
            start_duration = new Gtk.Label ("0:00");
            end_duration = new Gtk.Label ("0:00");
            start_duration.halign = Gtk.Align.START;
            end_duration.halign = Gtk.Align.END;
            duration_box.append (start_duration);
            duration_box.append (end_duration);

            bottom_box.append (song_box);
            bottom_box.append (scale);
            bottom_box.append (duration_box);

            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            main_box.vexpand = main_box.hexpand = true;
            main_box.valign = Gtk.Align.CENTER;
            main_box.margin_start = main_box.margin_end = 18;
            main_box.append(cover_box);
            main_box.append(bottom_box);

            child = main_box;

            main_box.set_parent (this);

            this.vexpand = this.hexpand = true;

            player.duration_changed.connect ((duration) => {
                this.duration = GstPlayer.to_second (duration);
            });
            player.position_updated.connect ((position) => {
                this.position = GstPlayer.to_second (position);
            });

            scale.adjust_bounds.connect ((value) => {
                player.seek (GstPlayer.from_second (value));
            });
        }

        public void update (Song song) {
            song_title.label = song.title;
            song_artist.label = song.artist;
        }
    }
}