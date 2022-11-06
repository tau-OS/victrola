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
    public class SongEntry : He.MiniContentBlock {
        public bool playing {
            set {
                if (value) {
                    icon = "media-playback-start-symbolic";
                    add_css_class ("playing");
                } else {
                    icon = "";
                    remove_css_class ("playing");
                }
            }
        }

        public void update (Song song, SortMode sort) {
            switch (sort) {
                case SortMode.ALBUM:
                    title = song.album;
                    subtitle = (0 < song.track < int.MAX) ? @"$(song.track). $(song.title)" : song.title;
                    break;

                case SortMode.ARTIST:
                    title = song.artist;
                    subtitle = song.title;
                    break;

                case SortMode.RECENT:
                    var date = new DateTime.from_unix_local (song.modified_time);
                    title = song.title;
                    subtitle = date.format ("%x %H:%M");
                    break;

                case SortMode.ALL:
                default:
                    title = song.title;
                    subtitle = song.artist;
                    break;
            }
        }
    }
}
