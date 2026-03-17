"""
Extract acronym/abbreviation and glossary term dictionaries from EIS documents.

Input:  salinasbox/intermediate_data/pdf_to_text_raw/*.txt
Output: salinasbox/intermediate_data/dictionaries/acronym_dictionary.json
        salinasbox/intermediate_data/dictionaries/glossary_dictionary.json

Each input file is a TSV with columns: page, text
Each row is one page of the document.

Acronym sections are two-column (term | full expansion).
Glossary sections are term + free-text definition paragraph.
The two types are detected separately and sent to distinct prompts.
"""

import anthropic
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SALINASBOX = Path.home() / "Library/CloudStorage/Box-Box/salinasbox"
INPUT_DIR = SALINASBOX / "intermediate_data/pdf_to_text_raw"
ACRONYM_OUTPUT_PATH = SALINASBOX / "intermediate_data/dictionaries/acronym_dictionary.json"
GLOSSARY_OUTPUT_PATH = SALINASBOX / "intermediate_data/dictionaries/glossary_dictionary.json"
CACHE_DIR = SALINASBOX / "intermediate_data/dictionaries/acronym_glossaries_cache"

# ---------------------------------------------------------------------------
# Regex anchors
# ---------------------------------------------------------------------------
ACRONYM_RE = re.compile(
    r"(?i)(acronyms\s+and\s+abbreviations"
    r"|list\s+of\s+acronyms"
    r"|list\s+of\s+abbreviations"
    r"|abbreviations\s+and\s+acronyms"
    r"|key\s+terms\s+and\s+acronyms"
    r"|^\s*[\d\.]+\s+acronyms\s*$"
    r"|^\s*acronyms\s*$"
    r"|^\s*abbreviations\s*$)",
    re.MULTILINE,
)

GLOSSARY_RE = re.compile(
    r"(?i)(^\s*[\d\.]+\s+glossary\s*$"
    r"|^\s*glossary\s*$"
    r"|glossary\s+of\s+terms"
    r"|list\s+of\s+terms"
    r"|key\s+terms\s+and\s+definitions"
    r"|terms\s+and\s+definitions"
    r"|^\s*definitions\s*$"
    r"|definitions\s+and\s+abbreviations)",
    re.MULTILINE,
)

ANY_TARGET_RE = re.compile(
    r"(?i)(acronyms\s+and\s+abbreviations"
    r"|list\s+of\s+acronyms"
    r"|list\s+of\s+abbreviations"
    r"|abbreviations\s+and\s+acronyms"
    r"|key\s+terms\s+and\s+acronyms"
    r"|^\s*[\d\.]+\s+acronyms\s*$"
    r"|^\s*acronyms\s*$"
    r"|^\s*abbreviations\s*$"
    r"|^\s*[\d\.]+\s+glossary\s*$"
    r"|^\s*glossary\s*$"
    r"|glossary\s+of\s+terms"
    r"|list\s+of\s+terms"
    r"|key\s+terms\s+and\s+definitions"
    r"|terms\s+and\s+definitions"
    r"|^\s*definitions\s*$"
    r"|definitions\s+and\s+abbreviations)",
    re.MULTILINE,
)

# A page looks like a TOC page if it says "table of contents" or the heading
# match is followed by dotted leaders + a page number on the same line.
TOC_PAGE_RE = re.compile(r"(?i)table\s+of\s+contents")
TOC_ENTRY_RE = re.compile(
    r"(?i)(acronyms|abbreviations|glossary|definitions)[\s\.]{4,}\d+",
)

# Max pages to include after the last anchor page in a section group.
MAX_SECTION_PAGES = 30

