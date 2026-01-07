Import-Module "$PSScriptRoot\..\Wv.BencodeKit" -Force

Function InitData {
	param (
		[Parameter(Position = 0)]
		[int] $Size,
		[Parameter(Position = 1)]
		[int] $Seed = 0
	)
	$buffer = [array]::CreateInstance([byte], $Size)
	[random]::new($Seed).NextBytes($buffer)
	$buffer
}

$DebugPreference = 'Continue'

Function TestBencodedString([string]$Data, [string]$Filename, [string]$Msg, [scriptblock]$Test) {
	$Data | Out-File -Path "$PSScriptRoot\$Filename" -NoNewLine
	try {
		$bencoded = ConvertFrom-BencodedFile -FilePath "$PSScriptRoot\$Filename"
		Write-Debug $bencoded.GetType()
		$result = @( $bencoded ) | ? $Test
		if( $result.Length -eq 0 ) {
			throw $Msg
		}
	}
	finally {
		Remove-Item -Path "$PSScriptRoot\$Filename"
	}
}

function TestBencodedStringAsList([string]$Data, [string]$Filename, [string]$Msg, [scriptblock]$Test) {
	$Data | Out-File -Path "$PSScriptRoot\$Filename" -NoNewLine
	try {
		$bencoded = ConvertFrom-BencodedFile -FilePath "$PSScriptRoot\$Filename"
		Write-Debug $bencoded.GetType()
		$result = @{ Value = $bencoded } | ? $Test
		if( $result.Length -eq 0 ) {
			throw $Msg
		}
	}
	finally {
		Remove-Item -Path "$PSScriptRoot\$Filename"
	}
}

TestBencodedString "i0e" "bencode_zero.bin" "Decoding zero failed" { $_ -eq 0 }
TestBencodedString "i1254e" "bencode_non_zero_integer.bin" "Decoding integer failed" { $_ -eq 1254 }
TestBencodedString "i-458e" "bencode_negative_integer.bin" "Decoding integer failed" { $_ -eq -458 }

TestBencodedString "0:" "bencode_empty_string.bin" "Decoding empty string failed" { $_.string -eq "" }
TestBencodedString "1:a" "bencode_string_one_character.bin" "Decoding string failed" { $_.string -eq "a" }
TestBencodedString "3:foo" "bencode_string_three_characters.bin" "Decoding string failed" { $_.string -eq "foo" }

TestBencodedStringAsList "le" "bencode_empty_list.bin" "Decoding empty list failed" { $_.Value -is [System.Collections.Generic.List[psobject]] -and $_.Value.Count -eq 0 }
TestBencodedStringAsList "li0ee" "bencode_list_integer.bin" "Decoding integer list failed" { $_.Value -is [System.Collections.Generic.List[psobject]] -and $_.Value[0] -eq 0 }
TestBencodedStringAsList "l0:e" "bencode_list_empty_string.bin" "Decoding empty string list failed" { $_.Value -is [System.Collections.Generic.List[psobject]] -and $_.Value[0].string -eq "" }
TestBencodedStringAsList "l0:i0ee" "bencode_list_string_integer.bin" "Decoding list failed" { $_.Value -is [System.Collections.Generic.List[psobject]] -and $_.Value.Count -eq 2 -and $_.Value[0].string -eq "" -and $_.Value[1] -eq 0 }
TestBencodedStringAsList "l3:bare" "bencode_list_string.bin" "Decoding string list failed" { $_.Value -is [System.Collections.Generic.List[psobject]] -and $_.Value[0].string -eq "bar" }

# Single file, full piece
try {
	$buffer = InitData (1 * 2 * 1024 * 1024) 1
	New-Item -Type Directory -Path "$PSScriptRoot\01" -Force
	[System.IO.File]::WriteAllBytes("$PSScriptRoot\01\01_single_file_single_full_piece.bin", $buffer)
	if(!(Test-TorrentData -Path "$PSScriptRoot\01_single_file_single_full_piece.bin.torrent" -DataDirectory "$PSScriptRoot\01")) {
		throw "Test failed"
	}
} finally {
	Remove-Item -Path "$PSScriptRoot\01\01_single_file_single_full_piece.bin"
}

