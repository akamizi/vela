// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
//! Formato dei messaggi verso Vela (versione 1): un oggetto JSON per riga, UTF-8, al massimo `MAX_LINE` byte.

use crate::json::Value;

pub const VERSION: i64 = 1;
pub const MAX_LINE: usize = 64 * 1024;
/// Lunghezza massima (in caratteri) delle stringhe che arrivano da fuori (nomi di layout, ecc.).
pub const MAX_STR: usize = 256;

/// Taglia una stringa esterna a `MAX_STR` caratteri.
pub fn clip(s: &str) -> String {
    s.chars().take(MAX_STR).collect()
}

fn obj(pairs: Vec<(&str, Value)>) -> Value {
    Value::Obj(pairs.into_iter().map(|(k, v)| (k.to_string(), v)).collect())
}

fn s(x: &str) -> Value {
    Value::Str(x.to_string())
}

pub fn hello(modules: &[String]) -> String {
    obj(vec![
        ("v", Value::Num(VERSION as f64)),
        ("type", s("hello")),
        ("modules", Value::Arr(modules.iter().map(|m| s(m)).collect())),
    ])
    .to_json()
}

pub fn state(module: &str, data: &Value) -> String {
    let line = obj(vec![("type", s("state")), ("module", s(module)), ("data", data.clone())]).to_json();
    if line.len() > MAX_LINE {
        return error(module, "stato troppo grande, scartato");
    }
    line
}

pub fn error(module: &str, message: &str) -> String {
    obj(vec![("type", s("error")), ("module", s(module)), ("message", s(&clip(message)))]).to_json()
}

pub fn tick(t: u64) -> String {
    obj(vec![("type", s("tick")), ("t", Value::Num(t as f64))]).to_json()
}

/// Nomi di modulo ammessi: minuscole e trattino basso, da 1 a 32 caratteri.
pub fn valid_module_name(n: &str) -> bool {
    !n.is_empty() && n.len() <= 32 && n.bytes().all(|b| b.is_ascii_lowercase() || b == b'_')
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::json::parse;

    #[test]
    fn messaggi_di_base() {
        assert_eq!(hello(&["night".into(), "sway".into()]), r#"{"v":1,"type":"hello","modules":["night","sway"]}"#);
        assert_eq!(hello(&[]), r#"{"v":1,"type":"hello","modules":[]}"#);
        assert_eq!(tick(42), r#"{"type":"tick","t":42}"#);
        let st = state("night", &parse(r#"{"on":true}"#).unwrap());
        assert_eq!(st, r#"{"type":"state","module":"night","data":{"on":true}}"#);
    }

    #[test]
    fn errore_con_testo_pericoloso_resta_una_riga_valida() {
        let line = error("sway", "a\nb\"c\u{0}\u{2028}");
        assert!(!line.contains('\n'));
        let v = parse(&line).unwrap();
        assert_eq!(v.get("message").unwrap().as_str(), Some("a\nb\"c\u{0}\u{2028}"));
    }

    #[test]
    fn stringhe_esterne_tagliate() {
        assert_eq!(clip(&"é".repeat(1000)).chars().count(), MAX_STR);
        assert_eq!(clip("breve"), "breve");
    }

    #[test]
    fn stato_troppo_grande_diventa_errore() {
        let big = Value::Str("x".repeat(MAX_LINE));
        let line = state("sway", &big);
        assert!(line.len() < 200);
        assert_eq!(parse(&line).unwrap().get("type").unwrap().as_str(), Some("error"));
    }

    #[test]
    fn nomi_di_modulo() {
        assert!(valid_module_name("night"));
        assert!(valid_module_name("a_b"));
        for bad in ["", "Night", "a-b", "a b", "../x", &"a".repeat(33)] {
            assert!(!valid_module_name(bad), "{bad:?}");
        }
    }
}
