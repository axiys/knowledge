#!/bin/bash

# --- SETTINGS ---
PDF_DIR="fincrime"
MD_DIR="fincrime"
QNA_FILE="fincrime/qna.yaml"

# Ensure output directory exists
mkdir -p "$MD_DIR"

# 🧹 Clean up old Markdown files
echo "🧹 Cleaning up old Markdown files in $MD_DIR"
rm -f "$MD_DIR"/*.md

# 📄 Convert and clean
for pdf in "$PDF_DIR"/*.pdf; do
  base=$(basename "${pdf%.pdf}")
  temp_txt="$MD_DIR/$base.temp.txt"
  clean_txt="$MD_DIR/$base.cleaned.txt"
  md_output="$MD_DIR/$base.md"

  echo "📄 Converting $pdf -> $md_output"

  pdftotext "$pdf" "$temp_txt"

  sed -e 's/ﬁ/fi/g' \
      -e 's/ﬂ/fl/g' \
      -e 's/ﬀ/ff/g' \
      -e 's/ﬃ/ffi/g' \
      -e 's/ﬄ/ffl/g' \
      -e 's/PLU//g' \
      -e 's/FF//g' \
      -e 's/[^[:print:]\t\r\n]//g' "$temp_txt" > "$clean_txt"

  pandoc "$clean_txt" -f markdown_strict -t markdown -o "$md_output"

  rm -f "$temp_txt" "$clean_txt"
done

# 📝 Update patterns in qna.yaml
echo "📝 Updating $QNA_FILE"

# Collect all markdown file paths into a tmp patterns file
patterns_tmp=$(mktemp)
find "$MD_DIR" -type f -name "*.md" | sort | sed 's|^|    - |' > "$patterns_tmp"

# Rewrite YAML with injected patterns block
tmp_yaml=$(mktemp)

awk -v pat="$patterns_tmp" '
  BEGIN {
    while ((getline line < pat) > 0) {
      pattern_lines[++n] = line
    }
    close(pat)
  }
  {
    if (/^\s*patterns:/) {
      print "  patterns:"
      in_patterns = 1
      next
    }

    if (in_patterns) {
      if ($0 ~ /^\s*-/) {
        next  # skip old pattern lines
      } else {
        for (i = 1; i <= n; i++) print pattern_lines[i]
        in_patterns = 0
      }
    }
    print
  }
' "$QNA_FILE" > "$tmp_yaml" && mv "$tmp_yaml" "$QNA_FILE"
rm -f "$patterns_tmp"

echo "✅ All PDFs converted, cleaned, and qna.yaml updated!"
