# BencodeKit
Forked from [Wv.BencodeKit](https://github.com/waltervos/Wv.BencodeKit), based on [@rchouinard's bencode library for PHP](https://github.com/rchouinard/bencode).

## Usage ##
To use BencodeKit, download this repository and place the Wv.Bencodekit subfolder anywhere you like on your system. Open a PowerShell session or write a script.
```
# Load module
Import-Module 'Location\Of\Module\Wv.Bencodekit'

# Read torrent file as object
$Torrent = ConvertFrom-BencodedFile -FilePath 'Path\To\MyTorrentFile.torrent'`
$Torrent.announce.string
$Torrent.info.pieces.bytestring[0..19]
$Torrent.info.files[0].path.string

# Verify downloaded torrent data
Test-TorrentData -Path 'Path\To\MyTorrentFile.torrent' -DataDirectory "Path\To\MyTorrentDirectory"
```

Torrent files are read as dictionaries, so `$Torrent` is now a hashtable with keys such as 'info', 'announce-list' and so on. [Check out this website](https://wiki.theory.org/index.php/BitTorrentSpecification#Metainfo_File_Structure) for more about the possible contents of a torrent file.

Strings are represented as both an array of `[Byte]` objects, as well as a decoded string. So, to access the announce URL as text use `$Torrent.announce.string`, and to access the bytes contained in info.pieces use `$Torrent.info.pieces.bytestring`.

The BitTorrent v2 protocol is not supported.

## To do's ##
* Add more unit tests
* Rework/optimize reads
* Support v2 torrent files
* Create a CI pipeline to run unit tests
