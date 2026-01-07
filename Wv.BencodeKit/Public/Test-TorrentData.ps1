function GetFilename($file) {
	if( $file.path -is [System.Collections.Generic.List[psobject]] ) {
		[System.IO.Path]::Combine([string[]]($file.path | % { $_.string }))
	} else {
		$file.path.string
	}
}

function Test-TorrentData {
	[CmdletBinding(ConfirmImpact='Low')]
	param (
		[Parameter(Mandatory=$True, ParameterSetName = 'Path', ValueFromPipeline=$True)]
		[ValidateScript({ Test-Path -Path $_ })]
		[String] $Path,
		[Parameter(Mandatory=$True, ParameterSetName = 'LiteralPath')]
		[ValidateScript({ Test-Path -LiteralPath $_ })]
		[String] $LiteralPath,
		[Parameter(Mandatory=$False)]
		[System.Text.Encoding] $Encoding = [System.Text.Encoding]::UTF8,
		[ValidateScript({ Test-Path -LiteralPath $_ })]
		[String] $DataDirectory
	)

	begin {
	}

	process {
		$Torrent = ConvertFrom-BencodedFile -FilePath $Path -Encoding $Encoding
		$pieceLength = $Torrent.info."piece length"
		$piecesCount = $Torrent.info.pieces.bytestring.Length / 20

		$resolvedDataDirectoryPath = Resolve-Path -LiteralPath $DataDirectory
		Write-Verbose $resolvedDataDirectoryPath

		#$buffer = [array]::CreateInstance([byte], $pieceLength)
		$valid = $true

		if( $Torrent.info.files -eq $null ) {
			$TargetFile = Join-Path $resolvedDataDirectoryPath $Torrent.info.name.string
			Write-Debug "Opening file $TargetFile"
			try {
				$fs = [System.IO.FileStream]::new($TargetFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
				$br = [System.IO.BinaryReader]::new($fs)
				$hasher = [System.Security.Cryptography.HashAlgorithm]::Create("SHA1")
				# Single file torrent
				for( $p = 0 ; $valid -and $p -lt $piecesCount ; $p++ ) {
					# public virtual int Read (byte[] buffer, int index, int count);
					# $br.Read($buffer)
					$buffer = $br.ReadBytes($pieceLength)
					$bufferHashHex = [System.Convert]::ToHexString($hasher.ComputeHash($buffer))
					$pieceHashHex = [System.Convert]::ToHexString($Torrent.info.pieces.bytestring[(20 * $p)..(20 * $p + 19)])
					$valid = $bufferHashHex -eq $pieceHashHex
					Write-Verbose "Piece $($p.ToString().PadLeft(4)) : $bufferHashHex / $pieceHashHex => $valid"
				}

				[pscustomobject]@{
					Path	= $TargetFile
					Valid	= $valid
				}
			}
			finally {
				if( $br ) {
					$br.Close()
				}
				if( $fs ) {
					$fs.Close()
				}
			}
		} else {
			try {
				# Multiple files torrent
				$hasher = [System.Security.Cryptography.HashAlgorithm]::Create("SHA1")
				$f = 0
				$file = $Torrent.info.files[$f]
				$filename = GetFilename $file
				$TargetFile = Join-Path $resolvedDataDirectoryPath $filename
				Write-Debug "Opening file $TargetFile"
				$fs = [System.IO.FileStream]::new($TargetFile, [System.IO.FileMode]::Open)
				$br = [System.IO.BinaryReader]::new($fs)
				for( $p = 0 ; $valid -and $p -lt $piecesCount ; $p++ ) {
					$buffer = $br.ReadBytes($pieceLength)

					# EOF of current file
					# trying to open and read next file(s) to complete the buffer
					# TODO : optimized read for small and big piece sizes
					while( $buffer.Length -lt $pieceLength -and $f -lt ($Torrent.info.files.Count - 1) )  {
						$br.Close()
						$fs.Close()
						$remaining = $pieceLength - $buffer.Length
						$f++
						$file = $Torrent.info.files[$f]
						$filename = GetFilename $file
						$TargetFile = Join-Path $resolvedDataDirectoryPath $filename
						Write-Debug "Opening file $TargetFile"
						$fs = [System.IO.FileStream]::new($TargetFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
						$br = [System.IO.BinaryReader]::new($fs)
						$tmpBuffer = $br.ReadBytes($remaining)
						$buffer = $buffer + $tmpBuffer
					}

					$bufferHashHex = [System.Convert]::ToHexString($hasher.ComputeHash($buffer))
					$pieceHashHex = [System.Convert]::ToHexString($Torrent.info.pieces.bytestring[(20 * $p)..(20 * $p + 19)])
					$valid = $bufferHashHex -eq $pieceHashHex
					Write-Verbose "Piece $($p.ToString().PadLeft(4)) : $bufferHashHex / $pieceHashHex => $valid"
				}

				[pscustomobject]@{
					Path	= $TargetFile
					Valid	= $valid
				}
			}
			finally {
				if( $br -ne $null ) {
					$br.Close()
				}
				if( $fs -ne $null ) {
					$fs.Close()
				}
			}
		}
	}

	end {
		Write-Verbose "Finished."
	}
}
