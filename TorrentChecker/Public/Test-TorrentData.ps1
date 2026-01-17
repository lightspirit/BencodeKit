enum ContentLayout {
	# Depends on torrent
	# Single file : no sub directory
	# Multiple files : subdirectory
	Original
	# Always create a directory
	CreateSubFolder
	# Never create a directory
	NoSubFolder
}

function Remove-InvalidPathChars([string]$Path) {
	$InvalidPathChars = [IO.Path]::GetInvalidPathChars() -join ''

	$regexPath = "[{0}]" -f [regex]::Escape($InvalidPathChars)

	# qBittorrent replaces invalid chars with underscores
	$Path -replace $regexPath,'_'
}

function Remove-InvalidFileNameChars([string]$Name) {
	$InvalidFileNameChars = [IO.Path]::GetInvalidFileNameChars() -join ''

	$regexFileName = "[{0}]" -f [regex]::Escape($InvalidFileNameChars)

	# qBittorrent replaces invalid chars with underscores
	$Name -replace $regexFileName,'_'
}

function GetTargetDirectory([ContentLayout]$ContentLayout, $Torrent, $Directory) {
	switch($ContentLayout) {
		([ContentLayout]::Original) {
			if( $Torrent.info.files -eq $null ) {
				# single file
				$Directory
			} else {
				# single file in a directory or multiple files
				Join-Path $Directory (Remove-InvalidPathChars $Torrent.info.name.string)
			}
		}
		([ContentLayout]::CreateSubFolder) {
			if( $Torrent.info.files -eq $null ) {
				# single file : use file base name
				Join-Path $Directory (Remove-InvalidPathChars ([System.IO.Path]::GetFileNameWithoutExtension($Torrent.info.name.string)))
			} else {
				# same as Original : single file in a directory or multiple files
				Join-Path $Directory (Remove-InvalidPathChars $Torrent.info.name.string)
			}
		}
		([ContentLayout]::NoSubFolder) {
			$Directory
		}
		default {
			throw "Layout $_ not handled"
		}
	}
}

function GetFilename($file) {
	if( $file.path -is [System.Collections.Generic.List[psobject]] ) {
		[System.IO.Path]::Combine([string[]]($file.path | % { Remove-InvalidPathChars $_.string }))
	} else {
		Remove-InvalidFileNameChars $file.path.string
	}
}

