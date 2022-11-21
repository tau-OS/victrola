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
    public const string UNKNOWN_ARTIST = _("Unknown Artist");
    public const string UNKNOWN_ALBUM = _("Unknown Album");
    public const int UNKNOWN_TRACK = int.MAX;
    public const string DEFAULT_MIMETYPE = "audio/mpeg";

    public enum TagType {
        NONE,
        GST,
        TAGLIB,
        SPARQL
    }

    public enum SortMode {
        ALBUM,
        ARTIST,
        TITLE,
        RECENT,
        SHUFFLE,
        ALL,
    }

    public size_t read_size (DataInputStream dis) throws IOError {
        var value = dis.read_byte ();
        switch (value) {
        case 254:
            return dis.read_uint16 ();
        case 255:
            return dis.read_uint32 ();
        default:
            return value;
        }
    }

    public void write_size (DataOutputStream dos, size_t value) throws IOError {
        if (value < 254) {
            dos.put_byte ((uint8) value);
        } else if (value <= 0xffff) {
            dos.put_byte (254);
            dos.put_uint16 ((uint16) value);
        } else {
            dos.put_byte (255);
            dos.put_uint32 ((uint32) value);
        }
    }

    public string read_string (DataInputStream dis) throws IOError {
        var size = read_size (dis);
        if ((int) size < 0 || size > 0xfffffff) { // 28 bits
            throw new IOError.INVALID_ARGUMENT (@"Size=$size");
        } else if (size > 0) {
            var buffer = new uint8[size + 1];
            if (dis.read_all (buffer[0:size], out size)) {
                buffer[size] = '\0';
                return (string) buffer;
            }
        }
        return "";
    }

    public void write_string (DataOutputStream dos, string value) throws IOError {
        size_t size = value.length;
        write_size (dos, size);
        if (size > 0) {
            unowned uint8[] data = (uint8[])value;
            dos.write_all (data[0:size], out size);
        }
    }

    public class Song : Object {
        public string album = "";
        public string artist = "";
        public string title = "";
        public string uri = "";
        public int64 modified_time = 0;
        public int track = UNKNOWN_TRACK;
        public TagType ttype = TagType.NONE;

        private string _album_key = "";
        private string _artist_key = "";
        private string _title_key = "";
        private string? _cover_uri = null;
        private int _order = 0;

        public string cover_uri {
            get {
                return _cover_uri ?? uri;
            }
            set {
                _cover_uri = value;
            }
        }

        public Song.deserialize (DataInputStream dis) throws IOError {
            album = read_string (dis);
            artist = read_string (dis);
            title = read_string (dis);
            track = dis.read_int32 ();
            modified_time = dis.read_int64 ();
            uri = read_string (dis);
            _album_key = album.collate_key_for_filename ();
            _artist_key = artist.collate_key_for_filename ();
            _title_key = title.collate_key_for_filename ();
        }

        public void serialize (DataOutputStream dos) throws IOError {
            write_string (dos, album);
            write_string (dos, artist);
            write_string (dos, title);
            dos.put_int32 (track);
            dos.put_int64 (modified_time);
            write_string (dos, uri);
        }

        public static GenericArray<string> split_string (string text, string delimiter) {
            var ar = text.split ("-");
            var sa = new GenericArray<string> (ar.length);
            foreach (var str in ar) {
                var s = str.strip ();
                if (s.length > 0)
                    sa.add (s);
            }
            return sa;
        }

        public bool from_gst_tags (Gst.TagList tags) {
            var changed = false;
            unowned string? al = null, ar = null, ti = null;
            if (tags.peek_string_index (Gst.Tags.ALBUM, 0, out al)
                    && al != null && al?.length > 0 && album != (!)al) {
                album = (!)al;
                _album_key = album.collate_key_for_filename ();
                changed = true;
            }
            if (tags.peek_string_index (Gst.Tags.ARTIST, 0, out ar)
                    && ar != null && ar?.length > 0 && artist != (!)ar) {
                artist = (!)ar;
                _artist_key = artist.collate_key_for_filename ();
                changed = true;
            }
            if (tags.peek_string_index (Gst.Tags.TITLE, 0, out ti)
                    && ti != null && ti?.length > 0 && title != (!)ti) {
                title = (!)ti;
                _title_key = title.collate_key_for_filename ();
                changed = true;
            }
            uint tr = 0;
            if (tags.get_uint (Gst.Tags.TRACK_NUMBER, out tr)
                    && (int) tr > 0 && track != tr) {
                track = (int) tr;
                changed = true;
            }
            return changed;
        }

        public void init_from_gst_tags (Gst.TagList? tags) {
            string? ar = null, ti = null;
            if (tags != null) {
                tags?.get_string ("artist", out ar);
                tags?.get_string ("title", out ti);
            } 
            this.artist = (ar != null && ar?.length > 0) ? (!)ar : UNKNOWN_ARTIST;
            if (ti != null && ti?.length > 0)
                this.title = (!)ti;
            this.ttype = TagType.GST;
            update_keys ();
        }

        public void parse_tags () {
            var file = File.new_for_uri (uri);
            var name = title;
            this.title = "";

            if (file.is_native ()) {
                var tags = parse_gst_tags (file);
                if (tags != null)
                    from_gst_tags ((!)tags);
            }

            if (title.length == 0 || artist.length == 0) {
                //  guess tags from the file name
                var end = name.last_index_of_char ('.');
                if (end > 0) {
                    name = name.substring (0, end);
                }

                int track_index = 0;
                var pos = name.index_of_char ('.');
                if (pos > 0) {
                    // assume prefix number as track index
                    int.try_parse (name.substring (0, pos), out track_index, null, 10);
                    name = name.substring (pos + 1);
                }

                //  split the file name by '-'
                var sa = split_string (name, "-");
                var len = sa.length;
                if (title.length == 0) {
                    title = len >= 1 ? sa[len - 1] : name;
                    _title_key = title.collate_key_for_filename ();
                }
                if (artist.length == 0) {
                    artist = len >= 2 ? sa[len - 2] : UNKNOWN_ARTIST;
                    _artist_key = artist.collate_key_for_filename ();
                }
                if (track_index == UNKNOWN_TRACK) {
                    if (track_index == 0 && len >= 3)
                        int.try_parse (sa[0], out track_index, null, 10);
                    if (track_index > 0)
                        this.track = track_index;
                }
            }
            if (album.length == 0) {
                //  assume folder name as the album
                album = file.get_parent ()?.get_basename () ?? UNKNOWN_ALBUM;
                _album_key = album.collate_key_for_filename ();
            }
        }

#if HAS_TAGLIB_C
        public void init_from_taglib (TagLib.File file) {
            string? ar = null, ti = null;
            if (file.is_valid ()) {
                unowned var tags = file.tag;
                ar = tags.artist;
                ti = tags.title;
            }
            this.artist = (ar != null && ar?.length > 0) ? (!)ar : UNKNOWN_ARTIST;
            if (ti != null && ti?.length > 0)
                this.title = (!)ti;
            this.ttype = TagType.TAGLIB;
            update_keys ();
        }
#endif

        public bool update (string? al, string? ar, string? ti) {
            bool changed = false;
            if (ar != null && ar != artist) {
                changed = true;
                artist = (!)ar;
                _artist_key = artist.collate_key ();
            }
            if (ti != null && ti != title) {
                changed = true;
                title = (!)ti;
                _title_key = title.collate_key ();
            }
            return changed;
        }

        public void update_keys () {
            _artist_key = artist.collate_key ();
            _title_key = title.collate_key ();
        }

        public static int compare_by_album (Object obj1, Object obj2) {
            var s1 = (Song) obj1;
            var s2 = (Song) obj2;
            int ret = strcmp (s1._album_key, s2._album_key);
            if (ret != 0) return ret;
            ret = s1.track - s2.track;
            if (ret != 0) return ret;
            ret = strcmp (s1._title_key, s2._title_key);
            if (ret != 0) return ret;
            return strcmp (s1.uri, s2.uri);
        }

        public static int compare_by_artist (Object obj1, Object obj2) {
            var s1 = (Song) obj1;
            var s2 = (Song) obj2;
            int ret = strcmp (s1._artist_key, s2._artist_key);
            if (ret != 0) return ret;
            ret = strcmp (s1._title_key, s2._title_key);
            if (ret != 0) return ret;
            return strcmp (s1.uri, s2.uri);
        }


        public static int compare_by_title (Object obj1, Object obj2) {
            var s1 = (Song) obj1;
            var s2 = (Song) obj2;
            int ret = strcmp (s1._title_key, s2._title_key);
            if (ret == 0)
                ret = strcmp (s1._artist_key, s2._artist_key);
            if (ret == 0)
                ret = strcmp (s1.uri, s2.uri);
            return ret;
        }

        public static int compare_by_order (Object obj1, Object obj2) {
            var s1 = (Song) obj1;
            var s2 = (Song) obj2;
            return s1._order - s2._order;
        }

        public static int compare_by_date_ascending (Object obj1, Object obj2) {
            var s1 = (Song) obj1;
            var s2 = (Song) obj2;
            var diff = s2.modified_time - s1.modified_time;
            return (int) diff.clamp (-1, 1);
        }

        public static void shuffle_order (GenericArray<Object> arr) {
            for (var i = arr.length - 1; i > 0; i--) {
                var r = Random.int_range (0, i);
                var s = arr[i];
                arr[i] = arr[r];
                arr[r] = s;
                ((Song)arr[i])._order = i;
            }
        }
    }

    public class TagCache {
        private static uint32 MAGIC = 0x54414743; //  'TAGC'

        private File _file;
        private bool _loaded = false;
        private bool _modified = false;
        private HashTable<weak string, Song> _cache = new HashTable<weak string, Song> (str_hash, str_equal);

        public TagCache (string name = "tag-cache") {
            var dir = Environment.get_user_cache_dir ();
            _file = File.new_build_filename (dir, Config.APP_ID, name);
        }

        public bool loaded {
            get {
                return _loaded;
            }
        }

        public bool modified {
            get {
                return _modified;
            }
        }

        public Song? @get (string uri) {
            weak string key;
            weak Song song;
            lock (_cache) {
                if (_cache.lookup_extended (uri, out key, out song)) {
                    return song;
                }
            }
            return null;
        }

        public void add (Song song) {
            lock (_cache) {
                _cache[song.uri] = song;
                _modified = true;
            }
        }

        public void load () {
            try {
                var fis = _file.read ();
                var bis = new BufferedInputStream (fis);
                bis.buffer_size = 16384;
                var dis = new DataInputStream (bis);
                var magic = dis.read_uint32 ();
                if (magic != MAGIC)
                    throw new IOError.INVALID_DATA (@"Magic=$magic");

                var count = read_size (dis);
                lock (_cache) {
                    for (var i = 0; i < count; i++) {
                        var song = new Song.deserialize (dis);
                        _cache[song.uri] = song;
                    }
                }
            } catch (Error e) {
                if (e.code != IOError.NOT_FOUND)
                    print ("Load tags error: %s\n", e.message);
            }
            _loaded = true;
        }

        public void save () {
            try {
                var parent = _file.get_parent ();
                var exists = parent?.query_exists () ?? false;
                if (exists)
                    parent?.make_directory_with_parents ();
                var fos = _file.replace (null, false, FileCreateFlags.NONE);
                var bos = new BufferedOutputStream (fos);
                bos.buffer_size = 16384;
                var dos = new DataOutputStream (bos);
                dos.put_uint32 (MAGIC);
                lock (_cache) {
                    write_size (dos, _cache.length);
                    _cache.for_each ((key, song) => {
                        try {
                            song.serialize (dos);
                        } catch (Error e) {
                        }
                    });
                }
                _modified = false;
            } catch (Error e) {
                print ("Save tags error: %s\n", e.message);
            }
        }
    }

    public class SongStore : Object {
        private CompareDataFunc<Object> _compare = Song.compare_by_title;
        private ListStore _store = new ListStore (typeof (Song));
        private SortMode _sort_mode = SortMode.TITLE;
        private TagCache _tag_cache = new TagCache ();

        public signal void parse_progress (int percent);

        public ListStore store {
            get {
                return _store;
            }
        }
        public SortMode sort_mode {
            get {
                return _sort_mode;
            }
            set {
                _sort_mode = value;
                switch (value) {
                    case SortMode.ALBUM:
                        _compare = Song.compare_by_album;
                        break;
                    case SortMode.ARTIST:
                        _compare = Song.compare_by_artist;
                        break;
                    case SortMode.RECENT:
                        _compare = Song.compare_by_date_ascending;
                        break;
                    case SortMode.SHUFFLE:
                        _compare = Song.compare_by_order;
                        break;
                    default:
                        _compare = Song.compare_by_title;
                        break;
                }
                if (_sort_mode == SortMode.SHUFFLE) {
                    var count = _store.get_n_items ();
                    var arr = new GenericArray<Object> (count);
                    for (var i = 0; i < count; i++) {
                        arr.add ((!)_store.get_item (i));
                    }
                    Song.shuffle_order (arr);
                }
                _store.sort (_compare);
            }
        }

        public uint size {
            get {
                return _store.get_n_items ();
            }
        }

        public void clear () {
            _store.remove_all ();
        }

        public Song? get_song (uint position) {
            return _store.get_item (position) as Song;
        }

        public async void load_tag_cache_async () {
            yield run_async<void> (_tag_cache.load);
        }
        public async void save_tag_cache_async () {
            if (_tag_cache.modified) {
                yield run_async<void> (_tag_cache.save);
            }
        }

#if HAS_TRACKER_SPARQL
        public const string SQL_QUERY_SONGS = """
            SELECT 
                nmm:artistName (nmm:artist (?song))
                nie:title (?song)
                nie:isStoredAs (?song)
            WHERE { ?song a nmm:MusicPiece }
        """;

        public async void add_sparql_async () {
            var arr = new GenericArray<Object> (4096);
            yield run_async<void> (() => {
                var begin_time = get_monotonic_time ();
                Tracker.Sparql.Connection connection;
                try {
                    connection = Tracker.Sparql.Connection.bus_new ("org.freedesktop.Tracker3.Miner.Files", null);
                    var cursor = connection.query (SQL_QUERY_SONGS);
                    while (cursor.next ()) {
                        var song = new Song ();
                        song.artist = cursor.get_string (1) ?? UNKNOWN_ARTIST;
                        song.title = cursor.get_string (2) ?? "";
                        song.uri = cursor.get_string (3) ?? "";
                        if (song.title.length == 0)
                            song.title = parse_name_from_uri (song.uri);
                        song.ttype = TagType.SPARQL;
                        song.update_keys ();
                        arr.add (song);
                    }
                } catch (Error e) {
                    warning ("Query error: %s\n", e.message);
                }
                arr.sort ((CompareFunc<Object>) _compare);
                print ("Found %u songs in %g seconds\n", arr.length,
                    (get_monotonic_time () - begin_time) / 1e6);
            });
            _store.splice (_store.get_n_items (), 0, arr.data);
        }
#endif

        private delegate G ThreadFunc<G> (uint index);
        private static void run_in_threads<G> (owned ThreadFunc<G> func, uint num_tasks) {
            var threads = new Thread<G>[num_tasks];
            for (var i = 0; i < num_tasks; i++) {
                var index = i;
                threads[i] = new Thread<G> (null, () => {
                    return func (index);
                });
            }
            foreach (var thread in threads) {
                thread.join ();
            }
        }

        public async void add_files_async (File[] files) {
            var songs = new GenericArray<Object> (4096);
            yield run_async<void> (() => {
                var begin_time = get_monotonic_time ();
                foreach (var file in files) {
                    add_file (file, songs);
                }

                var queue = new AsyncQueue<Song?> ();
                for (var i = 0; i < songs.length; i++) {
                    var song = (Song) songs[i];
                    queue.push (song);
                }
                var queue_count = queue.length ();
                if (queue_count > 0) {
                    int percent = -1;
                    uint progress = 0;
                    var num_tasks = uint.min (queue_count, get_num_processors ());
                    run_in_threads<void> ((index) => {
                        Song? s;
                        while ((s = queue.try_pop ()) != null) {
                            var song = (!)s;
                            song.parse_tags ();
                            var per = (int) AtomicUint.add (ref progress, 1) * 100 / queue_count;
                            if (percent != per) {
                                percent = per;
                                Idle.add (() => {
                                    parse_progress (per);
                                    return false;
                                });
                            }
                        }
                    }, num_tasks);
                }

                if (_sort_mode == SortMode.SHUFFLE) {
                    Song.shuffle_order (songs);
                }
                songs.sort ((CompareFunc<Object>) _compare);
                print ("Found %u songs in %g seconds\n", songs.length,
                        (get_monotonic_time () - begin_time) / 1e6);
            });
            _store.splice (_store.get_n_items (), 0, songs.data);
        }

        private static void add_file (File file, GenericArray<Object> arr) {
            try {
                var info = file.query_info ("standard::*", FileQueryInfoFlags.NONE);
                if (info.get_file_type () == FileType.DIRECTORY) {
                    var stack = new GenericArray<File> (1024);
                    stack.add (file);
                    while (stack.length > 0) {
                        add_directory (stack, arr);
                    }
                } else {
                    var parent = file.get_parent ();
                    var base_uri = parent != null ? get_uri_with_end_sep ((!)parent) : "";
                    var song = new_song_from_info (base_uri, info);
                    if (song != null)
                        arr.add ((!)song);
                }
            } catch (Error e) {
                warning ("Query %s: %s\n", file.get_parse_name (), e.message);
            }
        }

        private static void add_directory (GenericArray<File> stack, GenericArray<Object> arr) {
            var last = stack.length - 1;
            var dir = stack[last];
            stack.remove_index_fast (last);
            try {
                var base_uri = get_uri_with_end_sep (dir);
                FileInfo? info = null;
                var enumerator = dir.enumerate_children ("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
                while ((info = enumerator.next_file ()) != null) {
                    var pi = (!)info;
                    if (pi.get_is_hidden ()) {
                        continue;
                    } else if (pi.get_file_type () == FileType.DIRECTORY) {
                        var sub_dir = dir.resolve_relative_path (pi.get_name ());
                        stack.add (sub_dir);
                    } else {
                        var song = new_song_from_info (base_uri, pi);
                        if (song != null)
                            arr.add ((!)song);
                    }
                }
            } catch (Error e) {
                warning ("Enumerate %s: %s\n", dir.get_parse_name (), e.message);
            }
        }

        private static Song? new_song_from_info (string base_uri, FileInfo info) {
            var type = info.get_content_type ();
            if (type != null && ((!)type).has_prefix ("audio/") && !((!)type).has_suffix ("url")) {
                unowned var name = info.get_name ();
                var song = new Song ();
                // build same file uri as tracker sparql
                song.uri = base_uri + Uri.escape_string (name, null, false);
                var file = File.new_for_uri (song.uri);
                var path = file.get_path ();
                if (path != null) {  // parse local path only
#if HAS_TAGLIB_C
                    var tf = new TagLib.File ((!)path);
                    song.init_from_taglib (tf);
#else
                    var tags = parse_gst_tags (file);
                    song.init_from_gst_tags (tags);
#endif
                }
                if (song.title.length == 0) {
                    // title should not be empty always
                    song.title = parse_name_from_path (name);
                    song.update_keys ();
                }
                return song;
            }
            return null;
        }
    }

    public static int find_first_letter (string text) {
        var index = 0;
        var next = 0;
        var c = text.get_char (index);
        do {
            if ((c >= '0' && c <= '9')
                    || (c >= 'a' && c <= 'z')
                    || (c >= 'A' && c <= 'Z')
                    || c >= 0xff) {
                return index;
            }
            index = next;
        }  while (text.get_next_char (ref next, out c));
        return -1;
    }

    public static string get_uri_with_end_sep (File file) {
        var uri = file.get_uri ();
        if (uri[uri.length - 1] != '/')
            uri += "/";
        return uri;
    }

    public static string parse_abbreviation (string text) {
        var sb = new StringBuilder ();
        foreach (var s in text.split (" ")) {
            var index = find_first_letter (s);
            if (index >= 0) {
                sb.append (s.get_char (index).to_string ());
                if (sb.str.char_count () >= 2)
                    break;
            }
        }

        if (sb.str.char_count () >= 2) {
            return sb.str.up ();
        } else if (text.char_count () > 2) {
            var index = text.index_of_nth_char (2);
            return text.substring (0, index).up ();
        }
        return text.up ();
    }

    public static string parse_name_from_path (string path) {
        var begin = path.last_index_of_char ('/');
        var end = path.last_index_of_char ('.');
        if (end > begin)
            return path.slice (begin + 1, end);
        else if (begin > 0)
            return path.slice (begin + 1, path.length);
        return path;
    }

    public static string parse_name_from_uri (string uri) {
        try {
            var u = Uri.parse (uri, UriFlags.NONE);
            return parse_name_from_path (u.get_path ());
        } catch (Error e) {
            warning ("Parse %s: %s\n", uri, e.message);
        }
        return uri;
    }
}
