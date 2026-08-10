# Code review notes

Per-repo guidance for reviewers (human and Arby). The shared rubric — what counts as a finding, the P0–P3
severities — lives in [rinsed-org/review-bot-workflows](https://github.com/rinsed-org/review-bot-workflows);
this file adds only what is specific to this repo.

## What this repo is

A **fork of [thoughtbot/administrate](https://github.com/thoughtbot/administrate)**, not a standalone
project. The `rinsed-v0.17.0` branch is upstream's `v0.17.0` tag plus our patches, and it is what the Rinsed
app's `Gemfile` points at. Two consequences drive most of the review:

- **Divergence is a liability.** Every line we change is a line to re-apply when we rebase onto a newer
  upstream release. The diff against `v0.17.0` is currently ~50 files; keeping it small and legible is a
  goal in itself.
- **This is a published API.** The Rinsed app calls into these classes and overrides these views. Changing
  or removing something the app might use is a breaking change made in a different repo than the one that
  breaks.

## Fork discipline

- **Mark every divergence in an upstream-owned file.** Wrap it in `# RINSED: <why>` … `# END RINSED`
  comments so the next rebase can find it. A change to an upstream file with no marker is a finding.
  (Existing markers are inconsistent — both `# RINSED END` and `# END RINSED` appear, and some blocks have
  no closer. Prefer `# END RINSED` for new code; don't churn the old ones.)
- **Prefer additive over rewritten.** New behavior should be a new method with an upstream-compatible
  default rather than an edit to upstream logic. `Field::Base.search_exact?` (default `false`) and
  `search_lower?` (default `true`) are the model: dashboards that don't opt in behave exactly as upstream.
  A change that alters default behavior for existing dashboards without an explicit opt-in is a finding —
  it will silently change the admin UI for every resource in the app.
- **New specs go in `spec/rinsed/`**, mirroring the upstream path (e.g.
  `spec/rinsed/lib/administrate/order_spec.rb`). Editing upstream spec files creates rebase conflicts;
  only do it when the upstream expectation itself is now wrong, and mark it.
- Comments like `# TODO: Upstream this` are meaningful here — flag Rinsed-only behavior that looks
  generally useful and could go upstream instead of living in the fork forever.

## Raw SQL: `lib/administrate/search.rb` and `lib/administrate/order.rb`

These two files build **SQL by string interpolation** and hand it to `Arel.sql`, which explicitly tells
Rails "trust me, this is safe." They are the highest-risk code in the repo and both carry Rinsed patches.
On any diff touching them, check:

- **The search term stays a bound parameter.** It is passed as `?` with values supplied separately
  (`query_values`). A term reaching the SQL string itself — even via `sanitize`, even "just for a cast" —
  is a **P0**.
- **Interpolated identifiers stay behind their guards.** `Order#attribute` and `#direction` come straight
  from `params`; the interpolated string is only safe because `sanitize_direction` allowlists
  `asc`/`desc`, and because the query is executed only when `attribute` matches `relation.columns_hash` or
  a real `reflect_on_association`. In `Search`, identifiers come from dashboard-declared attributes. A new
  interpolation that isn't behind one of those guards, or a change that lets the built SQL execute without
  the `columns_hash` check, is a **P0**.
- **`search_skip_cast` changes the SQL shape.** Skipping the `CAST(... AS CHAR(256))` means the column's
  real type reaches the comparison, so a non-text column can now raise or coerce differently, and
  `search_lower?` interacts with it. Changes here want a spec covering the skip-cast × exact × lower
  combinations, which `spec/lib/administrate/search_spec.rb` already exercises.
- **Search runs against production-sized tables.** The whole point of `search_exact` was letting an indexed
  column be searched without a `LIKE '%…%'` full scan. Flag changes that reintroduce a leading-wildcard or
  a cast on a column that was deliberately exempted.

## Public surface the Rinsed app depends on

Treat these as API. Removing one, narrowing its visibility, or changing its signature breaks the app at
runtime with nothing in this repo's CI to catch it:

- `Administrate::Field::Base` / `Field::Deferred` class methods, including the Rinsed
  `search_skip_cast?` / `search_exact?` / `search_lower?` trio and their `options.fetch` keys — those keys
  are typed by hand in the app's dashboards.
- `Administrate::Page::Form#dashboard` (public here, private upstream) and `#attributes_for`.
- `Administrate::Page::Collection`'s `collection_attributes:` option.
- `Administrate::Field::HasMany#collection_partial` and `#associated_collection`.
- `Administrate::Punditize` — it depends on Pundit internals (`Pundit::Authorization`,
  `Pundit::PolicyFinder`, the `@_pundit_policy_scoped` ivar) that Pundit can rename in a minor release.
- **View partials and their locals.** Host apps override partials by path, so renaming one or changing the
  locals passed to it (e.g. `_collection.html.erb`, `fields/has_many/_show.html.erb`) breaks overrides in
  the app silently. Flag changes to partial names, local names, and the i18n keys built in them — including
  the `resource_name.gsub("/", "__")` namespacing, which the app's locale files are keyed to.

## What CI does and does not cover

CI (`.github/workflows/main.yml`) runs exactly one job: **Ruby 3.1, the root `Gemfile`, Postgres 14,
`bundle exec rspec`**. So don't duplicate "this spec fails" — but *do* flag what CI cannot see:

- **The Rails version matrix is not run.** `Appraisals` declares `rails60`, `rails61`, and `rails70`, and
  `gemfiles/` has locks for each, but no CI job uses them. Code relying on an API added in a newer Rails —
  or removed in an older one — will pass CI and break a consumer. Call it out.
- **No linter.** There is no RuboCop config and no lint step; style regressions are on review.
- **`bundler:audit` is not run by CI.** It is wired into `rake default`, which CI does not invoke.
- **JS is untested.** `app/assets/javascripts/` has no test coverage at all, and we've already diverged
  there: `jquery_ujs` is removed from the asset manifest (three feature specs are skipped as a result, with
  `RINSED:` notes) and selectize is applied to `.field-unit select` broadly rather than per field type.
  Changes to those files are reviewed by reading only — be correspondingly careful, and check whether a
  selector change catches inputs it shouldn't.

## Not worth flagging

- Upstream code style we inherited. This is thoughtbot's codebase; a finding whose only substance is
  "upstream would write this differently" is noise.
- `CHANGELOG.md` entries. It tracks upstream releases, not our patches.
- Missing translations in the non-English `config/locales/administrate.*.yml` files — we don't maintain
  them. A **new** user-facing string still needs an `administrate.en.yml` entry.
