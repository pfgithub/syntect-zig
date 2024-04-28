import {$} from "bun";

// 1. test cross-compile target
console.log("test cross-compile targets:");

const all_targets = await Bun.file("supported_targets").text();
const atsplit = all_targets.split("\n").map(m => m.trim()).filter(m => !!m);
for(let [i, target] of atsplit.entries()) {
    console.log("target: "+target + " (" + i + " / " + atsplit.length + ")");
    await $`zig build -Dtarget=${target}`;
}

// 2. test native target
await $`zig build run`;
