use serde_json;

pub fn emit(data: &[f32]) {
    let json = serde_json::to_string(data).unwrap();
    println!("{}", json);
}