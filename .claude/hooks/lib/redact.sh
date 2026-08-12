#!/usr/bin/env bash
# redact.sh — hash + redact sensitive text before it is ever written to disk.
#
# Journey events may carry raw prompt text, tool args, or tool output — any of
# which could contain a PAN, a CVV, a bearer token, or other cardholder/secret
# data pasted or generated during a live payments lab. We NEVER want that raw
# text landing in .claude/journey/*.jsonl, which is a plain, unencrypted,
# committable file. So every "*_text" field is:
#   1. hashed (SHA-256, first 16 hex chars) — stable enough to compare across
#      events without revealing content
#   2. reduced to a short, further-redacted preview — enough for a facilitator
#      to sanity-check the journey log without ever seeing a real PAN/CVV
#
# No python dependency (lab prereqs are Java + Maven, "no other tooling").

_sha256_16() {
    local text="$1" digest=""
    if command -v sha256sum >/dev/null 2>&1; then
        digest=$(printf '%s' "$text" | sha256sum | cut -c1-16)
    elif command -v shasum >/dev/null 2>&1; then
        digest=$(printf '%s' "$text" | shasum -a 256 | cut -c1-16)
    elif command -v openssl >/dev/null 2>&1; then
        digest=$(printf '%s' "$text" | openssl dgst -sha256 | sed 's/^.*= //' | cut -c1-16)
    else
        # Last-resort, non-cryptographic fallback so recording never hard-fails.
        digest="nohash_$(printf '%s' "$text" | cksum | cut -d' ' -f1)"
    fi
    printf '%s' "$digest"
}

# redact_preview <text> <max_chars>
# A short preview with obvious cardholder-data shapes masked outright, on top
# of the truncation. This is defense in depth on top of the hash — the preview
# is for human skimming, the hash is the durable comparison key.
redact_preview() {
    local text="$1" max="${2:-80}"
    printf '%s' "$text" \
        | tr '\n\r\t' '   ' \
        | sed -E \
            -e 's/[0-9]{13,19}/[REDACTED-PAN]/g' \
            -e 's/\b[0-9]{3,4}\b/[REDACTED-CVV?]/g' \
            -e 's/(Bearer|bearer)[[:space:]]+[A-Za-z0-9._-]+/[REDACTED-TOKEN]/g' \
        | cut -c "1-${max}"
}

# redact_field <label> <raw_text>
# Emits one JSON object fragment (no surrounding braces) for a *_text field:
#   "<label>_hash": "...", "<label>_preview": "...", "<label>_len": N
# Caller is responsible for splicing this into the event JSON.
redact_field() {
    local label="$1" raw="$2" hash preview len
    hash=$(_sha256_16 "$raw")
    preview=$(redact_preview "$raw" 80)
    len=${#raw}
    printf '"%s_hash":"%s","%s_preview":"%s","%s_len":%d' \
        "$label" "$hash" \
        "$label" "$(json_escape "$preview")" \
        "$label" "$len"
}
