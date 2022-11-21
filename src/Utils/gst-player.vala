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
    public class GstPlayer : Object {

        public static void init (ref weak string[]? args) {
            Gst.init (ref args);
        }

        public static double to_second (Gst.ClockTime time) {
            return (double) time / Gst.SECOND;
        }

        public static Gst.ClockTime from_second (double time) {
            return (Gst.ClockTime) (time * Gst.SECOND);
        }

        private dynamic Gst.Pipeline? _pipeline = Gst.ElementFactory.make ("playbin", "player") as Gst.Pipeline;
        private Gst.ClockTime _duration = Gst.CLOCK_TIME_NONE;
        private Gst.ClockTime _position = Gst.CLOCK_TIME_NONE;
        private Gst.ClockTime _last_seeked_pos = Gst.CLOCK_TIME_NONE;
        private bool _show_peak = false;
        private Gst.State _state = Gst.State.NULL;
        private uint _tag_hash = 0;
        private bool _tag_parsed = false;
        private TimeoutSource? _timer = null;

        public signal void duration_changed (Gst.ClockTime duration);
        public signal void error (Error error);
        public signal void end_of_stream ();
        public signal void position_updated (Gst.ClockTime position);
        public signal void state_changed (Gst.State state);
        public signal void tag_parsed (string? album, string? artist, string? title, Gst.Sample? image);

        public GstPlayer () {
            if (_pipeline != null) {
                var pipeline = (!)_pipeline;
                pipeline.async_handling = true;
                pipeline.flags = 0x0022; // audio | native audio
                pipeline.get_bus ().add_watch (Priority.DEFAULT, bus_callback);
            }
        }

        ~GstPlayer () {
            _pipeline?.set_state (Gst.State.NULL);
            _timer?.destroy ();
        }

        public bool playing {
            get {
                return _state == Gst.State.PLAYING;
            }
            set {
                state = _state == Gst.State.PLAYING ? Gst.State.PAUSED : Gst.State.PLAYING;
            }
        }

        public Gst.State state {
            get {
                return _state;
            }
            set {
                _pipeline?.set_state (value);
            }
        }

        public string? uri {
            get {
                if (_pipeline != null)
                    return ((!)_pipeline).uri;
                return null;
            }
            set {
                _duration = Gst.CLOCK_TIME_NONE;
                _position = Gst.CLOCK_TIME_NONE;
                _state = Gst.State.NULL;
                _tag_hash = 0;
                _tag_parsed = false;
                _pipeline?.set_state (Gst.State.READY);
                if (_pipeline != null)
                    ((!)_pipeline).uri = value;
            }
        }

        public void play () {
            _pipeline?.set_state (Gst.State.PLAYING);
        }

        public void pause () {
            _pipeline?.set_state (Gst.State.PAUSED);
        }

        public void restart () {
            var saved_state = _state;
            if (saved_state != Gst.State.NULL) {
                _pipeline?.set_state (Gst.State.NULL);
                _pipeline?.set_state (saved_state);
            }
        }

        public void seek (Gst.ClockTime position) {
            var diff = (Gst.ClockTimeDiff) (position - _last_seeked_pos);
            if (diff > 10 * Gst.MSECOND || diff < -10 * Gst.MSECOND) {
                _last_seeked_pos = position;
                _pipeline?.seek_simple (Gst.Format.TIME, Gst.SeekFlags.ACCURATE | Gst.SeekFlags.FLUSH, (int64) position);
            }
        }

        private bool bus_callback (Gst.Bus bus, Gst.Message message) {
            switch (message.type) {
                case Gst.MessageType.DURATION_CHANGED:
                    on_duration_changed ();
                    break;

                case Gst.MessageType.STATE_CHANGED:
                    Gst.State old = Gst.State.NULL;
                    Gst.State state = Gst.State.NULL;
                    Gst.State pending = Gst.State.NULL;
                    message.parse_state_changed (out old, out state, out pending);
                    if (old == Gst.State.READY && state == Gst.State.PAUSED) {
                        on_duration_changed ();
                    }
                    if (_state != state) {
                        _state = state;
                        state_changed (_state);
                    }
                    if (state == Gst.State.PLAYING) {
                        reset_timer ();
                    } else {
                        _timer?.destroy ();
                        _timer = null;
                    }
                    timeout_callback ();
                    break;

                case Gst.MessageType.ERROR:
                    Error err;
                    string debug;
                    message.parse_error (out err, out debug);
                    _state = Gst.State.NULL;
                    print ("Player error: %s, %s\n", err.message, debug);
                    error (err);
                    break;

                case Gst.MessageType.EOS:
                    _pipeline?.set_state (Gst.State.READY);
                    end_of_stream ();
                    break;

                case Gst.MessageType.TAG:
                    if (!_tag_parsed) {
                        parse_tags (message);
                    }
                    break;

                default:
                    break;
            }
            return true;
        }

        private void reset_timer () {
            _timer?.destroy ();
            _timer = new TimeoutSource (_show_peak ? 66 : 200);
            _timer?.set_callback (timeout_callback);
            _timer?.attach (MainContext.default ());
        }

        private void parse_tags (Gst.Message message) {
            Gst.TagList tags;
            message.parse_tag (out tags);

            string? album = null, artist = null, title = null;
            var ret = tags.get_string (Gst.Tags.ALBUM, out album);
            ret |= tags.get_string (Gst.Tags.ARTIST, out artist);
            ret |= tags.get_string (Gst.Tags.TITLE, out title);

            Gst.Sample? image = parse_image_from_tag_list (tags);
            ret |= image != null;
            _tag_parsed = ret;

            var hash = str_hash (album ?? "") | str_hash (artist ?? "") | str_hash (title ?? "")
                        | (image?.get_buffer ()?.get_size () ?? 0);
            if (_tag_hash != hash) {
                _tag_hash = hash;
                // notify only when changed
                tag_parsed (album, artist, title, image);
            }
        }
        public static Gst.Sample? parse_image_from_tag_list (Gst.TagList tags) {
            Gst.Sample? sample = null;
            if (tags.get_sample (Gst.Tags.IMAGE, out sample)) {
                return sample;
            }
            if (tags.get_sample (Gst.Tags.PREVIEW_IMAGE, out sample)) {
                return sample;
            }
    
            for (var i = 0; i < tags.n_tags (); i++) {
                var tag = tags.nth_tag_name (i);
                var value = tags.get_value_index (tag, 0);
                sample = null;
                if (value?.type () == typeof (Gst.Sample)
                        && tags.get_sample (tag, out sample)) {
                    var caps = sample?.get_caps ();
                    if (caps != null) {
                        return sample;
                    }
                    //  print (@"unknown image tag: $(tag)\n");
                }
            }
            return null;
        }

        private bool timeout_callback () {
            int64 position = (int64) Gst.CLOCK_TIME_NONE;
            if ((_pipeline?.query_position (Gst.Format.TIME, out position) ?? false)
                    && _position != position) {
                _position = position;
                _last_seeked_pos = position;
                position_updated (position);
            }
            return true;
        }

        private void on_duration_changed () {
            int64 duration = (int64) Gst.CLOCK_TIME_NONE;
            if ((_pipeline?.query_duration (Gst.Format.TIME, out duration) ?? false)
                    && _duration != duration) {
                _duration = duration;
                duration_changed (duration);
            }
        }

        public delegate void LevelCalculateFunc (void* data, uint num, uint channels, out double NCS, out double NPS);
    }
}