# Output tokens scaled by section size.
# Acronym sections: ~500 tokens/page (15-20 short entries × ~25-30 tokens each).
# Glossary sections: ~100 tokens/page (terms only, ~5-10 terms × ~10 tokens each).
def _max_tokens_for_pages(n_pages: int, section_type: str) -> int:
    tokens_per_page = 100 if section_type == "glossary" else 500
    return max(1024, min(n_pages * tokens_per_page, 16384))

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
ACRONYM_PROMPT = """This text is from an Environmental Impact Statement (EIS). \
It contains an acronyms or abbreviations section formatted as two columns: \
the left column is the acronym or abbreviation, the right column is the full \
spelled-out term or name.

Extract every entry. Include entries where the "acronym" is a word rather than \
initials (e.g. "Applicant" -> "Desert Stateline LLC").

Return a JSON array — no explanation, no markdown, just the array:
[
  {{"term": "BLM", "expansion": "Bureau of Land Management"}},
  {{"term": "NEPA", "expansion": "National Environmental Policy Act"}},
  {{"term": "Applicant", "expansion": "Desert Stateline, LLC"}},
  ...
]

Text:
{text}
"""

GLOSSARY_PROMPT = """This text is from an Environmental Impact Statement (EIS). \
It contains a glossary or definitions section. Each entry has a term followed \
by a definition.

Extract every term. Do not include definitions.

Return a JSON array of strings — no explanation, no markdown, just the array:
["Mitigation", "Significance", "Cumulative Impact", "Affected Environment", ...]

Text:
{text}
"""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def read_pages(filepath: Path) -> list[tuple[str, str]]:
    csv.field_size_limit(10_000_000)
    pages = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f, delimiter="\t")
        next(reader, None)
        for row in reader:
            if len(row) >= 2:
                pages.append((row[0], row[1]))
    return pages


def is_toc_page(text: str) -> bool:
    """Return True if this page is a Table of Contents page rather than the
    actual section.  Two signals: (1) the page contains 'table of contents',
    or (2) the heading keyword is followed by dotted leaders and a page number
    (the classic TOC entry format: 'Acronyms .......... 45')."""
    return bool(TOC_PAGE_RE.search(text) or TOC_ENTRY_RE.search(text))


def find_sections(pages: list[tuple[str, str]]) -> list[list[int]]:
    """Find anchor pages matching target headings (excluding TOC pages), group
    consecutive ones, then extend each group's window up to MAX_SECTION_PAGES
    beyond the last anchor."""
    anchors = [
        i for i, (_, text) in enumerate(pages)
        if ANY_TARGET_RE.search(text) and not is_toc_page(text)
    ]
    if not anchors:
        return []

    # Group anchors that are within 2 pages of each other
    groups: list[list[int]] = [[anchors[0]]]
    for idx in anchors[1:]:
        if idx - groups[-1][-1] <= 2:
            groups[-1].append(idx)
        else:
            groups.append([idx])

    # Extend each group forward up to MAX_SECTION_PAGES, stopping before the next group
    n = len(pages)
    sections = []
    for k, group in enumerate(groups):
        next_start = groups[k + 1][0] if k + 1 < len(groups) else n
        end = min(group[-1] + MAX_SECTION_PAGES + 1, next_start, n)
        sections.append(list(range(group[0], end)))
    return sections


def label_section(page_texts: list[str]) -> str:
    combined = " ".join(page_texts)
    if ACRONYM_RE.search(combined):
        return "acronym"
    if GLOSSARY_RE.search(combined):
        return "glossary"
    return "unknown"


def call_claude(client: anthropic.Anthropic, text: str, section_type: str, n_pages: int) -> list[dict]:
    prompt = ACRONYM_PROMPT if section_type != "glossary" else GLOSSARY_PROMPT
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=_max_tokens_for_pages(n_pages, section_type),
        messages=[{"role": "user", "content": prompt.format(text=text)}],
    )
    raw = response.content[0].text.strip()
    raw = re.sub(r"^```[a-z]*\n?", "", raw)
    raw = re.sub(r"\n?```$", "", raw)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        match = re.search(r"\[.*\]", raw, re.DOTALL)
        if match:
            try:
                return json.loads(match.group())
            except json.JSONDecodeError:
                pass
    print(f"  WARNING: could not parse Claude response: {raw[:200]}", file=sys.stderr)
    return []


