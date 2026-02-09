# AI Gardener blog tasks

# Create a new blog post with an interactive walkthrough
post:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🌱 New blog post"
    echo ""

    # Slug
    read -rp "URL slug (e.g. my-cool-post): " slug
    if [[ -z "$slug" ]]; then
        echo "Slug is required." >&2
        exit 1
    fi

    filepath="src/content/blog/${slug}.md"
    if [[ -f "$filepath" ]]; then
        echo "Post already exists: $filepath" >&2
        exit 1
    fi

    # Title
    read -rp "Title: " title
    if [[ -z "$title" ]]; then
        echo "Title is required." >&2
        exit 1
    fi

    # Description
    read -rp "Description (1-2 sentences for the listing page): " description
    if [[ -z "$description" ]]; then
        echo "Description is required." >&2
        exit 1
    fi

    # Date
    today=$(date +%Y-%m-%d)
    read -rp "Publish date [$today]: " pubdate
    pubdate="${pubdate:-$today}"

    # Draft?
    read -rp "Start as draft? (y/N): " is_draft
    draft="false"
    if [[ "$is_draft" =~ ^[Yy] ]]; then
        draft="true"
    fi

    # Create the file
    cat > "$filepath" <<EOF
---
title: "${title}"
description: "${description}"
pubDate: ${pubdate}
draft: ${draft}
---

Write your post here.
EOF

    echo ""
    echo "✅ Created: $filepath"
    nvim "$filepath"

    git add "$filepath"
    git commit -m "Add post: ${slug}"
    git push

# Start the dev server
dev:
    npm run dev

# Build the site
build:
    npm run build

# Preview the production build locally
preview:
    npm run build && npm run preview
