# Scraper 1337x - Clean code, español

import re
import requests
from bs4 import BeautifulSoup
from urllib.parse import quote


def _extraer_year_titulo(titulo):
    """Extrae el año del título si está presente."""
    m = re.search(r"(19|20)\d{2}", titulo)
    return m.group(0) if m else ""


def _buscar_poster_duckduckgo(titulo):
    """Busca el póster de la película en DuckDuckGo Images."""
    try:
        query = f"{titulo} movie poster"
        duck_url = f"https://duckduckgo.com/?q={quote(query)}&iax=images&ia=images"
        headers = {"User-Agent": "Mozilla/5.0"}
        duck_r = requests.get(duck_url, headers=headers, timeout=10)

        if "vqd=" not in duck_r.text:
            return ""

        vqd = duck_r.text.split("vqd=")[1].split("&")[0]
        base_url = "https://duckduckgo.com/i.js"
        api_url = f"{base_url}?l=us-en&o=json&q={quote(query)}&vqd={vqd}"
        api_r = requests.get(api_url, headers=headers, timeout=10)
        imgs = api_r.json().get("results", [])

        return imgs[0].get("image", "") if imgs else ""
    except Exception:
        return ""


def _obtener_magnet_link(link):
    """Obtiene el enlace magnet de la página de detalles."""
    if not link:
        return ""

    try:
        suburl = f"https://1337x.to{link}"
        subr = requests.get(suburl, timeout=10)
        subsoup = BeautifulSoup(subr.text, "html.parser")
        mag = subsoup.select_one('a[href^="magnet:"]')
        return mag["href"] if mag and "href" in mag.attrs else ""
    except Exception:
        return ""


def _extraer_seeds(row):
    """Extrae el número de seeds de la fila."""
    seeds_tag = row.select_one("td.coll-2")
    try:
        return (
            int(seeds_tag.text.strip())
            if seeds_tag and seeds_tag.text.strip().isdigit()
            else 0
        )
    except Exception:
        return 0


def _procesar_fila_resultado(row):
    """Procesa una fila de resultados y extrae la información del torrent."""
    title_tag = row.select_one("td.coll-1 a")
    if not title_tag:
        return None

    titulo = title_tag.text.strip()
    link = title_tag["href"] if "href" in title_tag.attrs else ""

    return {
        "titulo": titulo,
        "magnet": _obtener_magnet_link(link),
        "seeds": _extraer_seeds(row),
        "poster": _buscar_poster_duckduckgo(titulo),
        "year": _extraer_year_titulo(titulo),
        "tipo": "pelicula",
        "fuente": "1337x",
    }


def buscar(q):
    """Busca torrents en 1337x."""
    url = f"https://1337x.to/search/{q}/1/"
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, "html.parser")

        resultados = []
        for row in soup.select("tr"):
            resultado = _procesar_fila_resultado(row)
            if resultado:
                resultados.append(resultado)

        return resultados
    except Exception:
        return []
