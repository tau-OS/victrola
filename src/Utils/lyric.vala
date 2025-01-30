/*
* Copyright 2024-2025 Fyra Labs
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*/

using Gee;

namespace Victrola {
    public class LyricsFetcher : Object {
        private const string API_BASE_URL = "https://lrclib.net/api/";
        private Soup.Session session;

        public LyricsFetcher() {
            session = new Soup.Session();
            session.timeout = 5;
        }

        public async string? fetch_lyrics(string title, string artist) throws Error {
            var normalized_title = title;
            var normalized_artist = artist;

            try {
                var lyrics = yield get_lyrics(normalized_title, normalized_artist);
                return lyrics;
            } catch (Error e) {
                warning ("Failed to fetch lyrics: %s", e.message);
                return "";
            }
        }

        private async string? get_lyrics(string title, string artist) throws Error {
            var url = API_BASE_URL + "get";

            var params = new HashTable<string, string>(str_hash, str_equal);
            params["track_name"] = title;
            params["artist_name"] = artist;

            return yield make_request(url, params, title, artist);
        }

        private async string? make_request(string base_url, HashTable<string, string> params, string title, string artist) throws Error {
            var uri = new Soup.URI(base_url);

            var query_parts = new Gee.ArrayList<string>();
            foreach (var key in params.get_keys()) {
                string value = params[key];
                value = value.replace(" ", "+");
                query_parts.add(@"$key=$value");
            }
            string query = string.joinv("&", query_parts.to_array());
            uri.set_query(query);

            string url = uri.to_string(false);
            warning("Requesting URL: %s", url);

            var session = new Soup.Session ();
            var message = new Soup.Message ("GET", url);
            session.send_message (message);
            try {
                var parser = new Json.Parser();
                parser.load_from_data ((string) message.response_body.flatten ().data, -1);

                var root = parser.get_root();
                var result = root.get_object();
                
                // Check if the 'plainLyrics' field exists
                if (!result.has_member("plainLyrics")) {
                    warning("Response missing 'plainLyrics' field");
                    return null;
                }

                string lyrics_text = result.get_string_member("plainLyrics");
                warning("Lyrics extracted successfully!");
                return lyrics_text;
            } catch (Error e) {
                warning("JSON error: %s", e.message);
                return "";
            }
        }
    }
}