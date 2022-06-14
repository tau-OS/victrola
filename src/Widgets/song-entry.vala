namespace Victrola {
    public class SongEntry : He.MiniContentBlock {
        public bool playing {
            set {
                if (value) {
                    icon = "media-playback-start-symbolic";
                } else {
                    icon = "";
                }
            }
        }

        public void update (Song song) {
            title = song.title;
            subtitle = song.artist;
        }
    }
}