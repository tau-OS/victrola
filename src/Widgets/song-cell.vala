public class Victrola.SongCell : SongWidget {
    public SongCell () {
        orientation = Gtk.Orientation.VERTICAL;
        margin_top = 10;
        margin_bottom = 10;

        _cover.margin_start = 8;
        _cover.margin_end = 8;
        _cover.margin_bottom = 8;
        _cover.pixel_size = 160;
        _cover.paintable = _paintable;

        var overlay = new Gtk.Overlay ();
        overlay.child = _cover;
        overlay.add_overlay (_playing);
        append (overlay);

        _title.halign = Gtk.Align.CENTER;
        _title.ellipsize = Pango.EllipsizeMode.MIDDLE;
        _title.margin_start = 2;
        _title.margin_end = 2;
        _title.add_css_class ("cb-title");
        append (_title);

        _subtitle.halign = Gtk.Align.CENTER;
        _subtitle.ellipsize = Pango.EllipsizeMode.MIDDLE;
        _subtitle.margin_start = 2;
        _subtitle.margin_end = 2;
        _subtitle.visible = false;
        _subtitle.add_css_class ("dim-label");
        var font_size = _subtitle.get_pango_context ().get_font_description ().get_size () / Pango.SCALE;
        if (font_size >= 13)
            _subtitle.add_css_class ("cb-subtitle");
        append (_subtitle);

        width_request = 200;
    }
}
