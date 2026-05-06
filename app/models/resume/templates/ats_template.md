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

{all reference links on a single horizontal line — full URLs separated by " · " (space + middle dot + space), same spirit as pipes on the contact line; paste each URL as plain text only — no [label](url) markdown}
{example: https://www.linkedin.com/in/example · https://github.com/example · https://example.com}

(blank line — exactly one empty line before the target role, so it sits visually below contact/links)

{target role line — prefix + role name exactly as injected for this request, e.g. "Cargo pretendido: Consultor" for pt_br}
{omit this line only if no role is linked}

---

## Professional Summary   ← illustrative; use injected localized title in output

{2–5 sentence professional summary. Align with the resume title and description; mention the target role when provided. Write in third person or first person — keep it consistent. No buzzwords; lead with concrete, quantifiable value where possible.}

---

## Work Experience

### {Job Title} — {Company Name}{  · {Remote} | · {On-site} | · {Hybrid} — use injected locale words}
*{Start Month Year} – {End Month Year | localized "current" word from prompt, e.g. Atual / Actual / Present}*

{Plain paragraphs only (no `-` bullets, no `*` lists) for this role: the database field `work_experiences.description` is passed in SOURCE DATA per job. When it is **non-empty**, rewrite it as **continuous prose** in the OUTPUT LANGUAGE — typically one or two short paragraphs separated by one blank line. Preserve every substantive fact; improve clarity and word choice; weave in alignment with the target role only when grounded in that text (or linked skills when description is sparse). When description is **empty / not provided**, write one concise paragraph grounded only in job title, employer, dates, arrangement, and skills. Do **not** use bullet lists under work experience headings. }

{Body = normal Markdown paragraphs (no list markers). Typically one paragraph; add a second separated by a blank line only if the SOURCE description is dense. Each paragraph: full sentences, professional tone.}

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

*(One comma-separated line. Names must match **exactly** the skills linked to this resume in the database (`resume_skills`) — not skills copied from jobs or inferred from narratives. Omit this section if there are zero resume-linked skills.)*
```

---

## ATS formatting rules (do not deviate)

1. **No tables, no columns** — ATS parsers reject multi-column layouts.
2. **Section headings** — use exactly the `##` strings injected for this resume's language (see compiler prompt). Do not reorder sections relative to that list; omit a `##` block entirely when that section has no data.
3. **Work experience body text** — use **plain paragraphs only** under each job (normal line breaks and blank lines between paragraphs). Do **not** use `-`, `*`, numbering, or `•` lists for responsibilities and achievements within "## Work Experience". (Certifications may still use the hyphen line pattern defined below for that section.)
4. **Dates as abbreviated month + year** — use month abbreviations in the output language (see compiler). For an open-ended range, use only the injected "current" word (e.g. Atual, Actual, Present).
5. **No icons, emojis, decorative separators** — the `---` horizontal rule is acceptable only between the header block and the first `##` body section.
6. **Header block (only)** — plain text: email, phone, age (if provided in source data), address (if provided), profile URLs (full `https://…` as plain text, never markdown link syntax), and the **target role** line using exactly the Role name supplied for this resume. Email and phone may share the first line with pipes. **All profile URLs go on one line**, separated by ` · ` — not one URL per line. Links must not use `[text](url)` — ATS-friendly plain URLs only. **Before the target role line**, insert **exactly one blank line** after the last contact/address/URL line (visual separation; no `---` here).
7. **Language output** — every visible word (all `##` and `###` titles, month names, "current" date word, remote/on-site, target-role label, body text) must be in the resume's preferred language. Never mix English into a Portuguese or Spanish document.
8. **Omit empty segments** — if age, address, links, or role are missing in the source data, omit that line or segment; do not invent placeholders beyond what the template allows.
9. **Preserve all factual data** — do not invent, infer, or omit any employer name, date, degree, certification, skill, URL, role name, or **work-experience `description` text** that is provided in the source data. For work experience **prose**, you may rephrase and emphasise themes relevant to the target role only when defensible from the stored description (when present), else from job title, company, skills, and dates—never invent tools, metrics, clients, or outcomes.
10. **Consistent tone** — professional, active voice throughout.
11. **Work experience prose** — when `description` is populated for a job, it is the primary source for that job's paragraphs; when it is absent, write a short factual paragraph only from title, employer, dates, and arrangement (do not infer a skills catalogue for this §). Never switch to bullet lists for this section.
12. **Coverage** — when the compiler lists numbered fragments from a job's stored description, reflect **every** fragment's meaning in your prose for that role (same facts; smoother wording). Emphasise or order ideas toward the resume's linked **target role** only where the description honestly supports it.
13. **Skills comma line** — list **only** names from the resume ↔ skills join (`resume_skills`). Do not harvest extra labels from experience prose, certifications, or free text. Mentions inside job paragraphs are narrative only unless that keyword is already a resume-linked skill.
