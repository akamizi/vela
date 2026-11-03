// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
// Microfono in uso (D-064): quali app stanno registrando da un microfono (una sorgente audio vera) in questo momento.
// Si ricava dai collegamenti PipeWire: un flusso di registrazione (nodo stream, non uscita) collegato e attivo a un nodo che non
// è né un'uscita né un flusso. Registrare il monitor di un'uscita (per esempio catturare l'audio del desktop) non conta:
// il monitor appartiene a un'uscita. I flussi in pausa non contano. I nomi arrivano dalle proprietà dei flussi
// (application.name, poi il programma, poi il nome del nodo).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    function nameOf(node) {
        var p = node.properties || {};
        return p["application.name"] || p["application.process.binary"] || p["node.name"] || node.description || node.name || "?";
    }

    // Nomi delle app che registrano dal microfono, senza doppioni e in ordine alfabetico.
    readonly property var apps: {
        var seen = {}, out = [], links = Pipewire.links.values;
        for (var i = 0; i < links.length; i++) {
            var l = links[i];
            if (!l.target || !l.source || l.state !== PwLinkState.Active) continue;
            if (!l.target.isStream || l.target.isSink) continue;              // il bersaglio è un flusso di registrazione
            if (l.source.isStream || l.source.isSink) continue;               // la sorgente è un dispositivo, non un'uscita o un flusso
            var n = nameOf(l.target);
            if (!seen[n]) { seen[n] = true; out.push(n); }
        }
        out.sort();
        return out;
    }
    readonly property bool active: apps.length > 0

    // Le proprietà dei nodi e lo stato dei collegamenti arrivano solo per gli oggetti seguiti.
    PwObjectTracker {
        objects: Pipewire.links.values.concat(Pipewire.nodes.values.filter(function (n) { return n.isStream; }))
    }
}
