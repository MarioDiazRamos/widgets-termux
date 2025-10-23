# Scraper YTS - Clean code, español
import requests


def buscar(q):
    url = f"https://yts.mx/api/v2/list_movies.json?query_term={q}"
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        data = r.json()
        pelis = data.get("data", {}).get("movies", [])
        resultados = []
        for peli in pelis:
            titulo = peli.get("title", "")
            torrents = peli.get("torrents", [])
            poster = peli.get("medium_cover_image", "")
            magnet = ""
            seeds = 0
            if torrents and isinstance(torrents, list):
                t = torrents[0]
                if isinstance(t, dict):
                    # Construir el enlace magnet a partir del hash y nombre
                    hash_ = t.get("hash", "")
                    nombre = titulo.replace(" ", "+")
                    if hash_:
                        magnet = f"magnet:?xt=urn:btih:{hash_}&dn={nombre}"
                    seeds = t.get("seeds", 0)
            resultados.append(
                {"titulo": titulo, "magnet": magnet, "seeds": seeds, "poster": poster}
            )
        return resultados
    except Exception:
        return []
