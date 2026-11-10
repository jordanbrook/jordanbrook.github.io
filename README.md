# jordanbrook.github.io

Personal academic website of Jordan Brook, published at <https://jordanbrook.github.io>.

Built with [Jekyll](https://jekyllrb.com/) using the [al-folio](https://github.com/alshedivat/al-folio) theme (MIT licence, see `LICENSE`).
For theme documentation, see the [al-folio repository](https://github.com/alshedivat/al-folio).

## Where things live

| Content                     | File                                                     |
| --------------------------- | -------------------------------------------------------- |
| About page                  | `_pages/about.md`, photo in `assets/img/profile_pic.jpg` |
| CV page                     | `assets/json/resume.json`, PDF in `assets/pdf/`          |
| Publications                | `_bibliography/papers.bib`                               |
| Software page               | `_pages/repositories.md`, `_data/repositories.yml`       |
| Site settings               | `_config.yml`                                            |
| Parked (unused) theme pages | `_ignore/`                                               |

## Refreshing cached data

The software page and citation badges read from committed snapshots so the build does not depend on
GitHub or Google Scholar being reachable from CI:

- `_data/github_metadata.yml`: regenerate with `pwsh bin/refresh-github-metadata.ps1`
- `_data/google-scholar-citations.yml`: regenerate with `pwsh bin/refresh-google-scholar-cache.ps1`

## Local preview

```bash
bundle install
bundle exec jekyll serve
```

Or with Docker: `docker compose up`, then open <http://localhost:8080>.

## Formatting

CI runs Prettier on every push. To format locally before pushing:

```bash
npm install
npx prettier . --write
```

## Deployment

Pushing to `main` runs `.github/workflows/deploy.yml`, which builds the site and publishes it to the `gh-pages` branch.
After a deploy, `broken-links-site.yml` checks internal links on the published site.
