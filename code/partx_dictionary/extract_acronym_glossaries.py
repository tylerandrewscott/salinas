"""
Extract acronym/abbreviation and glossary term dictionaries from EIS documents.

Input:  salinasbox/intermediate_data/pdf_to_text_raw/*.txt
Output: salinasbox/intermediate_data/dictionaries/acronym_glossaries.json

Each input file is a TSV with columns: page, text
Each row is one page of the document.
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
OUTPUT_PATH = SALINASBOX / "intermediate_data/dictionaries/acronym_glossaries.json"
CACHE_DIR = SALINASBOX / "intermediate_data/dictionaries/acronym_glossaries_cache"

# ---------------------------------------------------------------------------
# Regex anchors
# ---------------------------------------------------------------------------
ACRONYM_RE = re.compile(
    r"(?i)(acronyms\s+and\s+abbreviations"
    r"|list\s+of\s+acronyms"
    r"|^\s*[\d\.]+\s+acronyms\s*$"
    r"|abbreviations\s+and\s+acronyms)",
    re.MULTILINE,
)

GLOSSARY_RE = re.compile(
    r"(?i)(^\s*[\d\.]+\s+glossary\s*$"
    r"|glossary\s+of\s+terms"
    r"|list\s+of\s+terms"
    r"|definitions\s+and\s+abbreviations)",
    re.MULTILINE,
)

ANY_TARGET_RE = re.compile(
    r"(?i)(acronyms\s+and\s+abbreviations"
    r"|list\s+of\s+acronyms"
    r"|abbreviations\s+and\s+acronyms"
    r"|^\s*[\d\.]+\s+acronyms\s*$"
    r"|^\s*[\d\.]+\s+glossary\s*$"
    r"|glossary\s+of\s+terms"
    r"|list\s+of\s+terms"
    r"|definitions\s+and\s+abbreviations)",
    re.MULTILINE,
)

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
PROMPT_TEMPLATE = """This text is from an Environmental Impact Statement (EIS). \
It contains an acronyms, abbreviations, or glossary section.

Extract every acronym/abbreviation and its full expansion, OR every glossary \
term and its definition. Include entries where the "acronym" is a word \
(e.g. "Applicant" -> "Desert Stateline LLC").

Return a JSON array — no explanation, no markdown, just the array:
[
  {{"term": "BLM", "expansion": "Bureau of Land Management", "type": "acronym"}},
  {{"term": "Applicant", "expansion": "Desert Stateline, LLC", "type": "acronym"}},
  {{"term": "Mitigation", "expansion": "Actions taken to reduce adverse impacts...", "type": "glossary"}},
  ...
]

Valid types: acronym | glossary

Text:
{text}
"""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def read_pages(filepath: Path) -> list[tuple[str, str]]:
    pages = []
    with open(filepath, encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f, delimiter="\t")
        next(reader, None)
        for row in reader:
            if len(row) >= 2:
                pages.append((row[0], row[1]))
    return pages


def find_target_indices(pages: list[tuple[str, str]]) -> list[int]:
    return [i for i, (_, text) in enumerate(pages) if ANY_TARGET_RE.search(text)]


def group_consecutive(indices: list[int], gap: int = 2) -> list[list[int]]:
    if not indices:
        return []
    groups = [[indices[0]]]
    for idx in indices[1:]:
        if idx - groups[-1][-1] <= gap:
            groups[-1].append(idx)
        else:
            groups.append([idx])
    return groups


def label_section(page_texts: list[str]) -> str:
    combined = " ".join(page_texts)
    if ACRONYM_RE.search(combined):
        return "acronym"
    if GLOSSARY_RE.search(combined):
        return "glossary"
    return "unknown"


def call_claude(client: anthropic.Anthropic, text: str) -> list[dict]:
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=4096,
        messages=[{"role": "user", "content": PROMPT_TEMPLATE.format(text=text)}],
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


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    client = anthropic.Anthropic()

    # Aggregate: term -> {expansions: {expansion: count}, type, sources}
    aggregate: dict[str, dict] = defaultdict(
        lambda: {"expansions": defaultdict(int), "type": "acronym", "sources": []}
    )

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
            target_indices = find_target_indices(pages)

            if not target_indices:
                print(f"  {doc_id}: no target sections found")
                cache_path.write_text("[]")
                continue

            groups = group_consecutive(target_indices)
            print(f"  {doc_id}: {len(groups)} section group(s) detected")

            doc_results = []
            for group in groups:
                page_texts = [pages[i][1] for i in group]
                section_type = label_section(page_texts)
                chunk = "\n\n--- page break ---\n\n".join(page_texts)
                entries = call_claude(client, chunk)
                for entry in entries:
                    term = entry.get("term", "").strip()
                    expansion = entry.get("expansion", "").strip()
                    if term and expansion:
                        doc_results.append({
                            "term": term,
                            "expansion": expansion,
                            "type": entry.get("type", section_type),
                        })

            cache_path.write_text(json.dumps(doc_results, indent=2))
            print(f"    -> {len(doc_results)} entries extracted")

        for entry in doc_results:
            term = entry["term"]
            expansion = entry["expansion"]
            aggregate[term]["expansions"][expansion] += 1
            aggregate[term]["type"] = entry.get("type", "acronym")
            if doc_id not in aggregate[term]["sources"]:
                aggregate[term]["sources"].append(doc_id)

    # Build output — flag terms with conflicting expansions
    output = []
    for term, data in aggregate.items():
        expansions = data["expansions"]
        top_expansion = max(expansions, key=expansions.get)
        output.append({
            "term": term,
            "expansion": top_expansion,
            "n_docs": len(data["sources"]),
            "n_expansions": len(expansions),  # > 1 means ambiguous across docs
            "type": data["type"],
            "sources": data["sources"],
        })

    output.sort(key=lambda x: (-x["n_docs"], x["term"]))
    OUTPUT_PATH.write_text(json.dumps(output, indent=2))
    print(f"\nDone. {len(output)} unique terms written to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
