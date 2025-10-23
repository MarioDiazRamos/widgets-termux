# Scraper TPB (The Pirate Bay) - Clean code, español
import requests
from bs4 import BeautifulSoup
from urllib.parse import quote

def buscar(q):
    url = f"https://thepiratebay.org/search/{q}/1/99/0"
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, 'html.parser')
        resultados = []
        for row in soup.select('tr'):
            name_tag = row.select_one('.detName a')
            if not name_tag:
                continue
            titulo = name_tag.text.strip()
            magnet_tag = row.select_one('a[title="Download this torrent using magnet"]')
            magnet = magnet_tag['href'] if magnet_tag and 'href' in magnet_tag.attrs else ''
            poster = ''
            year = ''
            tipo = 'pelicula'
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
                if 'vqd=' in duck_r.text:
                    vqd = duck_r.text.split('vqd=')[1].split('&')[0]
                    api_url = f"https://duckduckgo.com/i.js?l=us-en&o=json&q={quote(query)}&vqd={vqd}"
                    api_r = requests.get(api_url, headers=headers, timeout=10)
                    imgs = api_r.json().get('results', [])
                    if imgs:
                        poster = imgs[0].get('image', '')
            except Exception:
                poster = ''
            seeds_tag = row.select_one('td[align="right"]')
            try:
                seeds = int(seeds_tag.text.strip()) if seeds_tag and seeds_tag.text.strip().isdigit() else 0
            except Exception:
                seeds = 0
            resultados.append({'titulo': titulo, 'magnet': magnet, 'seeds': seeds, 'poster': poster, 'year': year, 'tipo': tipo, 'fuente': 'TPB'})
        return resultados
    except Exception:
        return []
