# Deploying Chairfighter to itch.io

The game is exported as an HTML5 (Web) build and pushed to itch.io with
[butler](https://itch.io/docs/butler/). Everything is driven by
[`scripts/deploy_itch.sh`](../scripts/deploy_itch.sh).

## One-time setup

1. **Create the itch.io page.** Make a new project at
   <https://itch.io/game/new>, set its **Kind of project** to *HTML*, and note
   its URL slug (`https://<user>.itch.io/<slug>`). The page can stay a draft.

2. **Get a butler API key** from
   <https://itch.io/user/settings/api-keys> ("Generate new API key").

3. **Fill in `.itch.env`** at the repo root (this file is gitignored — never
   commit it):

   ```ini
   BUTLER_API_KEY=<your key>
   ITCH_USER=<your itch username>
   ITCH_GAME=chairfighter
   ITCH_CHANNEL=html5
   ```

   `.itch.env.example` is the committed template.

4. **Tools.** `butler` and `godot` must be installed.
   - butler lives in `~/.local/bin` (installed from `https://broth.itch.zone`).
   - The script auto-installs the matching Godot **export templates** the first
     time it runs if they're missing.

## Deploy

```bash
scripts/deploy_itch.sh            # build the Web export and push to itch.io
scripts/deploy_itch.sh --build    # build only (output in build/web/), no push
scripts/deploy_itch.sh --dry-run  # build, then print the butler push command
```

Each push is tagged with the current git short SHA as the itch.io user version.

After the first successful push, set the uploaded file to **"This file will be
played in the browser"** on the itch.io edit page (butler marks `html5`-channel
uploads as playable automatically, but confirm the embed options/viewport).

## Notes

- The build uses Godot's `gl_compatibility` renderer with **no thread support**,
  so it runs on itch.io without cross-origin-isolation headers.
- Build artifacts (`build/`, `*.pck`, `*.zip`) are gitignored.
