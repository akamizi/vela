// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load, plain } from "./run.mjs";

const sub = load("shell/core/subsonic.js");
const eq = (a, b) => assert.deepStrictEqual(plain(a), b);

// file env
let e = sub.parseEnv('SUBSONIC_URL="https://s.example.org/"\r\nSUBSONIC_USER=u\n# commento\n\nSUBSONIC_PASS=\'p$"&\'\n');
eq(e, { url: "https://s.example.org", user: "u", pass: 'p$"&', missing: [] });
eq(sub.parseEnv("SUBSONIC_URL=http://x\nSUBSONIC_USER=u\n").missing, ["SUBSONIC_PASS"]);
eq(sub.parseEnv("").missing, ["SUBSONIC_URL", "SUBSONIC_USER", "SUBSONIC_PASS"]);
assert.strictEqual(sub.parseEnv("export SUBSONIC_USER=ann\n").user, "ann");
assert.strictEqual(sub.parseEnv("SUBSONIC_PASS=a=b\n").pass, "a=b");

assert.strictEqual(sub.validUrl("https://a.b"), true);
assert.strictEqual(sub.validUrl("http://a.b:4533/x"), true);
assert.strictEqual(sub.validUrl("file:///x"), false);
assert.strictEqual(sub.validUrl(""), false);

// autenticazione e indirizzi
const md5 = s => "MD5(" + s + ")";
const auth = sub.authQuery("u", "pw", "ab12", md5);
assert.strictEqual(auth, "u=u&t=MD5(pwab12)&s=ab12&v=1.16.1&c=vela&f=json");
assert.ok(sub.authQuery("a&b", "p", "s", md5).startsWith("u=a%26b&"));
assert.strictEqual(sub.albumListUrl("https://s", auth), "https://s/rest/getAlbumList2.view?type=newest&size=100&" + auth);
assert.strictEqual(sub.albumUrl("https://s", "al 1", auth), "https://s/rest/getAlbum.view?id=al%201&" + auth);
assert.strictEqual(sub.streamUrl("https://s", "7", auth), "https://s/rest/stream.view?id=7&" + auth);

// album
let r = sub.parseAlbums({ "subsonic-response": { status: "failed", error: { message: "Wrong username or password." } } });
assert.strictEqual(r.ok, false);
assert.strictEqual(r.error, "Wrong username or password.");
r = sub.parseAlbums({ "subsonic-response": { status: "ok", albumList2: { album: [
    { id: "1", name: "Live", artist: "A" }, { id: "2", name: "Live", artist: "A" }] } } });
assert.strictEqual(r.ok, true);
eq(r.albums, [{ id: "1", label: "A - Live" }, { id: "2", label: "A - Live" }]);
r = sub.parseAlbums({ "subsonic-response": { status: "ok", albumList2: {} } });
assert.strictEqual(r.ok, true);
eq(r.albums, []);
assert.strictEqual(sub.parseAlbums({}).ok, false);
assert.strictEqual(sub.parseAlbums(null).ok, false);

// brani
r = sub.parseSongs({ "subsonic-response": { status: "ok", album: { song: [
    { id: "s1", track: 1, title: "Uno", artist: "A" }, { id: "s2", title: "Senza numero", artist: "A" }] } } });
assert.strictEqual(r.ok, true);
eq(r.songs, [{ id: "s1", label: "1. Uno", artist: "A", title: "Uno" }, { id: "s2", label: "Senza numero", artist: "A", title: "Senza numero" }]);
assert.strictEqual(sub.parseSongs({ "subsonic-response": { status: "ok", album: {} } }).songs.length, 0);

// playlist
const pl = sub.playlistText([{ artist: "A", title: "T", url: "https://s/x" }]);
assert.strictEqual(pl, "#EXTM3U\n#EXTINF:-1,A - T\nhttps://s/x\n");
assert.ok(!sub.playlistText([{ artist: "A\nB", title: "T", url: "https://s/x" }]).includes("A\nB"));
console.log("ok subsonic");
