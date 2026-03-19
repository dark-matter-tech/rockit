// Build 100-column CSV line
const parts = [];
for (let i = 0; i < 100; i++) parts.push("f" + i);
const line = parts.join(",");

let count = 0;
for (let i = 0; i < 500000; i++) {
    count = line.split(",").length;
}
console.log(count);
