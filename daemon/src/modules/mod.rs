// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
//! Moduli del demone: ognuno gira in un proprio thread e manda eventi al ciclo principale.
//! Un guasto (errore o panico) in un modulo non ferma gli altri.

mod night;
mod sway;

use crate::json::Value;
use std::sync::mpsc::Sender;

pub enum Event {
    /// Stato completo del modulo (il confronto con l'ultimo comunicato lo fa `Hub`).
    State(String, Value),
    /// Problema del modulo: va a Vela come messaggio `error`.
    Error(String, String),
    /// Vela ha chiuso il canale: uscire.
    Quit,
}

pub trait Module: Send {
    fn name(&self) -> &'static str;
    /// Corpo del thread: manda `Event::State` ogni volta che qualcosa cambia (almeno una volta all'inizio).
    fn run(self: Box<Self>, tx: Sender<Event>);
}

/// Crea i moduli richiesti. I nomi sconosciuti vengono restituiti a parte (non sono un errore fatale).
pub fn build(names: &[String]) -> (Vec<Box<dyn Module>>, Vec<String>) {
    let mut mods: Vec<Box<dyn Module>> = Vec::new();
    let mut unknown = Vec::new();
    for n in names {
        match n.as_str() {
            "night" => mods.push(Box::new(night::Night::new())),
            "sway" => mods.push(Box::new(sway::Sway::new())),
            _ => unknown.push(n.clone()),
        }
    }
    (mods, unknown)
}
