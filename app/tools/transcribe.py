#!/usr/bin/env python3
"""Turns a sermon recording into a timed transcript for testing the detector.

    pip install sherpa-onnx numpy
    ffmpeg -i sermon.mp3 -ac 1 -ar 16000 sermon.wav
    python3 tools/transcribe.py MODELS_DIR sermon.wav transcripts/sermon.jsonl

MODELS_DIR holds two downloads from
https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models :
    sherpa-onnx-whisper-small.en/   (unpacked .tar.bz2)
    silero_vad.onnx

This is a stand-in for Apple's on-device recogniser, which only runs on a Mac.
It writes one JSON object per line: {"start": seconds, "end": seconds, "text": "..."}.
Keep transcripts out of the public repo (see DECISIONS.md).
"""
import sys, wave, json, time
import numpy as np, sherpa_onnx
M=sys.argv[1]; wav=sys.argv[2]; out=sys.argv[3]
d=M+"/sherpa-onnx-whisper-small.en/"
rec=sherpa_onnx.OfflineRecognizer.from_whisper(encoder=d+"small.en-encoder.int8.onnx",decoder=d+"small.en-decoder.int8.onnx",tokens=d+"small.en-tokens.txt",num_threads=1,language="en")
cfg=sherpa_onnx.VadModelConfig(); cfg.silero_vad.model=M+"/silero_vad.onnx"; cfg.silero_vad.min_silence_duration=0.35; cfg.silero_vad.max_speech_duration=20; cfg.sample_rate=16000
vad=sherpa_onnx.VoiceActivityDetector(cfg,buffer_size_in_seconds=120)
w=wave.open(wav); n=w.getnframes(); a=np.frombuffer(w.readframes(n),dtype=np.int16).astype(np.float32)/32768
win=cfg.silero_vad.window_size; segs=[]; t0=time.time()
f=open(out,"w")
def drain():
    while not vad.empty():
        s=vad.front; st=s.start/16000; x=np.array(s.samples,dtype=np.float32); vad.pop()
        # hard split anything over 28s
        for k in range(0,len(x),28*16000):
            c=x[k:k+28*16000]
            if len(c)<1600: continue
            r=rec.create_stream(); r.accept_waveform(16000,c); rec.decode_stream(r)
            txt=r.result.text.strip()
            if txt:
                f.write(json.dumps({"start":round(st+k/16000,2),"end":round(st+(k+len(c))/16000,2),"text":txt})+"\n"); f.flush()
for i in range(0,len(a)-win,win):
    vad.accept_waveform(a[i:i+win]); drain()
vad.flush(); drain()
print("done",wav,round(time.time()-t0),"s")
