# ---------- CONFIG ----------
$GEMINI_API_KEY = ""   # Replace with your Gemini API key
$INPUT_FILE     = ""   # Your audio/video file
$OUTPUT_DIR     = ""   # Folder for final clips
$BUFFER_SECONDS = 5    # Seconds before/after each clip
# ----------------------------

Write-Host "=== Checking dependencies ==="

# 1. Check for Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "Python not found. Installing Python..."
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.12.5/python-3.12.5-amd64.exe" -OutFile "$env:TEMP\python_installer.exe"
    Start-Process "$env:TEMP\python_installer.exe" -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait
} else {
    Write-Host "Python is already installed."
}

# 2. Check for FFmpeg
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "FFmpeg not found. Installing FFmpeg..."
    $ffmpegZip = "$env:TEMP\ffmpeg.zip"
    Invoke-WebRequest -Uri "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip" -OutFile $ffmpegZip
    Expand-Archive $ffmpegZip -DestinationPath "$env:ProgramFiles\ffmpeg"
    $binPath = (Get-ChildItem "$env:ProgramFiles\ffmpeg" -Recurse -Directory | Where-Object { $_.Name -eq "bin" }).FullName
    setx PATH "$env:PATH;$binPath"
} else {
    Write-Host "FFmpeg is already installed."
}

# 3. Check for Whisper (Python package)
try {
    python -m whisper --help > $null 2>&1
    Write-Host "Whisper is already installed."
} catch {
    Write-Host "Installing Whisper..."
    python -m pip install --upgrade pip
    python -m pip install git+https://github.com/openai/whisper.git
}

Write-Host "=== All dependencies ready ==="


# Ensure output folder exists
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR | Out-Null
}

Write-Host "🎙 Running Whisper transcription..."
$BaseName = [System.IO.Path]::GetFileNameWithoutExtension($INPUT_FILE)
$TranscriptFile = "$BaseName.vtt"

# Run Whisper CLI (requires whisper installed via pip)
whisper $INPUT_FILE --model medium --output_format vtt --output_dir .

# Load transcript
$TranscriptText = Get-Content -Raw -Path $TranscriptFile

Write-Host "🤖 Sending transcript to Gemini..."
$Prompt = @"
You are analyzing a transcript from a Dungeons & Dragons podcast.

Your goal is to identify **up to 10 clip-worthy moments** that are around a minute long
(with a tolerance of ±10 seconds if needed to capture complete moments). The goal is to produce rough clips that I can 
touch up and edit manually so your focus should be on the content try to prioritize capture the whole exhange over 
keeping it within the time boundary if need be.  

Clips must fall into one or both categories:
- Funny moments/exchanges
- Roleplay highlights

**Timestamps in the transcript are in hour:minute:second.millisecond format (HH:MM:SS.MS).**  
- You MUST convert milliseconds to seconds, rounding down.  
- Return times in **HH:MM:SS** format with zero-padded digits. 
- The end time MUST be after the start time.  
- Do NOT invent timestamps; only use ones found in the transcript.

Examples:

Original Timestamp = 00:30.680 New Timestamp = 00:00:30
Original Timestamp = 02:53.480 New Timestamp = 00:02:53
Original Timestamp = 01:02:01.400 New Timestamp = 01:02:01

Return results in **valid JSON** format, with no extra commentary or text outside the JSON.  
Each JSON object should have:
- "title": short descriptive title
- "start": clip start time (HH:MM:SS)
- "end": clip end time (HH:MM:SS)
- "reason": brief explanation of why the clip was chosen

Transcript:
$TranscriptText
"@


# Gemini API call
$Headers = @{
    "Content-Type"  = "application/json"
    "x-goog-api-key" = $GEMINI_API_KEY
}
$Body = @{
    contents = @(@{
        role = "user"
        parts = @(@{ text = $Prompt })
    })
} | ConvertTo-Json -Depth 10

$Response = Invoke-RestMethod -Uri "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" `
    -Method Post -Headers $Headers -Body $Body

# Extract model text
$RawOutput = $Response.candidates[0].content.parts[0].text

# Remove Markdown code block fences if present
$RawOutput = $RawOutput -replace '```json', '' -replace '```', ''

# Try to parse JSON
try {
    $Clips = $RawOutput | ConvertFrom-Json

} catch {
    Write-Error "Gemini output was not valid JSON:"
    Write-Host $RawOutput
    exit
}

# Save JSON
$Clips | ConvertTo-Json -Depth 10 | Out-File "clips.json" -Encoding UTF8
Write-Host "✅ Saved clips.json with $($Clips.Count) clips"

# Function to adjust time with buffer
function Add-Buffer {
    param (
        [string]$Time,
        [int]$Seconds
    )
    $fmt = "hh\:mm\:ss"
    $dt = [TimeSpan]::Parse($Time)
    $dt = $dt.Add([TimeSpan]::FromSeconds($Seconds))
    if ($dt -lt [TimeSpan]::Zero) { $dt = [TimeSpan]::Zero }
    return $dt.ToString($fmt)
}

Write-Host "✂ Cutting clips with FFmpeg..."
$Index = 1
foreach ($Clip in $Clips) {
    $SafeTitle = ($Clip.title -replace '[^a-zA-Z0-9_\- ]', '').Trim()
    $OutputFile = Join-Path $OUTPUT_DIR ("{0:D2}_{1}.mp4" -f $Index, $SafeTitle)

    $StartTime = Add-Buffer $Clip.start (-$BUFFER_SECONDS)
    $EndTime   = Add-Buffer $Clip.end   ($BUFFER_SECONDS)

    Write-Host $StartTime $EndTime

    ffmpeg -ss $StartTime -to $EndTime -i $INPUT_FILE -c copy $OutputFile

    $Index++
}

Write-Host "🎉 Done! Clips saved in '$OUTPUT_DIR' folder."
