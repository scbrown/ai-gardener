---
title: "Hello, World"
description: "First post on AI Gardener — a blog about using generative AI to write code."
pubDate: 2026-02-09
---

Welcome to AI Gardener. This blog explores the practice of using generative AI tools to write software.

## What to expect

Posts here will cover:

- Prompting strategies that produce better code
- When AI-assisted coding helps and when it gets in the way
- Practical workflows for integrating LLMs into development

## A quick example

Here's a Python snippet that an LLM might generate:

```python
def fibonacci(n: int) -> list[int]:
    """Return the first n Fibonacci numbers."""
    if n <= 0:
        return []
    seq = [0, 1]
    while len(seq) < n:
        seq.append(seq[-1] + seq[-2])
    return seq[:n]
```

Simple enough, but the interesting questions are about the conversation that led to it.

More soon.
