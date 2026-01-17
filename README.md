# BencodeKit
Forked from [Wv.BencodeKit](https://github.com/waltervos/Wv.BencodeKit), based on [@rchouinard's bencode library for PHP](https://github.com/rchouinard/bencode).

Utility to read bencoded files.

## Usage

```
Import-Module 'Bencodekit'

# Read torrent file as object
$Torrent = ConvertFrom-BencodedFile -FilePath 'Path\To\MyTorrentFile.torrent'
$Torrent.announce.string
$Torrent.info.pieces.bytestring[0..19]
$Torrent.info.files[0].path.string
```

(from forked repository)

Torrent files are read as dictionaries, so `$Torrent` is now a hashtable with keys such as 'info', 'announce-list' and so on. [Check out this website](https://wiki.theory.org/index.php/BitTorrentSpecification#Metainfo_File_Structure) for more about the possible contents of a torrent file.

Strings are represented as both an array of `[Byte]` objects, as well as a decoded string. So, to access the announce URL as text use `$Torrent.announce.string`, and to access the bytes contained in info.pieces use `$Torrent.info.pieces.bytestring`.

# TorrentChecker

Small utility to verify downloaded torrent data.

## Usage ##

```
Import-Module 'Bencodekit'
Import-Module 'TorrentChecker'

Test-TorrentData -Path '~/MyTorrentFile.torrent' -DataDirectory 'Path\To\MyTorrentDirectory'

# You can check multiple files
Test-TorrentData -Path '~/*.torrent' -DataDirectory 'Path\To\MyTorrentDirectory'

# Paths with wildcards are supported
Test-TorrentData -LiteralPath '~/[MyTorrentFile].torrent' -DataDirectory 'Path\To\MyTorrentDirectory'

# In some torrent clients, you can add or remove the nested root directory
Test-TorrentData -Path '~/MyTorrentFile.torrent' -DataDirectory 'Path\To\MyTorrentDirectory' -ContentLayout NoSubFolder

# Output is an object with the torrent file path and the result
Path                             Valid
----                             -----
/home/user/MyTorrentFile.torrent  True

# When en error is encoutered, a message is added
Path                             Valid Error
----                             ----- -----
/home/user/MyTorrentFile.torrent False Exception calling ".ctor" with "3" argument(s): "Could not
```

## To do's ##
* Add more unit tests
* Rework/optimize reads
* Support v2 torrent files
* Create a CI pipeline to run unit tests
