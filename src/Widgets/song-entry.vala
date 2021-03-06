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

        public void update (Song song) {
            title = song.title;
            subtitle = song.artist;
        }
    }
}
