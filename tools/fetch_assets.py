"""Download chosen Pixabay assets (Pixabay Content License) in CI.

For each page: save the HTML, record whether it is marked AI-generated,
find the media file URL and download it. Results go to fetched/ with a report.
"""
import json
import os
import re
import urllib.request

PAGES = {
    'music': [
        'https://pixabay.com/music/religious-theme-jai-hanuman-hindu-festive-music-619429/',
        'https://pixabay.com/music/instrumental-sita-ram-tarang-hindu-festive-music-612281/',
        'https://pixabay.com/music/world-ram-bhajan-hindu-festive-music-446987/',
        'https://pixabay.com/music/india-krishna-flute-hindu-music-450217/',
    ],
    'images': [
        'https://pixabay.com/illustrations/hanuman-rama-ramayana-god-hinduism-8743531/',
        'https://pixabay.com/illustrations/hanuman-lord-hanuman-hanuman-ji-god-8727645/',
        'https://pixabay.com/illustrations/hanuman-lord-hanuman-hanuman-ji-god-8727646/',
        'https://pixabay.com/illustrations/hanuman-ramayana-monkey-rama-8783408/',
        'https://pixabay.com/illustrations/hanuman-ramayana-hindu-hinduism-8761489/',
        'https://pixabay.com/illustrations/hanuman-rama-ramayana-god-hinduism-8743534/',
        'https://pixabay.com/illustrations/hanuman-ramayana-monkey-rama-8783443/',
        'https://pixabay.com/illustrations/hanuman-god-hinduism-hindu-9282371/',
    ],
}
UA = ('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36')
OUT = 'fetched'
os.makedirs(f'{OUT}/html', exist_ok=True)


def get(url, binary=False):
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Referer': 'https://pixabay.com/',
                                               'Accept-Language': 'en-US,en;q=0.9'})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read()
        return data if binary else data.decode('utf-8', 'ignore')


report = []
for kind, urls in PAGES.items():
    os.makedirs(f'{OUT}/{kind}', exist_ok=True)
    for url in urls:
        slug = url.rstrip('/').split('/')[-1]
        entry = {'kind': kind, 'page': url, 'slug': slug}
        try:
            html = get(url)
            open(f'{OUT}/html/{slug}.html', 'w').write(html)
            entry['ai_generated'] = bool(re.search(r'ai[ _-]?generated', html, re.I))
            if kind == 'music':
                cands = re.findall(r'https://cdn\.pixabay\.com/(?:download/)?audio/[^"\'\s<>]+?\.mp3', html)
            else:
                cands = re.findall(r'https://cdn\.pixabay\.com/photo/[^"\'\s<>]+?_(?:1280|960_720|640)\.(?:jpg|png)', html)
                cands += re.findall(r'https://pixabay\.com/get/[^"\'\s<>]+?\.(?:jpg|png)', html)
            cands = list(dict.fromkeys(c.replace('\\u002F', '/').replace('&amp;', '&') for c in cands))
            entry['candidates'] = cands[:6]
            if cands:
                pick = cands[0]
                if kind == 'images':
                    big = [c for c in cands if '_1280.' in c]
                    pick = big[0] if big else cands[0]
                data = get(pick, binary=True)
                ext = pick.rsplit('.', 1)[-1]
                path = f'{OUT}/{kind}/{slug}.{ext}'
                open(path, 'wb').write(data)
                entry['file'] = path
                entry['bytes'] = len(data)
        except Exception as e:  # keep going; the report shows what failed
            entry['error'] = repr(e)
        report.append(entry)
        print(json.dumps(entry))

json.dump(report, open(f'{OUT}/report.json', 'w'), indent=1)
