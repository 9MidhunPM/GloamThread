import { build } from 'esbuild';
import { Marked } from 'marked';
import { createHash } from 'node:crypto';
import { existsSync } from 'node:fs';
import { lstat, mkdir, mkdtemp, readFile, readdir, rename, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const web = path.dirname(fileURLToPath(import.meta.url));
const root = path.dirname(web);
const buildRoot = path.join(root, 'build');
const output = path.join(buildRoot, 'web-site');
const publicName = /^(?:help\.html|site-[A-Za-z0-9_-]+\.(?:js|css|png|webp|svg|woff2))$/;
const github = 'https://github.com/9MidhunPM/GloamThread/blob/main/';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const escape = value => String(value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));

async function validatePrevious(folder) {
  if (!existsSync(folder)) return;
  const directory = await lstat(folder);
  if (!directory.isDirectory() || directory.isSymbolicLink()) throw new Error('Website build output must be a real directory.');
  for (const file of await readdir(folder)) {
    const stat = await lstat(path.join(folder, file));
    if (!stat.isFile() || stat.isSymbolicLink() || (!publicName.test(file) && file !== 'site-manifest.json')) {
      throw new Error(`Unexpected previous website build entry; preserved: ${file}`);
    }
  }
}

async function copyAsset(stage, source) {
  const stat = await lstat(source);
  if (!stat.isFile() || stat.isSymbolicLink()) throw new Error(`Website asset must be a regular file: ${source}`);
  const bytes = await readFile(source);
  const extension = path.extname(source).toLowerCase();
  if (!['.png', '.webp', '.svg', '.woff2'].includes(extension)) throw new Error(`Unsupported website asset: ${source}`);
  const name = `site-${sha256(bytes).slice(0, 16)}${extension}`;
  await writeFile(path.join(stage, name), bytes);
  return name;
}

async function guideHtml(stage, css, script, favicon) {
  const markdown = await readFile(path.join(root, 'docs/PLAYER_GUIDE.md'), 'utf8');
  const parser = new Marked({ gfm: true });
  const tokens = parser.lexer(markdown);
  const sourceIds = new Set([...markdown.matchAll(/\bid=["']([^"']+)["']/g)].map(match => match[1]));
  // Preserve explicit Markdown anchors and the document skip target.
  const slugs = new Map([...sourceIds, 'guide'].map(id => [id, 1]));
  parser.use({ renderer: { heading({ tokens: inline, depth }) {
    const label = this.parser.parseInline(inline);
    const plain = label.replace(/<[^>]*>/g, '').replace(/&[^;]+;/g, '');
    const base = plain.toLowerCase().replace(/[^\p{L}\p{N}\s-]/gu, '').trim().replace(/\s+/g, '-');
    const count = slugs.get(base) || 0;
    slugs.set(base, count + 1);
    const id = `${base}${count ? `-${count}` : ''}`;
    const aliases = depth === 2 ? {
      '1': ['start-playing'], '2': ['modes', 'arena-story'], '3': ['controls'],
      '6': ['create-a-fighter'], '7': ['saves', 'saves-backups'], '8': ['troubleshooting'],
    } : {};
    const alias = aliases[plain.match(/^\d+/)?.[0]] || (depth === 3 && /accessibility/i.test(plain) ? ['accessibility'] : []);
    const anchor = alias.filter(id => !sourceIds.has(id)).map(id => `<span class="anchor-alias" id="${id}" aria-hidden="true"></span>`).join('');
    return `${anchor}<h${depth} id="${escape(id)}">${label}</h${depth}>\n`;
  } } });
  const copies = [];
  parser.walkTokens(tokens, token => {
    if (token.type !== 'link' && token.type !== 'image') return;
    const href = token.href || '';
    if (href.startsWith('#') || /^(?:https?:|mailto:)/i.test(href)) {
      if (token.type === 'image' && !href.startsWith('#')) throw new Error('Guide images must be original repository assets.');
      return;
    }
    const [filename, anchor] = href.split('#', 2);
    const source = path.resolve(root, 'docs', decodeURIComponent(filename));
    const relative = path.relative(root, source).split(path.sep).join('/');
    if (relative.startsWith('../') || path.isAbsolute(relative)) throw new Error(`Guide link escapes repository: ${href}`);
    if (token.type === 'image') {
      if (!relative.startsWith('docs/screenshots/') && !relative.startsWith('docs/media/')) throw new Error(`Guide image is not an approved public illustration: ${href}`);
      copies.push(copyAsset(stage, source).then(name => { token.href = name; }));
    } else if (relative === 'docs/PLAYER_GUIDE.md') {
      token.href = anchor ? `#${anchor}` : 'help.html';
    } else {
      token.href = `${github}${relative.split('/').map(encodeURIComponent).join('/')}${anchor ? `#${anchor}` : ''}`;
    }
  });
  await Promise.all(copies);
  const content = parser.parser(tokens);
  const sections = [
    ['start-playing', 'Start playing'], ['modes', 'Arena & Story'],
    ['controls', 'Controls'], ['saves', 'Saves & backups'],
    ['create-a-fighter', 'Create a fighter'], ['accessibility', 'Accessibility'],
    ['troubleshooting', 'Troubleshooting'],
  ];
  const nav = sections.map(([id, label]) => `<a href="#${id}">${label}</a>`).join('\n');
  const outline = [
    ['start-playing', 'Start playing'], ['modes', 'Choose a mode'], ['controls', 'Keyboard controls'],
  ].map(([id, label]) => `<a href="#${id}">${label}</a>`).join('\n');
  const template = await readFile(path.join(web, 'templates/help.html'), 'utf8');
  const html = template.replaceAll('@@GUIDE_CONTENT@@', content)
    .replaceAll('@@GUIDE_NAV@@', nav).replaceAll('@@GUIDE_OUTLINE@@', outline)
    .replaceAll('@@SITE_STYLE@@', css).replaceAll('@@HELP_SCRIPT@@', script)
    .replaceAll('@@SITE_FAVICON@@', favicon);
  const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
  if (new Set(ids).size !== ids.length) throw new Error('Generated guide contains duplicate heading or anchor IDs.');
  for (const [, anchor] of html.matchAll(/\bhref="#([^"]+)"/g)) {
    if (!ids.includes(anchor)) throw new Error(`Generated guide has a broken internal anchor: #${anchor}`);
  }
  if (/@@[A-Z_]+@@/.test(html)) throw new Error('Generated guide contains an unresolved build placeholder.');
  return html;
}

