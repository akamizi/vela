// Copyright (C) 2026 Maurizio Cavalletti — Licensed under the EUPL-1.2
import assert from "node:assert";
import { load, plain } from "./run.mjs";

const ud = load("shell/core/userdirs.js");
const ml = load("shell/core/musiclib.js");

// userdirs
assert.strictEqual(ud.userDir('XDG_MUSIC_DIR="$HOME/Musica"\n', "/home/u", "XDG_MUSIC_DIR"), "/home/u/Musica");
assert.strictEqual(ud.userDir('XDG_MUSIC_DIR="$HOME/"\n', "/home/u", "XDG_MUSIC_DIR"), "");
assert.strictEqual(ud.userDir('XDG_MUSIC_DIR="$HOME"\n', "/home/u", "XDG_MUSIC_DIR"), "");
assert.strictEqual(ud.userDir("# vuoto\n", "/home/u", "XDG_MUSIC_DIR"), "");
assert.strictEqual(ud.userDir('# c\nXDG_VIDEOS_DIR="$HOME/Filmati"\nXDG_MUSIC_DIR="$HOME/Música"\n', "/home/u", "XDG_VIDEOS_DIR"), "/home/u/Filmati");
assert.strictEqual(ud.userDir('XDG_MUSIC_DIR="/dati/musica"\n', "/home/u", "XDG_MUSIC_DIR"), "/dati/musica");

// candidati
assert.deepStrictEqual(plain(ml.musicDirCandidates('XDG_MUSIC_DIR="$HOME/Música"\n', "/home/u")),
    ["/home/u/Música", "/home/u/Musica", "/home/u/Music"]);
assert.deepStrictEqual(plain(ml.musicDirCandidates('XDG_MUSIC_DIR="$HOME/Musica"\n', "/home/u")),
    ["/home/u/Musica", "/home/u/Music"]);
assert.deepStrictEqual(plain(ml.musicDirCandidates("", "/home/u")), ["/home/u/Musica", "/home/u/Music"]);

// estensioni
assert.strictEqual(ml.isAudio("A.FLAC"), true);
assert.strictEqual(ml.isAudio("x.opus"), true);
assert.strictEqual(ml.isAudio("a.txt"), false);
assert.strictEqual(ml.isAudio("mp3"), false);
assert.strictEqual(ml.isAudio(".mp3"), true);

// raggruppamento
const g = ml.groupFolders(["/m/Rock/b b.mp3", "/m/Rock/a|a.flac", "/m/jazz/x.opus", "/m/note.txt", "/m/s.mp3", "/m/Rock/new\nline.ogg"], "/m");
assert.deepStrictEqual(plain(g.map(f => f.rel)), ["", "jazz", "Rock"]);
assert.deepStrictEqual(plain(g[2].files.map(f => f.name)), ["a|a.flac", "b b.mp3", "new\nline.ogg"]);
assert.strictEqual(g[2].files[1].path, "/m/Rock/b b.mp3");
assert.strictEqual(g[2].path, "/m/Rock");
assert.strictEqual(g[0].path, "/m");
console.log("ok musiclib");
