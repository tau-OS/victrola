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
        Gtk.Label start_duration;
        Gtk.Label end_duration;
        Gtk.Label song_title;
        Gtk.Label song_artist;
        public Gtk.Image cover_art;
        public Gtk.Image cover_blur;
        private int _duration = 1;
        private int _position = 0;
        Application app = (Application) GLib.Application.get_default ();

        public signal void enter ();
        public signal void leave ();

        construct {
            var builder = new Gtk.Builder ();
            var player = app.player;

            _play.action_name = ACTION_APP + ACTION_PLAY;
            _play.icon_name = "media-playback-start-symbolic";
            _play.tooltip_text = _("Play/Pause");
            _play.is_iconic = true;
            _play.add_css_class ("play-button");

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

            var cover_box  = new Gtk.Overlay () {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            cover_box.add_overlay (cover_art);
            cover_box.set_child (cover_blur);

            var cover_action = new Gtk.Stack() {
                halign = Gtk.Align.CENTER,
                valign = Gtk.Align.CENTER
            };
            cover_action.transition_type = SLIDE_UP;
            cover_action.add_named (new Gtk.Box (VERTICAL, 0), "empty");
            cover_action.add_named (new Gtk.Image.from_icon_name ("external-link-symbolic"), "info");
            cover_action.visible_child_name = "empty";
            cover_action.set_opacity (0.88);

            var motion = new Gtk.EventControllerMotion ();
            motion.enter.connect (() => {
                cover_action.set_visible_child_full ("info", SLIDE_UP);
                cover_action.add_css_class("light");
                enter ();
            });
            motion.leave.connect (() => {
                cover_action.set_visible_child_full ("empty", SLIDE_DOWN);
                cover_action.remove_css_class("light");
                leave ();
            });
            cover_action.add_controller (motion);

            var click = new Gtk.GestureClick ();
            click.pressed.connect (() => {
                ((MainWindow)app.active_window).album.set_visible_child (((MainWindow)app.active_window).infogrid);
            });
            cover_action.add_controller (click);

            var cover_action_box  = new Gtk.Overlay ();
            cover_action_box.add_overlay (cover_action);
            cover_action_box.set_child (cover_box);

            var song_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            song_box.halign = Gtk.Align.CENTER;
            song_box.valign = Gtk.Align.CENTER;
            song_title = new Gtk.Label ("");
            song_title.add_css_class ("cb-subtitle");
            song_title.width_chars = 15;
            song_title.max_width_chars = 15;
            song_title.wrap = true;
            song_title.ellipsize = Pango.EllipsizeMode.END;
            song_artist = new Gtk.Label ("");
            song_artist.width_chars = 15;
            song_artist.max_width_chars = 15;
            song_artist.wrap = true;
            song_artist.ellipsize = Pango.EllipsizeMode.END;
            song_box.append (song_title);
            song_box.append (song_artist);

            var duration_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            duration_box.halign = Gtk.Align.CENTER;
            duration_box.valign = Gtk.Align.CENTER;
            start_duration = new Gtk.Label ("0:00");
            start_duration.add_css_class ("caption");
            var sep_duration = new Gtk.Label ("/");
            sep_duration.add_css_class ("caption");
            end_duration = new Gtk.Label ("0:00");
            end_duration.add_css_class ("caption");
            duration_box.append (start_duration);
            duration_box.append (sep_duration);
            duration_box.append (end_duration);

            var bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
                hexpand = true
            };
            bottom_box.append (song_box);
            bottom_box.append (duration_box);

            this.spacing = 18;
            this.add_css_class ("bottom-bar");

            append (cover_action_box);
            append (bottom_box);
            append (_play);

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