# Improve tutorial prompts

**Date:** 2026-06-08
**Filed by:** Sihl
**Project:** chairfighter
**Card chain root:** IAKE

## What the friend asked for

this tutorial needs to be better. it has no commands, the only thing I can figure out how to do on my own is move left and right and jump, and then I think I get blocked by the friendly NPC (I can't read all his text) and I can't seem to get past him

## What we agreed on

Improve the opening tutorial so a new player can see the basic commands and understand how to keep moving through the first NPC/tutorial moment. This is mainly a tutorial clarity issue, not a request to redesign the NPC system. The NPC text being cut off at the top of the screen is supporting context because it currently makes the tutorial feel blocked, but the main goal is to make the tutorial itself show the controls and the next objective clearly.

Players should not have to guess beyond move, jump, and basic exploration. The tutorial should clearly teach movement, jump, attack, interact/talk/advance dialogue if applicable, and what to do after reaching the friendly NPC. Existing player mechanics and the Basic Chair -> boss -> Armchair -> grapple route should stay intact.

## Acceptance criteria

- The opening tutorial visibly shows the basic commands instead of relying on the player to discover them silently.
- Tutorial prompts include move left/right, jump, attack, and interact/talk/advance dialogue if that is required near the NPC.
- The player gets a clear next objective when reaching the friendly NPC and is not left thinking the NPC is an impassable blocker.
- Any visible tutorial text appears inside the safe screen area and is readable in the opening level.
- The existing MVP route remains intact: Basic Chair practice, boss/unlock, Armchair grapple progression.
- The protagonist remains silent; NPC/tutorial text may explain controls.

## Conversation

[Sihl] this tutorial needs to be better. it has no commands, the only thing I can figure out how to do on my own is move left and right and jump, and then I think I get blocked by the friendly NPC (I can't read all his text) and I can't seem to get past him

[Sihl] this tutorial needs to be better. it has no commands, the only thing I can figure out how to do on my own is move left and right and jump, and then I think I get blocked by the friendly NPC (I can't read all his text) and I can't seem to get past him

[Sihl] try again

[Sihl] try again

[Big Al] Got it — the tutorial needs to actually teach the controls, and right now the friendly NPC feels like a blocker because the text isn’t readable and it’s unclear how to get past him.

Quick one: when you say you can’t read all his text, is it because the text disappears too fast, gets cut off, is too small, or there’s no way to advance/rewind it?

[Sihl] I don't see any text other than "safe area" and whatever the npc is saying (that gets cut off at the top)

[Sihl] I don't see any text other than "safe area" and whatever the npc is saying (that gets cut off at the top)

[Big Al] Ahh, got it — so the only visible tutorial text is “safe area,” and the NPC’s dialogue is partly off-screen/cut off at the top. That makes it hard to know the controls or what you’re supposed to do next.

Quick one: do you want this filed mainly as a **tutorial instructions problem** — “show the player the basic commands and next objective” — or as a **UI/dialogue bug** — “NPC text is getting cut off/off-screen”?

[Sihl] more the tutorial issue for now

[Sihl] more the tutorial issue for now

[Big Al] Yep, that makes sense — we’ll treat it as a tutorial problem first, with the cut-off NPC text as supporting context.

I think I’ve got enough to file it:

**Request:** Improve the tutorial so players can understand basic controls and how to progress.

**What’s happening now:**
- The tutorial doesn’t clearly show commands or controls.
- The only obvious control discovery is moving left/right and jumping.
- The only visible tutorial text seems to be “safe area.”
- The friendly NPC appears to block progress.
- The NPC’s dialogue is hard to use because it gets cut off at the top of the screen.

**Why it matters:**
Players can get stuck very early because they don’t know what actions are available or what the NPC expects from them.

**Suggested improvement:**
Add clear tutorial prompts for the basic commands, especially:
- Move left/right
- Jump
- Interact/talk/advance dialogue, if applicable
- How to get past or resolve the friendly NPC encounter

Also make sure the player has a clear “next thing to do” after reaching the NPC.

Want me to file this as-is, or add anything else before it goes in?

[Sihl] yes file it
