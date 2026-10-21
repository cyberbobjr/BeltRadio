# Multiplayer

Belt Walkie-Talkie works on dedicated and hosted servers. It sends no network command of its own; the server and every client need the mod and TooltipLib.

- **Listening:** in multiplayer the game already makes every switched-on radio of your main inventory receive, but only in the radio chat. The mod adds the **radio bubble** above your character for a walkie-talkie on the belt (option *Bubble for an unheld radio*). A radio stored in the inventory gets no bubble. The same line is not shown twice within 2 seconds.
- **Bubble colour:** white, or the colour declared by the mod that owns the station (for example Military Drop, Operation Artemis, Radio Survivor). Storm scrambling does not turn it grey.
- **Battery, noise, sound:** as in singleplayer, handled by your own client. The noise is sent to the server and attracts zombies; the sound is heard by you only.
- **Mains power:** a carried radio is handled by your client; the server learns its charge through the vanilla battery updates sent while the radio is switched on. Placed radios are handled by the server, which sends their charge to the players at each percent gained.
- **Talking** from the belt: take the walkie-talkie in hand.

Not yet tested in game: noise and sound for radio messages of other players (they rely on the radio chat event).

> Capture à faire : radio bubble above a player in multiplayer, walkie-talkie on the belt.
