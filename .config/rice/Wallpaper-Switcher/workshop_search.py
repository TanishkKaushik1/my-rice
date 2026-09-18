#!/usr/bin/env python3
"""
Steam Workshop search helper for Wallpaper Engine (appid 431960).
Called by WorkshopBrowser.qml via Process.
Usage: workshop_search.py <query> [page] [resolution] [sort_by] [allow_nsfw]
Prints JSON array of results to stdout.
"""
import os
import sys
import json
import urllib.request
import urllib.parse

APP_ID    = 431960
PAGE_SIZE = 20


def _load_dotenv(script_dir):
    env_path = os.path.join(script_dir, ".env")
    try:
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, val = line.partition("=")
                os.environ.setdefault(key.strip(), val.strip())
    except FileNotFoundError:
        pass


_load_dotenv(os.path.dirname(os.path.abspath(__file__)))
API_KEY = os.environ.get("STEAM_API_KEY", "")

# Steam API Query Types mapping
SORT_MAP = {
    "recent": 1,       # RankedByPublicationDate
    "trend": 3,        # RankedByTrend
    "popular": 9,      # RankedByTotalUniqueSubscriptions
    "relevance": 12    # RankedByTextSearch
}

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read().decode())

def search(query, page=1, res_filter="", sort_by="relevance", allow_nsfw=False):
    if not API_KEY:
        raise RuntimeError("STEAM_API_KEY not set — copy .env.example to .env and add your key")

    # Default to relevance if search text is provided
    query_type = SORT_MAP.get(sort_by, 12)

    params_dict = {
        "key":             API_KEY,
        "appid":           APP_ID,
        "search_text":     query,
        "query_type":      query_type,
        "numperpage":      PAGE_SIZE,
        "page":            page,
        "return_previews": True,
        "return_metadata": True,
        "return_tags":     False,
    }
    
    url = f"https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/?{urllib.parse.urlencode(params_dict)}"
    
    # If a resolution filter is passed, we append it as a required tag array
    if res_filter:
        url += f"&requiredtags[0]={urllib.parse.quote(res_filter)}"

    # Automatically exclude Adult/NSFW content unless allow_nsfw is True
    if not allow_nsfw:
        nsfw_tags = ["Mature", "Questionable", "NSFW"]
        for i, tag in enumerate(nsfw_tags):
            url += f"&excludedtags[{i}]={urllib.parse.quote(tag)}"

    data = fetch(url)

    files = data.get("response", {}).get("publishedfiledetails", [])
    if not files:
        files = data.get("response", {}).get("files", [])

    results = []
    for f in files:
        fid = str(f.get("publishedfileid", ""))
        if not fid:
            continue
        results.append({
            "id":            fid,
            "title":         f.get("title", f"Wallpaper {fid}"),
            "preview_url":   f.get("preview_url", ""),
            "author":        f.get("creator", ""),
            "subscriptions": f.get("subscriptions", 0),
            "type":          f.get("file_type", ""),
            "url":           f"https://steamcommunity.com/sharedfiles/filedetails/?id={fid}",
        })
    return results

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("[]")
        sys.exit(0)

    query = sys.argv[1]
    page  = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    res_filter = sys.argv[3] if len(sys.argv) > 3 else ""
    sort_by = sys.argv[4] if len(sys.argv) > 4 else "relevance"
    allow_nsfw = sys.argv[5].lower() == "true" if len(sys.argv) > 5 else False

    try:
        print(json.dumps(search(query, page, res_filter, sort_by, allow_nsfw)))
    except Exception as e:
        sys.stderr.write(f"error: {e}\n")
        print("[]")