await mkdir(buildRoot, { recursive: true });
await validatePrevious(output);
const stage = await mkdtemp(path.join(buildRoot, '.web-site-'));
let previous;
try {
  for (const source of ['src/site.js', 'src/site.css', 'src/diorama.js', 'src/help.js', 'assets/display.woff2', 'assets/poster.webp']) {
    if (!existsSync(path.join(web, source))) throw new Error(`Missing website source: web/${source}`);
  }
  const result = await build({
    absWorkingDir: root,
    entryPoints: { site: 'web/src/site.js', help: 'web/src/help.js' },
    outdir: stage,
    bundle: true, splitting: true, format: 'esm', target: ['chrome110', 'firefox115'],
    minify: true, metafile: true, sourcemap: false,
    entryNames: 'site-[hash]', chunkNames: 'site-[hash]', assetNames: 'site-[hash]',
    loader: { '.png': 'file', '.webp': 'file', '.svg': 'file', '.woff2': 'file' },
    legalComments: 'inline', logLevel: 'warning',
  });
  const outputs = Object.entries(result.metafile.outputs);
  const entry = name => outputs.find(([, detail]) => detail.entryPoint === `web/src/${name}.js`);
  const site = entry('site');
  const help = entry('help');
  if (!site || !help || !site[1].cssBundle) throw new Error('Website build did not produce its script and stylesheet entries.');
  const css = path.basename(site[1].cssBundle);
  const script = path.basename(site[0]);
  const favicon = await copyAsset(stage, path.join(web, 'assets/favicon.svg'));
  const poster = await copyAsset(stage, path.join(web, 'assets/poster.webp'));
  await writeFile(path.join(stage, 'help.html'), await guideHtml(stage, css, path.basename(help[0]), favicon));
  const files = (await readdir(stage)).sort();
  const hashes = {};
  for (const file of files) {
    if (!publicName.test(file)) throw new Error(`Unexpected website output: ${file}`);
    hashes[file] = sha256(await readFile(path.join(stage, file)));
  }
  const manifest = { schema_version: 1, files, hashes, replacements: {
    '@@SITE_SCRIPT@@': script, '@@SITE_STYLE@@': css,
    '@@SITE_POSTER@@': poster, '@@SITE_FAVICON@@': favicon,
  } };
  await writeFile(path.join(stage, 'site-manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
  if (existsSync(output)) {
    previous = `${stage}.previous`;
    await rename(output, previous);
  }
  try { await rename(stage, output); }
  catch (error) { if (previous) await rename(previous, output); throw error; }
  // A cleanup failure must not misreport a complete publication as failed.
  if (previous) await rm(previous, { recursive: true }).catch(() => console.warn('Previous generated website copy could not be removed.'));
  console.log(`Built ${files.length} public website files in build/web-site.`);
} catch (error) {
  if (existsSync(stage)) await rm(stage, { recursive: true });
  throw error;
}
