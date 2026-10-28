import './site.css';

const links = [...document.querySelectorAll('.guide-sidebar a[href^="#"], .guide-outline a[href^="#"], .guide-mobile-contents a[href^="#"]')];
const headings = [...document.querySelectorAll('.guide-content h2[id], .guide-content h3[id]')];
const contents = document.querySelector('.guide-mobile-contents');

function headingId(id) {
  let target = document.getElementById(id);
  while (target && !/^H[23]$/.test(target.tagName)) {
    if (target.nextElementSibling) target = target.nextElementSibling;
    else {
      target = target.parentElement;
      if (target?.classList.contains('guide-content')) return id;
    }
  }
  return target?.id || id;
}

function markCurrent(id) {
  const current = headingId(id);
  // Subheadings without a navigation entry keep their parent section selected.
  if (!links.some(link => headingId(decodeURIComponent(link.hash.slice(1))) === current)) return;
  links.forEach(link => {
    if (headingId(decodeURIComponent(link.hash.slice(1))) === current) link.setAttribute('aria-current', 'location');
    else link.removeAttribute('aria-current');
  });
}

if ('IntersectionObserver' in window && headings.length) {
  const visible = new Map();
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => visible.set(entry.target.id, entry.isIntersecting));
    const current = headings.find(heading => visible.get(heading.id));
    if (current) markCurrent(current.id);
  }, { rootMargin: '-88px 0px -160px 0px', threshold: 0 });
  headings.forEach(heading => observer.observe(heading));
}

links.forEach(link => link.addEventListener('click', () => {
  markCurrent(decodeURIComponent(link.hash.slice(1)));
  if (contents && window.innerWidth < 900) contents.open = false;
}));
if (location.hash) markCurrent(decodeURIComponent(location.hash.slice(1)));
else if (headings.length) markCurrent(headings[0].id);
