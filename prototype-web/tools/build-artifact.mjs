// Inlines the game into one HTML file for the web preview. Usage: node tools/build-artifact.mjs <output.html>
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const gameDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'game');
const SCRIPTS = ['logic.js', 'surface.js', 'audio.js', 'flies.js', 'app.js'];

const output = process.argv[2];
if (!output) throw new Error('Pass the output file path as the first argument');

const read = (name) => readFile(join(gameDir, name), 'utf8');
const [html, css, ...scripts] = await Promise.all([read('index.html'), read('style.css'), ...SCRIPTS.map(read)]);
const body = html.match(/<!--BODY-->([\s\S]*)<!--\/BODY-->/);
if (!body) throw new Error('index.html is missing the BODY markers');

await writeFile(output, [
  '<title>Рисуй на говне</title>',
  '<meta name="claude:viewport-fit-sides" content="cover">',
  `<style>${css}</style>`,
  body[1],
  `<script>${scripts.join('\n')}</script>`,
].join('\n'));