# Single file, size less than a piece
try {
	$buffer = InitData (0.6 * 2 * 1024 * 1024) 2
	New-Item -Type Directory -Path "$PSScriptRoot\02" -Force
	[System.IO.File]::WriteAllBytes("$PSScriptRoot\02\02_single_file_single_less_than_piece.bin", $buffer)
	if(!(Test-TorrentData -Path "$PSScriptRoot\02_single_file_single_less_than_piece.bin.torrent" -DataDirectory "$PSScriptRoot\02")) {
		throw "Test failed"
	}
} finally {
	Remove-Item -Path "$PSScriptRoot\02\02_single_file_single_less_than_piece.bin"
}

# Single file, two full pieces
try {
	$buffer = InitData (2 * 2 * 1024 * 1024) 3
	New-Item -Type Directory -Path "$PSScriptRoot\03" -Force
	[System.IO.File]::WriteAllBytes("$PSScriptRoot\03\03_single_file_two_full_pieces.bin", $buffer)
	if(!(Test-TorrentData -Path "$PSScriptRoot\03_single_file_two_full_pieces.bin.torrent" -DataDirectory "$PSScriptRoot\03")) {
		throw "Test failed"
	}
} finally {
	Remove-Item -Path "$PSScriptRoot\03\03_single_file_two_full_pieces.bin"
}

# Single file, size less than two pieces
try {
	$buffer = InitData (1.6 * 2 * 1024 * 1024) 4
	New-Item -Type Directory -Path "$PSScriptRoot\04" -Force
	[System.IO.File]::WriteAllBytes("$PSScriptRoot\04\04_single_file_less_than_two_pieces.bin", $buffer)
	if(!(Test-TorrentData -Path "$PSScriptRoot\04_single_file_less_than_two_pieces.bin.torrent" -DataDirectory "$PSScriptRoot\04")) {
		throw "Test failed"
	}
} finally {
	Remove-Item -Path "$PSScriptRoot\04\04_single_file_less_than_two_pieces.bin"
}

# Two files, a full piece each
try {
	$buffer1 = InitData (2 * 2 * 1024 * 1024) 5
	$buffer2 = InitData (2 * 2 * 1024 * 1024) 6
	New-Item -Type Directory -Path "$PSScriptRoot\05" -Force
	[System.IO.File]::WriteAllBytes("$PSScriptRoot\05\05_two_files_single_full_piece_1.bin", $buffer1)
	[System.IO.File]::WriteAllBytes("$PSScriptRoot\05\05_two_files_single_full_piece_2.bin", $buffer2)
	if(!(Test-TorrentData -Path "$PSScriptRoot\05.torrent" -DataDirectory "$PSScriptRoot\05")) {
		throw "Test failed"
	}
} finally {
	Remove-Item -Path "$PSScriptRoot\05\05_two_files_single_full_piece_1.bin"
	Remove-Item -Path "$PSScriptRoot\05\05_two_files_single_full_piece_2.bin"
}

# Two files, a shared piece
try {
	$buffer1 = InitData (0.7 * 2 * 1024 * 1024) 7
	$buffer2 = InitData (1.3 * 2 * 1024 * 1024) 8
	New-Item -Type Directory -Path "$PSScriptRoot\06" -Force
	[System.IO.File]::WriteAllBytes("$PSScriptRoot\06\06_1_two_files_less than_a_piece.bin", $buffer1)
	[System.IO.File]::WriteAllBytes("$PSScriptRoot\06\06_2_two_files_more_than_a_piece.bin", $buffer2)
	if(!(Test-TorrentData -Path "$PSScriptRoot\06.torrent" -DataDirectory "$PSScriptRoot\06")) {
		throw "Test failed"
	}
} finally {
	Remove-Item -Path "$PSScriptRoot\06\06_1_two_files_less than_a_piece.bin"
	Remove-Item -Path "$PSScriptRoot\06\06_2_two_files_more_than_a_piece.bin"
}
