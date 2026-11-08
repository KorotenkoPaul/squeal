# OUTDATED (v1, OpenAI TTS). The current file web/voice/two-knocks-door.mp3 = design/audio/two-knocks-door-v8.mp3:
# ElevenLabs Eleven v3 via Artlist (Lily: voice "Grace", whisper; door: voice "Mild", persuasive),
# mixed with ffmpeg: Lily close and slightly muffled, his voice through the door, one double knock at 4.5 s, 9.5 s.
#!/bin/sh
# Rebuilds web/voice/two-knocks-door.mp3: the voice through Lily's door (Two Knocks), recorded "on a phone".
# Voice: OpenAI text-to-speech (gpt-4o-mini-tts); the API key is supplied by the environment's proxy, never written here.
set -e
cd "$(dirname "$0")"
curl -sS -o door-raw.mp3 https://api.openai.com/v1/audio/speech -H "Content-Type: application/json" -d '{"model":"gpt-4o-mini-tts","voice":"ash","input":"Lil... it'"'"'s me. It'"'"'s freezing out here. Lil. Let me in.","instructions":"A young man speaking softly through a closed apartment door at 3am. Calm, slightly too calm, warm but subtly wrong, like someone imitating a voice they have only heard. Slow, with small unnatural pauses.","response_format":"mp3"}'
ffmpeg -loglevel error -y -f lavfi -i "anoisesrc=d=0.09:c=brown:a=0.9" -af "lowpass=f=260,afade=t=out:st=0.01:d=0.08,volume=3" knock1.wav
ffmpeg -loglevel error -y -f lavfi -i "anullsrc=r=44100:cl=mono" -t 0.7 sil.wav
ffmpeg -loglevel error -y -i knock1.wav -i sil.wav -filter_complex "[0:a]aresample=44100,aformat=channel_layouts=mono[k];[1:a]atrim=0:0.22[s1];[1:a]atrim=0:0.7[s2];[k]asplit[k1][k2];[k1][s1][k2][s2]concat=n=4:v=0:a=1[out]" -map "[out]" knocks.wav
ffmpeg -loglevel error -y -i door-raw.mp3 -af "aresample=44100,aformat=channel_layouts=mono,lowpass=f=1100,highpass=f=120,aecho=0.8:0.6:35|70:0.25|0.12,volume=1.4" voice.wav
ffmpeg -loglevel error -y -i knocks.wav -i voice.wav -filter_complex "[0:a]volume=0.5[k];[k][1:a]concat=n=2:v=0:a=1[a];anoisesrc=c=pink:a=0.006:d=30[n];[a][n]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-19:TP=-2:LRA=11[o]" -map "[o]" -ac 1 -ar 44100 -b:a 64k ../../web/voice/two-knocks-door.mp3
rm -f door-raw.mp3 knock1.wav sil.wav knocks.wav voice.wav
