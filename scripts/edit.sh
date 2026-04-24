#!/bin/bash
set -e

INPUT_DIR="input/clips"
AUDIO_DIR="input/audio"
MUSIC_DIR="input/music"
OUTPUT_DIR="output"
mkdir -p $OUTPUT_DIR

echo "========================================="
echo "🎬 Video Edit Pipeline Started"
echo "========================================="

# ① সব clips count করো
CLIP_COUNT=$(ls $INPUT_DIR/*.mp4 2>/dev/null | wc -l)
echo "📂 Found $CLIP_COUNT clips"

if [ "$CLIP_COUNT" -eq 0 ]; then
    echo "❌ No clips found! Exiting."
    exit 1
fi

# ② প্রতিটা clip resize করো (1080x1920 Shorts format)
echo "-----------------------------------------"
echo "📐 Step 1: Resizing clips to 1080x1920..."
INDEX=1
for clip in $(ls $INPUT_DIR/*.mp4 | sort); do
    OUTPUT_CLIP="$OUTPUT_DIR/resized_$(printf '%02d' $INDEX).mp4"
    ffmpeg -y \
        -i "$clip" \
        -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:black,setsar=1" \
        -c:v libx264 \
        -crf 23 \
        -preset fast \
        -r 30 \
        -an \
        "$OUTPUT_CLIP"
    echo "✅ Resized: $clip → $OUTPUT_CLIP"
    INDEX=$((INDEX + 1))
done

# ③ Clips list বানাও
echo "-----------------------------------------"
echo "📝 Step 2: Creating clips list..."
> "$OUTPUT_DIR/clips_list.txt"
for clip in $(ls $OUTPUT_DIR/resized_*.mp4 | sort); do
    echo "file '$(realpath $clip)'" >> "$OUTPUT_DIR/clips_list.txt"
done
cat "$OUTPUT_DIR/clips_list.txt"

# ④ সব clips জোড়া লাগাও
echo "-----------------------------------------"
echo "🔗 Step 3: Merging all clips..."
ffmpeg -y \
    -f concat \
    -safe 0 \
    -i "$OUTPUT_DIR/clips_list.txt" \
    -c copy \
    "$OUTPUT_DIR/merged_video.mp4"
echo "✅ Clips merged"

# ⑤ Audio mix করো (Voiceover + Background Music)
echo "-----------------------------------------"
echo "🎵 Step 4: Mixing audio..."

VOICEOVER="$AUDIO_DIR/voiceover.mp3"
MUSIC="$MUSIC_DIR/background.mp3"

if [ -f "$VOICEOVER" ] && [ -f "$MUSIC" ]; then
    ffmpeg -y \
        -i "$VOICEOVER" \
        -i "$MUSIC" \
        -filter_complex \
        "[0:a]volume=1.0[voice];[1:a]volume=0.12[music];[voice] [music]amix=inputs=2:duration=first[aout]" \
        -map "[aout]" \
        "$OUTPUT_DIR/mixed_audio.mp3"
    echo "✅ Voiceover + Music mixed"

elif [ -f "$VOICEOVER" ]; then
    cp "$VOICEOVER" "$OUTPUT_DIR/mixed_audio.mp3"
    echo "✅ Only voiceover used (no music found)"

else
    echo "⚠️ No audio found, video will be silent"
fi

# ⑥ Video + Audio জোড়া লাগাও
echo "-----------------------------------------"
echo "🎬 Step 5: Adding audio to video..."

if [ -f "$OUTPUT_DIR/mixed_audio.mp3" ]; then
    ffmpeg -y \
        -i "$OUTPUT_DIR/merged_video.mp4" \
        -i "$OUTPUT_DIR/mixed_audio.mp3" \
        -c:v copy \
        -c:a aac \
        -b:a 128k \
        -shortest \
        "$OUTPUT_DIR/video_with_audio.mp4"
    echo "✅ Audio added to video"
else
    cp "$OUTPUT_DIR/merged_video.mp4" "$OUTPUT_DIR/video_with_audio.mp4"
fi

# ⑦ Subtitle যোগ করো (থাকলে)
echo "-----------------------------------------"
echo "📝 Step 6: Adding subtitles..."

SUBTITLE="$AUDIO_DIR/subtitles.srt"

if [ -f "$SUBTITLE" ]; then
    ffmpeg -y \
        -i "$OUTPUT_DIR/video_with_audio.mp4" \
        -vf "subtitles=$(realpath $SUBTITLE):force_style='FontSize=16,FontName=Arial,PrimaryColour=&HFFFFFF,OutlineColour=&H000000,Outline=2,Bold=1,Alignment=2'" \
        -c:a copy \
        "$OUTPUT_DIR/final_video.mp4"
    echo "✅ Subtitles added"
else
    cp "$OUTPUT_DIR/video_with_audio.mp4" "$OUTPUT_DIR/final_video.mp4"
    echo "⚠️ No subtitle file, skipping"
fi

echo "========================================="
echo "🎉 Final video ready: output/final_video.mp4"
echo "========================================="
