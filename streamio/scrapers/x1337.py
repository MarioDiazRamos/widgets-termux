# Scraper 1337x - Clean code, español

import requests
from bs4 import BeautifulSoup
from urllib.parse import quote

def buscar(q):
    url = f"https://1337x.to/search/{q}/1/"
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, 'html.parser')
        resultados = []
        for row in soup.select('tr'):
            title_tag = row.select_one('td.coll-1 a')
            if not title_tag:
                continue
            titulo = title_tag.text.strip()
            link = title_tag['href'] if 'href' in title_tag.attrs else ''
            magnet = ''
            poster = ''
            year = ''
            tipo = 'pelicula'  # por defecto
            # Extraer año si está en el título
            import re
            m = re.search(r'(19|20)\d{2}', titulo)
            if m:
                year = m.group(0)
            # Buscar carátula en DuckDuckGo Images
            try:
                query = f"{titulo} movie poster"
                duck_url = f"https://duckduckgo.com/?q={quote(query)}&iax=images&ia=images"
                headers = {'User-Agent': 'Mozilla/5.0'}
                duck_r = requests.get(duck_url, headers=headers, timeout=10)
                img_url = ''
                if 'vqd=' in duck_r.text:
                    vqd = duck_r.text.split('vqd=')[1].split('&')[0]
                    api_url = f"https://duckduckgo.com/i.js?l=us-en&o=json&q={quote(query)}&vqd={vqd}"
                    api_r = requests.get(api_url, headers=headers, timeout=10)
                    imgs = api_r.json().get('results', [])
                    if imgs:
                        poster = imgs[0].get('image', '')
            except Exception:
                poster = ''
            if link:
                try:
                    suburl = f"https://1337x.to{link}"
                    subr = requests.get(suburl, timeout=10)
                    subsoup = BeautifulSoup(subr.text, 'html.parser')
                    mag = subsoup.select_one('a[href^="magnet:"]')
                    if mag and 'href' in mag.attrs:
                        magnet = mag['href']
                except Exception:
                    magnet = ''
            seeds_tag = row.select_one('td.coll-2')
            try:
                seeds = int(seeds_tag.text.strip()) if seeds_tag and seeds_tag.text.strip().isdigit() else 0
            except Exception:
                seeds = 0
            resultados.append({'titulo': titulo, 'magnet': magnet, 'seeds': seeds, 'poster': poster, 'year': year, 'tipo': tipo, 'fuente': '1337x'})
        return resultados
    except Exception:
        return []
