const fs = require('fs');
const path = 'Core/Sources/NoteMath.swift';
let text = fs.readFileSync(path, 'utf8');
text = text.replace('return "in tune";', 'return "准";');
text = text.replace('return rounded > 0 ? "high \\(rounded) cents" : "low \\(abs(rounded)) cents";', 'return rounded > 0 ? "高 \\(rounded) 音分" : "低 \\(abs(rounded)) 音分";');
fs.writeFileSync(path, text, { encoding: 'utf8' });
console.log(text.slice(-320));