def build_output(aggregate: dict) -> list[dict]:
    """Convert aggregate dict to sorted output list."""
    output = []
    for term, data in aggregate.items():
        exp_sources = data["expansion_sources"]
        expansions = sorted(
            [
                {"expansion": exp, "n_docs": len(srcs), "sources": sorted(srcs)}
                for exp, srcs in exp_sources.items()
            ],
            key=lambda x: -x["n_docs"],
        )
        all_sources = sorted({s for srcs in exp_sources.values() for s in srcs})
        output.append({
            "term": term,
            "n_docs": len(all_sources),
            "n_expansions": len(exp_sources),
            "expansions": expansions,
            "sources": all_sources,
        })
    return sorted(output, key=lambda x: (-x["n_docs"], x["term"]))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    client = anthropic.Anthropic()

    acronym_agg: dict[str, dict] = defaultdict(
        lambda: {"expansion_sources": defaultdict(set)}
    )
    glossary_agg: dict[str, set] = defaultdict(set)  # term -> set of doc_ids

    txt_files = sorted(INPUT_DIR.glob("*.txt"))
    print(f"Processing {len(txt_files)} files...")

    for filepath in txt_files:
        doc_id = filepath.stem
        cache_path = CACHE_DIR / f"{doc_id}.json"

        if cache_path.exists():
            print(f"  {doc_id}: cached")
            doc_results = json.loads(cache_path.read_text())
        else:
            pages = read_pages(filepath)
            sections = find_sections(pages)

            if not sections:
                print(f"  {doc_id}: no target sections found")
                cache_path.write_text("[]")
                continue

            print(f"  {doc_id}: {len(sections)} section group(s) detected")

            doc_results = []
            for group in sections:
                page_texts = [pages[i][1] for i in group]
                section_type = label_section(page_texts)
                chunk = "\n\n--- page break ---\n\n".join(page_texts)
                entries = call_claude(client, chunk, section_type, len(group))

                if section_type == "glossary":
                    for entry in entries:
                        term = (entry.strip() if isinstance(entry, str) else entry.get("term", "").strip())
                        if term:
                            doc_results.append({"term": term, "type": "glossary"})
                else:
                    for entry in entries:
                        term = entry.get("term", "").strip()
                        expansion = entry.get("expansion", "").strip()
                        if term and expansion:
                            doc_results.append({
                                "term": term,
                                "expansion": expansion,
                                "type": "acronym",
                            })

            cache_path.write_text(json.dumps(doc_results, indent=2))
            n_acronym = sum(1 for e in doc_results if e["type"] == "acronym")
            n_glossary = sum(1 for e in doc_results if e["type"] == "glossary")
            print(f"    -> {n_acronym} acronyms, {n_glossary} glossary terms extracted")

        for entry in doc_results:
            term = entry["term"]
            if entry.get("type") == "glossary":
                glossary_agg[term].add(doc_id)
            else:
                expansion = entry.get("expansion", "")
                if expansion:
                    acronym_agg[term]["expansion_sources"][expansion].add(doc_id)

    # Write separate output files
    acronym_output = build_output(acronym_agg)
    glossary_output = sorted(
        [{"term": term, "n_docs": len(srcs), "sources": sorted(srcs)}
         for term, srcs in glossary_agg.items()],
        key=lambda x: (-x["n_docs"], x["term"]),
    )

    ACRONYM_OUTPUT_PATH.write_text(json.dumps(acronym_output, indent=2))
    GLOSSARY_OUTPUT_PATH.write_text(json.dumps(glossary_output, indent=2))
    print(f"\nDone.")
    print(f"  {len(acronym_output)} unique acronym/abbreviation terms -> {ACRONYM_OUTPUT_PATH}")
    print(f"  {len(glossary_output)} unique glossary terms -> {GLOSSARY_OUTPUT_PATH}")


if __name__ == "__main__":
    main()
