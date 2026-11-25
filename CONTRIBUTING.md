# Contributing

Thanks for helping. Humans and AI agents follow the same rules, which live in [AGENTS.md](AGENTS.md). The short version:

1. **Pick a task** from [tasks/BACKLOG.md](tasks/BACKLOG.md), or open an issue to propose one.
2. **Original work only.** No content from other games or mods, and nothing you don't have the right to license. See [docs/06-legal-and-licensing.md](docs/06-legal-and-licensing.md).
3. **Log every asset** in `ASSET_MANIFEST.csv` with author, source and license.
4. **Run the checks** before opening a pull request: `tools/run_tests.sh` and `python3 tools/check_repo.py`.
5. **Keep pull requests small**, one task each, and fill in the pull request template.

## Licensing of contributions

- Code is licensed GPL-3.0-or-later; assets are CC BY-SA 4.0 ([ASSETS_LICENSE.md](ASSETS_LICENSE.md)).
- By submitting a contribution, you confirm that you wrote it or have the right to submit it under these licenses.
- Once outside contributors join, every commit must carry a DCO sign-off (`git commit -s`). See <https://developercertificate.org/>. Backlog task P3-21 tracks turning this on.

## AI-assisted contributions

These are welcome. Say which tool you used in the pull request, and review the output yourself. You are responsible for what you submit. AI-generated assets need `generated_by` filled in the manifest.

## Code of conduct

Be kind and constructive. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
