#!/usr/bin/env python3
"""Independent WAV acceptance for original Sing tract candidate (stdlib only).

Reports spectral balance, time envelope, repeat-pattern proxy and voice-pitch
autocorrelation. These are acoustic proxies, NOT perceptual realism judgments.
"""
import argparse
import array
import hashlib
import json
import math
import struct
import sys
import wave
from pathlib import Path


def rms(values):
    return math.sqrt(sum(v*v for v in values) / max(1, len(values)))


def fft_power(samples):
    n=len(samples)
    re=[0.0] * n
    im=[0.0] * n
    for i,v in enumerate(samples):
        re[i] = v * (0.5 - 0.5 * math.cos(2*math.pi*i/(n-1)))
    j=0
    for i in range(1,n):
        bit=n>>1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i<j:
            re[i],re[j]=re[j],re[i]
            im[i],im[j]=im[j],im[i]
    width=2
    while width<=n:
        th=-2*math.pi/width
        wr,wi=math.cos(th),math.sin(th)
        half=width//2
        for k in range(0,n,width):
            cr,ci=1.0,0.0
            for i in range(k,k+half):
                vr=re[i+half]*cr-im[i+half]*ci
                vi=re[i+half]*ci+im[i+half]*cr
                ur,ui=re[i],im[i]
                re[i]=ur+vr
                im[i]=ui+vi
                re[i+half]=ur-vr
                im[i+half]=ui-vi
                cr,ci=cr*wr-ci*wi,cr*wi+ci*wr
        width <<= 1
    return [re[k]*re[k]+im[k]*im[k] for k in range(n//2)]


def analyze(path):
    with wave.open(str(path),'rb') as w:
        rate=w.getframerate()
        if w.getnchannels()!=1 or w.getsampwidth()!=2:
            raise ValueError("Only 16-bit mono PCM admitted")
        count=w.getnframes()
        raw=w.readframes(count)
    pcm=array.array("h")
    pcm.frombytes(raw)
    if sys.byteorder != "little":
        pcm.byteswap()
    data=[v/32768 for v in pcm]
    segment=rate//10
    # Ignore the attack first 200ms for envelope assessments, and for the
    # multi-stage demonstration inspect the open-breath first two seconds only.
    sample_end = 2*rate if path.name=="breath-to-voice.wav" else len(data)
    steady=data[2*segment:sample_end]
    windows=[rms(steady[k:k+segment]) for k in range(0,len(steady)-segment+1,segment)]
    mean=sum(windows)/len(windows)
    envelope_cv=rms([x-mean for x in windows])/mean if mean else 0
    nfft=4096
    # Mean over 8 independent, nonoverlapping slices from the steady interval.
    start=2*segment
    step=max(nfft,(sample_end-start- nfft)//7)
    spectra=[fft_power(data[k:k+nfft]) for k in range(start,sample_end-nfft+1,step)][:8]
    power=[sum(row[i] for row in spectra)/len(spectra) for i in range(nfft//2)]
    def band(lo,hi):
        low=int(lo*nfft/rate)
        high=min(len(power),int(hi*nfft/rate))
        return sum(power[low:high])
    low=band(100,1000)
    high=band(3000,9000)
    spectral_total=sum(power[1:])
    centroid=sum((k*rate/nfft)*p for k,p in enumerate(power))/max(1e-30,spectral_total)
    # Normalized autocorrelation is only a coarse *within-window* periodicity
    # proxy. We report the strongest 80..300Hz candidate and lag. It is not
    # evidence that a human would hear rhythm, or evidence of absent pumping.
    trial=steady[rate//3:rate//3+8192]
    best=0.0
    best_lag=0
    for lag in range(rate//300,rate//80):
        a=trial[:-lag]
        b=trial[lag:]
        ab=sum(x*y for x,y in zip(a,b))
        aa=sum(x*x for x in a)
        bb=sum(y*y for y in b)
        corr=ab/max(1e-30,math.sqrt(aa*bb))
        if corr>best:
            best,best_lag=corr,lag
    return {
        "file":path.name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
        "sampleRateHz":rate,"frames":len(data),"durationSeconds":len(data)/rate,
        "rmsDbFS":round(20*math.log10(max(1e-15,rms(data))),2),
        "peakDbFS":round(20*math.log10(max(1e-15,max(abs(x) for x in data))),2),
        "steady100msEnvelopeCV":round(envelope_cv,4),
        "spectralCentroidHz":round(centroid,1),
        "power3000to9000Over100to1000":round(high/max(1e-30,low),3),
        "voicingPeriodicityProxyMaxCorrelation":round(best,4),
        "voicingPeriodicityProxyAtHz":round(rate/best_lag,1) if best_lag else 0,
        "interpretation":"machine acoustic witness only; human breath realism not established"
    }


def main():
    p=argparse.ArgumentParser()
    p.add_argument("directory",type=Path)
    p.add_argument("--expected",type=Path)
    args=p.parse_args()
    found={x.name:analyze(x) for x in sorted(args.directory.glob("*.wav"))}
    if len(found)!=4:
        raise ValueError(f"Expected four Sing source-owned WAVs, got {list(found)}")
    if args.expected:
        wanted=json.loads(args.expected.read_text())
        for name,sha in wanted.items():
            if found[name]["sha256"]!=sha:
                raise ValueError(f"Source lock digest differs for {name}")
    print(json.dumps({"schema":"sing.tract.acoustic-audit.v1","results":found},indent=2,sort_keys=True))


if __name__=="__main__":
    main()
