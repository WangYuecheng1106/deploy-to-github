---
name: deploy-to-github
description: >-
  Detect the web framework in the current workspace, build it, and deploy to
  GitHub Pages, Vercel, Netlify, or Cloudflare Pages. Creates or rebinds the
  GitHub remote, generates platform config files (deploy workflow, vercel.json,
  netlify.toml, wrangler.toml), pushes the build output, and returns the live
  URL. Use when the user asks to "deploy", "publish", "ship", "go live", "put
  online", "deploy to GitHub/Pages/Vercel/Netlify/Cloudflare", or says a site
  should be "上线 / 部署 / 发布 / 上 GitHub".
license: MIT
metadata:
  tags: [deploy, github-pages, vercel, netlify, cloudflare-pages, static, ssr, publish, ship]
---

# Deploy to GitHub

Help the user ship the current workspace to the web. One helper script handles every phase; load the reference docs only when you need them.

## Paths and State

All `scripts/...` and `references/...` paths in this document are relative to this skill's install directory, not the user's project. When the working directory is the user's project, call the helper with its full installed path, for example:

```bash
python3 ~/.cursor/skills/deploy-to-github/scripts/deploy_helper.py detect
```

The helper writes runtime state (logs, config backups, `state.json`) to `.deploy-skill/` inside the current working directory, so run `status` from the same directory where you deployed. If that directory is a git repository, make sure `.deploy-skill/` is in its `.gitignore` before committing.

## Workflow

When the user asks to deploy the current workspace:

1. **Check tools** — `python3 scripts/deploy_helper.py check`. Required: `git`, `node`. If either is missing, print the install commands from `references/troubleshooting.md` and STOP. Do not silently install. `gh` is required for the fully-automated flow but has a manual fallback (see "GitHub Desktop fallback" below): if only `gh` is missing and the chosen target is `pages`, ask the user whether to switch to the GitHub Desktop fallback; if they agree, follow that section instead of stopping.
2. **Detect the project** — `python3 scripts/deploy_helper.py detect [--repo <name>]`. Prints `{framework, build_cmd, output_dir, is_ssr, package_manager, base_path}`.
3. **Pick a target** — apply the default rule below unless the user named a platform.
4. **Check auth** — `python3 scripts/deploy_helper.py auth`. Prints auth status for all four platforms.
5. **Ensure a GitHub repo** — `python3 scripts/deploy_helper.py repo [--name <name>] [--visibility public|private]`. **Confirm with the user before creating a repo** (it is a public, externally-visible action). Never `--force` push `main`/`master` unless the user explicitly asks.
6. **Build** — `python3 scripts/deploy_helper.py build` (uses the detected `build_cmd`, or `--build-cmd` to override).
7. **Write platform config** — `python3 scripts/deploy_helper.py config --target <pages|vercel|netlify|cloudflare>`. Renders from `templates/` with `{{REPO}}`, `{{BUILD_CMD}}`, `{{OUTPUT_DIR}}`, `{{BASE_PATH}}`, `{{FRAMEWORK}}` substituted. Existing files are backed up to `.deploy-skill/backup/` first.
8. **Deploy** — `python3 scripts/deploy_helper.py deploy --target <target>`. For Pages, `--pages-mode actions` (default) pushes `main` and watches the workflow; `--pages-mode branch` pushes `OUTPUT_DIR` to an orphan `gh-pages` branch with `--force` (allowed for orphan branches).
9. **Validate** — `python3 scripts/deploy_helper.py validate --url <url> [--contains <substring>]`. Retries up to 3 times (10s sleep) with a DNS-over-HTTPS fallback for fresh Pages/CDN hostnames.
10. **Report** — print the live URL and the next-actions checklist below.

## Default target rule

```
if user named a target: use it
elif project is_ssr:
    vercel > netlify > cloudflare > ask
else:
    pages > vercel > ask
```

## SSR guard

If `is_ssr=true` and target=`pages`: **do not proceed**. Tell the user:

> GitHub Pages only serves static files. Either switch target to Vercel/Netlify/Cloudflare, or set `output: 'export'` in `next.config.js` (Next.js) / use the static adapter (Astro/SvelteKit), then redeploy.

## Auth handling

- **GitHub**: prefer `gh auth status`; fall back to `$GH_TOKEN` then `$GITHUB_TOKEN`. Never print tokens; mask as `<first6>***`.
- **Vercel**: `vercel whoami` or `$VERCEL_TOKEN`.
- **Netlify**: `netlify status` or `$NETLIFY_AUTH_TOKEN`.
- **Cloudflare**: `wrangler whoami` or `$CLOUDFLARE_API_TOKEN`.

If auth is missing for the chosen target: print the platform's login command and STOP. Do not attempt to install CLIs without asking. See `references/security.md` for token-handling rules.

## GitHub Desktop fallback (when `gh` is missing)

When `git` and `node` are present but `gh` is missing **and the chosen target is `pages`**, ask the user before switching to this manual flow. If they decline, stop and print the `gh` install command (`winget install --id GitHub.cli -e` on Windows, `brew install gh` on macOS, `sudo apt install gh` on Linux).

GitHub Desktop is GitHub's official GUI client. It can create the remote repo and push branches without `gh`, which covers the two things `gh` does for Pages: `repo create` and `git push`. The trade-off is that repo creation, pushing, the Actions run, and Pages-source settings all become manual steps the user does in the GUI / on github.com.

