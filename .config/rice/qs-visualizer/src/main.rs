mod audio;
mod fft;
mod smoothing;
mod output;

use fft::{FFTProcessor, to_bars};
use smoothing::Smoother;

const FFT_SIZE: usize = 1024;
const BARS: usize = 32;

fn normalize(mut data: Vec<f32>) -> Vec<f32> {
    let max = data.iter().cloned().fold(0.0, f32::max);

    if max > 0.0 {
        for v in data.iter_mut() {
            *v /= max;
        }
    }

    for v in data.iter_mut() {
        *v = v.clamp(0.0, 1.0);
        if *v < 0.02 {
            *v = 0.0;
        }
    }
    data
}

fn main() {
    let mut fft = FFTProcessor::new(FFT_SIZE);
    let mut smoother = Smoother::new(BARS, 0.5);
    
    let mut was_silent = false;

    audio::start_audio_stream(move |data| {
        // Calculate RMS volume to detect silence
        let mut sum_squares = 0.0;
        for &sample in data {
            sum_squares += sample * sample;
        }
        let rms = (sum_squares / data.len() as f32).sqrt();

        // If audio is practically silent, sleep the visualizer
        if rms < 0.001 {
            if !was_silent {
                // Send one final flatline frame to clear the UI
                let zeros = vec![0.0; BARS];
                output::emit(&zeros);
                was_silent = true;
            }
            // Skip the FFT and JSON serialization completely
            return; 
        }
        
        was_silent = false;

        let spectrum = fft.process(data);
        let bars = to_bars(&spectrum, BARS);
        let smoothed = smoother.apply(bars);
        let normalized = normalize(smoothed);

        output::emit(&normalized);
    });
}