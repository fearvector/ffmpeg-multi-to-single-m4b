$totalMilliseconds = 0
$null | Set-Content -Path .\Build_Files.txt -NoNewline
";FFMETADATA1" | Set-Content -Path .\Build_Metadata.txt

$audioFiles = Get-ChildItem *.MP3 -Recurse | Sort-Object Name
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
	$inputAudio = $audioFiles[$i]
	$fileName = Split-Path $inputAudio -leaf
	"file '$fileName'" | Add-Content -Path .\Build_Files.txt
	
	$partNumber = $i + 1
	$chapterNumber = "{0:D3}" -f $partNumber
	# Get duration in seconds using ffprobe and convert to milliseconds
	$duration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$($inputAudio.FullName)"
	$durationMilliseconds = [math]::Round([double]::Parse($duration,[System.Globalization.CultureInfo]::InvariantCulture) * 1000)
	# Chapter start/end
	$start = $totalMilliseconds
	$end = $totalMilliseconds + $durationMilliseconds
	# Add chapter metadata
    Add-Content -Path .\Build_Metadata.txt -Value @(
        ""
        "[CHAPTER]"
        "TIMEBASE=1/1000"
        "START=$start"
        "END=$end"
        "title=Chapter $chapterNumber"
    )
	$totalMilliseconds = $end
}

# Extracts the cover based on if it jpeg or png
$coverCodec = & ffprobe -v error $audioFiles[0].FullName -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 
if ($coverCodec -eq "mjpeg") {$coverFile = ".\Build_Cover.jpg"}elseif ($coverCodec -eq "png") {$coverFile = ".\Build_Cover.png"}else {$coverFile = $null}
if ($coverFile) {ffmpeg -y -i $audioFiles[0].FullName -map 0 -c copy -frames 1 $coverFile}

# Brings it all together for the final output file
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($audioFiles[0].FullName)
$baseName = $baseName -replace '\s*[-–—]?\s*[\(\[\{]?\d+[\)\]\}]?\s*$', ''
ffmpeg -y -f concat -safe 0 -i ".\Build_Files.txt" -i ".\Build_Metadata.txt" -i "$coverFile" -map 0:a:0 -map 2:v:0 -map_metadata 1 -c:a aac -b:a 128k -c:v copy -disposition:v:0 attached_pic -movflags +faststart "$baseName.m4b"

# Removes Build files and the script + deployment bat file, has built in protection againts removing the origonal script
Write-Host "Removing remotely deployed ffmpeg script and Build files..."
Start-Sleep -s 1
rm build_*.*
if (Test-Path -path "$baseName.m4b") {foreach ($inputAudio in $audioFiles){Remove-Item $inputAudio}}
if ($PSScriptRoot -ne "C:\Users\ricky\Desktop\Coding Projects\Bindery") {
		$batPath = $PSScriptRoot + "\ffmpeg multi to single m4b.ps1"
		$ps1Path = $PSScriptRoot + "\ffmpeg multi to single m4b.bat"
		Remove-Item $batPath
		Remove-Item $ps1Path
	}