Prerequisite: GitHub Desktop installed from https://desktop.github.com/ and signed in.

Helper commands that do **not** need `gh` and can run normally: `detect`, `build`, `config --target pages`, `validate`. Skip `auth` and `repo` — the user does the equivalent in GitHub Desktop.

### Actions mode (default)

1. Run `detect` and `build` as usual.
2. Run `config --target pages` to generate `.github/workflows/deploy-pages.yml` plus any framework config (e.g. Vite `base: '/<repo>/'`).
3. Ensure a local git repo and commit everything (the workflow file must be in the commit). Add `.deploy-skill/` to `.gitignore` first if present:
   ```bash
   git init && printf "\n.deploy-skill/\n" >> .gitignore && git add -A && git commit -m "deploy: pages"
   ```
4. Print these manual steps for the user (do **not** run them yourself):
   > 1. Open GitHub Desktop → **File → New Repository…**
   > 2. Set **Local path** to the current project folder.
   > 3. Set **Name** to `<repo>`, pick **Public** (Pages free tier requires public), uncheck "Initialize this repository with README".
   > 4. Click **Publish repository**. This creates the GitHub remote and pushes `main`.
5. Tell the user to enable Pages output: on github.com → repo **Settings → Pages → Source: GitHub Actions** (the workflow file we committed handles the rest).
6. Expected URL: `https://<user>.github.io/<repo>/` (or `https://<user>.github.io/` if repo is `<user>.github.io`).
7. Once the user confirms the repo is published, run `validate --url <expected-url>` (`validate` needs `node` only, not `gh`).

### Branch mode (`--pages-mode branch`)

Use only when the user explicitly wants branch mode without `gh`. More manual than actions mode.

1. Run `detect`, `build`, `config --target pages` (no workflow file needed for branch mode; only framework config).
2. Prepare the orphan `gh-pages` branch holding `OUTPUT_DIR` contents:
   ```bash
   git checkout --orphan gh-pages
   git rm -rf . 2>/dev/null || true
   cp -r <OUTPUT_DIR>/. .
   git add -A && git commit -m "deploy: gh-pages"
   git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
   ```
3. Print these manual steps for the user:
   > 1. Open GitHub Desktop → **File → New Repository…** → set **Local path** to this folder → **Publish** (creates the remote + pushes `main`).
   > 2. Push `gh-pages`: in GitHub Desktop switch branch to `gh-pages` and push it; **or** from a terminal run `git push origin gh-pages --force` (force is allowed for the orphan branch).
   > 3. On github.com: **repo Settings → Pages → Source = Deploy from a branch → Branch: `gh-pages` / root**.
4. Expected URL: `https://<user>.github.io/<repo>/`.
5. Run `validate --url <expected-url>` once the user confirms.

### Limitations of the fallback

- Cannot auto-create the repo or push from CLI; the user does it in GitHub Desktop.
- Cannot watch the Actions run; the user checks the **Actions** tab on github.com.
- Cannot set the Pages source automatically; the user configures it in repo Settings.
- For non-Pages targets (Vercel/Netlify/Cloudflare), `gh` is not required — if the user picks those, proceed normally with the platform's own CLI.

## Repo handling

- Default repo name = basename of current dir.
- Default visibility = public (Pages requires public on free plans). **Confirm before `gh repo create`.**
- If a GitHub remote already exists, reuse it. If a same-name repo already exists on the account, bind it rather than recreating, unless the user says otherwise.
- Back up any existing config file to `.deploy-skill/backup/<name>.<ts>.bak` before overwriting.

## Per-platform notes

- **Pages (actions mode, default):** push `main`, run workflow, `gh run watch`, read Pages URL. Add `base: '/<repo>/'` to Vite/Astro config when the repo is not `<user>.github.io`. Use `config --spa` to drop a `404.html` for SPAs, and `--cname <domain>` for a custom domain.
- **Pages (branch mode):** build locally, push `OUTPUT_DIR` to `gh-pages` with `--force` (allowed for orphan branch).
- **Vercel:** `vercel --prod --yes`; first run creates the project. Add `VERCEL_TOKEN` env for non-interactive runs.
- **Netlify:** first run `netlify sites:create --name=<repo>`, then `netlify deploy --prod`. The `@netlify/plugin-nextjs` plugin block is appended automatically for Next.js.
- **Cloudflare Pages:** `wrangler pages deploy "$OUTPUT_DIR" --project-name=<repo> --commit-dirty=true`. Next.js needs `@cloudflare/next-on-pages` (tell the user).

Load `references/platforms.md` for the deep dive on any platform.

## Validation loop

After deploy, run `validate`. If it still fails after 3 retries, print the deploy log path (`.deploy-skill/deploy.log`) and walk through `references/troubleshooting.md`.

## Report format

End with:

```text
✅ Deployed
   URL:        <live url>
   Target:     <pages|vercel|netlify|cloudflare>
   Repo:       <owner>/<repo>
   Next:       - set a custom domain
               - bind `vercel git connect` / Netlify auto / Pages custom domain
               - share the URL
```

## Reference (load on demand)

- Platform deep dive: `references/platforms.md`
- Detection rules: `references/framework-detection.md`
- Security & token handling: `references/security.md`
- Troubleshooting: `references/troubleshooting.md`
- Worked examples: `examples.md`
