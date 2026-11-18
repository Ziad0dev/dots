"""Tools that let a local model search and read the offline library.

An OpenAPI server for Open WebUI ("tool server"): search_library runs a
full-text search over every book kiwix-serve has (language by language, as
kiwix-serve requires), read_article returns one result as plain text.
Read-only, and it only ever talks to kiwix-serve.
"""

from __future__ import annotations

import os
import re
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from html.parser import HTMLParser

import uvicorn
from fastapi import FastAPI, HTTPException, Query

KIWIX = os.environ.get("KIWIX_URL", "http://127.0.0.1:8092/library").rstrip("/")
ORIGIN = "{0.scheme}://{0.netloc}".format(urllib.parse.urlparse(KIWIX))
CONTENT = urllib.parse.urlparse(KIWIX).path + "/content/"

app = FastAPI(
    title="Offline library",
    version="1.0.0",
    description=(
        "Search and read the offline library: Wikipedia, medical references, "
        "survival and preparedness guides, repair manuals, textbooks and books. "
        "Look facts up here instead of answering from memory, and cite the "
        "article titles you used."
    ),
)


class _Text(HTMLParser):
    SKIP = {"script", "style", "noscript", "head", "nav", "footer"}
    BLOCK = {"p", "div", "br", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "table", "section"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self.skipping = 0

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self.skipping += 1
        elif tag in self.BLOCK:
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if tag in self.SKIP and self.skipping:
            self.skipping -= 1
        elif tag in self.BLOCK:
            self.parts.append("\n")

    def handle_data(self, data):
        if not self.skipping:
            self.parts.append(data)


def plain(html: str) -> str:
    parser = _Text()
    parser.feed(html)
    text = "".join(parser.parts)
    text = re.sub(r"[ \t\r\f\v]+", " ", text)
    return re.sub(r"\n\s*\n+", "\n\n", text).strip()


def get(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read()


# Kiwix finds only articles that contain every word of the query, so words
# like these make a search miss without narrowing it
STOPWORDS = set(
    "a an and are as at be by can could do does for from has have how i if in into is it its me my "
    "no not of on or should so that the their there this to was what when where which who why will "
    "with without would you your best way ways method methods guide tips use using make get "
    "och att det som en ett är på för med av till den har inte om hur jag kan vad".split()
)
# each Gutenberg book is one document holding a whole book, so it matches
# nearly any query and crowds out the articles
GUTENBERG = "_category:gutenberg"


def keywords(query: str) -> list[str]:
    words = re.findall(r"[\w'-]+", query.lower())
    return [w for w in words if w not in STOPWORDS] or words


def search(pattern: str, limit: int, books: bool) -> list[dict]:
    """One search per language, since kiwix-serve won't search books of
    different languages together; the language with the most hits (the
    query's own) comes first."""
    try:
        root = ET.fromstring(get(f"{KIWIX}/catalog/v2/languages"))
    except Exception as error:
        raise HTTPException(502, f"the library did not answer: {error}") from error
    langs = [lang.text for lang in root.iter("{http://purl.org/dc/terms/}language") if lang.text]
    hits, errors = [], []
    for lang in langs:
        params = {"pattern": pattern, "format": "xml", "pageLength": limit, "books.filter.lang": lang}
        if not books:
            params["books.filter.notag"] = GUTENBERG
        try:
            root = ET.fromstring(get(f"{KIWIX}/search?{urllib.parse.urlencode(params)}"))
        except Exception as error:  # e.g. no book in this language has a full-text index
            errors.append(f"{lang}: {error}")
            continue
        total = re.sub(r"\D", "", root.findtext("channel/{http://a9.com/-/spec/opensearch/1.1/}totalResults") or "")
        hits.append((int(total or 0), list(root.iter("item"))))
    if not hits:
        raise HTTPException(502, "the library did not answer: " + "; ".join(errors))
    return [
        {
            "title": (item.findtext("title") or "").strip(),
            "book": (item.findtext("book/title") or "").strip(),
            "path": (item.findtext("link") or "").strip(),
            "snippet": plain(item.findtext("description") or "")[:400],
        }
        for _, items in sorted(hits, key=lambda hit: -hit[0])
        for item in items
    ]


@app.get("/search", operation_id="search_library", summary="Search the offline library")
def search_library(
    query: str = Query(
        ...,
        description="2-4 keywords, not a sentence: an article must contain every word (e.g. 'purify water boiling')",
    ),
    limit: int = Query(5, ge=1, le=10, description="How many results to return"),
    books: bool = Query(False, description="Also search the Project Gutenberg books (literature and old texts)"),
) -> dict:
    """Full-text search across the offline library."""
    terms = keywords(query)
    results, seen, searched = [], set(), []
    # a long query matches little: fall back to its first three, then two, keywords
    for words in [terms] + [terms[:n] for n in (3, 2) if len(terms) > n]:
        searched.append(" ".join(words))
        for result in search(searched[-1], limit, books):
            if result["path"] not in seen:
                seen.add(result["path"])
                results.append(result)
        if len(results) >= limit:
            break
    return {"query": query, "searched": searched, "results": results[:limit]}


@app.get("/article", operation_id="read_article", summary="Read an article from the offline library")
def read_article(
    path: str = Query(..., description="The `path` of a search_library result"),
    max_chars: int = Query(8000, ge=500, le=40000, description="Cut the text after this many characters"),
) -> dict:
    """The text of one article, without markup."""
    if not path.startswith(CONTENT):
        raise HTTPException(400, "path must be a search_library result")
    try:
        text = plain(get(ORIGIN + path).decode("utf-8", "replace"))
    except Exception as error:
        raise HTTPException(502, f"the library did not answer: {error}") from error
    return {"path": path, "text": text[:max_chars], "truncated": len(text) > max_chars}


if __name__ == "__main__":
    uvicorn.run(
        app,
        host=os.environ.get("HOST", "127.0.0.1"),
        port=int(os.environ.get("PORT", "8093")),
        log_level="warning",
    )
