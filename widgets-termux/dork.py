#!/usr/bin/env python3
# dork.py – Generador local de Google Dorks (sin dependencias externas)
# Uso:
#   python dork.py "palabra clave" [--json] [--open N]
#   python dork.py                 # modo interactivo

import argparse
import json
import subprocess
import sys
import urllib.parse

TEMPLATES = [
    'intitle:"{kw}"',
    'inurl:"{kw}"',
    'intext:"{kw}"',
    '"{kw}" filetype:pdf',
    '"{kw}" filetype:docx',
    '"{kw}" filetype:xlsx',
    '"{kw}" "index of"',
    '"{kw}" (password|contraseña) -github -stackoverflow',
    '"{kw}" (admin|login|panel) inurl:(login|admin)',
    'site:*.* "{kw}"',
    '"{kw}" ext:sql | ext:bak',
    '"{kw}" (confidential|privado|restringido) -site:github.com',
]


def generate_dorks(keyword: str) -> list[str]:
    kw = keyword.strip()
    if not kw:
        return []
    return [t.format(kw=kw) for t in TEMPLATES]


def open_in_browser(query: str) -> None:
    url = "https://www.google.com/search?q=" + urllib.parse.quote(query)
    # Intentar con termux-open-url si existe, si no usar xdg-open
    for cmd in ("termux-open-url", "xdg-open", "start"):  # 'start' para Windows
        try:
            if subprocess.call([cmd, url]) == 0:
                return
        except FileNotFoundError:
            continue
    print("No se pudo abrir el navegador automáticamente. URL:", url)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Generador local de Google Dorks")
    parser.add_argument("keyword", nargs="?", help="Palabra clave o frase")
    parser.add_argument("--json", action="store_true", help="Imprime solo JSON")
    parser.add_argument(
        "--open", type=int, default=0, help="Abrir en navegador el dork N (1..N)"
    )
    args = parser.parse_args(argv)

    keyword = args.keyword
    if not keyword:
        try:
            keyword = input("Palabra clave para generar dorks: ").strip()
        except (EOFError, KeyboardInterrupt):
            return 1

    dorks = generate_dorks(keyword)
    payload = {"keyword": keyword, "generated": dorks}

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(f"\nDorks generados para: {keyword}\n")
        for i, d in enumerate(dorks, 1):
            print(f"{i:2d}) {d}")
        print(
            "\nSugerencia: usa --json para obtenerlos en JSON o --open N para abrir uno."
        )

    if args.open:
        idx = args.open - 1
        if 0 <= idx < len(dorks):
            open_in_browser(dorks[idx])
        else:
            print("Índice fuera de rango.", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
