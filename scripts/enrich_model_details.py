#!/usr/bin/env python3
"""
Auto-enrich model_details.json with data from ollama.com.

Discovers models via the Ollama cloud API (/api/tags), then scrapes
individual library pages for descriptions, capabilities, context lengths,
and other metadata not available through the API.

Usage:
    python scripts/enrich_model_details.py              # enrich new models only
    python scripts/enrich_model_details.py --dry-run    # report only, no file changes
    python scripts/enrich_model_details.py --all        # re-enrich all models
"""

import argparse
import json
import re
import sys
import time
from pathlib import Path

import requests
from bs4 import BeautifulSoup

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

OLLAMA_API_URL = "https://ollama.com/api/tags"
OLLAMA_LIBRARY_URL = "https://ollama.com/library"
HUGGINGFACE_API_URL = "https://huggingface.co/api/models"

JSON_PATH = Path(__file__).resolve().parent.parent / "poly_chat" / "Resources" / "model_details.json"

REQUEST_DELAY = 1.0  # seconds between scrape requests
MAX_RETRIES = 3

HEADERS = {
    "User-Agent": "PolyChat-ModelEnricher/1.0 (https://github.com/polychat)"
}

# ---------------------------------------------------------------------------
# Provider map — maps model family prefixes to known providers
# ---------------------------------------------------------------------------

PROVIDER_MAP = {
    "llama": "Meta",
    "gemma": "Google",
    "qwen": "Alibaba",
    "deepseek": "DeepSeek",
    "mistral": "Mistral",
    "devstral": "Mistral",
    "ministral": "Mistral",
    "codestral": "Mistral",
    "phi": "Microsoft",
    "command-r": "Cohere",
    "nemotron": "NVIDIA",
    "kimi": "Moonshot AI",
    "glm": "Zhipu",
    "minimax": "MiniMax",
    "cogito": "Deep Cogito",
    "gpt-oss": "OpenAI",
    "gemini": "Google",
    "rnj": "Essential AI",
    "falcon": "TII",
    "yi": "01.AI",
    "vicuna": "LMSYS",
    "solar": "Upstage",
    "starcoder": "Hugging Face",
    "granite": "IBM",
    "aya": "Cohere",
    "internlm": "Shanghai AI Lab",
    "olmo": "AI2",
    "nomic": "Nomic AI",
    "mxbai": "Mixedbread AI",
    "snowflake": "Snowflake",
    "smollm": "Hugging Face",
    "moondream": "Vikhyat",
    "dolphin": "Cognitive Computations",
    "wizard": "WizardLM",
}

# Capability tag strings found on Ollama library pages → JSON capabilities
CAPABILITY_TAG_MAP = {
    "vision": ("vision", True, None),      # (capability_str, hasVision, hasTools)
    "tools": (None, None, True),
    "thinking": ("reasoning", None, None),
    "code": ("code", None, None),
    "coding": ("code", None, None),
    "embedding": ("embedding", None, None),
    "audio": ("audio", None, None),
}

# ---------------------------------------------------------------------------
# Display name generation
# ---------------------------------------------------------------------------



# Known acronyms that should stay uppercase in display names
ACRONYMS = {"glm", "gpt", "vl", "oss", "rnj", "yi"}


def generate_display_name(model_name: str) -> str:
    """Convert a model name like 'qwen3-coder:80b' to 'Qwen 3 Coder 80B'."""
    base, _, tag = model_name.partition(":")
    # Replace hyphens/underscores with spaces, but preserve dots within versions
    parts = base.replace("-", " ").replace("_", " ")
    # Insert space between letters and digits, but NOT when separated by a dot
    # e.g., "qwen3" -> "qwen 3" but "k2.6" stays as "k2.6"
    parts = re.sub(r"([a-zA-Z])(\d)(?![\d.])", r"\1 \2", parts)
    # Insert space between digits and letters (but not after dots in versions)
    parts = re.sub(r"(?<!\.)(\d)([a-zA-Z])", r"\1 \2", parts)

    # Title-case each word, keeping acronyms uppercase
    words = []
    for w in parts.split():
        if w.lower() in ACRONYMS:
            words.append(w.upper())
        elif w.isupper() and len(w) > 1:
            words.append(w)  # preserve existing all-caps
        else:
            words.append(w.capitalize())
    parts = " ".join(words)

    if tag:
        # If the tag looks like a size (e.g., "80b", "1t", "671b"), uppercase it
        if re.match(r"^\d+[btmk]?$", tag, re.IGNORECASE):
            tag_display = tag.upper()
        else:
            tag_display = tag.replace("-", " ").replace("_", " ").title()
        return f"{parts} {tag_display}"
    return parts


