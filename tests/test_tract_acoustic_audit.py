"""Regression checks for the independent original-WAV auditor."""
import importlib.util
import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "sing_tract_audit", ROOT / "tools" / "analyze_tract_audio.py")
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class TestOriginalTractAudioAudit(unittest.TestCase):
    def test_fft_places_196hz_pitch_near_expected_bin(self):
        n=4096
        sample=[math.sin(2*math.pi*196*k/48000) for k in range(n)]
        spectrum=audit.fft_power(sample)
        dominant=max(range(1,len(spectrum)),key=lambda i:spectrum[i])
        self.assertAlmostEqual(dominant*48000/n,196,delta=7)

    def test_noise_is_finite_in_spectral_analysis(self):
        n=4096
        x=1
        a=[]
        for _ in range(n):
            x ^= (x << 13) & 0xffffffff
            x ^= x >> 17
            x ^= (x << 5) & 0xffffffff
            a.append((x&0xffff)/32767.5-1)
        spectrum=audit.fft_power(a)
        self.assertEqual(len(spectrum),n//2)
        self.assertTrue(all(math.isfinite(y) and y>=0 for y in spectrum))
        self.assertGreater(sum(spectrum[1000:1700]),0)

    def test_rms_and_zeros(self):
        self.assertEqual(audit.rms([0]*12),0)
        self.assertAlmostEqual(audit.rms([1,-1,1,-1]),1)


if __name__=="__main__":
    unittest.main()
