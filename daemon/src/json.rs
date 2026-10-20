// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
//! JSON minimo: serve a leggere le risposte di Sway e a scrivere i messaggi verso Vela.
//! Analizzatore con limiti (dimensione, profondità), scrittore con escape completo.

use std::fmt::Write;

/// Dimensione massima accettata per un documento da analizzare.
pub const MAX_INPUT: usize = 1 << 20;
/// Profondità massima di annidamento.
pub const MAX_DEPTH: usize = 32;

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Null,
    Bool(bool),
    Num(f64),
    Str(String),
    Arr(Vec<Value>),
    /// Coppie in ordine di inserimento (le chiavi doppie vincono l'ultima in `get`).
    Obj(Vec<(String, Value)>),
}

impl Value {
    pub fn get(&self, key: &str) -> Option<&Value> {
        match self {
            Value::Obj(v) => v.iter().rev().find(|(k, _)| k == key).map(|(_, v)| v),
            _ => None,
        }
    }
    pub fn as_str(&self) -> Option<&str> {
        match self {
            Value::Str(s) => Some(s),
            _ => None,
        }
    }
    pub fn as_array(&self) -> Option<&[Value]> {
        match self {
            Value::Arr(a) => Some(a),
            _ => None,
        }
    }
    pub fn as_i64(&self) -> Option<i64> {
        match self {
            Value::Num(n) if n.fract() == 0.0 && n.abs() < 9.0e15 => Some(*n as i64),
            _ => None,
        }
    }
    pub fn as_bool(&self) -> Option<bool> {
        match self {
            Value::Bool(b) => Some(*b),
            _ => None,
        }
    }

    /// Serializza in una sola riga (nessun a capo letterale: vanno tutti in escape).
    pub fn to_json(&self) -> String {
        let mut s = String::new();
        self.write(&mut s);
        s
    }

    fn write(&self, out: &mut String) {
        match self {
            Value::Null => out.push_str("null"),
            Value::Bool(b) => out.push_str(if *b { "true" } else { "false" }),
            Value::Num(n) => {
                if !n.is_finite() {
                    out.push_str("null");
                } else if n.fract() == 0.0 && n.abs() < 9.0e15 {
                    let _ = write!(out, "{}", *n as i64);
                } else {
                    let _ = write!(out, "{n}");
                }
            }
            Value::Str(s) => write_str(s, out),
            Value::Arr(a) => {
                out.push('[');
                for (i, v) in a.iter().enumerate() {
                    if i > 0 {
                        out.push(',');
                    }
                    v.write(out);
                }
                out.push(']');
            }
            Value::Obj(o) => {
                out.push('{');
                for (i, (k, v)) in o.iter().enumerate() {
                    if i > 0 {
                        out.push(',');
                    }
                    write_str(k, out);
                    out.push(':');
                    v.write(out);
                }
                out.push('}');
            }
        }
    }
}

/// Stringa JSON tra virgolette: escape di virgolette, barra inversa e di tutti i caratteri di controllo.
/// U+2028 e U+2029 vanno in escape perché alcuni interpreti JS li trattano come a capo.
fn write_str(s: &str, out: &mut String) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 || c == '\u{7f}' || c == '\u{2028}' || c == '\u{2029}' => {
                let _ = write!(out, "\\u{:04x}", c as u32);
            }
            c => out.push(c),
        }
    }
    out.push('"');
}

#[derive(Debug, PartialEq)]
pub struct JsonError(pub &'static str);

pub fn parse(text: &str) -> Result<Value, JsonError> {
    if text.len() > MAX_INPUT {
        return Err(JsonError("documento troppo grande"));
    }
    let mut p = Parser { b: text.as_bytes(), i: 0 };
    p.ws();
    let v = p.value(0)?;
    p.ws();
    if p.i != p.b.len() {
        return Err(JsonError("dati dopo il valore"));
    }
    Ok(v)
}

struct Parser<'a> {
    b: &'a [u8],
    i: usize,
}

