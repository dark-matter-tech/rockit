const fs = require('fs');
const content = fs.readFileSync(process.argv[2], 'utf8');
let lines = 0;
let bytes = Buffer.byteLength(content, 'utf8');
for (let i = 0; i < content.length; i++) {
    if (content[i] === '\n') lines++;
}
console.log(lines + " " + bytes);
