"""
Filter acronym_dictionary.json using the same FILTER_PATTERNS as the original
filter_acronym_dictionary.py (chemicals, units of measurement, scientific
concepts, etc.).

Input:  salinasbox/intermediate_data/dictionaries/acronym_dictionary.json
Output: salinasbox/intermediate_data/dictionaries/acronym_dictionary_filtered.json

Filtering logic (mirrors filter_acronym_dictionary.py):
  - Normalize each expansion: lowercase, underscores/hyphens → spaces
  - If the normalized expansion exactly matches a FILTER_PATTERNS entry, drop it
  - If a term loses all its expansions, drop the term entirely
  - Terms with at least one surviving expansion are written with only those expansions
"""

import importlib.util
import json
import sys
from pathlib import Path

SALINASBOX = Path.home() / "Library/CloudStorage/Box-Box/salinasbox"
INPUT_PATH  = SALINASBOX / "intermediate_data/dictionaries/acronym_dictionary.json"
OUTPUT_PATH = SALINASBOX / "intermediate_data/dictionaries/acronym_dictionary_filtered.json"
FILTER_SCRIPT = SALINASBOX / "dictionary_data/filter_acronym_dictionary.py"


def load_filter_module():
    spec = importlib.util.spec_from_file_location("filter_acronym_dictionary", FILTER_SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    mod = load_filter_module()
    filter_patterns = set(mod.FILTER_PATTERNS)
    normalize = mod.normalize

    data = json.loads(INPUT_PATH.read_text())

    kept_terms = 0
    removed_terms = 0
    removed_expansions = 0

    output = []
    for entry in data:
        filtered_expansions = []
        for exp_obj in entry["expansions"]:
            norm = normalize(exp_obj["expansion"])
            if norm in filter_patterns:
                removed_expansions += 1
            else:
                filtered_expansions.append(exp_obj)

        if not filtered_expansions:
            removed_terms += 1
            continue

        # Recompute aggregate fields from surviving expansions
        all_sources = sorted({s for e in filtered_expansions for s in e["sources"]})
        output.append({
            **entry,
            "expansions": filtered_expansions,
            "n_expansions": len(filtered_expansions),
            "n_docs": len(all_sources),
            "sources": all_sources,
        })
        kept_terms += 1

    OUTPUT_PATH.write_text(json.dumps(output, indent=2))
    print(f"Done.")
    print(f"  Kept {kept_terms} terms, removed {removed_terms} terms")
    print(f"  Removed {removed_expansions} individual expansions from kept terms")
    print(f"  Output: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
