# Security Notes

Pre-deploy security review for the public web export of Horror Battler. Dated 2026-04-20.

This file documents what was checked before shipping a browser build, and why the project is configured the way it is. It is an assessment log, not a vulnerability-reporting policy.

## Engine version

**Pinned to Godot 4.6.2-stable** for both CI workflows (`smoke-test.yml` and `deploy-web.yml`).

- 4.6-stable released 2026-01-26.
- 4.6.1 fixed the show-stopping regressions introduced in 4.6 (ClassDB sort, NodePath hash, Android plugin, rendering regressions in VoxelGI/SDFGI/sky shaders).
- 4.6.2 is the current maintenance release, documented as the "most stable iteration yet" with 100+ regression fixes.
- The known 4.6 rendering regressions are **3D-only**. Horror Battler is a 2D game, so not affected.
- Breaking changes from 4.5 → 4.6 (glow post-processing mode, GLSL `view_matrix` transposition) are also 3D/shader-specific and do not apply.

No open engine-level CVEs against Godot 4.x were surfaced during review (searches against NVD and cvedetails.com, April 2026).

## CVE-2026-25546 — not applicable

[CVE-2026-25546](https://github.com/Coding-Solo/godot-mcp/security/advisories/GHSA-8jx2-rhfh-q928) reports a command-injection vulnerability in **Coding-Solo's `godot-mcp` npm package** (a Node.js wrapper that shells out to the Godot CLI). The fix — switching `exec()` to `execFile()` — shipped in that package's version 0.1.1.

That package is **not used in this repository.** The addon in `addons/godot_mcp/` is a separate GDScript-side MCP bridge (version 2.17.0, `godot_version_min=4.5`) that runs inside Godot itself, not a Node.js tool that shells out.

## GodLoader malware

The 2024–2025 GodLoader campaign used Godot's GDScript runtime to deliver malware to end users who ran untrusted `.pck` files. It is not an engine vulnerability — it is a misuse of a scripting runtime by attackers. See [the Godot team's statement](https://godotengine.org/article/statement-on-godloader-malware-loader/). Not a factor for a self-built web export served from our own GitHub Pages.

## `addons/godot_mcp` stripped from web export

The `godot_mcp` addon provides editor-time AI assistant integration — a websocket server (`websocket_server.gd`, `@tool`-annotated, editor-only) and a runtime game bridge (`game_bridge/mcp_game_bridge.gd`, autoloaded but gated by `EngineDebugger.is_active()`).

Even though the runtime bridge is already inert in release builds (the debugger is not active in a production export), **we exclude the entire addon from the exported PCK.** Rationale:

1. **Safe by default, not just hardenable.** An AI-control websocket component has no business in a public browser game — not even as dormant code. Excluding it reduces attack surface and removes a class of "if the guard were ever loosened, what then?" worries.
2. **Smaller PCK.** The addon is ~dev tooling; end users playing in the browser never benefit from it.
3. **Keeps the dev workflow intact.** The addon stays installed and functional in the Godot editor — it is only stripped at release-build time.

Implementation:

- `export_presets.cfg` sets `exclude_filter="addons/godot_mcp/*"`, preventing the addon's files from being packaged into the Web export's PCK.
- `.github/workflows/deploy-web.yml` runs a pre-export `sed` step that removes the `MCPGameBridge` autoload line and the plugin-enable entry from `project.godot`, so the exported build does not carry a reference to code that is no longer in the PCK.
- The smoke-test workflow does **not** strip the addon — it validates the full project as it would run in the editor.

## Hosting posture

- Deployed to GitHub Pages from the `main` branch via Actions; no personal infrastructure or persistent server.
- Export is built with `variant/thread_support=false` so the game runs single-threaded in the browser. This avoids the `SharedArrayBuffer` requirement for Cross-Origin-Isolation headers, which GitHub Pages does not serve.
- A `.nojekyll` file is written into the artifact so GitHub Pages does not strip files beginning with `_`.

## Reporting

This is a personal portfolio project; it does not process user data, authenticate users, or persist anything server-side. If you find something that looks like a security issue anyway, open an issue on the repository.
