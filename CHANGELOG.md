# Changelog

## 1.0.2

- Render a date badge for CV entries that carry a single point-in-time `date` instead of a `start_date`/`end_date` pair (ports `alshedivat/al-folio#3339`). `al_cv_sort_by_date` has understood a bare `date` since 1.0.1, so such entries were already being ordered by it while the templates dropped the badge without any warning. The experience and education templates now fall back to `date` (and the JSONResume `releaseDate`) when no start date is set, rendering it as a single year — a standalone date is a point in time, so it is never labelled `Present`. An explicit `start_date`/`startDate` still wins, and closed ranges render exactly as before.
- Render dates in the projects section, which previously rendered none at all (`alshedivat/al-folio#3339`). Projects now accept the same inputs as the other sections — a `start_date`/`end_date` pair, its `startDate`/`endDate` camelCase equivalent, or a bare `date` — and gain a date badge column when any of them is set. Undated projects keep their existing full-width markup.
- Strip the captured date in the awards and publications templates, so an entry with no date no longer renders an empty badge and no longer leaves stray whitespace inside a populated one. This is the same `capture`-keeps-its-whitespace bug fixed for experience and education in 1.0.1.

## 1.0.1

- Sort experience, volunteering, and education entries by date instead of rendering them in source order, so volunteering is no longer always appended after work history (#3, ports `alshedivat/al-folio#3272`). Ordering is handled by the new `al_cv_sort_by_date` Liquid filter, which understands both RenderCV and JSONResume key names, partial dates (`2020`, `2020-06`), YAML date objects, textual `present` end dates, and undated entries.
- Strip captured dates and locations in the experience and education entry templates (#2, ports `alshedivat/al-folio#3537`). An entry with no end date now renders `Present` instead of a dangling separator, an entry with no dates renders no date badge, and an entry with no location no longer renders a location row containing just the map pin icon.

## 1.0.0

- Initial CV extraction from `al_folio_core`.