# ---------------------------------------------------------------------------
# Ollama API — model discovery
# ---------------------------------------------------------------------------


def fetch_ollama_models() -> list[str]:
    """Fetch all model names from the Ollama cloud API /api/tags."""
    print(f"Fetching model list from {OLLAMA_API_URL}...")
    resp = requests.get(OLLAMA_API_URL, headers=HEADERS, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    models = [m["name"] for m in data.get("models", [])]
    print(f"  Found {len(models)} models on Ollama cloud API")
    return models


# ---------------------------------------------------------------------------
# Ollama library page scraping
# ---------------------------------------------------------------------------


def _get_base_name(model_name: str) -> str:
    """Extract the base model name: 'qwen3-coder:80b' -> 'qwen3-coder'."""
    return model_name.partition(":")[0]


def _fetch_with_retry(url: str) -> requests.Response | None:
    """Fetch a URL with retries and rate limiting."""
    for attempt in range(MAX_RETRIES):
        try:
            resp = requests.get(url, headers=HEADERS, timeout=30)
            if resp.status_code == 200:
                return resp
            if resp.status_code == 404:
                return None
            print(f"  HTTP {resp.status_code} for {url}, retrying...")
        except requests.RequestException as e:
            print(f"  Request failed for {url}: {e}, retrying...")
        time.sleep(REQUEST_DELAY * (attempt + 1))
    return None


def scrape_model_page(base_name: str) -> dict:
    """Scrape an Ollama library page for model details.

    Returns a dict with keys: description, capabilities, tags (size variants),
    context_length, has_vision, has_tools, input_type.
    """
    url = f"{OLLAMA_LIBRARY_URL}/{base_name}"
    resp = _fetch_with_retry(url)
    if resp is None:
        print(f"  Could not fetch library page for '{base_name}'")
        return {}

    soup = BeautifulSoup(resp.text, "html.parser")
    result = {}

    # --- Description: try meta description first, then first paragraph ---
    meta_desc = soup.find("meta", attrs={"name": "description"})
    if meta_desc and meta_desc.get("content"):
        result["description"] = meta_desc["content"].strip()
    else:
        # Try og:description
        og_desc = soup.find("meta", attrs={"property": "og:description"})
        if og_desc and og_desc.get("content"):
            result["description"] = og_desc["content"].strip()

    # --- Capability tags: look for common tag text patterns ---
    page_text = soup.get_text(" ", strip=True).lower()
    found_capabilities = set()
    has_vision = False
    has_tools = False

    for tag_str, (cap, vision, tools) in CAPABILITY_TAG_MAP.items():
        # Look for the tag as a standalone word in page content
        # Use word boundaries to avoid false matches
        if re.search(rf"\b{re.escape(tag_str)}\b", page_text):
            if cap:
                found_capabilities.add(cap)
            if vision:
                has_vision = True
            if tools:
                has_tools = True

    if found_capabilities:
        result["capabilities"] = sorted(found_capabilities)
    # Pass through as internal keys used by enrich_model() to build the capabilities list
    result["has_vision"] = has_vision
    result["has_tools"] = has_tools

    # --- Variants table: look for rows with context and input info ---
    # The table typically has columns: Name, Size, Context, Input
    tables = soup.find_all("table")
    variants = []
    for table in tables:
        rows = table.find_all("tr")
        for row in rows:
            cells = row.find_all(["td", "th"])
            cell_texts = [c.get_text(strip=True) for c in cells]
            if len(cell_texts) >= 3:
                variants.append(cell_texts)

    # Extract context length from variants table
    for variant in variants:
        for cell in variant:
            ctx_match = re.search(r"(\d+)[Kk]", cell)
            if ctx_match:
                result["context_length"] = int(ctx_match.group(1)) * 1000
                break
        if "context_length" in result:
            break

    # Check input column for vision capability
    for variant in variants:
        for cell in variant:
            if "image" in cell.lower():
                result["has_vision"] = True
                break

    # --- Also look for context length in general page text ---
    if "context_length" not in result:
        ctx_patterns = [
            r"(\d{1,3})[Kk]\s*(?:context|ctx|token)",
            r"context\s*(?:window|length)?\s*(?:of\s*)?(\d{1,3})[Kk]",
            r"(\d{4,7})\s*(?:context|token)",
        ]
        for pattern in ctx_patterns:
            m = re.search(pattern, page_text)
            if m:
                val = int(m.group(1))
                # If it's a small number, it's in K units
                result["context_length"] = val * 1000 if val < 10000 else val
                break

    return result


# ---------------------------------------------------------------------------
# HuggingFace fallback
# ---------------------------------------------------------------------------


def fetch_huggingface_info(model_name: str) -> dict:
    """Search HuggingFace for a model and return description + provider."""
    base = _get_base_name(model_name)
    search_url = f"{HUGGINGFACE_API_URL}?search={base}&limit=3"

    resp = _fetch_with_retry(search_url)
    if resp is None:
        return {}

    try:
        models = resp.json()
    except (ValueError, KeyError):
        return {}

    if not models:
        return {}

    result = {}
    # Use the first matching result
    best = models[0]

    # Extract org/provider from modelId (e.g., "google/gemma-3-4b-it")
    model_id = best.get("modelId", "")
    if "/" in model_id:
        org = model_id.split("/")[0]
        result["provider_hint"] = org

    # Try to get description from pipeline_tag or tags
    if best.get("pipeline_tag"):
        result["pipeline_tag"] = best["pipeline_tag"]

    # The cardData field may have a description
    card_data = best.get("cardData", {})
    if isinstance(card_data, dict):
        desc = card_data.get("description") or card_data.get("model_description")
        if desc:
            result["description"] = desc.strip()

    return result


# ---------------------------------------------------------------------------
# Provider resolution
# ---------------------------------------------------------------------------


def resolve_provider(model_name: str, hf_hint: str | None = None) -> str:
    """Determine the provider for a model using the provider map and fallbacks."""
    base = _get_base_name(model_name).lower()

    # Try longest prefix match first (e.g., "command-r" before "command")
    sorted_prefixes = sorted(PROVIDER_MAP.keys(), key=len, reverse=True)
    for prefix in sorted_prefixes:
        if base.startswith(prefix):
            return PROVIDER_MAP[prefix]

    # Fallback to HuggingFace org hint
    if hf_hint:
        return hf_hint.replace("-", " ").title()

    return "Unknown"


# ---------------------------------------------------------------------------
# Parameter size normalization
# ---------------------------------------------------------------------------


def normalize_parameter_size(value) -> str | None:
    """Normalize parameterSize to a string. Handles arrays, strings, and None."""
    if value is None:
        return None
    if isinstance(value, list):
        if len(value) == 0:
            return None
        if len(value) == 1:
            return str(value[0])
        return " / ".join(str(v) for v in value)
    return str(value)


def parse_size_from_tag(model_name: str) -> str | None:
    """Extract parameter size from the model name tag, e.g., ':80b' -> '80B'.

    Also handles compound tags like '235b-instruct' -> '235B'.
    """
    _, _, tag = model_name.partition(":")
    if not tag:
        return None
    # Match a size at the start of the tag: "80b", "235b-instruct", "1t"
    m = re.match(r"^(\d+[btmk])", tag, re.IGNORECASE)
    if m:
        return m.group(1).upper()
    return None


# ---------------------------------------------------------------------------
# Enrichment pipeline
# ---------------------------------------------------------------------------


def enrich_model(model_name: str, existing_entry: dict | None = None) -> dict:
    """Build a fully enriched model entry for the given model name.

    If existing_entry is provided, it's used as the base (for --all mode
    re-enrichment or parameterSize fix).
    """
    base_name = _get_base_name(model_name)

    # Step 1: Scrape the Ollama library page
    print(f"  Scraping ollama.com/library/{base_name}...")
    scraped = scrape_model_page(base_name)
    time.sleep(REQUEST_DELAY)

    # Step 2: HuggingFace fallback if no description
    hf_info = {}
    if not scraped.get("description"):
        print(f"  No description from Ollama, trying HuggingFace...")
        hf_info = fetch_huggingface_info(model_name)
        time.sleep(REQUEST_DELAY)

    # Step 3: Resolve provider
    provider = resolve_provider(model_name, hf_info.get("provider_hint"))

    # Step 4: Build capabilities list
    capabilities = ["text-generation"]
    if scraped.get("capabilities"):
        for cap in scraped["capabilities"]:
            if cap not in capabilities:
                capabilities.append(cap)

    has_vision = scraped.get("has_vision", False)
    has_tools = scraped.get("has_tools", False)

    if has_vision and "vision" not in capabilities:
        capabilities.append("vision")
    if has_tools and "tool-use" not in capabilities:
        capabilities.append("tool-use")

    # Step 5: Description
    description = (
        scraped.get("description")
        or hf_info.get("description")
        or None
    )

    # Step 6: Parameter size
    param_size = parse_size_from_tag(model_name)

    # Step 7: Context length
    context_length = scraped.get("context_length")

    # Step 8: Build the entry — hasVision/hasTools are derived from capabilities at runtime
    entry = {
        "name": model_name,
        "displayName": generate_display_name(model_name),
        "provider": provider,
        "capabilities": capabilities,
        "description": description,
        "parameterSize": param_size,
        "quantizationLevel": None,
        "contextLength": context_length,
        "family": base_name.split("-")[0] if "-" in base_name else base_name,
    }

    # If we have an existing entry, preserve fields that we couldn't scrape
    if existing_entry:
        for key in ["quantizationLevel", "contextLength", "description", "family"]:
            if entry.get(key) is None and existing_entry.get(key) is not None:
                entry[key] = existing_entry[key]
        # Keep existing parameterSize if we couldn't determine one
        if entry["parameterSize"] is None and existing_entry.get("parameterSize") is not None:
            entry["parameterSize"] = normalize_parameter_size(existing_entry["parameterSize"])
        # Keep existing provider if resolved to Unknown
        if entry["provider"] == "Unknown" and existing_entry.get("provider", "Unknown") != "Unknown":
            entry["provider"] = existing_entry["provider"]
        # Keep existing displayName if it was manually set
        if existing_entry.get("displayName"):
            entry["displayName"] = existing_entry["displayName"]

    return entry


# ---------------------------------------------------------------------------
# Confidence reporting
# ---------------------------------------------------------------------------

def confidence_for(field: str, value, source: str) -> str:
    """Return HIGH/MEDIUM/LOW confidence label."""
    if value is None:
        return "MISSING"
    if source == "existing":
        return "EXISTING"
    if source == "scraped":
        return "MEDIUM"
    if source == "heuristic":
        return "HIGH"
    if source == "huggingface":
        return "LOW"
    return "UNKNOWN"


def print_report(new_entries: list[dict], updated_entries: list[dict]):
    """Print a human-readable enrichment report."""
    print("\n" + "=" * 70)
    print("ENRICHMENT REPORT")
    print("=" * 70)

    if new_entries:
        print(f"\n--- NEW MODELS ({len(new_entries)}) ---")
        for entry in new_entries:
            print(f"\n  {entry['name']}")
            print(f"    displayName:      {entry['displayName']}")
            print(f"    provider:         {entry['provider']}")
            print(f"    description:      {(entry.get('description') or 'MISSING')[:80]}...")
            print(f"    parameterSize:    {entry.get('parameterSize') or 'MISSING'}")
            print(f"    contextLength:    {entry.get('contextLength') or 'MISSING'}")
            print(f"    capabilities:     {entry.get('capabilities', [])}")
            print(f"    hasVision:        {entry.get('hasVision', False)}")
            print(f"    hasTools:         {entry.get('hasTools', False)}")

    if updated_entries:
        print(f"\n--- UPDATED MODELS ({len(updated_entries)}) ---")
        for entry in updated_entries:
            print(f"  {entry['name']}: parameterSize normalized")

    if not new_entries and not updated_entries:
        print("\n  No changes needed. All models are up to date.")

    print("\n" + "=" * 70)


# ---------------------------------------------------------------------------
# JSON validation
# ---------------------------------------------------------------------------


def validate_entry(entry: dict) -> list[str]:
    """Validate a model entry against the expected schema. Returns list of issues."""
    issues = []
    required_fields = ["name", "displayName", "provider", "capabilities"]

    for field in required_fields:
        if not entry.get(field):
            issues.append(f"Missing required field: {field}")

    if entry.get("capabilities") and not isinstance(entry["capabilities"], list):
        issues.append("capabilities must be an array")

    if entry.get("contextLength") is not None and not isinstance(entry["contextLength"], int):
        issues.append("contextLength must be an integer or null")

    if entry.get("hasVision") is not None and not isinstance(entry["hasVision"], bool):
        issues.append("hasVision must be a boolean or null")

    if entry.get("hasTools") is not None and not isinstance(entry["hasTools"], bool):
        issues.append("hasTools must be a boolean or null")

    if entry.get("parameterSize") is not None and not isinstance(entry["parameterSize"], str):
        issues.append(f"parameterSize must be a string or null, got {type(entry['parameterSize']).__name__}")

    return issues


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="Auto-enrich model_details.json with data from ollama.com"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would change without modifying the JSON file",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Re-enrich all models, not just new ones",
    )
    args = parser.parse_args()

    # --- Load existing JSON ---
    if not JSON_PATH.exists():
        print(f"ERROR: model_details.json not found at {JSON_PATH}")
        sys.exit(1)

    with open(JSON_PATH) as f:
        data = json.load(f)

    existing_models = data.get("models", [])
    existing_by_name = {m["name"]: m for m in existing_models}
    print(f"Loaded {len(existing_models)} existing model entries from {JSON_PATH.name}")

    # --- Discover models from Ollama cloud API ---
    try:
        api_models = fetch_ollama_models()
    except requests.RequestException as e:
        print(f"ERROR: Failed to fetch models from Ollama API: {e}")
        sys.exit(1)

    # --- Determine which models need enrichment ---
    if args.all:
        models_to_enrich = api_models
        print(f"Re-enriching all {len(models_to_enrich)} models (--all flag)")
    else:
        models_to_enrich = [m for m in api_models if m not in existing_by_name]
        print(f"Found {len(models_to_enrich)} new models to enrich")

    # --- Fix parameterSize on all existing entries ---
    updated_entries = []
    for model in existing_models:
        old_val = model.get("parameterSize")
        if isinstance(old_val, list):
            model["parameterSize"] = normalize_parameter_size(old_val)
            updated_entries.append(model)
            print(f"  Fixed parameterSize for {model['name']}: {old_val} -> {model['parameterSize']}")

    # --- Enrich new/all models ---
    new_entries = []
    # Track base names we've already scraped to avoid re-scraping variants
    scraped_bases = {}

    for i, model_name in enumerate(models_to_enrich, 1):
        print(f"\n[{i}/{len(models_to_enrich)}] Enriching: {model_name}")
        existing = existing_by_name.get(model_name)

        base = _get_base_name(model_name)

        # Scrape base page only once for models that share the same base
        if base not in scraped_bases:
            entry = enrich_model(model_name, existing)
            scraped_bases[base] = entry
        else:
            # Reuse scraped data from the same base model
            print(f"  Reusing scraped data from {base}")
            base_entry = scraped_bases[base]
            entry = {
                **base_entry,
                "name": model_name,
                "displayName": generate_display_name(model_name),
                "parameterSize": parse_size_from_tag(model_name) or base_entry.get("parameterSize"),
            }
            # Preserve existing entry fields if available
            if existing:
                for key in ["quantizationLevel", "contextLength", "description", "family"]:
                    if entry.get(key) is None and existing.get(key) is not None:
                        entry[key] = existing[key]
                if existing.get("displayName"):
                    entry["displayName"] = existing["displayName"]
                if entry["provider"] == "Unknown" and existing.get("provider", "Unknown") != "Unknown":
                    entry["provider"] = existing["provider"]
                if entry["parameterSize"] is None and existing.get("parameterSize") is not None:
                    entry["parameterSize"] = normalize_parameter_size(existing["parameterSize"])

        # Validate
        issues = validate_entry(entry)
        if issues:
            print(f"  WARNING: Validation issues for {model_name}:")
            for issue in issues:
                print(f"    - {issue}")

        new_entries.append(entry)

    # --- Report ---
    print_report(new_entries, updated_entries)

    if args.dry_run:
        print("\n[DRY RUN] No files were modified.")
        return

    # --- Merge and write ---
    if not new_entries and not updated_entries:
        print("\nNo changes to write.")
        return

    # Build final model list: existing (with fixes) + new entries
    final_names = set()
    final_models = []

    # Add existing models (with parameterSize fixes applied in-place)
    for model in existing_models:
        final_names.add(model["name"])
        final_models.append(model)

    # Add new models (skip if already exists, e.g., in --all mode replace)
    for entry in new_entries:
        if entry["name"] in final_names:
            if args.all:
                # Replace existing entry
                final_models = [m if m["name"] != entry["name"] else entry for m in final_models]
        else:
            final_models.append(entry)
            final_names.add(entry["name"])

    output = {"models": final_models}
    with open(JSON_PATH, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"\nWrote {len(final_models)} models to {JSON_PATH.name}")
    print(f"  {len(new_entries)} new, {len(updated_entries)} parameterSize fixes")


if __name__ == "__main__":
    main()
