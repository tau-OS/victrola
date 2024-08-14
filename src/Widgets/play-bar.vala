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
    public class PlayBar : Gtk.Box {
        private Gtk.ToggleButton _repeat = new Gtk.ToggleButton ();
        private He.Button _prev = new He.Button (null, "");
        private He.Button _play = new He.Button (null, "");
        private He.Button _next = new He.Button (null, "");
        private He.Button _stop = new He.Button (null, "");
        private int _duration = 1;
        private int _position = 0;
        Application app = (Application) GLib.Application.get_default ();

        construct {
            var builder = new Gtk.Builder ();
            var player = app.player;

            this.orientation = Gtk.Orientation.VERTICAL;
            this.halign = Gtk.Align.CENTER;
            this.spacing = 12;
            this.add_css_class ("play-bar");

            var top_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 18);
            var bottom_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 18);

            top_box.append (_prev);
            top_box.append (_play);
            top_box.append (_next);
            bottom_box.append (_repeat);
            bottom_box.append (_stop);

            append(top_box);
            append(bottom_box);

            _repeat.valign = Gtk.Align.CENTER;
            _repeat.icon_name = "media-playlist-repeat-symbolic";
            _repeat.halign = Gtk.Align.START;
            _repeat.hexpand = true;
            _repeat.tooltip_text = _("Repeat Song");
            _repeat.add_css_class ("iconic-button");
            _repeat.add_css_class ("media-toggle-button");
            _repeat.remove_css_class ("image-button");
            _repeat.toggled.connect (() => {
                _repeat.icon_name = _repeat.active ? "media-playlist-repeat-song-symbolic" : "media-playlist-repeat-symbolic";
                app.single_loop = ! app.single_loop;
            });

            _prev.action_name = ACTION_APP + ACTION_PREV;
            _prev.icon_name = "media-skip-backward-symbolic";
            _prev.tooltip_text = _("Play Previous");
            _prev.is_iconic = true;
            _prev.add_css_class ("media-button");

            _play.action_name = ACTION_APP + ACTION_PLAY;
            _play.icon_name = "media-playback-start-symbolic";
            _play.tooltip_text = _("Play/Pause");
            _play.is_iconic = true;
            _play.add_css_class ("play-button");

            _next.action_name = ACTION_APP + ACTION_NEXT;
            _next.icon_name = "media-skip-forward-symbolic";
            _next.tooltip_text = _("Play Next");
            _next.is_iconic = true;
            _next.add_css_class ("media-button");

            _stop.halign = Gtk.Align.END;
            _stop.hexpand = true;
            _stop.action_name = ACTION_APP + ACTION_STOP;
            _stop.icon_name = "media-playback-stop-symbolic";
            _stop.add_css_class ("media-toggle-button");
            _stop.tooltip_text = _("Stop");
            _stop.is_iconic = true;

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