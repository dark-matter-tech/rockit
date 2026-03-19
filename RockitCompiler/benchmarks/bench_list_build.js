const n = 500000;
const arr = [];
for (let i = 0; i < n; i++) {
    arr.push(i);
}
let sum = 0;
for (let i = 0; i < arr.length; i++) {
    sum += arr[i];
}
console.log(sum);
