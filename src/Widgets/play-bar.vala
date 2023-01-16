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
    public class PlayBar : He.BottomBar {
        private Gtk.ToggleButton _repeat = new Gtk.ToggleButton ();
        private He.IconicButton _prev = new He.IconicButton ("");
        private He.IconicButton _play = new He.IconicButton ("");
        private He.IconicButton _next = new He.IconicButton ("");
        private He.IconicButton _stop = new He.IconicButton ("");
        private int _duration = 1;
        private int _position = 0;
        Application app = (Application) GLib.Application.get_default ();

        construct {
            var builder = new Gtk.Builder ();
            var player = app.player;

            this.collapse_actions = false;
            this.margin_top = 12;

            append_button ((He.IconicButton)_repeat, Position.LEFT);
            append_button (_prev, Position.LEFT);
            append_button (_play, Position.LEFT);
            append_button (_next, Position.LEFT);
            append_button (_stop, Position.LEFT);

            _repeat.icon_name = "media-playlist-repeat-symbolic";
            _repeat.valign = Gtk.Align.CENTER;
            _repeat.tooltip_text = _("Repeat Song");
            _repeat.add_css_class ("flat");
            _repeat.toggled.connect (() => {
                _repeat.icon_name = _repeat.active ? "media-playlist-repeat-song-symbolic" : "media-playlist-repeat-symbolic";
                app.single_loop = ! app.single_loop;
            });

            _prev.valign = Gtk.Align.CENTER;
            _prev.action_name = ACTION_APP + ACTION_PREV;
            _prev.icon_name = "media-skip-backward-symbolic";
            _prev.tooltip_text = _("Play Previous");
            _prev.add_css_class ("flat");

            _play.valign = Gtk.Align.CENTER;
            _play.action_name = ACTION_APP + ACTION_PLAY;
            _play.icon_name = "media-playback-start-symbolic";
            _play.tooltip_text = _("Play/Pause");
            _play.add_css_class ("flat");

            _next.valign = Gtk.Align.CENTER;
            _next.action_name = ACTION_APP + ACTION_NEXT;
            _next.icon_name = "media-skip-forward-symbolic";
            _next.tooltip_text = _("Play Next");
            _next.add_css_class ("flat");

            _stop.valign = Gtk.Align.CENTER;
            _stop.action_name = ACTION_APP + ACTION_STOP;
            _stop.icon_name = "media-playback-stop-symbolic";
            _stop.tooltip_text = _("Stop");
            _stop.add_css_class ("flat");

            player.duration_changed.connect ((duration) => {
                ((MainWindow)app.active_window).album.notify["folded"].connect (() => {
                    if (((MainWindow)app.active_window).album.folded) {
                        this.duration = GstPlayer.to_second (duration);
                    }
                });
            });
            player.position_updated.connect ((position) => {
                ((MainWindow)app.active_window).album.notify["folded"].connect (() => {
                    if (((MainWindow)app.active_window).album.folded) {
                        this.position = GstPlayer.to_second (position);
                    }
                });
            });
            player.state_changed.connect ((state) => {
                var playing = state == Gst.State.PLAYING;
                _play.icon_name = playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic";
            });
        }

        public double duration {
            get { return _duration; }
            set {
                _duration = (int) (value + 0.5);
            }
        }

        public double position {
            get { return _position; }
            set {
                if (_position != (int) value) {
                    _position = (int) value;
                }
            }
        }
    }

    public static string format_time (int seconds) {
        int minutes = seconds / 60;
        seconds -= minutes * 60;
        var sb = new StringBuilder ();
        sb.printf ("%d:%02d", minutes, seconds);
        return sb.str;
    }
}