#!/usr/bin/env python3
# Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
# greetd finto per provare il greeter senza root né greetd vero (D-055): parla il protocollo IPC di greetd
# (lunghezza u32 in ordine nativo + JSON) su un socket Unix indicato da GREETD_SOCK. Utente «mizi», password «ok».
# Uso: fake-greetd.py <socket> <file-log>
import json, os, socket, struct, sys, threading

path, log = sys.argv[1], sys.argv[2]

def note(msg):
    with open(log, "a") as f: f.write(msg + "\n")

def recv_exact(c, n):
    buf = b""
    while len(buf) < n:
        d = c.recv(n - len(buf))
        if not d: return None
        buf += d
    return buf

def send(c, obj):
    data = json.dumps(obj).encode()
    c.sendall(struct.pack("=I", len(data)) + data)

def serve(c):
    user = None
    while True:
        h = recv_exact(c, 4)
        if h is None: return
        req = json.loads(recv_exact(c, struct.unpack("=I", h)[0]))
        t = req["type"]
        note("richiesta: " + t + (" " + req.get("username", "") if t == "create_session" else ""))
        if t == "create_session":
            user = req["username"]
            send(c, {"type": "auth_message", "auth_message_type": "secret", "auth_message": "Password: "})
        elif t == "post_auth_message_response":
            if user == "mizi" and req.get("response") == "ok":
                send(c, {"type": "success"})
            else:
                send(c, {"type": "error", "error_type": "auth_error", "description": "Authentication failed"})
        elif t == "start_session":
            note("avvio sessione: " + json.dumps(req.get("cmd")))
            send(c, {"type": "success"})
        elif t == "cancel_session":
            send(c, {"type": "success"})

if os.path.exists(path): os.unlink(path)
s = socket.socket(socket.AF_UNIX)
s.bind(path); s.listen(1)
note("in ascolto")
while True:
    c, _ = s.accept()
    threading.Thread(target=serve, args=(c,), daemon=True).start()
