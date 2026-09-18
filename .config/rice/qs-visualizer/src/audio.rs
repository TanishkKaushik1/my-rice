use libpulse_binding::sample::{Format, Spec};
use libpulse_binding::stream::Direction;
use libpulse_binding::def::BufferAttr;
use libpulse_simple_binding::Simple;
use std::time::Duration;

const SAMPLE_RATE: u32 = 44100;
const CHANNELS: u8 = 2;
// 44100 Hz / 30 FPS = 1470 frames per chunk. Locks UI updates to 30 FPS.
const CHUNK_FRAMES: usize = 1470;

pub fn start_audio_stream<F>(mut callback: F)
where
    F: FnMut(&[f32]) + Send + 'static,
{
    let spec = Spec {
        format: Format::FLOAT32NE,
        channels: CHANNELS,
        rate: SAMPLE_RATE,
    };

    // Calculate exactly how many bytes are in one 30FPS frame
    let bytes_per_chunk = (CHUNK_FRAMES * CHANNELS as usize * 4) as u32;

    // Force PipeWire to buffer data instead of waking up every microsecond
    let attr = BufferAttr {
        maxlength: std::u32::MAX,
        tlength: std::u32::MAX,
        prebuf: std::u32::MAX,
        minreq: std::u32::MAX,
        fragsize: bytes_per_chunk, // Tell the server to only wake us up when 33ms of audio is ready
    };

    let simple = match Simple::new(
        None,
        "qs-visualizer",
        Direction::Record,
        Some("@DEFAULT_MONITOR@"),
        "Audio Capture",
        &spec,
        None,
        Some(&attr), // Apply the strict buffering rules here
    ) {
        Ok(s) => {
            println!("Native PipeWire capture started on @DEFAULT_MONITOR@");
            s
        },
        Err(e) => {
            eprintln!("Failed to connect to PipeWire: {}", e);
            return;
        }
    };

    let mut byte_buf = vec![0u8; bytes_per_chunk as usize];
    let mut mono_samples = Vec::with_capacity(CHUNK_FRAMES);

    loop {
        if let Err(e) = simple.read(&mut byte_buf) {
            eprintln!("Failed to read audio data: {}", e);
            std::thread::sleep(Duration::from_millis(200));
            continue;
        }

        mono_samples.clear();
        
        let mut i = 0;
        while i < byte_buf.len() {
            let left = f32::from_ne_bytes([byte_buf[i], byte_buf[i+1], byte_buf[i+2], byte_buf[i+3]]);
            let right = f32::from_ne_bytes([byte_buf[i+4], byte_buf[i+5], byte_buf[i+6], byte_buf[i+7]]);
            mono_samples.push((left + right) / 2.0);
            i += 8;
        }

        callback(&mono_samples);
    }
}