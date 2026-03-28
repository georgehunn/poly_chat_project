# Model Details Management

This document explains how to manage model details in the Open Chat application.

## Overview

The application uses a local JSON file (`model_details.json`) to store comprehensive information about AI models. This file is used as a fallback when the Ollama API is unavailable or when specific model details are not returned by the API.

## File Location

The model details file is located at:
```
open_chat/Resources/model_details.json
```

## Structure

The JSON file contains an array of model objects with the following properties:

- `name`: The internal model name (required)
- `displayName`: Human-readable model name (required)
- `provider`: Model provider (e.g., "Ollama")
- `capabilities`: Array of capabilities (e.g., ["text-generation"])
- `description`: Detailed description of the model
- `parameterSize`: Size of the model parameters (e.g., "8B", "70B")
- `quantizationLevel`: Quantization level (e.g., "Q4_K_M")
- `family`: Model family (e.g., "llama3")
- `contextLength`: Maximum context length in tokens
- `hasVision`: Boolean indicating vision capability
- `hasTools`: Boolean indicating tool usage capability

## Updating Model Details

To update model information:

1. Open `open_chat/Resources/model_details.json` in a text editor
2. Modify existing entries or add new model objects to the `models` array
3. Ensure all required fields are present
4. Validate the JSON syntax
5. Commit the changes to version control

## Example Entry

```json
{
  "name": "llama3",
  "displayName": "Llama 3",
  "provider": "Ollama",
  "capabilities": ["text-generation"],
  "description": "Meta's Llama 3 is a collection of state-of-the-art multilingual large language models...",
  "parameterSize": "8B",
  "quantizationLevel": "Q4_K_M",
  "family": "llama3",
  "contextLength": 8192,
  "hasVision": false,
  "hasTools": true
}
```

## Best Practices

1. Keep descriptions concise but informative
2. Use consistent naming conventions
3. Verify technical specifications are accurate
4. Update the file when new models are added to your Ollama installation
5. Regularly review and update model information as needed