$ErrorActionPreference = "Stop"

Import-Module "$PSScriptRoot/../../../Wv.BencodeKit" -Force

Function TestBencodedString([string]$Data, [string]$Filename, [string]$Msg, [scriptblock]$Test) {
	$Data | Out-File -Path "$PSScriptRoot/$Filename" -NoNewLine
	try {
		$bencoded = ConvertFrom-BencodedFile -FilePath "$PSScriptRoot/$Filename"
		$result = @( $bencoded ) | ? $Test
		if( $result.Length -eq 0 ) {
			throw $Msg
		}
	}
	finally {
		Remove-Item -Path "$PSScriptRoot/$Filename"
	}
}

function TestBencodedStringAsList([string]$Data, [string]$Filename, [string]$Msg, [scriptblock]$Test) {
	$Data | Out-File -Path "$PSScriptRoot/$Filename" -NoNewLine
	try {
		$bencoded = ConvertFrom-BencodedFile -FilePath "$PSScriptRoot/$Filename"
		$result = @{ Value = $bencoded } | ? $Test
		if( $result.Length -eq 0 ) {
			throw $Msg
		}
	}
	finally {
		Remove-Item -Path "$PSScriptRoot/$Filename"
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
TestBencodedStringAsList "le" "bencode_empty_list.bin" "Decoding empty list failed" { $_.Value -is [System.Collections.Generic.List[psobject]] -and $_.Value.Count -eq 0 }
