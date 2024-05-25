# Quest Song Manager

This is a simple song manager for the Quest version of Beat Saber.
Starting with 1.4 an experimental build for Windows is also available.

## Features

- Manage songs and playlists
- Download songs and playlists from websites that support the `beatsaver://` and `bsplaylist://` protocols, examples are
	- https://bsaber.info/
	- https://beatsaver.com/
- Download songs directly to playlists
- Add your own sources to the browser bookmarks
- Find songs that are not in any playlist
- Super fast startup
- Open source :)

## Getting Started

1) [Download the APK](https://github.com/exelix11/QuestSongManager/releases/latest) and install it on your Quest
2) Start the app, allow file access and let it scan your songs
3) Enjoy!

## Details

This started as a personal project from my unsatisfaction with the other song management options available on the Quest. I made it public hoping it can be useful to others but I don't plan to offer support or major updates. 

I tested this app only on my own device where I use a limited number of mods, use at your own risk.

The app will scan the beat saber `ModData` folder in the quest internal storage. It can load and save `json` playlists in a way that is compatible with BMBF.

Additionally, the app caches the song hashes to files called `.bsq_hash_cache` in each song folder. These files can be safely deleted and this feature can be disabled in the settings, but it will make the app start much slower.

## Screenshots

[Video recorded on a Quest](https://imgur.com/a/K1zUxex)

Main screen

![Main screen](.images/songlist.png)

Download manager

![Download manager](.images/downloads.png)

Playlist editor

![Playlist editor](.images/playlist.png)

## Development

The app is written using the flutter framework. To build it, you need to have flutter installed and a working android development environment.

Testing on the quest is rather annoying, for development purposes the app also run on Windows and Linux with most features working, you need to change the hardcoded path in `lib/main.dart` to a folder that has the same file structure as the quest internal storage. The webview feature is only available on Android though, for testing that you can run the app on an emulator or a simple android phone.
