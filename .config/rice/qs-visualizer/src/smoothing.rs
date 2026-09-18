pub struct Smoother {
    prev: Vec<f32>,
    alpha: f32,
}

impl Smoother {
    pub fn new(size: usize, alpha: f32) -> Self {
        Self {
            prev: vec![0.0; size],
            alpha,
        }
    }

pub fn apply(&mut self, input: Vec<f32>) -> Vec<f32> {
    let mut out = vec![0.0; input.len()];

    for i in 0..input.len() {
        let smoothed = self.alpha * input[i] + (1.0 - self.alpha) * self.prev[i];

        if input[i] < 0.01 {
            self.prev[i] *= 0.96;  // decay
        } else {
            self.prev[i] = smoothed;
        }

        if self.prev[i] < 0.005 {
            self.prev[i] = 0.0;
        }

        out[i] = self.prev[i];
    }

    out
}
}