// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
//! Stato dei moduli e decisione su cosa scrivere: solo i cambiamenti, al massimo una volta ogni `min_gap` per modulo.
//! Logica pura (il tempo arriva dal chiamante), quindi testabile senza thread né orologio.

use crate::json::Value;
use crate::proto;
use std::collections::BTreeMap;
use std::time::{Duration, Instant};

pub struct Hub {
    sent: BTreeMap<String, Value>,
    pending: BTreeMap<String, Value>,
    last: BTreeMap<String, Instant>,
    min_gap: Duration,
}

impl Hub {
    pub fn new(min_gap: Duration) -> Self {
        Hub { sent: BTreeMap::new(), pending: BTreeMap::new(), last: BTreeMap::new(), min_gap }
    }

    /// Un modulo ha un nuovo stato. Restituisce le righe da scrivere adesso (vuoto se uguale o rimandato).
    pub fn submit(&mut self, module: &str, data: Value, now: Instant) -> Vec<String> {
        if self.sent.get(module) == Some(&data) {
            self.pending.remove(module); // tornato a com'era già stato comunicato
            return vec![];
        }
        let ready = self.last.get(module).map_or(true, |t| now.duration_since(*t) >= self.min_gap);
        if ready {
            self.pending.remove(module);
            vec![self.send(module, data, now)]
        } else {
            self.pending.insert(module.to_string(), data);
            vec![]
        }
    }

    /// Righe rimandate che adesso si possono scrivere.
    pub fn due(&mut self, now: Instant) -> Vec<String> {
        let ready: Vec<String> = self
            .pending
            .keys()
            .filter(|m| self.last.get(*m).map_or(true, |t| now.duration_since(*t) >= self.min_gap))
            .cloned()
            .collect();
        ready
            .into_iter()
            .filter_map(|m| self.pending.remove(&m).map(|d| self.send(&m, d, now)))
            .collect()
    }

    /// Quando va richiamato `due` (se c'è qualcosa in attesa).
    pub fn next_deadline(&self) -> Option<Instant> {
        self.pending.keys().filter_map(|m| self.last.get(m).map(|t| *t + self.min_gap)).min()
    }

    fn send(&mut self, module: &str, data: Value, now: Instant) -> String {
        let line = proto::state(module, &data);
        self.sent.insert(module.to_string(), data);
        self.last.insert(module.to_string(), now);
        line
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const GAP: Duration = Duration::from_millis(100);
    fn n(x: f64) -> Value {
        Value::Num(x)
    }

    #[test]
    fn il_primo_stato_esce_subito_e_l_uguale_no() {
        let t0 = Instant::now();
        let mut h = Hub::new(GAP);
        assert_eq!(h.submit("a", n(1.0), t0).len(), 1);
        assert!(h.submit("a", n(1.0), t0 + GAP * 5).is_empty());
    }

    #[test]
    fn i_cambi_ravvicinati_si_accorpano_e_vince_l_ultimo() {
        let t0 = Instant::now();
        let mut h = Hub::new(GAP);
        h.submit("a", n(1.0), t0);
        assert!(h.submit("a", n(2.0), t0 + Duration::from_millis(10)).is_empty());
        assert!(h.submit("a", n(3.0), t0 + Duration::from_millis(20)).is_empty());
        assert_eq!(h.next_deadline(), Some(t0 + GAP));
        assert!(h.due(t0 + Duration::from_millis(50)).is_empty());
        let out = h.due(t0 + GAP);
        assert_eq!(out.len(), 1);
        assert!(out[0].contains("\"data\":3"));
        assert_eq!(h.next_deadline(), None);
    }

    #[test]
    fn tornare_al_valore_gia_comunicato_annulla_l_attesa() {
        let t0 = Instant::now();
        let mut h = Hub::new(GAP);
        h.submit("a", n(1.0), t0);
        h.submit("a", n(2.0), t0 + Duration::from_millis(10));
        assert!(h.submit("a", n(1.0), t0 + Duration::from_millis(20)).is_empty());
        assert!(h.due(t0 + GAP * 2).is_empty());
    }

    #[test]
    fn i_moduli_sono_indipendenti() {
        let t0 = Instant::now();
        let mut h = Hub::new(GAP);
        assert_eq!(h.submit("a", n(1.0), t0).len(), 1);
        assert_eq!(h.submit("b", n(1.0), t0).len(), 1);
    }

    #[test]
    fn dopo_la_pausa_il_cambio_esce_subito() {
        let t0 = Instant::now();
        let mut h = Hub::new(GAP);
        h.submit("a", n(1.0), t0);
        assert_eq!(h.submit("a", n(2.0), t0 + GAP).len(), 1);
    }
}
