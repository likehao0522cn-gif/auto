const fs = require('fs');
const path = require('path');
let failed = false;

function checkFile(file) {
  let source = fs.readFileSync(file, 'utf8');
  source = source.replace(/\/\*[\s\S]*?\*\//g, '');
  source = source.replace(/\/\/.*$/gm, '');
  source = source.replace(/"(?:\\.|[^"\\])*"/g, '""');
  const stack = [];
  const pairs = { '}': '{', ')': '(', ']': '[' };
  for (let i = 0; i < source.length; i += 1) {
    const char = source[i];
    if ('{(['.includes(char)) stack.push({ char, i });
    if ('})]'.includes(char)) {
      const top = stack.pop();
      if (!top || top.char !== pairs[char]) {
        console.log(`MISMATCH ${file} at ${i}: ${char}`);
        failed = true;
        return;
      }
    }
  }
  if (stack.length) {
    console.log(`UNCLOSED ${file}: ${stack.slice(-5)}`);
    failed = true;
  }
}

function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'build') continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full);
    else if (full.endsWith('.swift')) checkFile(full);
  }
}

walk('.');
if (failed) process.exit(1);
console.log('All Swift files have balanced braces, brackets, and parentheses (rough check).');
