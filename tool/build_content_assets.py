#!/usr/bin/env python3
"""Builds Sakina's bundled religious content from published sources.

Nothing here is typed by hand. Every text comes from an established source,
so it can be regenerated and audited rather than trusted:

  Quran text      Tanzil "quran-uthmani", via api.alquran.cloud
  Search text     Tanzil "quran-simple-clean": the same verses in plain modern
                  spelling, which is what people type. Searched, never shown.
  Translation     Saheeh International ("en.sahih"), via api.alquran.cloud
  Verse metadata  juz / page / hizb quarter / sajda, from the same response
  Azkar           Hisn al-Muslim, from the official hisnmuslim.com API
  99 Names        api.aladhan.com
  Ahadeth         An-Nawawi's Forty (42), Arabic and English, from the
                  fawazahmed0/hadith-api editions (text from sunnah.com).
                  Ibn Rajab's 8 additions come from the original project's
                  files in tool/content/ibn_rajab/ (not yet sourced).

Usage:  python3 tool/build_content_assets.py
Downloads are cached in .content_cache/ (gitignored).
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, '.content_cache')
ASSETS = os.path.join(ROOT, 'assets')

BOM = '﻿'


def fetch(url, name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        # curl rather than urllib: python.org builds on macOS ship without CA
        # certificates, and curl uses the system trust store.
        subprocess.run(
            ['curl', '-sSfL', '--retry', '3', '--max-time', '180', '-o', path, url],
            check=True,
        )
    with open(path, 'rb') as f:
        return json.loads(f.read().decode('utf-8-sig'))


def write(rel, text):
    path = os.path.join(ASSETS, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def build_quran():
    ar = fetch('https://api.alquran.cloud/v1/quran/quran-uthmani', 'quran-uthmani.json')['data']['surahs']
    en = fetch('https://api.alquran.cloud/v1/quran/en.sahih', 'en.sahih.json')['data']['surahs']
    assert len(ar) == 114 and len(en) == 114

    basmala = ar[0]['ayahs'][0]['text'].replace(BOM, '').strip()
    # Suras 95 and 97 carry the basmala with a shadda on the ba (بِّسْمِ) in
    # this edition; both spellings are the basmala.
    basmala_forms = (basmala, basmala[0] + '\u0651' + basmala[1:])
    suras, verse_meta, juz_starts, hizb_starts = [], {}, [], []
    stripped = 0

    for s_ar, s_en in zip(ar, en):
        n = s_ar['number']
        assert len(s_ar['ayahs']) == len(s_en['ayahs']), n
        lines_ar, lines_en = [], []
        juz, page, hizb, sajda = [], [], [], []
        for a_ar, a_en in zip(s_ar['ayahs'], s_en['ayahs']):
            text = a_ar['text'].replace(BOM, '').strip()
            # The source prefixes verse 1 of every sura except Al-Fatiha (where
            # the basmala *is* verse 1) and At-Tawbah (which has none) with the
            # basmala. It is not part of the verse, so it is removed here and
            # the app draws it as a header instead.
            if a_ar['numberInSurah'] == 1 and n not in (1, 9):
                for form in basmala_forms:
                    if text.startswith(form):
                        text = text[len(form):].strip()
                        stripped += 1
                        break
            assert text, f'empty verse {n}:{a_ar["numberInSurah"]}'
            assert '\n' not in text
            lines_ar.append(text)
            lines_en.append(a_en['text'].replace(BOM, '').replace('\n', ' ').strip())
            juz.append(a_ar['juz'])
            page.append(a_ar['page'])
            hizb.append(a_ar['hizbQuarter'])
            if a_ar['sajda']:
                sajda.append(a_ar['numberInSurah'])
            if not juz_starts or juz_starts[-1]['juz'] != a_ar['juz']:
                juz_starts.append({'juz': a_ar['juz'], 'sura': n, 'ayah': a_ar['numberInSurah']})
            if not hizb_starts or hizb_starts[-1]['quarter'] != a_ar['hizbQuarter']:
                hizb_starts.append({'quarter': a_ar['hizbQuarter'], 'sura': n, 'ayah': a_ar['numberInSurah']})

        write(f'quran/ar/{n}.txt', '\n'.join(lines_ar) + '\n')
        write(f'quran/en/{n}.txt', '\n'.join(lines_en) + '\n')
        suras.append({
            'n': n,
            'ar': s_ar['name'].replace('سُورَةُ', '').strip(),
            'en': s_ar['englishName'],
            'meaning': s_ar['englishNameTranslation'],
            'type': s_ar['revelationType'],
            'ayahs': len(lines_ar),
            'page': page[0],
        })
        verse_meta[str(n)] = {'juz': juz, 'page': page, 'hizb': hizb, 'sajda': sajda}

    assert stripped == 112, f'expected to strip 112 basmalas, stripped {stripped}'
    assert len(juz_starts) == 30, len(juz_starts)
    assert len(hizb_starts) == 240, len(hizb_starts)
    total = sum(s['ayahs'] for s in suras)
    assert total == 6236, total

    write('quran/meta.json', json.dumps(
        {'source': 'Tanzil quran-uthmani + Saheeh International via api.alquran.cloud',
         'suras': suras, 'verses': verse_meta, 'juz': juz_starts, 'hizb': hizb_starts},
        ensure_ascii=False, separators=(',', ':')))
    print(f'quran: 114 suras, {total} verses, {stripped} basmala prefixes removed, '
          f'{sum(len(v["sajda"]) for v in verse_meta.values())} sajda verses')


def build_search_text():
    data = fetch('https://api.alquran.cloud/v1/quran/quran-simple-clean',
                 'quran-simple-clean.json')['data']['surahs']
    basmala = 'بسم الله الرحمن الرحيم'
    lines, stripped = [], 0
    for s in data:
        n = s['number']
        for a in s['ayahs']:
            text = a['text'].replace(BOM, '').strip()
            if a['numberInSurah'] == 1 and n not in (1, 9) and text.startswith(basmala):
                text = text[len(basmala):].strip()
                stripped += 1
            assert text and '\n' not in text
            # sura:ayah prefix keeps the file self-describing and lets the app
            # check it lines up with the Uthmani text.
            lines.append(f"{n}:{a['numberInSurah']}\t{text}")
    assert stripped == 112, stripped
    assert len(lines) == 6236, len(lines)
    write('quran/search.txt', '\n'.join(lines) + '\n')
    print(f'search text: {len(lines)} verses, {stripped} basmala prefixes removed')


def build_hisn():
    index = fetch('https://www.hisnmuslim.com/api/ar/husn_ar.json', 'hisn_index.json')
    chapters = []
    for entry in list(index.values())[0]:
        cid = entry['ID']
        url = entry['TEXT'].replace('http://', 'https://')
        body = fetch(url, f'hisn_{cid}.json')
        items = []
        for item in list(body.values())[0]:
            text = (item.get('ARABIC_TEXT') or '').replace(BOM, '').strip()
            if not text:
                continue
            items.append({'id': item['ID'], 'text': text, 'repeat': max(1, int(item.get('REPEAT') or 1))})
        if items:
            chapters.append({'id': cid, 'title': entry['TITLE'].strip(), 'items': items})
    write('azkar/hisn.json', json.dumps(
        {'source': 'Hisn al-Muslim, hisnmuslim.com', 'chapters': chapters},
        ensure_ascii=False, separators=(',', ':')))
    print(f'hisn al-muslim: {len(chapters)} chapters, {sum(len(c["items"]) for c in chapters)} adhkar')


def build_names():
    data = fetch('https://api.aladhan.com/v1/asmaAlHusna', 'asma.json')['data']
    names = [{'n': d['number'], 'ar': d['name'], 'tr': d['transliteration'], 'en': d['en']['meaning']} for d in data]
    assert len(names) == 99 and [x['n'] for x in names] == list(range(1, 100))
    write('names/asma.json', json.dumps({'source': 'api.aladhan.com', 'names': names},
                                        ensure_ascii=False, separators=(',', ':')))
    print('99 names: ok')


_UNITS = ['', 'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع']
_COMPOUND = ['', 'الحادي', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع']
_TENS = {1: 'عشر', 2: 'العشرون', 3: 'الثلاثون', 4: 'الأربعون', 5: 'الخمسون'}


def arabic_ordinal_title(n):
    """'الحديث الأول' … 'الحديث الخمسون'."""
    tens, units = divmod(n, 10)
    if tens == 0:
        word = _UNITS[units]
    elif n == 10:
        word = 'العاشر'
    elif tens == 1:
        word = f'{_COMPOUND[units]} عشر'
    elif units == 0:
        word = _TENS[tens]
    else:
        word = f'{_COMPOUND[units]} و{_TENS[tens]}'
    return f'الحديث {word}'


def _fold(s):
    """Letters only, for comparing a generated title with a legacy one."""
    s = re.sub('[ً-ْٰـ﻿]', '', s)
    s = re.sub('[إأآٱ]', 'ا', s)
    return re.sub('[^ء-ي]', '', s)


# Defects in the source, each checked to still be there before it is fixed, so
# a corrected upstream fails loudly here instead of being patched twice.
_NAWAWI_AR_FIXES = {
    # Ibn Majah's number is missing; 3976, as in the original project's file.
    12: [('ابن ماجه [رقم:]', 'ابن ماجه [رقم:3976]')],
    # At-Tirmidhi 2676, not 266 (a dropped digit; the original file has 2676).
    28: [('[رقم:266]', '[رقم:2676]')],
    # Unbalanced quotation marks.
    16: [('لَا تَغْضَبْ" .', 'لَا تَغْضَبْ.')],
    19: [('مَعَ الْعُسْرِ يُسْرًا', 'مَعَ الْعُسْرِ يُسْرًا"')],
    33: [('فِي "الصَّحِيحَيْنِ', 'فِي "الصَّحِيحَيْنِ"')],
    39: [('["السنن]', '["السنن"]')],
}


def _paragraphs(text):
    text = re.sub(r'[​-‏‪-‮﻿]', '', text)
    text = re.sub(r'\s*<br\s*/?>\s*', '\n', text)
    paras = [re.sub(r'[ \t]+', ' ', p).strip() for p in text.split('\n')]
    return [p for p in paras if p]


def build_hadeth():
    base = 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions'
    ar = fetch(f'{base}/ara-nawawi.json', 'fz-ara-nawawi.json')['hadiths']
    en = fetch(f'{base}/eng-nawawi.json', 'fz-eng-nawawi.json')['hadiths']
    assert len(ar) == len(en) == 42
    assert [h['hadithnumber'] for h in ar] == [h['hadithnumber'] for h in en] == list(range(1, 43))

    out = []
    for a, e in zip(ar, en):
        n = a['hadithnumber']
        text = a['text']
        for bad, good in _NAWAWI_AR_FIXES.get(n, []):
            assert text.count(bad) == 1, f'nawawi {n}: expected exactly one {bad!r}'
            text = text.replace(bad, good)
        paras = _paragraphs(text)
        assert paras and all('<' not in p and '>' not in p for p in paras), n
        assert sum(p.count('"') for p in paras) % 2 == 0, f'nawawi {n}: unbalanced quotes'
        english = ' '.join(_paragraphs(e['text']))
        assert english, n
        out.append({'n': n, 'c': 'nawawi', 'title': arabic_ordinal_title(n), 'ar': paras, 'en': english})

    legacy_dir = os.path.join(ROOT, 'tool', 'content', 'ibn_rajab')
    for n in range(43, 51):
        with open(os.path.join(legacy_dir, f'h{n}.txt'), encoding='utf-8-sig') as f:
            lines = [l.strip() for l in f.read().replace('\r', '').split('\n') if l.strip()]
        title = arabic_ordinal_title(n)
        assert _fold(lines[0]) == _fold(title), f'h{n}: legacy title {lines[0]!r} is not {title!r}'
        # Tatweel is decoration only; removing it changes no letter.
        body = [p for p in (re.sub(r'ـ', '', l) for l in lines[1:]) if p]
        out.append({'n': n, 'c': 'ibn_rajab', 'title': title, 'ar': body, 'en': None})

    write('hadeth/hadeth.json', json.dumps({
        'source': {
            'nawawi': 'Forty Hadith of an-Nawawi, fawazahmed0/hadith-api (sunnah.com)',
            'ibn_rajab': "Ibn Rajab's additions, the original project's files (unverified)",
        },
        'hadeth': out,
    }, ensure_ascii=False, separators=(',', ':')))
    print(f'ahadeth: {sum(h["c"] == "nawawi" for h in out)} nawawi, {sum(h["c"] == "ibn_rajab" for h in out)} ibn rajab')


if __name__ == '__main__':
    build_quran()
    build_search_text()
    build_hisn()
    build_names()
    build_hadeth()
    sys.exit(0)
