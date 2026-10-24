# Obtainium: all seven games, auto-updating

`ghost-kit-games.json` adds every game to [Obtainium](https://github.com/ImranR98/Obtainium) in one import.
Each entry follows the game's beta release in this repo:
- it filters the releases by the game's title;
- it picks the 64-bit APK;
- it treats each new release date as a new version, because the release tags are reused.

On the phone: install Obtainium, download the JSON, then in Obtainium go to Import/Export, choose Obtainium Import,
pick the file, and install each game from the list once. After that Obtainium updates them.
If a game is already installed from an APK, it updates in place (same signing key) and keeps saves.
