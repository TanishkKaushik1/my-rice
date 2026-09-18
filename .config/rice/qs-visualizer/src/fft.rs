use rustfft::{FftPlanner, num_complex::Complex};
use std::sync::Arc;

pub struct FFTProcessor {
    size: usize,
    fft: Arc<dyn rustfft::Fft<f32>>,
    buffer: Vec<Complex<f32>>, // Pre-allocated to prevent hot-loop allocations
}

impl FFTProcessor {
    pub fn new(size: usize) -> Self {
        let mut planner = FftPlanner::new();
        let fft = planner.plan_fft_forward(size);
        let buffer = vec![Complex { re: 0.0, im: 0.0 }; size];

        Self { size, fft, buffer }
    }

    // Note: process now requires &mut self to mutate the internal buffer
    pub fn process(&mut self, input: &[f32]) -> Vec<f32> {
        // Overwrite the existing buffer in place
        for i in 0..self.size {
            if i < input.len() {
                self.buffer[i] = Complex { re: input[i], im: 0.0 };
            } else {
                self.buffer[i] = Complex { re: 0.0, im: 0.0 };
            }
        }

        self.fft.process(&mut self.buffer);

        self.buffer.iter().map(|c| c.norm()).collect()
    }
}

pub fn to_bars(spectrum: &[f32], bars: usize) -> Vec<f32> {
    let mut result = vec![0.0; bars];

    for (i, &val) in spectrum.iter().enumerate().take(spectrum.len() / 2) {
        let freq = i as f32 / (spectrum.len() as f32 / 2.0);
        let log_index = (freq.powf(0.4) * bars as f32) as usize;
        let idx = log_index.min(bars - 1);
        result[idx] += val;
    }

    result
}