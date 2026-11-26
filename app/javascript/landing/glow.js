// Pointer light shared by the landing and the sign-in pages: glass cards are lit from where the
// pointer is, and a soft glow trails the mouse. Never shown for touch or with reduced motion.
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const litCards = '.integration-rows article, .human-stages article, .auth-card';
let glowX = 0;
let glowY = 0;
let targetX = 0;
let targetY = 0;
let glowFrame = 0;

// Looked up on every use: Turbo replaces <body> on the sign-in pages, taking the glow with it.
function glowElement() {
  let glow = document.querySelector('.cursor-glow');
  if (!glow) {
    glow = document.createElement('div');
    glow.className = 'cursor-glow';
    glow.setAttribute('aria-hidden', 'true');
    document.body.append(glow);
  }
  return glow;
}

function moveGlow() {
  glowX += (targetX - glowX) * 0.12;
  glowY += (targetY - glowY) * 0.12;
  glowElement().style.transform = `translate(${glowX}px, ${glowY}px)`;
  glowFrame = Math.abs(targetX - glowX) + Math.abs(targetY - glowY) > 0.5 ? requestAnimationFrame(moveGlow) : 0;
}

document.addEventListener('pointermove', event => {
  const card = event.target.closest(litCards);
  if (card) {
    const box = card.getBoundingClientRect();
    card.style.setProperty('--mx', `${event.clientX - box.left}px`);
    card.style.setProperty('--my', `${event.clientY - box.top}px`);
  }
  const glow = glowElement();
  if (event.pointerType !== 'mouse' || reducedMotion.matches) {
    glow.classList.remove('is-visible');
    return;
  }
  targetX = event.clientX;
  targetY = event.clientY;
  glow.classList.add('is-visible');
  glowFrame ||= requestAnimationFrame(moveGlow);
}, { passive: true });
document.documentElement.addEventListener('pointerleave', () => document.querySelector('.cursor-glow')?.classList.remove('is-visible'));
