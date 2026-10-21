# Installation

- **Game:** Project Zomboid Build 42.21 or later (`versionMin=42.21`).
- **Requirement:** [TooltipLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3694097672). Subscribe to it and enable it too.
- **Workshop:** [Belt Walkie-Talkie](https://steamcommunity.com/sharedfiles/filedetails/?id=3817018338), mod ID `batman_BeltRadio`.

## Singleplayer

Enable **Belt Walkie-Talkie** and **TooltipLib** in the mod list, or in the mods of your save. The mod adds no item to the world: it can be added to an existing save.

## Dedicated server

Add both mods to the server settings, next to the ones your server already uses:

```
WorkshopItems=3694097672;3817018338
Mods=\TooltipLib;\batman_BeltRadio
```

Options are on the **Belt Walkie-Talkie** sandbox page (see [Sandbox options](04-sandbox-options.md)).

## Removing the mod

The mod only stores a small marker on radios adapted for mains power. Removing it from a running save has not been tested: a radio last seen on mains power may keep a battery that does not drain.

> Capture à faire : the Belt Walkie-Talkie and TooltipLib entries in the mod list.
