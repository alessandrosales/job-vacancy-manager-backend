# ATS Resume Template — Reference

This file defines the canonical structure used by `Resume::MarkdownCompiler` when generating
ATS-optimised resumes. Editing this file changes what the LLM receives as its formatting
instructions on every subsequent compilation.

---

## Template structure

The English labels below (e.g. "Professional Summary", "Present", "Target role") describe **shape only**.
At generation time the compiler injects the **exact** `##` titles, "current job" word, remote/on-site
words, and target-role label for `en`, `pt_br`, or `es`. The model must copy those injected strings
character-for-character — never keep English headings when the resume language is Portuguese or Spanish.

```
# {Full Name}

{email} | {phone} | {age when available — label in output language, e.g. "Idade: 34" for pt_br}
{full street address / city / country — one line; omit the line if not provided}

{each reference link on its own line, OR separated by " · ": paste the full URL as plain text only — no [label](url) markdown}
{example: https://www.linkedin.com/in/example  |  https://github.com/example}

{target role line — prefix + role name exactly as injected for this request, e.g. "Cargo pretendido: Consultor" for pt_br}
{omit this line only if no role is linked}

---

## Professional Summary   ← illustrative; use injected localized title in output

{2–5 sentence professional summary. Align with the resume title and description; mention the target role when provided. Write in third person or first person — keep it consistent. No buzzwords; lead with concrete, quantifiable value where possible.}

---

## Work Experience

### {Job Title} — {Company Name}{  · {Remote} | · {On-site} | · {Hybrid} — use injected locale words}
*{Start Month Year} – {End Month Year | localized "current" word from prompt, e.g. Atual / Actual / Present}*

- {Achievement or responsibility 1 — use strong action verbs; quantify when possible}
- {Achievement or responsibility 2}
- {Achievement or responsibility 3}

*(Repeat the block above for each work experience, most-recent first.)*

---

## Education

### {Degree} in {Field of Study}
**{Institution Name}** | *{Start Month Year} – {End Month Year | Present}*

*(Repeat for each education entry, most-recent first.)*

---

## Certifications

- **{Certification Name}** | *{Start Month Year} – {End Month Year | Present}*

*(Repeat for each certification. Omit this section entirely if there are no certifications.)*

---

## Skills

{skill_1}, {skill_2}, {skill_3}, …

*(List all skills as a comma-separated single line or a short grouped list. Omit this section
entirely if there are no skills.)*
```

---

## ATS formatting rules (do not deviate)

1. **No tables, no columns** — ATS parsers reject multi-column layouts.
2. **Section headings** — use exactly the `##` strings injected for this resume's language (see compiler prompt). Do not reorder sections relative to that list; omit a `##` block entirely when that section has no data.
3. **Bullet points for work experience** — use `-` (hyphen + space). Do not use `*` or `•`.
4. **Dates as abbreviated month + year** — use month abbreviations in the output language (see compiler). For an open-ended range, use only the injected "current" word (e.g. Atual, Actual, Present).
5. **No icons, emojis, decorative separators** — the `---` horizontal rule is acceptable only between the header block and the first `##` body section.
6. **Header block (only)** — plain text: email, phone, age (if provided in source data), address (if provided), profile URLs (full `https://…` as plain text, never markdown link syntax), and the **target role** line using exactly the Role name supplied for this resume. Email and phone may share the first line with pipes. Links must not use `[text](url)` — ATS-friendly plain URLs only.
7. **Language output** — every visible word (all `##` and `###` titles, month names, "current" date word, remote/on-site, target-role label, body text) must be in the resume's preferred language. Never mix English into a Portuguese or Spanish document.
8. **Omit empty segments** — if age, address, links, or role are missing in the source data, omit that line or segment; do not invent placeholders beyond what the template allows.
9. **Preserve all factual data** — do not invent, infer, or omit any employer name, date, degree, certification, skill, URL, or role name that is provided in the source data.
10. **Consistent tone** — professional, active voice throughout.
