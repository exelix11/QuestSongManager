# Quest Song Manager

This is a simple song manager for the Quest version of Beat Saber.
Starting with 1.4 an experimental build for Windows is also available.

## Features

- Manage songs and playlists
- Sync beatsaver playlists.
- OneClick download of songs and playlists from popular websites like bsaber.com and beatsaver.com.
- Convenience organization features like download to playlists and find songs that are not in any playlist
- Super fast startup
- Open source :)

## Getting Started (Quest)

1) Make sure beatsaber mods are properly configured on your Quest, follow the community guides.
2) [Download the APK](https://github.com/exelix11/QuestSongManager/releases/latest) and install it on your Quest
3) Start the app, allow file access and let it scan your songs
4) Enjoy!

## Getting Started (PC)

Just download and unzip to a folder, no installation needed. On first start you'll be asked to select the install path of the game.
Note that the Windows version is not my main focus, it works mostly fine, however it does not implement all the common playlist json fields so it may lose some metadata when saving playlists.

## Screenshots

[Video recorded on a Quest](https://imgur.com/a/K1zUxex)

Main screen

![Main screen](.images/songlist.png)

Download manager

![Download manager](.images/downloads.png)

Playlist editor

![Playlist editor](.images/playlist.png)

## Advanced features

Aside from simply managing playlists and songs Quest Song Manager includes a few advanced features that you might find interesting

### Playlist management

If you like neatly organizing every song in playlists you can set automatic download to playlist so you can always keep an eye on new songs. Also from the three dots menu in the playlist management tab you can search for songs that are not in any playlist to find ones that slipped through the cracks.

### Playlist sync

For playlists that are linked to beatsaver you can tap the three dot menu in the playlist page and select one of the cloud sync options. Sync means that it will try to download the latest version of the playlist so if new songs have been added you'll get them instantly.

If you login with your beatsaver account you can access your private playlists and bookmarks. You can also upload local changes to playlists on your account, this lets you easily synchronize playlists across multiple beatsaber installations. Another use case is that you can create a playlist of songs you want to download on a pc and then immediately download them with a few clicks on your quest.

When you try to download or upload playlists that can't be merged automatically (say, you edited it on two different devices) you'll be prompted for which songs to add or remove so no song is ever lost.

## Development

The app is written using the flutter framework. To build it, you need to have flutter installed and a working android development environment.

Testing on the quest is rather annoying, for development purposes the app also run on Windows and Linux with most features working, you need to change the hardcoded path in `lib/main.dart` to a folder that has the same file structure as the quest internal storage. The webview feature is only available on Android though, for testing that you can run the app on an emulator or a simple android phone.

### Temp files

The app will scan the beat saber `ModData` folder in the quest internal storage. For the fast startup feature the song hashes are cached to files called `.bsq_hash_cache` in each song folder. These files can be safely deleted and this feature can be disabled in the settings, but it will make the app start much slower.
