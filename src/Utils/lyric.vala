using Gee;

namespace Victrola {
    public class Lyric : Object {

        /* Fields */
        public string title { get; set; }
        public string artist { get; set; }
        public string lyric { get; set; }
        public string lyric_sync { get; set; }
        private string[] urls;
        public string current_url { get; set; }
        public string current_sync_url { get; set; }

        public void add_url(string url) {
            urls += url;
        }

        public int get_len_urls() {
            return urls.length;
        }

        public string get_url_from_index(int index) {
            if (index > get_len_urls()) {
                return "";
            }
            return urls[index];
        }
    }
}
