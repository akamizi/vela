// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
.pragma library

// Nome passato come argomento a un comando (stampanti, job, servizi): lettere, cifre, «_», «.», «-», ma non può cominciare con «-»,
// altrimenti il comando lo leggerebbe come un'opzione (es. `cancel -a`).
function validName(n) { return typeof n === "string" && /^[A-Za-z0-9_.][A-Za-z0-9_.\-]*$/.test(n); }
