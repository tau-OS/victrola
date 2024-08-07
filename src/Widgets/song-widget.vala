namespace Victrola.PageName {
    public const string ALBUM = "album";
    public const string ARTIST = "artist";
    public const string PLAYING = "playing";
    public const string PLAYLIST = "playlist";
}

public class Victrola.SongWidget : Gtk.Box {
    protected Gtk.Image _cover = new Gtk.Image ();
    protected Gtk.Label _title = new Gtk.Label ("");
    protected Gtk.Label _subtitle = new Gtk.Label ("");
    protected Gdk.Paintable _paintable;
    protected Gtk.Image _playing = new Gtk.Image ();

    public ulong first_draw_handler = 0;
    public Song? music = null;

    public SongWidget () {
        _playing.valign = Gtk.Align.CENTER;
        _playing.halign = Gtk.Align.END;
        _playing.icon_name = "media-playback-start-symbolic";
        _playing.margin_end = 4;
        _playing.pixel_size = 10;
        _playing.visible = false;
        _playing.add_css_class ("dim-label");
    }

    public Gdk.Paintable cover {
        get {
            return _paintable;
        }
    }

    public Gdk.Paintable? paintable {
        set {
            _paintable = value;
        }
    }

    public bool playing {
        get {
            return _playing.visible;
        }
        set {
            _playing.visible = value;
        }
    }

    public string title {
        set {
            _title.label = value;
        }
    }

    public string subtitle {
        set {
            _subtitle.label = value;
            _subtitle.visible = value.length > 0;
        }
    }

    public void disconnect_first_draw () {
        if (first_draw_handler != 0) {
            _paintable.disconnect (first_draw_handler);
            first_draw_handler = 0;
        }
    }

    public void update (Song song) {
        _title.label = song.artist;
        _subtitle.label = song.title;
    }
}
