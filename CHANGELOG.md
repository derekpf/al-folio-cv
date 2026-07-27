# Changelog

## 1.0.1

- Sort experience, volunteering, and education entries by date instead of rendering them in source order, so volunteering is no longer always appended after work history (#3, ports `alshedivat/al-folio#3272`). Ordering is handled by the new `al_cv_sort_by_date` Liquid filter, which understands both RenderCV and JSONResume key names, partial dates (`2020`, `2020-06`), YAML date objects, textual `present` end dates, and undated entries.
- Strip captured dates and locations in the experience and education entry templates (#2, ports `alshedivat/al-folio#3537`). An entry with no end date now renders `Present` instead of a dangling separator, an entry with no dates renders no date badge, and an entry with no location no longer renders a location row containing just the map pin icon.

## 1.0.0

- Initial CV extraction from `al_folio_core`.
