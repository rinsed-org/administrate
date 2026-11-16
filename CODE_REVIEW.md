# Code review notes

Per-repo guidance for reviewers (human and Arby). The shared rubric — what counts as a finding, the P0–P3
severities — lives in [rinsed-org/review-bot-workflows](https://github.com/rinsed-org/review-bot-workflows);
this file adds only what is specific to this repo.

## What this repo is

A **fork of [thoughtbot/administrate](https://github.com/thoughtbot/administrate)**, not a standalone
project. The `rinsed-v1.0.0` branch is upstream's `v1.0.0` release (commit `cbd360d5`) plus the patches
listed below, and it is what the Rinsed app's `Gemfile` points at. Two consequences drive most of the
review:

- **Divergence is a liability.** The previous branch (`rinsed-v0.17.0`) accumulated 15 patches across ~50
  files and took a dedicated project to get off. The whole point of this branch is that moving to the next
  upstream release is a rebase of a handful of commits. Every new patch has to justify itself against
  that.
- **This is a published API.** The Rinsed app calls into these classes and overrides these views. Changing
  or removing something the app might use is a breaking change made in a different repo than the one that
  breaks.

Always diff against the upstream commit, **`git diff cbd360d5..HEAD`**, never against a tag in this repo:
the fork's own `v0.17.0` tag points at a Rinsed commit, not at upstream's release, and hides the patches.

## The patch set

This is the complete list of what the fork changes in the gem. A diff against `cbd360d5` that touches gem
code outside it is either a new patch (needs a row here, in the same PR) or a mistake.

| # | Patch | Files | Kind | Removable when |
| --- | --- | --- | --- | --- |
| 1 | `String#mb_chars` removal — Rails 8.1 deprecates it and the app raises on deprecations in test, so every search 500s | `lib/administrate/search.rb` | Upstream backport (`90c2fde9`, #2967), unmodified | First upstream release after 1.0.0 |
| 2 | Primary-key tiebreak when sorting — without it, lists sorted on a nullable / non-unique column repeat or lose rows between pages | `lib/administrate/order.rb` (+ upstream's docs and spec) | Upstream backport (`4ffbef35`, #2886), unmodified | First upstream release after 1.0.0 |
| 3 | `search_exact` / `search_lower` / `search_skip_cast` field options — upstream's `LOWER(CAST(col AS CHAR(256))) LIKE '%x%'` cannot use an index; on emails / text messages / support-agent conversations that is a table scan per search | `lib/administrate/field/base.rb`, `field/deferred.rb`, `search.rb` | Rinsed | Upstream offers per-field control of the search predicate (nothing planned) |
| 4 | `Search#attribute_types` reads the dashboard instance — the app's `BaseDashboard#attribute_types` adds types at runtime, which the `ATTRIBUTE_TYPES` constant misses | `lib/administrate/search.rb` | Rinsed (upstreamable) | Upstream does the same |
| — | `kaminari` constraint relaxed to `>= 1.2.2, < 2` — the app locks 1.3.2, upstream says `~> 1.2.2` | `administrate.gemspec`, `Gemfile.lock` | Rinsed | Upstream admits kaminari 1.3 |

Not gem code, but also carried: the review-bot workflows, this file, and `rinsed-tests.yml`, an added
workflow that tests the app's Ruby / Rails (see [What CI covers](#what-ci-does-and-does-not-cover)).
Upstream's own workflow files are left byte-identical so they never conflict on a rebase. One
test-app-only backport is carried for that workflow: `aa750464` (#2923), which makes the example app's
docs pages render as HTML on Rails 8.1. It drops out at the first upstream release after 1.0.0.

Things the old fork patched that are **deliberately not here** — do not reintroduce them in the fork;
they now live in the app or are covered by upstream: selectize on custom fields, the bulk-select row-click
guard, the `@_pundit_policy_scoped` flag, `HasMany#collection_partial`, the `helpers.label` i18n key
namespacing (all app-side), and public `Page::Form#dashboard` / `#attributes_for` (unused).

## Fork discipline

- **No asset patches in this fork. Ever.** Upstream v1 ships its JS and CSS as a prebuilt esbuild / sass
  bundle in `app/assets/builds`. Patching `app/assets/javascripts` or `app/assets/stylesheets` means
  rebuilding and committing those bundles, and re-doing that by hand on every rebase — this is exactly how
  the 0.17.0 fork became expensive. Admin JS and CSS behaviour that differs from upstream belongs in the
  Rinsed app's own admin pack (Stimulus controllers, stylesheet overrides). A Rinsed-authored change to
  anything under `app/assets/` is a **P1** regardless of how small it is — and a change that touches only
  `app/assets/builds` counts. The one exemption is an unmodified `cherry-pick -x` upstream backport whose
  committed builds pass `diff-check`: that is upstream's asset change, not ours, and it drops out on the
  next rebase.
- **Prefer the app over the fork.** Before accepting a new patch, ask whether the app can do it: view and
  partial overrides, a field subclass, a module prepended in an initializer, a controller concern. A fork
  patch is the last resort, for things that are private to the gem and cannot be reached from outside
  (as with `Search`'s SQL).
- **Prefer an upstream backport over a Rinsed patch.** If upstream `main` already fixes it, cherry-pick
  that commit unmodified with `git cherry-pick -x` and add a note to the message saying why we need it
  early. It then vanishes on the next rebase. Do not "improve" a backport — a modified cherry-pick no
  longer drops out cleanly.
- **Mark every divergence in an upstream-owned file.** Wrap it in `# RINSED: <why>` … `# END RINSED` so
  the next rebase can find it. A change to an upstream file with no marker is a finding. Two things need
  no markers: unmodified backports, because the upstream commit is the record, and files that exist only
  in the fork (everything under `spec/rinsed/`, `rinsed-tests.yml`, the review-bot workflows, this file),
  because the whole file is Rinsed's and cannot conflict.
- **Prefer additive over rewritten.** New behaviour is a new method with an upstream-compatible default,
  and the upstream line it replaces becomes a single call into it. `Field::Base.search_exact?` (default
  `false`), `search_skip_cast?` (`false`) and `search_lower?` (`true`) are the model: a dashboard that does
  not opt in gets upstream's SQL byte for byte. A change that alters default behaviour for existing
  dashboards without an explicit opt-in is a finding — it silently changes the admin UI for every
  resource in the app.
- **One patch, one commit, and the message says why and until when.** Each commit above states the problem
  it solves and what upstream change makes it removable.
- **Never rewrite a published `rinsed-vX` branch.** The app's `Gemfile.lock` pins this repo by commit sha;
  a squash or force-push orphans that sha, and once it is garbage-collected the app can no longer
  install. A fix to an existing patch is therefore stacked on top as a `fixup! <patch subject>` commit,
  which keeps `git log cbd360d5..HEAD` readable as an inventory. The fixups are squashed into their
  patches only when the next `rinsed-vX` branch is cut from a new upstream release.
- **New specs go in `spec/rinsed/`**, mirroring the upstream path (e.g.
  `spec/rinsed/lib/administrate/search_spec.rb`). Do not edit upstream spec files or the example app's
  dashboards to exercise Rinsed behaviour; define what the spec needs inside the spec. Editing an upstream
  spec is acceptable only when the upstream expectation itself is now wrong, and then it is marked.
- Comments like `# TODO: upstream this` are meaningful here — flag Rinsed-only behaviour that looks
  generally useful and could go upstream instead of living in the fork forever.

## Raw SQL: `lib/administrate/search.rb`

`Search` builds its `WHERE` clause **by string interpolation** and carries both Rinsed patches (3 and 4)
plus backport 1. It is the highest-risk code in the repo. On any diff touching it, check:

- **The search term stays a bound parameter.** It is passed as `?` with values supplied separately
  (`query_values` / `search_value`). A term reaching the SQL string itself — even via `sanitize`, even
  "just for a cast" — is a **P0**.
- **Only quoted, dashboard-declared identifiers are interpolated.** Table and column names come from the
  dashboard's attributes and associations and pass through `quote_table_name` / `quote_column_name`. A new
  interpolation of anything derived from `params`, or of an unquoted identifier, is a **P0**.
- **Placeholders and values stay aligned.** `query_template` emits one `?` per searchable field per
  attribute; `query_values` must return the same number in the same order, and since patch 3 the values
  differ per attribute. A change to one without the other shifts every later value onto the wrong column.
  The association spec in `spec/rinsed/lib/administrate/search_spec.rb` exists to catch this.
- **The options compose.** `search_skip_cast` removes the `CAST`, `search_lower: false` removes `LOWER`
  *and* stops the term being downcased, `search_exact` switches `LIKE` to `=` *and* drops the `%`
  wildcards. All three together must produce a bare `table.col = ?` with the term as typed — the one
  shape an ordinary index can serve, and what the app's `TextMessageDashboard` depends on. Skipping the
  cast also means the column's real type reaches the comparison, so a non-text column can raise or coerce
  differently. Changes here want a spec per affected combination.
- **Search runs against production-sized tables.** Flag changes that reintroduce a leading wildcard, a
  `LOWER`, or a cast on a path that was deliberately exempted.

`lib/administrate/order.rb` is no longer in this category: v1 builds ordering from Arel nodes rather than
interpolated strings. `attribute` and `direction` still come straight from `params`, so the guards still
matter — `sanitize_direction` allowlists `asc` / `desc`, and ordering is applied only when the column
exists in `columns_hash` or the attribute is a real association — but there is no Rinsed code in that
file beyond the unmodified backport.

## Public surface the Rinsed app depends on

Treat these as API. Removing one, narrowing its visibility, or changing its signature breaks the app at
runtime with nothing in this repo's CI to catch it:

- `Administrate::Field::Base` / `Field::Deferred` class methods, including the Rinsed
  `search_skip_cast?` / `search_exact?` / `search_lower?` trio and their `options.fetch` keys — those keys
  are typed by hand in the app's dashboards (`EmailDashboard`, `TextMessageDashboard`,
  `SupportAgent::ConversationDashboard`).
- `Administrate::BaseDashboard#attribute_types` being the single source of attribute types. The app
  overrides it; anything in the gem that reads `ATTRIBUTE_TYPES` directly bypasses the override.
- `Administrate::Page::Collection#attributes_for` and the `collection_attributes:` option (both upstream).
- `Administrate::Punditize` — the app layers its own authorization concern on top of it (the
  `policy_scope_admin` helper and the `verify_policy_scoped` flag live app-side now), so its method names
  and what it leaves unset are relied on.
- **View partials and their locals.** The app overrides partials by path (`_collection.html.erb`,
  `fields/has_many/_show.html.erb`, and per-resource copies), so renaming one or changing the locals
  passed to it breaks the overrides silently. Flag changes to partial names, local names, and the i18n
  keys built in them.

## What CI does and does not cover

The check that matters is **`.github/workflows/rinsed-tests.yml`**, the only workflow file Rinsed added:
one job, **Ruby 4.0, Rails 8.1, Postgres, `bundle exec rspec`** — the combination the app runs, which
upstream's v1.0.0 matrix does not cover. So don't duplicate "this spec fails", but do flag what CI cannot
see:

- **The Rails 8.1 gemfile is derived inside the job**, from `gemfiles/rails80.gemfile`, and resolved
  without a lockfile. That keeps the fork's diff out of `Appraisals` / `gemfiles/`, at the price that a
  red build can come from a new release of an unrelated gem rather than from the PR. Check the failure
  before blaming the diff.
- **Upstream's workflows are inherited byte-identical and still run.** `main.yml` (Tests) runs upstream's
  own matrix, Ruby 3.0–3.4 on Rails 6.0–8.0, on every PR; a failure there on a combination the app does
  not run is information, not a blocker. `lint.yml` runs standardrb, which Rinsed code must pass.
  `codeql-analysis.yml` runs on PRs. `diff-check.yml` runs **on push only**, so it reports on the branch
  after the fact, not on the PR. `bundle-audit.yml` audits upstream's frozen Rails 8.0.3 `Gemfile.lock`,
  which nobody ships, so its failures are not about the PR. `dynamic-readme.yml` and
  `dynamic-security.yml` exist but only trigger on pushes to `main`. Do not edit or delete any of these
  files to silence them — see the follow-ups below.
- **JS and CSS are untested here** — and unpatched; see the no-asset-patches rule.
- **The app is the real integration test.** Nothing here exercises the app's dashboards, view overrides or
  policies. A change to the public surface above should be validated against the app before it merges.

## Not worth flagging

- Upstream code style we inherited. This is thoughtbot's codebase; a finding whose only substance is
  "upstream would write this differently" is noise.
- `CHANGELOG.md` entries. It tracks upstream releases, not our patches — the table above is our changelog.
- Missing translations in the non-English `config/locales/administrate.*.yml` files — we don't maintain
  them. A **new** user-facing string still needs an `administrate.en.yml` entry.

## Follow-ups that need a repo admin

Not doable from a PR; listed so they are not forgotten.

- **Repoint the default branch** away from `rinsed-v1` to `rinsed-v1.0.0`. Despite its name, `rinsed-v1`
  is the *oldest* line (upstream 0.16.0), so new PRs currently target a dead branch by default — and
  `pull_request_target` workflows run from the base branch, so they would not be reviewed by this file.
- **Delete the fork's `v0.17.0` tag.** It points at the Rinsed squash commit `759ae1ae`, not at
  upstream's `v0.17.0` (`b49efe46`), so `git diff v0.17.0` in this repo hides nearly every old patch.
- **Disable three inherited workflows in the repo's Actions settings**: `bundle-audit` (it audits
  upstream's frozen Rails 8.0.3 lockfile, which nobody ships, so it would be red on every PR),
  `dynamic-readme` and `dynamic-security` (thoughtbot housekeeping). Disable them in settings rather than
  deleting the files: a deleted file turns every upstream edit to it into a modify/delete conflict on
  rebase. Keep `lint`, `diff-check` and `codeql-analysis` enabled.
