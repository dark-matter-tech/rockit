fn main() {
    let mut line = String::from("f0");
    for i in 1..100 {
        line.push(',');
        line.push('f');
        line.push_str(&i.to_string());
    }

    let mut result = String::new();
    for _ in 0..500_000 {
        let mut field_idx = 0;
        let mut start = 0;
        let bytes = line.as_bytes();
        for j in 0..bytes.len() {
            if bytes[j] == b',' {
                if field_idx == 50 {
                    result = line[start..j].to_string();
                    break;
                }
                field_idx += 1;
                start = j + 1;
            }
        }
    }
    println!("{}", result);
}
