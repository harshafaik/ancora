# TODO

## On-Device AI
- [ ] Implement on-device crux generation using `flutter_gemma` or `mediapipe_genai`.
- [ ] Handle large model file (1.5GB+) downloading and management.
- [ ] Optimize inference for mobile GPUs.
- [ ] Fix dependency conflicts and API mismatches in the `flutter_gemma` package integration.

## Roadmap: The Ancora Experience

### Layer 1 — Article Level (V1 Scope Expansion)
- [ ] **Concept Nudges**: Identify unexplained concepts (e.g., fiscal deficit, FII, reverse repo) within an article.
- [ ] **Subtle Indicators**: Add non-intrusive UI cues that allow users to optionally "unpack" these concepts without leaving the reading context.

### Layer 2 — Reading Companion (V2)
- [ ] **Thinking Partner Mode**: Implement a conversational interface scoped strictly to the current article.
- [ ] **Context-Aware Chat**: Ensure the AI uses the full article text as primary context.
- [ ] **Intellectual Friction**: Logic to flag opposing viewpoints for opinion pieces and highlight contested facts for news pieces.

### Layer 3 — Memory (V3)
- [ ] **Local RAG Layer**: Implement local vector embeddings for everything the user has read.
- [ ] **Knowledge Delta**: Automatically surface relevant context from history (e.g., "You read about this three weeks ago, here's what was different then").
- [ ] **Temporal Nudges**: Notifications or indicators highlighting how new information connects to or contradicts previous reading history.
