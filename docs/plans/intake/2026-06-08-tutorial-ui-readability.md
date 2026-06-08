# Tutorial UI readability

**Date:** 2026-06-08
**Filed by:** Sihl
**Project:** chairfighter
**Card chain root:** JBWO

## What the friend asked for

After the tutorial prompt improvement landed, Sihl shared a screenshot and said: "doesn't look great, plus the actual icons/buttons aren't coming through".

Screenshot evidence: `/home/stevets/.hermes/profiles/intake-bot/image_cache/img_fbaf02bb11eb.png`

## What we agreed on

The tutorial still needs a visual/readability repair. The control cues are present, but the on-level labels look cluttered and unfinished, and some intended button/icon glyphs render as missing-character boxes. The fix should not rely on special icon fonts unless the font is bundled and verified. Prefer plain, readable ASCII labels or simple placeholder button boxes drawn with Godot UI nodes.

This is a presentation and clarity repair for the existing tutorial, not a request to change movement, combat, NPC behavior, boss flow, or final art. The result should look clean enough for the prototype and make the actual controls readable.

## Acceptance criteria

- No tutorial label or signpost displays missing-glyph boxes/tofu characters.
- Control prompts use readable text or simple placeholder button boxes that work with the default/bundled Godot font.
- The safe-zone control hints look intentional and uncluttered, not like overlapping debug text.
- The grapple/platform cue is readable and positioned so it does not collide with the safe-zone controls in the opening view.
- The tutorial overlay and world labels use consistent wording for actions such as Move, Jump, Attack, Interact, Special/Grapple.
- The existing MVP route remains intact: Basic Chair practice, boss/unlock, Armchair grapple progression.

## Conversation

[Sihl] doesn't look great, plus the actual icons/buttons aren't coming through

[Image attached at: /home/stevets/.hermes/profiles/intake-bot/image_cache/img_fbaf02bb11eb.png]
