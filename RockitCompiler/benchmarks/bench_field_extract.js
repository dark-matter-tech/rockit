const parts = [];
for (let i = 0; i < 100; i++) parts.push("f" + i);
const line = parts.join(",");

let result = "";
for (let iter = 0; iter < 500000; iter++) {
    let fieldIdx = 0;
    let start = 0;
    for (let j = 0; j < line.length; j++) {
        if (line[j] === ",") {
            if (fieldIdx === 50) {
                result = line.substring(start, j);
                break;
            }
            fieldIdx++;
            start = j + 1;
        }
    }
}
console.log(result);
