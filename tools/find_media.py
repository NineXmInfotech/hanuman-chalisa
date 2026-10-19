"""Find openly licensed Hanuman pictures (Wellcome Collection) and Indian
instrumental music (Wikimedia Commons) and download candidates for review.

Writes found/ with images, audio and a report.json including licenses.
"""
import json
import os
import re
import urllib.parse
import urllib.request

UA = 'NineXmInfotech-HanumanChalisa/1.0 (contact: ninexminfotech.com)'
OUT = 'found'
os.makedirs(f'{OUT}/images', exist_ok=True)
os.makedirs(f'{OUT}/audio', exist_ok=True)


def get(url, binary=False):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=90) as r:
        data = r.read()
    return data if binary else json.loads(data.decode('utf-8'))


report = {'images': [], 'audio': []}

# ---------------- Wellcome Collection pictures ----------------
seen = set()
for query in ['hanuman', 'hanuman chromolithograph', 'hanuman ravi varma', 'maruti']:
    url = ('https://api.wellcomecollection.org/catalogue/v2/works?'
           + urllib.parse.urlencode({'query': query, 'include': 'items,production',
                                     'pageSize': 60, 'availabilities': 'online'}))
    try:
        data = get(url)
    except Exception as e:
        report['images'].append({'query': query, 'error': repr(e)})
        continue
    for w in data.get('results', []):
        if w['id'] in seen:
            continue
        seen.add(w['id'])
        title = w.get('title', '')
        if not re.search(r'hanuman|maruti|anjaneya', title, re.I):
            continue
        lic, iiif = None, None
        for item in w.get('items', []):
            for loc in item.get('locations', []):
                if loc.get('license'):
                    lic = loc['license'].get('id')
                u = loc.get('url', '')
                if 'iiif.wellcomecollection.org/image/' in u and u.endswith('info.json'):
                    iiif = u[:-len('/info.json')]
        thumb = (w.get('thumbnail') or {}).get('url', '')
        if not iiif and 'iiif.wellcomecollection.org' in thumb:
            iiif = thumb.split('/full/')[0].replace('/thumbs/', '/image/')
        entry = {'id': w['id'], 'title': title, 'license': lic,
                 'page': f"https://wellcomecollection.org/works/{w['id']}", 'iiif': iiif}
        if iiif and lic in ('pdm', 'cc-0', 'cc-by'):
            try:
                img = get(f'{iiif}/full/1000,/0/default.jpg', binary=True)
                path = f"{OUT}/images/{w['id']}.jpg"
                open(path, 'wb').write(img)
                entry['file'] = path
            except Exception as e:
                entry['error'] = repr(e)
        report['images'].append(entry)
        print('IMG', lic, title[:90])

# ---------------- Wikimedia Commons music ----------------
OK_LICENSES = re.compile(r'^(cc0|public domain|pd|cc by( |-)?(4\.0|3\.0|2\.5|2\.0)?$|cc by-sa)', re.I)
for query in ['bansuri raga', 'shehnai', 'sitar raga', 'santoor', 'flute raga bhairavi', 'harmonium bhajan', 'indian classical flute']:
    api = ('https://commons.wikimedia.org/w/api.php?'
           + urllib.parse.urlencode({
               'action': 'query', 'format': 'json', 'generator': 'search',
               'gsrsearch': f'{query} filemime:audio', 'gsrnamespace': 6, 'gsrlimit': 15,
               'prop': 'imageinfo', 'iiprop': 'url|size|mime|extmetadata',
               'iiextmetadatafilter': 'LicenseShortName|Artist|ImageDescription|ObjectName'}))
    try:
        data = get(api)
    except Exception as e:
        report['audio'].append({'query': query, 'error': repr(e)})
        continue
    for page in (data.get('query', {}).get('pages', {}) or {}).values():
        info = (page.get('imageinfo') or [{}])[0]
        meta = info.get('extmetadata', {})
        lic = meta.get('LicenseShortName', {}).get('value', '')
        entry = {'title': page.get('title'), 'license': lic,
                 'artist': re.sub('<[^>]+>', '', meta.get('Artist', {}).get('value', ''))[:120],
                 'desc': re.sub('<[^>]+>', '', meta.get('ImageDescription', {}).get('value', ''))[:200],
                 'url': info.get('url'), 'size': info.get('size'), 'mime': info.get('mime'),
                 'page': info.get('descriptionurl'), 'query': query}
        if any(a.get('url') == entry['url'] for a in report['audio']):
            continue
        if OK_LICENSES.search(lic.strip()) and info.get('size', 0) < 25_000_000:
            try:
                data_bin = get(info['url'], binary=True)
                name = re.sub(r'[^A-Za-z0-9._-]+', '_', page['title'].replace('File:', ''))[:80]
                path = f'{OUT}/audio/{name}'
                open(path, 'wb').write(data_bin)
                entry['file'] = path
            except Exception as e:
                entry['error'] = repr(e)
        report['audio'].append(entry)
        print('AUD', lic, entry['title'])

json.dump(report, open(f'{OUT}/report.json', 'w'), indent=1, ensure_ascii=False)
