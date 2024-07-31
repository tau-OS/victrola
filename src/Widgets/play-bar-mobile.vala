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
    public class PlayBarMobile : Gtk.Box {
        private He.Button _play = new He.Button (null, "");
        private He.Button _expand = new He.Button (null, "");
        Gtk.Label start_duration;
        Gtk.Label end_duration;
        Gtk.Label song_title;
        Gtk.Label song_artist;
        public Gtk.Image cover_art;
        public Gtk.Image cover_blur;
        private int _duration = 1;
        private int _position = 0;
        Application app = (Application) GLib.Application.get_default ();

        construct {
            var builder = new Gtk.Builder ();
            var player = app.player;

            _play.action_name = ACTION_APP + ACTION_PLAY;
            _play.icon_name = "media-playback-start-symbolic";
            _play.tooltip_text = _("Play/Pause");
            _play.is_iconic = true;
            _play.add_css_class ("play-button");

            _expand.icon_name = "external-link-symbolic";
            _expand.tooltip_text = _("Expand Info");
            _expand.is_iconic = true;
            _expand.add_css_class ("media-button");

            cover_art = new Gtk.Image ();
            cover_art.width_request = 64;
            cover_art.height_request = 64;
            cover_art.halign = Gtk.Align.CENTER;
            cover_art.valign = Gtk.Align.CENTER;
            cover_art.add_css_class ("cover-art");

            cover_blur = new Gtk.Image ();
            cover_blur.width_request = 64;
            cover_blur.height_request = 64;
            cover_blur.halign = Gtk.Align.CENTER;
            cover_blur.valign = Gtk.Align.CENTER;
            cover_blur.add_css_class ("cover-art-blur");

            var cover_box  = new Gtk.Overlay ();
            cover_box.add_overlay (cover_art);
            cover_box.set_child (cover_blur);

            var song_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            song_box.halign = Gtk.Align.CENTER;
            song_box.valign = Gtk.Align.CENTER;
            song_title = new Gtk.Label ("");
            song_title.add_css_class ("title");
            song_title.max_width_chars = 1;
            song_title.max_width_chars = 20;
            song_title.wrap = true;
            song_title.ellipsize = Pango.EllipsizeMode.MIDDLE;
            song_title.margin_start = 18;
            song_title.margin_end = 18;
            song_artist = new Gtk.Label ("");
            song_artist.add_css_class ("subtitle");
            song_box.append (song_title);
            song_box.append (song_artist);

            var duration_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            duration_box.halign = Gtk.Align.CENTER;
            duration_box.valign = Gtk.Align.CENTER;
            start_duration = new Gtk.Label ("0:00");
            var sep_duration = new Gtk.Label ("/");
            end_duration = new Gtk.Label ("0:00");
            duration_box.append (start_duration);
            duration_box.append (sep_duration);
            duration_box.append (end_duration);

            var bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
                hexpand = true
            };
            bottom_box.append (song_box);
            bottom_box.append (duration_box);

            this.spacing = 18;
            this.add_css_class ("bottom-bar");

            append (cover_box);
            append(bottom_box);
            append (_expand);
            append (_play);

            _expand.clicked.connect (() => {
                ((MainWindow)app.active_window).album.set_visible_child (((MainWindow)app.active_window).infogrid);
            });

            player.duration_changed.connect ((duration) => {
                this.duration = GstPlayer.to_second (duration);
            });
            player.position_updated.connect ((position) => {
                this.position = GstPlayer.to_second (position);
            });
            player.state_changed.connect ((state) => {
                var playing = state == Gst.State.PLAYING;
                _play.icon_name = playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic";
            });
        }

        public void update (Song song) {
            song_title.label = song.title;
            song_artist.label = song.artist;
        }

        public double duration {
            get { return _duration; }
            set {
                _duration = (int) (value);
                this.end_duration.label = format_time (_duration);
            }
        }

        public double position {
            get { return _position; }
            set {
                if (_position != (int) value) {
                    _position = (int) value;
                    this.start_duration.label = format_time (_position);
                }
            }
        }
    }
}