function Test-TorrentData {
	[CmdletBinding(ConfirmImpact='Low')]
	param (
		[SupportsWildcards()]
		[Parameter(Mandatory=$True, ParameterSetName = 'Path', ValueFromPipeline=$True, HelpMessage = 'Wildcards supported torrent files path. Can be relative.')]
		[ValidateScript({ Test-Path -Path $_ })]
		[String] $Path,
		[Parameter(Mandatory=$True, ParameterSetName = 'LiteralPath', HelpMessage = 'Torrent file path. Can be relative.')]
		[ValidateScript({ Test-Path -LiteralPath $_ })]
		[String] $LiteralPath,
		[Parameter(Mandatory=$False, HelpMessage = 'Torrent file encoding. Default to UTF-8.')]
		[System.Text.Encoding] $Encoding = [System.Text.Encoding]::UTF8,
		[Parameter(HelpMessage = 'Directory where torrent data files are stored.')]
		[ValidateScript({ Test-Path -LiteralPath $_ })]
		[String] $DataDirectory,
		[Parameter(HelpMessage = "Content layout defined in qBittorrent")]
		[ContentLayout] $ContentLayout = [ContentLayout]::Original
	)

	begin {
	}

	process {
		$resolvedDataDirectoryPath = Resolve-Path -LiteralPath $DataDirectory
		Write-Verbose $resolvedDataDirectoryPath

		if( $Path ) {
			$resolvedPaths = Resolve-Path -Path $Path
		} else {
			$resolvedPaths = Resolve-Path -LiteralPath $LiteralPath
		}

		#$buffer = [array]::CreateInstance([byte], $pieceLength)
		$valid = $true
		$startTime = Get-Date
		$totalBytesRead = 0

		for( $i = 0 ; $i -lt $resolvedPaths.Length ; $i++ ) {
			$resolvedPath = $resolvedPaths[$i].Path
			Write-Debug $resolvedPath
			Write-Progress -Id 0 -Activity "Verifying torrent files data" -PercentComplete (100 * $i / $resolvedPaths.Length) -CurrentOperation $resolvedPath -ProgressAction ($resolvedPaths.Length -gt 1 ? $ProgressPreference : "SilentlyContinue")

			try {
				$Torrent = ConvertFrom-BencodedFile -FilePath $resolvedPath -Encoding $Encoding
				$pieceLength = $Torrent.info.'piece length'
				$piecesCount = $Torrent.info.pieces.bytestring.Length / 20

				if( $Torrent.info.files -eq $null ) {
					$TargetDirectory = GetTargetDirectory $ContentLayout $Torrent $resolvedDataDirectoryPath
					$TargetFile = Join-Path $TargetDirectory (Remove-InvalidFileNameChars $Torrent.info.name.string)
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
							$totalBytesRead += $buffer.Length
							$bufferHashHex = [System.Convert]::ToHexString($hasher.ComputeHash($buffer))
							$pieceHashHex = [System.Convert]::ToHexString($Torrent.info.pieces.bytestring[(20 * $p)..(20 * $p + 19)])
							$valid = $bufferHashHex -eq $pieceHashHex
							Write-Verbose "Piece $($p.ToString().PadLeft(6)) : $bufferHashHex / $pieceHashHex => $valid"
							$currentTime = Get-Date
							$timeSpent = $currentTime - $startTime
							Write-Progress -Id 1 -Parent 0 -Activity 'Verifying...' -Status "$(($totalBytesRead / 1mb / $timeSpent.TotalSeconds).ToString('#')) MiB/s average" -CurrentOperation $TargetFile -PercentComplete (100 * ($p + 1) / $piecesCount)
						}

						[pscustomobject]@{
							Path	= $resolvedPath
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
						$hasher = [System.Security.Cryptography.HashAlgorithm]::Create('SHA1')
						$TargetDirectory = GetTargetDirectory $ContentLayout $Torrent $resolvedDataDirectoryPath
						Write-Debug "Target directory : $TargetDirectory"
						$f = 0
						$file = $Torrent.info.files[$f]
						$filename = GetFilename $file
						$TargetFile = Join-Path $TargetDirectory $filename
						Write-Debug "Opening file $TargetFile"
						$fs = [System.IO.FileStream]::new($TargetFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
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
								$TargetFile = Join-Path $TargetDirectory $filename
								Write-Debug "Opening file $TargetFile"
								$fs = [System.IO.FileStream]::new($TargetFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
								$br = [System.IO.BinaryReader]::new($fs)
								$tmpBuffer = $br.ReadBytes($remaining)
								$buffer = $buffer + $tmpBuffer
							}

							$totalBytesRead += $buffer.Length
							$bufferHashHex = [System.Convert]::ToHexString($hasher.ComputeHash($buffer))
							$pieceHashHex = [System.Convert]::ToHexString($Torrent.info.pieces.bytestring[(20 * $p)..(20 * $p + 19)])
							$valid = $bufferHashHex -eq $pieceHashHex
							Write-Verbose "Piece $($p.ToString().PadLeft(6)) : $bufferHashHex / $pieceHashHex => $valid"
							$currentTime = Get-Date
							$timeSpent = $currentTime - $startTime
							Write-Progress -Id 1 -Parent 0 -Activity 'Verifying...' -Status "$(($totalBytesRead / 1mb / $timeSpent.TotalSeconds).ToString('#')) MiB/s average" -CurrentOperation $TargetFile -PercentComplete (100 * ($p + 1) / $piecesCount)
						}

						[pscustomobject]@{
							Path	= $resolvedPath
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
			catch {
				[pscustomobject]@{
					Path	= $resolvedPath
					Valid	= $false
					Error	= $_
				}
			}
		}
	}

	end {
		Write-Verbose "Finished."
	}
}
