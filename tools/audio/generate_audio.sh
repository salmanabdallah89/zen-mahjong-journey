#!/usr/bin/env bash
# Generates the game's original procedural sound effects and ambience with
# ffmpeg (pure tones, envelopes and filtered noise; no samples, no third-party
# audio). Re-run from the project root:  bash tools/audio/generate_audio.sh
# Music and bird ambience are NOT generated; see docs/AUDIO_ASSETS.md.
set -euo pipefail
SFX=assets/audio/sfx
AMB=assets/audio/ambient
mkdir -p "$SFX" "$AMB"
R=44100
# Soft attack shared by tonal sounds (avoids clicks): rises over ~4 ms.
A="(1-exp(-t*250))"

tone() {  # name, duration, expression
  ffmpeg -loglevel error -y -f lavfi -i "aevalsrc=exprs='$3':s=$R:d=$2" \
    -af "afade=t=out:st=$(awk "BEGIN{print $2*0.8}"):d=$(awk "BEGIN{print $2*0.2}"),volume=-1dB" \
    -ac 1 -c:a pcm_s16le "$SFX/$1.wav"
}

# Tile select: soft wooden tap with a warm body.
tone sfx_tile_select 0.16 "$A*(0.55*sin(2*PI*1320*t)*exp(-t*55)+0.35*sin(2*PI*660*t)*exp(-t*38)+0.12*sin(2*PI*2640*t)*exp(-t*90))"
# Pair matched: two-partial bell chime (E6 + B6) with a gentle shimmer.
tone sfx_tile_match 1.10 "$A*(0.42*sin(2*PI*1318.5*t)*exp(-t*4.2)+0.26*sin(2*PI*1975.5*t)*exp(-t*5.5)+0.12*sin(2*PI*2637*t)*exp(-t*8)+0.08*sin(2*PI*659.3*t)*exp(-t*3))"
# Blocked tile: muted low thud.
tone sfx_tile_blocked 0.22 "$A*(0.6*sin(2*PI*196*t)*exp(-t*24)+0.25*sin(2*PI*98*t)*exp(-t*16))"
# Hint: three-note rising sparkle (C6 E6 G6).
tone sfx_hint 0.95 "$A*(0.32*sin(2*PI*1046.5*t)*exp(-t*6)+gte(t,0.08)*0.30*sin(2*PI*1318.5*(t-0.08))*exp(-(t-0.08)*6)+gte(t,0.16)*0.30*sin(2*PI*1568*(t-0.16))*exp(-(t-0.16)*5))"
# Undo: two descending soft notes (G5 then D5).
tone sfx_undo 0.45 "$A*(0.40*sin(2*PI*784*t)*exp(-t*14)+gte(t,0.09)*0.40*sin(2*PI*587.3*(t-0.09))*exp(-(t-0.09)*10))"
# Button click: tiny bamboo tick.
tone sfx_button_click 0.08 "$A*(1.0*sin(2*PI*1760*t)*exp(-t*120)+0.6*sin(2*PI*880*t)*exp(-t*80))"
# Level complete: plucked pentatonic arpeggio (D5 E5 G5 A5 D6) with harmonics.
P() { echo "gte(t,$2)*0.24*(sin(2*PI*$1*(t-$2))+0.35*sin(4*PI*$1*(t-$2))+0.12*sin(6*PI*$1*(t-$2)))*exp(-(t-$2)*3.2)"; }
tone sfx_level_complete 2.60 "$A*($(P 587.3 0)+$(P 659.3 0.16)+$(P 784 0.32)+$(P 880 0.48)+$(P 1174.7 0.64))"
# Reward: bright double chime (A6, then E7).
tone sfx_reward 1.20 "$A*(0.34*sin(2*PI*1760*t)*exp(-t*5)+gte(t,0.12)*0.30*sin(2*PI*2637*(t-0.12))*exp(-(t-0.12)*5)+0.1*sin(2*PI*880*t)*exp(-t*3))"
# Unlock: soft low gong with rising shimmer.
tone sfx_unlock 1.80 "$A*(0.40*sin(2*PI*220*t)*exp(-t*1.8)+0.18*sin(2*PI*331*t)*exp(-t*2.2)+0.12*sin(2*PI*(880+220*t)*t)*exp(-t*3))"

# Shuffle: soft whoosh of band-passed pink noise.
ffmpeg -loglevel error -y -f lavfi -i "anoisesrc=c=pink:r=$R:d=0.55:a=0.6:seed=7" \
  -af "bandpass=f=1800:width_type=q:w=0.9,afade=t=in:d=0.18,afade=t=out:st=0.25:d=0.3,volume=8dB" \
  -ac 1 -c:a pcm_s16le "$SFX/sfx_shuffle.wav"

# Ambience loops (Ogg Vorbis, 30 s). Noise is stationary, so the loop seam is
# not audible; wind's swell (0.1 Hz) completes whole cycles within 30 s.
ffmpeg -loglevel error -y -f lavfi -i "anoisesrc=c=pink:r=$R:d=30:a=0.5:seed=11" \
  -af "highpass=f=180,lowpass=f=2600,lowpass=f=5000,volume=-7dB" \
  -ac 1 -c:a libvorbis -q:a 3 "$AMB/ambient_waterfall.ogg"
ffmpeg -loglevel error -y -f lavfi -i "anoisesrc=c=brown:r=$R:d=30:a=0.7:seed=23" \
  -af "lowpass=f=520,highpass=f=60,tremolo=f=0.1:d=0.55,volume=-10dB" \
  -ac 1 -c:a libvorbis -q:a 3 "$AMB/ambient_wind.ogg"
echo "generated: $(ls "$SFX" | wc -l) sfx, $(ls "$AMB" | wc -l) ambience"
