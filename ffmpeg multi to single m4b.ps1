# Detects first relevant audio file extenson we want and sets it to that for the rest of the script 
$ext = $null
$items = Get-Childitem
$extensions = @("*.mp3", "*.wav", "*.flac", "*.m4a", "*.m4b")
foreach ($line in $items) {
	foreach ($extension in $extensions) {
		if ($line -like $extension) {
			$ext = $extension
		}
	}
	if ($ext -ne $null) {break}
}

# Create or reset .txt files we will use to make a single audio file
$null | Set-Content -Path .\Build_Files.txt -NoNewline
";FFMETADATA1" | Set-Content -Path .\Build_Metadata.txt 

# Get all files in folder Based of what we detected earlier and start processing them
$audioFiles = Get-ChildItem $ext -Recurse | Sort-Object Name 
$totalMilliseconds = 0
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
	#Remove file path add it to Build_Files.txt witch correct structure
	$inputAudio = $audioFiles[$i]
	$fileName = Split-Path $inputAudio -leaf
	"file '$fileName'" | Add-Content -Path .\Build_Files.txt
	
	# Determine part number and set it to be the chapet number 
	$partNumber = $i + 1
	$chapterNumber = "{0:D3}" -f $partNumber
	
	# Get duration in seconds using ffprobe and convert to milliseconds
	$duration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$($inputAudio.FullName)"
	$durationMilliseconds = [math]::Round([double]::Parse($duration,[System.Globalization.CultureInfo]::InvariantCulture) * 1000)
	
	# Get chapter start/end
	$start = $totalMilliseconds
	$end = $totalMilliseconds + $durationMilliseconds
	
	#Write to Build_Metadata
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
if ($coverCodec -eq "mjpeg") {$coverFile = ".\Build_Cover.jpg"}
elseif ($coverCodec -eq "png") {$coverFile = ".\Build_Cover.png"} 
else {$coverFile = $null}
if ($coverFile) {ffmpeg -y -i $audioFiles[0].FullName -map 0 -c copy -frames 1 $coverFile}

# Brings it all together for the final output file
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($audioFiles[0].FullName)
$baseName = $baseName -replace '\s*[-–—]?\s*[\(\[\{]?\d+[\)\]\}]?\s*$', ''
ffmpeg -y -f concat -safe 0 -i ".\Build_Files.txt" -i ".\Build_Metadata.txt" -i "$coverFile" -map 0:a:0 -map 2:v:0 -map_metadata 1 -c:a aac -b:a 128k -c:v copy -disposition:v:0 attached_pic -movflags +faststart "$baseName.m4b"

# Removes Build files and the script + deployment bat file, has built in protection againts removing the origonal script
Write-Host "Removing remotely deployed ffmpeg script and Build files..."
Start-Sleep -s 1
rm build_*
if (Test-Path -path "$baseName.m4b") {foreach ($inputAudio in $audioFiles){Remove-Item $inputAudio}}
if ($PSScriptRoot -ne "C:\Users\ricky\Desktop\Coding Projects\Bindery") {
		rm *.bat
		rm *.ps1
	}