impl Parser<'_> {
    fn ws(&mut self) {
        while matches!(self.b.get(self.i), Some(b' ' | b'\t' | b'\n' | b'\r')) {
            self.i += 1;
        }
    }

    fn peek(&self) -> Option<u8> {
        self.b.get(self.i).copied()
    }

    fn eat(&mut self, c: u8) -> Result<(), JsonError> {
        if self.peek() == Some(c) {
            self.i += 1;
            Ok(())
        } else {
            Err(JsonError("carattere inatteso"))
        }
    }

    fn literal(&mut self, word: &str, v: Value) -> Result<Value, JsonError> {
        if self.b[self.i..].starts_with(word.as_bytes()) {
            self.i += word.len();
            Ok(v)
        } else {
            Err(JsonError("valore non valido"))
        }
    }

    fn value(&mut self, depth: usize) -> Result<Value, JsonError> {
        if depth > MAX_DEPTH {
            return Err(JsonError("annidamento troppo profondo"));
        }
        match self.peek() {
            None => Err(JsonError("fine inattesa")),
            Some(b'n') => self.literal("null", Value::Null),
            Some(b't') => self.literal("true", Value::Bool(true)),
            Some(b'f') => self.literal("false", Value::Bool(false)),
            Some(b'"') => self.string().map(Value::Str),
            Some(b'[') => {
                self.i += 1;
                let mut a = Vec::new();
                self.ws();
                if self.peek() == Some(b']') {
                    self.i += 1;
                    return Ok(Value::Arr(a));
                }
                loop {
                    self.ws();
                    a.push(self.value(depth + 1)?);
                    self.ws();
                    match self.peek() {
                        Some(b',') => self.i += 1,
                        Some(b']') => {
                            self.i += 1;
                            return Ok(Value::Arr(a));
                        }
                        _ => return Err(JsonError("array non valido")),
                    }
                }
            }
            Some(b'{') => {
                self.i += 1;
                let mut o = Vec::new();
                self.ws();
                if self.peek() == Some(b'}') {
                    self.i += 1;
                    return Ok(Value::Obj(o));
                }
                loop {
                    self.ws();
                    let k = self.string()?;
                    self.ws();
                    self.eat(b':')?;
                    self.ws();
                    o.push((k, self.value(depth + 1)?));
                    self.ws();
                    match self.peek() {
                        Some(b',') => self.i += 1,
                        Some(b'}') => {
                            self.i += 1;
                            return Ok(Value::Obj(o));
                        }
                        _ => return Err(JsonError("oggetto non valido")),
                    }
                }
            }
            Some(b'-' | b'0'..=b'9') => self.number(),
            Some(_) => Err(JsonError("carattere inatteso")),
        }
    }

    /// Numeri secondo la grammatica JSON (niente zeri iniziali, niente "+", niente ".5").
    fn number(&mut self) -> Result<Value, JsonError> {
        let start = self.i;
        if self.peek() == Some(b'-') {
            self.i += 1;
        }
        match self.peek() {
            Some(b'0') => self.i += 1,
            Some(b'1'..=b'9') => self.digits(),
            _ => return Err(JsonError("numero non valido")),
        }
        if self.peek() == Some(b'.') {
            self.i += 1;
            if !matches!(self.peek(), Some(b'0'..=b'9')) {
                return Err(JsonError("numero non valido"));
            }
            self.digits();
        }
        if matches!(self.peek(), Some(b'e' | b'E')) {
            self.i += 1;
            if matches!(self.peek(), Some(b'+' | b'-')) {
                self.i += 1;
            }
            if !matches!(self.peek(), Some(b'0'..=b'9')) {
                return Err(JsonError("numero non valido"));
            }
            self.digits();
        }
        std::str::from_utf8(&self.b[start..self.i])
            .ok()
            .and_then(|t| t.parse::<f64>().ok())
            .map(Value::Num)
            .ok_or(JsonError("numero non valido"))
    }

    fn digits(&mut self) {
        while matches!(self.peek(), Some(b'0'..=b'9')) {
            self.i += 1;
        }
    }

    fn hex4(&mut self) -> Result<u32, JsonError> {
        let h = self.b.get(self.i..self.i + 4).ok_or(JsonError("escape non valido"))?;
        let mut n = 0u32;
        for &c in h {
            n = n * 16 + (c as char).to_digit(16).ok_or(JsonError("escape non valido"))?;
        }
        self.i += 4;
        Ok(n)
    }

    fn string(&mut self) -> Result<String, JsonError> {
        self.eat(b'"')?;
        let mut out: Vec<u8> = Vec::new();
        loop {
            match self.peek().ok_or(JsonError("stringa non terminata"))? {
                b'"' => {
                    self.i += 1;
                    return String::from_utf8(out).map_err(|_| JsonError("UTF-8 non valido"));
                }
                b'\\' => {
                    self.i += 1;
                    let c = self.peek().ok_or(JsonError("escape non valido"))?;
                    self.i += 1;
                    let ch = match c {
                        b'"' => '"',
                        b'\\' => '\\',
                        b'/' => '/',
                        b'b' => '\u{8}',
                        b'f' => '\u{c}',
                        b'n' => '\n',
                        b'r' => '\r',
                        b't' => '\t',
                        b'u' => {
                            let hi = self.hex4()?;
                            let cp = if (0xD800..0xDC00).contains(&hi) {
                                // coppia surrogata: deve seguire \uDC00..DFFF
                                if self.b.get(self.i..self.i + 2) != Some(b"\\u") {
                                    return Err(JsonError("surrogato isolato"));
                                }
                                self.i += 2;
                                let lo = self.hex4()?;
                                if !(0xDC00..0xE000).contains(&lo) {
                                    return Err(JsonError("surrogato isolato"));
                                }
                                0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00)
                            } else if (0xDC00..0xE000).contains(&hi) {
                                return Err(JsonError("surrogato isolato"));
                            } else {
                                hi
                            };
                            char::from_u32(cp).ok_or(JsonError("escape non valido"))?
                        }
                        _ => return Err(JsonError("escape non valido")),
                    };
                    let mut buf = [0u8; 4];
                    out.extend_from_slice(ch.encode_utf8(&mut buf).as_bytes());
                }
                c if c < 0x20 => return Err(JsonError("carattere di controllo nella stringa")),
                c => {
                    out.push(c);
                    self.i += 1;
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn obj(pairs: &[(&str, Value)]) -> Value {
        Value::Obj(pairs.iter().map(|(k, v)| (k.to_string(), v.clone())).collect())
    }

    #[test]
    fn scrive_e_rilegge() {
        let v = obj(&[
            ("a", Value::Num(1.0)),
            ("b", Value::Arr(vec![Value::Bool(true), Value::Null, Value::Str("x".into())])),
            ("c", Value::Num(2.5)),
        ]);
        let t = v.to_json();
        assert_eq!(t, r#"{"a":1,"b":[true,null,"x"],"c":2.5}"#);
        assert_eq!(parse(&t).unwrap(), v);
    }

    #[test]
    fn escape_in_scrittura() {
        let s = Value::Str("a\"b\\c\nd\te\u{1}f\u{7f}\u{2028}é😀".into()).to_json();
        assert_eq!(s, "\"a\\\"b\\\\c\\nd\\te\\u0001f\\u007f\\u2028é😀\"");
        assert!(!s.contains('\n'));
        assert_eq!(parse(&s).unwrap().as_str().unwrap(), "a\"b\\c\nd\te\u{1}f\u{7f}\u{2028}é😀");
    }

    #[test]
    fn numeri_non_finiti_diventano_null() {
        assert_eq!(Value::Num(f64::NAN).to_json(), "null");
        assert_eq!(Value::Num(f64::INFINITY).to_json(), "null");
        assert_eq!(Value::Num(-3.0).to_json(), "-3");
    }

    #[test]
    fn legge_risposta_tipo_sway() {
        let t = r#"[{"identifier":"1:1:AT","name":"AT Translated Set 2 keyboard","type":"keyboard",
            "xkb_layout_names":["Italian","English (US)"],"xkb_active_layout_index":1,
            "libinput":{"send_events":"enabled"}}]"#;
        let v = parse(t).unwrap();
        let k = &v.as_array().unwrap()[0];
        assert_eq!(k.get("type").unwrap().as_str(), Some("keyboard"));
        assert_eq!(k.get("xkb_active_layout_index").unwrap().as_i64(), Some(1));
        assert_eq!(k.get("xkb_layout_names").unwrap().as_array().unwrap().len(), 2);
        assert_eq!(k.get("libinput").unwrap().get("send_events").unwrap().as_str(), Some("enabled"));
    }

    #[test]
    fn escape_unicode_e_surrogati() {
        assert_eq!(parse(r#""\u00e9\ud83d\ude00\/""#).unwrap().as_str(), Some("é😀/"));
        assert!(parse(r#""\ud83d""#).is_err());
        assert!(parse(r#""\ude00""#).is_err());
        assert!(parse(r#""\ud83d\u0041""#).is_err());
        assert!(parse(r#""\u12""#).is_err());
    }

    #[test]
    fn rifiuta_json_malformato() {
        for bad in [
            "", "{", "[1,]", "{\"a\":}", "{\"a\" 1}", "[1 2]", "01", "+1", ".5", "1.", "1e", "tru", "nul", "'a'", "\"a", "\"\u{1}\"",
            "{} x", "[1]]", "{\"a\":1,}", "\"\\x\"", "-", "--1",
        ] {
            assert!(parse(bad).is_err(), "{bad:?}");
        }
    }

    #[test]
    fn accetta_numeri_validi() {
        for (t, n) in [("0", 0.0), ("-0", 0.0), ("12", 12.0), ("-1.5e2", -150.0), ("1E+2", 100.0), ("0.25", 0.25)] {
            assert_eq!(parse(t).unwrap(), Value::Num(n), "{t}");
        }
    }

    #[test]
    fn limiti_di_profondita_e_dimensione() {
        let ok = "[".repeat(MAX_DEPTH) + &"]".repeat(MAX_DEPTH);
        assert!(parse(&ok).is_ok());
        let deep = "[".repeat(MAX_DEPTH + 2) + &"]".repeat(MAX_DEPTH + 2);
        assert_eq!(parse(&deep), Err(JsonError("annidamento troppo profondo")));
        let huge = format!("\"{}\"", "a".repeat(MAX_INPUT));
        assert_eq!(parse(&huge), Err(JsonError("documento troppo grande")));
    }

    #[test]
    fn documento_troncato_non_manda_in_panico() {
        let full = r#"{"a":[1,2,{"b":"c\u00e9"}],"d":true}"#;
        for n in 0..full.len() {
            if full.is_char_boundary(n) {
                let _ = parse(&full[..n]);
            }
        }
    }

    #[test]
    fn chiave_doppia_vince_l_ultima() {
        assert_eq!(parse(r#"{"a":1,"a":2}"#).unwrap().get("a").unwrap().as_i64(), Some(2));
    }
}
