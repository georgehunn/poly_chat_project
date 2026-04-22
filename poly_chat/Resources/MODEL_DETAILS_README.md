# Model Details Management

This document explains how `model_details.json` works and how to keep it up to date when new models appear on the Ollama cloud API.

## Overview

The app uses `model_details.json` to enrich model information that the Ollama API doesn't provide — descriptions, provider names, full capability lists, context lengths, and display names. When a model is fetched from the API but has no entry in this file, it appears with generic placeholder data in the UI.

## File Location

```
poly_chat/Resources/model_details.json
```

This file is **bundled into the app at build time**. Any changes only take effect after a rebuild and re-run.

## Schema

Each model entry contains:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | ✓ | Exact name as returned by the Ollama API (e.g. `"qwen3-coder:80b"`) |
| `displayName` | string | ✓ | Human-readable label shown in the UI (e.g. `"Qwen 3 Coder 80B"`) |
| `provider` | string | ✓ | Model creator (e.g. `"Alibaba"`, `"Google"`, `"Mistral"`) |
| `capabilities` | string[] | ✓ | Features the model supports — see capability values below |
| `description` | string \| null | | One or two sentence summary shown in the Model Details view |
| `parameterSize` | string \| null | | Parameter count as a string (e.g. `"80B"`, `"671B"`, `"120B (12B active)"`) |
| `quantizationLevel` | string \| null | | Quantization format (e.g. `"BF16"`, `"INT4"`, `"FP8"`) |
| `contextLength` | integer \| null | | Maximum context window in tokens (e.g. `131072`) |
| `family` | string \| null | | Model family identifier (e.g. `"qwen3-coder"`, `"gemma"`) |
| `hasVision` | boolean \| null | | `true` if the model can process images |
| `hasTools` | boolean \| null | | `true` if the model supports tool/function calling |

### Capability values

The `capabilities` array is a **positive list** — only include what the model actually supports:

| Value | Meaning |
|---|---|
| `"text-generation"` | Standard text output — include on all models |
| `"vision"` | Image understanding |
| `"multimodal"` | Mixed-media (image + text) as primary use case |
| `"tool-use"` | Tool / function calling |
| `"function-calling"` | Alias for `tool-use` (older models) |
| `"code"` | Strong code generation focus |
| `"reasoning"` | Extended chain-of-thought / thinking mode |
| `"audio"` | Audio understanding or generation |
| `"embedding"` | Produces vector embeddings |
| `"agentic"` | Designed for autonomous multi-step task execution |

---

## Keeping model data up to date

### When to run

Run the enrichment script whenever:
- You notice a new model in the app that shows no description or provider
- You want to proactively check whether new models have been added to the Ollama cloud API
- A periodic refresh (e.g. monthly) to pick up new additions

### Setup (one-time)

```bash
# From the repo root
pip install -r scripts/requirements.txt
```

### Workflow

**Step 1 — Preview what's new**

```bash
python scripts/enrich_model_details.py --dry-run
```

This fetches the current Ollama cloud model list, diffs it against `model_details.json`, and prints a report. No files are changed.

Example output:
```
Found 3 new models to enrich

--- NEW MODELS (3) ---
  gemma5:9b
    displayName:  Gemma 5 9B
    provider:     Google
    description:  Google's latest efficient open model...
    contextLength: 128000
    capabilities: ['text-generation', 'vision', 'tool-use']
```

**Step 2 — Enrich and review**

```bash
python scripts/enrich_model_details.py
```

This runs the same process but writes the new entries to `model_details.json`. Review the printed report and spot-check entries that are flagged as missing a description or parameter size — these may need a manual edit.

**Step 3 — Edit if needed**

Open `poly_chat/Resources/model_details.json` and fix any entries that the scraper couldn't fully populate. Common cases:
- MoE models where parameter size needs the active count (e.g. `"120B (12B active)"`)
- Models with non-standard names that didn't match a provider in the map
- Descriptions that are too long or generic

**Step 4 — Rebuild**

Build and run the app in Xcode. The new entries are now bundled and will appear in the Models view with full detail.

**Step 5 — Commit**

```bash
git add poly_chat/Resources/model_details.json
git commit -m "model-data: add [model names] from Ollama cloud"
```

### Re-enriching existing entries

If you want to refresh scraped fields for all models (e.g. after a model's library page was updated):

```bash
python scripts/enrich_model_details.py --all
```

> **Note:** `--all` will overwrite scraped fields but preserve manually set fields like `quantizationLevel` if the scraper returns null.

---

## Manual entries

To add a model manually:

1. Open `poly_chat/Resources/model_details.json`
2. Add a new object to the `models` array, following the schema above
3. Validate JSON syntax (Xcode will catch parse errors at build time)
4. Rebuild

Example:
```json
{
  "name": "llama4:70b",
  "displayName": "Llama 4 70B",
  "provider": "Meta",
  "capabilities": ["text-generation", "vision", "tool-use"],
  "description": "Meta's latest open model with strong multilingual and vision capabilities.",
  "parameterSize": "70B",
  "quantizationLevel": "BF16",
  "contextLength": 128000,
  "family": "llama4",
  "hasVision": true,
  "hasTools": true
}
```

## Best practices

- `parameterSize` should always be a **string**, not a number or array — the Swift parser reads it as `as? String`
- `contextLength` should be the full token count as an **integer** (e.g. `131072`, not `"131K"`) — the app formats the display
- Keep descriptions to 1–2 sentences; the UI truncates to ~100 chars in list rows
- The `name` field must exactly match what the Ollama API returns — copy it from the dry-run output
