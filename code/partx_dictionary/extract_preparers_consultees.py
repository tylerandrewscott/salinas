"""
Extract organization names from "List of Preparers" and consulting/cooperating
party sections across all EIS documents.

Input:  salinasbox/intermediate_data/pdf_to_text_raw/*.txt
Output: salinasbox/intermediate_data/dictionaries/preparers_consultees.json

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
OUTPUT_PATH = SALINASBOX / "intermediate_data/dictionaries/preparers_consultees.json"
CACHE_DIR = SALINASBOX / "intermediate_data/dictionaries/preparers_consultees_cache"

# ---------------------------------------------------------------------------
# Regex anchors — conservative, high-precision patterns only
# ---------------------------------------------------------------------------
PREPARERS_RE = re.compile(
    r"(?i)(list\s+of\s+preparers|preparers\s+and\s+(contributors|reviewers))"
)

CONSULTING_RE = re.compile(
    r"(?i)(consulting\s+part(y|ies)"
    r"|parties\s+invited\s+to\s+(participate|consult)"
    r"|cooperating\s+agenc"
    r"|(signatory|invited\s+signatory|concurring\s+party)\s*:)"
)

# Combined for a quick pre-filter
ANY_TARGET_RE = re.compile(
    r"(?i)(list\s+of\s+preparers"
    r"|preparers\s+and\s+(contributors|reviewers)"
    r"|consulting\s+part(y|ies)"
    r"|parties\s+invited\s+to\s+(participate|consult)"
    r"|cooperating\s+agenc"
    r"|(signatory|invited\s+signatory|concurring\s+party)\s*:)"
)

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
PROMPT_TEMPLATE = """This text is from an Environmental Impact Statement (EIS). \
It might contain one or more sections listing organizations involved in preparing or \
reviewing this document (e.g. List of Preparers, Cooperating Agencies, \
Consulting Parties, or MOA signatories).

If yes, extract every ORGANIZATION name. Do not include individual person names, \
job titles, degrees, or place names. For each organization, infer its category.

Return a JSON array — no explanation, no markdown, just the array:
[
  {{"name": "Bureau of Land Management", "category": "federal_agency"}},
  ...
]

Valid categories: federal_agency | state_agency | tribe | local_government | \
consulting_firm | ngo | utility | other

Text:
{text}
"""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def read_pages(filepath: Path) -> list[tuple[str, str]]:
    """Return list of (page_num_str, text) from a TSV file."""
    pages = []
    csv.field_size_limit(10_000_000)
    with open(filepath, encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f, delimiter="\t")
        next(reader, None)  # skip header
        for row in reader:
            if len(row) >= 2:
                pages.append((row[0], row[1]))
    return pages


def find_target_indices(pages: list[tuple[str, str]]) -> list[int]:
    """Return sorted indices of pages that match any target anchor."""
    return [i for i, (_, text) in enumerate(pages) if ANY_TARGET_RE.search(text)]


def group_consecutive(indices: list[int], gap: int = 2) -> list[list[int]]:
    """Group indices that are within `gap` of each other into contiguous windows."""
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
    if PREPARERS_RE.search(combined):
        return "List of Preparers"
    if CONSULTING_RE.search(combined):
        return "Consulting / Cooperating Parties"
    return "Unknown target section"


def call_claude(client: anthropic.Anthropic, text: str) -> list[dict]:
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=2048,
        messages=[{"role": "user", "content": PROMPT_TEMPLATE.format(text=text)}],
    )
    raw = response.content[0].text.strip()
    # Strip markdown code fences if present
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

    # Aggregate results: name -> {count, category, sources}
    aggregate: dict[str, dict] = defaultdict(
        lambda: {"count": 0, "category": "other", "sources": []}
    )

    txt_files = sorted(INPUT_DIR.glob("*.txt"))
    print(f"Processing {len(txt_files)} files...")

    for filepath in txt_files:
        doc_id = filepath.stem
        cache_path = CACHE_DIR / f"{doc_id}.json"

        # Load from cache if already processed
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
                section_label = label_section(page_texts)
                chunk = "\n\n--- page break ---\n\n".join(page_texts)
                orgs = call_claude(client, chunk)
                for org in orgs:
                    name = org.get("name", "").strip()
                    if name:
                        doc_results.append({
                            "name": name,
                            "category": org.get("category", "other"),
                            "section": section_label,
                        })

            cache_path.write_text(json.dumps(doc_results, indent=2))
            print(f"    -> {len(doc_results)} organizations extracted")

        # Merge into aggregate
        for entry in doc_results:
            name = entry["name"]
            aggregate[name]["count"] += 1
            aggregate[name]["category"] = entry.get("category", "other")
            if doc_id not in aggregate[name]["sources"]:
                aggregate[name]["sources"].append(doc_id)

    # Write final output
    output = sorted(
        [{"name": k, **v} for k, v in aggregate.items()],
        key=lambda x: (-x["count"], x["name"]),
    )
    OUTPUT_PATH.write_text(json.dumps(output, indent=2))
    print(f"\nDone. {len(output)} unique organizations written to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
