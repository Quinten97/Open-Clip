# Open-Clip

Open-Clip is a PowerShell script that uses **Whisper**, **Google Gemini's API**, and **FFmpeg** to replicate the core functionality of *Opus Clip* — entirely on your local machine.

## How It Works

1. **Transcription** – Your video or audio file is transcribed locally using Whisper
2. **Clip Selection** – The transcription is sent to Google Gemini with a custom prompt, which returns 10 recommended clips (each with a title, reason, and precise start/end timestamps) in JSON format
3. **Clip Extraction** – FFmpeg automatically processes the JSON and cuts the clips directly from the original source file

## Prerequisites

Before running Open-Clip, ensure you have the following installed:

- **Python** 3.9.9 or later
- **PyTorch** 1.10.1 or later (required for GPU acceleration)
- **Whisper** (Python package)
- **FFmpeg** (installed and accessible via system PATH)
- **Google Gemini API key** (required to connect to the API)

> **Note:** Open-Clip will attempt to install Python, Whisper, and FFmpeg automatically, but this may not work in all environments.

## Installation

1. **Download the Script**
   
   We recommend downloading as ZIP or cloning the repository to obtain the file. Alternatively, you can copy and paste the content into a `.ps1` file.

## Configuration

### Configuration Block

At the top of the script, you'll find the **configuration block**:

```powershell
# ---------- CONFIG ----------
$GEMINI_API_KEY = ""   # Replace with your Gemini API key
$INPUT_FILE     = ""   # Your audio/video file
$OUTPUT_DIR     = ""   # Folder for final clips
$BUFFER_SECONDS = 5    # Seconds before/after each clip
# ----------------------------
```

### Configuration Options

#### `$GEMINI_API_KEY`

**What it does:** Allows the script to connect to Google Gemini's API.

**How to set it:**
1. Sign up for a Gemini API key at [Google AI Studio](https://ai.google.dev/aistudio)
2. Copy your API key
3. Paste it between the quotes:

```powershell
$GEMINI_API_KEY = "YOUR_API_KEY_HERE"
```

#### `$INPUT_FILE`

**What it does:** Tells the script which video or audio file to process.

**How to set it:** Use a full path or relative path to your file.

**Examples:**
```powershell
$INPUT_FILE = "C:\Videos\session1.mp4"
$INPUT_FILE = ".\audio\podcast_episode.wav"
```

#### `$OUTPUT_DIR`

**What it does:** Decides where your finished clips will be saved.

**How to set it:** Use a full path or relative path to an existing folder (the script will create it if needed).

**Examples:**
```powershell
$OUTPUT_DIR = "C:\Videos\Clips"
$OUTPUT_DIR = ".\output"
```

#### `$BUFFER_SECONDS`

**What it does:** Adds extra seconds before and after each clip to ensure no dialogue is cut off.

**How to set it:** Use positive numbers to increase clip length on both ends.

**Examples:**
```powershell
$BUFFER_SECONDS = 5   # Adds 5 seconds before and after
$BUFFER_SECONDS = 0   # No buffer
$BUFFER_SECONDS = 10  # Adds 10 seconds before and after
```

## Customization

### Customizing the Gemini Prompt

The Gemini instructions are located in this section:

```powershell
$Prompt = @"
You are analyzing a transcript from a Dungeons & Dragons podcast.

Your goal is to identify **up to 10 clip-worthy moments** ...
...
Transcript:
$TranscriptText
"@
```

**To customize:**
1. Change "Dungeons & Dragons podcast" to match your content type
2. Modify the clip rules to look for:
   - "Inspirational moments"
   - "Educational tips"
   - "Sports highlights"
   - etc.

> **Important:** Be careful not to remove the `Transcript:` line — it's where your transcription is inserted.

### Changing Whisper Settings

In this line:

```powershell
whisper $INPUT_FILE --model medium --output_format vtt --output_dir .
```

You can adjust:
- `--model` → "tiny", "base", "small", "medium", "large" (larger models = better accuracy but slower)
- `--output_format` → "vtt", "txt", "srt" (the script is configured for `.vtt`)

### Changing FFmpeg Output Format

In this section:

```powershell
$OutputFile = Join-Path $OUTPUT_DIR ("{0:D2}_{1}.mp4" -f $Index, $SafeTitle)
```

You can:
- Change `.mp4` to `.mov`, `.mkv`, `.avi`, etc.
- Modify the naming pattern as needed
