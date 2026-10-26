// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Registrazione dello schermo: nome del file, scelta dell'encoder e argomenti di wf-recorder (logica pura, senza audio).
.pragma library

function pad(n) { return (n < 10 ? "0" : "") + n; }

// rec-AAAAMMGG-HHMMSS.mp4
function fileName(d) {
    return "rec-" + d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + "-" + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds()) + ".mp4";
}

// wf-recorder con VA-API usa scale_vaapi: servono un encoder H.264 e il ridimensionamento (VideoProc), come in vainfo.
function vaapiOk(vainfoText) {
    var t = String(vainfoText);
    return /VAProfileH264\w*\s*:\s*VAEntrypointEncSlice/.test(t) && /VAEntrypointVideoProc/.test(t);
}

// Argomenti di wf-recorder. L'area richiede la geometria di slurp ("x,y WxH"): senza, non c'è niente da registrare ([]).
function recorderArgs(mode, geometry, encoder, file, render) {
    var out = [];
    if (mode === "area") {
        if (geometry === "") return [];
        out.push("-g", geometry);
    }
    if (encoder === "vaapi") out.push("-c", "h264_vaapi", "-d", render);
    else out.push("-c", "libx264", "-p", "preset=veryfast");
    out.push("-f", file);
    return out;
}
