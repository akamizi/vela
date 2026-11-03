// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
.pragma library

// Coda delle notifiche trattenute mentre una finestra è a schermo intero (D-065). `ids` sono gli identificatori in ordine di
// arrivo. Aggiunge `id` (senza doppioni: una notifica che si ripete non si conta due volte) e, se si supera `max`, scarta le più
// vecchie. Restituisce { ids, dropped }: la nuova coda e gli id scartati (dal più vecchio), da chiudere.
function hold(ids, id, max) {
    var out = ids.filter(function (x) { return x !== id; });
    out.push(id);
    var limit = Math.max(1, Math.floor(Number(max)) || 1);
    var dropped = out.length > limit ? out.slice(0, out.length - limit) : [];
    return { ids: out.slice(dropped.length), dropped: dropped };
}

function isHeld(ids, id) { return ids.indexOf(id) >= 0; }
