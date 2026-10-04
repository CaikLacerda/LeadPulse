// The landing illustrates workflows; it never calls product or provider APIs.
const workflows = {
  support: {
    start: 'Receber uma chamada',
    question: 'Entender a solicitação',
    decision: 'Pode ser resolvido?',
    action: 'Consultar e orientar',
    human: 'Transferir com contexto'
  },
  qualification: {
    start: 'Iniciar um contato',
    question: 'Entender a necessidade',
    decision: 'Há aderência ao perfil?',
    action: 'Registrar no CRM',
    human: 'Encaminhar ao comercial'
  },
  scheduling: {
    start: 'Receber uma solicitação',
    question: 'Coletar serviço e local',
    decision: 'Há disponibilidade?',
    action: 'Registrar agendamento',
    human: 'Buscar outra solução'
  }
};

const explanations = {
  start: ['Cada processo tem um ponto de partida.', 'Uma chamada de entrada ou saída inicia o workflow com o contexto da sua operação.'],
  question: ['A conversa constrói o contexto.', 'A IA coleta as informações necessárias, esclarece respostas e prepara os dados para a próxima decisão.'],
  decision: ['Uma decisão, caminhos diferentes.', 'O workflow avalia as informações coletadas e aplica os critérios da sua operação. A conversa segue pelo caminho adequado.'],
  action: ['Suas ferramentas entram na conversa.', 'Uma API consulta ou registra informações no sistema. O resultado da ação orienta a continuidade da conversa.'],
  human: ['A pessoa certa, com o contexto necessário.', 'Defina quando encaminhar ou transferir. Sua equipe recebe o que já foi conversado para dar continuidade ao processo.']
};

function selectNode(key) {
  document.querySelectorAll('[data-node]').forEach(button => {
    const active = button.dataset.node === key;
    button.setAttribute('aria-pressed', String(active));
    button.classList.toggle('selected', active);
  });
  const [heading, description] = explanations[key];
  document.querySelector('[data-flow-heading]').textContent = heading;
  document.querySelector('[data-flow-description]').textContent = description;
}

function selectWorkflow(kind) {
  const workflow = workflows[kind];
  if (!workflow) return;
  document.querySelectorAll('[data-workflow-kind]').forEach(button => {
    button.setAttribute('aria-pressed', String(button.dataset.workflowKind === kind));
  });
  document.querySelectorAll('[data-node-title]').forEach(title => {
    title.textContent = workflow[title.dataset.nodeTitle];
  });
  selectNode('decision');
}

document.querySelectorAll('[data-workflow-kind]').forEach(button => button.addEventListener('click', () => selectWorkflow(button.dataset.workflowKind)));
document.querySelectorAll('[data-node]').forEach(button => button.addEventListener('click', () => selectNode(button.dataset.node)));
document.querySelectorAll('[data-usecase]').forEach(link => link.addEventListener('click', () => selectWorkflow(link.dataset.usecase)));

const stories = [
  ['“Preciso de uma visita técnica na quinta pela manhã.”', '“Claro. Qual é o serviço e o endereço da visita?”', 'Etapa do workflow', 'Coletar informações para o atendimento'],
  ['“É uma instalação no escritório, no centro.”', '“Vou consultar os horários disponíveis para esse serviço.”', 'Tool acionada: consultar disponibilidade', 'Agenda retorna uma opção para quinta, às 10h'],
  ['“Quinta às 10h funciona para mim.”', '“Sua visita foi agendada. Vou enviar a confirmação.”', 'Ação concluída no exemplo', 'Agendamento registrado e confirmação encaminhada']
];
const storyFields = ['person', 'agent', 'action-label', 'action-result'];

document.querySelectorAll('[data-story]').forEach(button => button.addEventListener('click', () => {
  const story = stories[Number(button.dataset.story)];
  document.querySelectorAll('[data-story]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
  storyFields.forEach((field, i) => {
    document.querySelector(`[data-${field}]`).textContent = story[i];
  });
  playTurn();
}));

const menu = document.querySelector('.menu-toggle');
const navigation = document.querySelector('#main-navigation');

function closeMenu(returnFocus = false) {
  navigation.classList.remove('is-open');
  menu.setAttribute('aria-expanded', 'false');
  if (returnFocus) menu.focus();
}

menu.addEventListener('click', () => {
  const open = menu.getAttribute('aria-expanded') !== 'true';
  navigation.classList.toggle('is-open', open);
  menu.setAttribute('aria-expanded', String(open));
});
navigation.querySelectorAll('a').forEach(link => link.addEventListener('click', () => closeMenu()));
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && menu.getAttribute('aria-expanded') === 'true') closeMenu(true);
});
matchMedia('(min-width: 801px)').addEventListener('change', () => closeMenu());

const dialog = document.querySelector('.image-dialog');
let imageTrigger;

document.querySelectorAll('[data-image]').forEach(button => button.addEventListener('click', () => {
  imageTrigger = button;
  const image = dialog.querySelector('img');
  image.src = button.dataset.image;
  image.alt = button.dataset.caption;
  document.querySelector('#image-caption').textContent = button.dataset.caption;
  dialog.showModal();
  lenis?.stop();
}));
dialog.querySelector('.dialog-close').addEventListener('click', () => dialog.close());
dialog.addEventListener('click', event => {
  if (event.target === dialog) dialog.close();
});
dialog.addEventListener('close', () => {
  lenis?.start();
  imageTrigger?.focus();
});

const video = document.querySelector('.hero video');
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let filmVisible = true;

// The hero film plays in a loop while on screen; with reduced motion or data saving only the poster shows.
function updatePlayback() {
  if (reducedMotion.matches || navigator.connection?.saveData) {
    video.pause();
    if (video.hasAttribute('src')) {
      video.removeAttribute('src');
      video.load();
    }
    return;
  }
  if (!video.hasAttribute('src')) video.src = video.dataset.source;
  if (!filmVisible || document.hidden) {
    video.pause();
  } else {
    // Autoplay can still be refused (e.g. battery saver); the poster then stays.
    video.play().catch(() => {});
  }
}

reducedMotion.addEventListener('change', updatePlayback);
document.addEventListener('visibilitychange', updatePlayback);
new IntersectionObserver(entries => {
  filmVisible = entries[0].isIntersecting;
  updatePlayback();
}).observe(document.querySelector('.hero-film'));

// Motion layer. Pre-reveal hiding only applies under .motion-ready, so content is never hidden without it.
function syncMotionReady() {
  document.documentElement.classList.toggle('motion-ready', !reducedMotion.matches);
}

syncMotionReady();
reducedMotion.addEventListener('change', syncMotionReady);

const conversation = document.querySelector('.conversation-content');

// Replays the turn sequence: person speaks, voice bars, agent answers, action receipt.
function playTurn() {
  conversation.classList.remove('is-playing');
  void conversation.offsetWidth;
  conversation.classList.add('is-playing');
}

const revealObserver = new IntersectionObserver(entries => entries.forEach(entry => {
  if (!entry.isIntersecting) return;
  revealObserver.unobserve(entry.target);
  if (entry.target === conversation) playTurn();
  else entry.target.classList.add('is-visible');
}), { threshold: 0.15, rootMargin: '0px 0px -8% 0px' });
document.querySelectorAll('.section-heading, .section-copy, .reliability-copy, .integration-rows, .human-stages, .usecase-list, .closing-copy').forEach(group => {
  group.classList.add('reveal');
  [...group.children].forEach((child, n) => child.style.setProperty('--n', n));
});
document.querySelectorAll('.workflow-studio, .simulation-figure, .analytics-figure, .conversation-example, .closing-shot').forEach(block => block.classList.add('reveal-block'));
document.querySelectorAll('[data-reveal], .reveal, .reveal-block').forEach(element => revealObserver.observe(element));

// Scroll-linked progress (0..1) for the hero and its film; the CSS decides what it moves.
const hero = document.querySelector('.hero');
const film = document.querySelector('.hero-film');
const nav = document.querySelector('.site-nav');
const clamp01 = value => Math.min(1, Math.max(0, value)).toFixed(3);
let scrollFrame = 0;

function updateScrollMotion() {
  scrollFrame = 0;
  nav.classList.toggle('is-top', scrollY < 8);
  hero.style.setProperty('--scroll', clamp01(scrollY / hero.offsetHeight));
  // Measured from its untransformed container, so the film's own tilt never feeds back into its progress.
  const filmTop = film.parentElement.getBoundingClientRect().top;
  film.style.setProperty('--scroll', clamp01((innerHeight - filmTop) / (innerHeight * 0.75)));
}

function requestScrollMotion() {
  scrollFrame ||= requestAnimationFrame(updateScrollMotion);
}

addEventListener('scroll', requestScrollMotion, { passive: true });
addEventListener('resize', requestScrollMotion);
updateScrollMotion();

// Inertial smooth scrolling (vendor/javascript/lenis.js); native scrolling with reduced motion.
let lenis = null;

function syncSmoothScroll() {
  if (reducedMotion.matches) {
    lenis?.destroy();
    lenis = null;
  } else if (!lenis && window.Lenis) {
    lenis = new Lenis({ autoRaf: true, anchors: true });
  }
}

syncSmoothScroll();
reducedMotion.addEventListener('change', syncSmoothScroll);

// Builder demo: a signal walks the workflow and alternates branches. It runs only while visible,
// stops when the visitor picks a step, and can be paused (WCAG 2.2.2).
const canvas = document.querySelector('.flow-canvas');
const demoToggle = document.querySelector('.demo-toggle');
const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
let demoRun = 0;
let demoPaused = false;
let studioVisible = false;

function light(selector) {
  canvas.querySelector(selector).classList.add('is-lit');
}

function clearLights() {
  canvas.querySelectorAll('.is-lit').forEach(element => element.classList.remove('is-lit'));
}

async function runDemo(run) {
  const live = async ms => {
    await wait(ms);
    return run === demoRun;
  };
  canvas.classList.add('is-demo');
  for (let branch = 'yes'; ; branch = branch === 'yes' ? 'no' : 'yes') {
    light('[data-node="start"]');
    if (!await live(380)) return;
    for (const [segment, node] of [['in1', 'question'], ['in2', 'decision'], [branch, branch === 'yes' ? 'action' : 'human']]) {
      light(`[data-segment="${segment}"]`);
      if (segment === branch) light(`.branch-${branch}`);
      if (!await live(520)) return;
      light(`[data-node="${node}"]`);
      if (!await live(380)) return;
    }
    if (!await live(1800)) return;
    clearLights();
    if (!await live(700)) return;
  }
}

function updateDemo() {
  const eligible = !reducedMotion.matches;
  demoToggle.hidden = !eligible;
  demoToggle.textContent = demoPaused ? 'Reproduzir demonstração' : 'Pausar demonstração';
  demoRun++;
  canvas.classList.remove('is-demo');
  clearLights();
  if (eligible && !demoPaused && studioVisible && !document.hidden) runDemo(demoRun);
}

demoToggle.addEventListener('click', () => {
  demoPaused = !demoPaused;
  updateDemo();
});
document.querySelectorAll('[data-node]').forEach(button => button.addEventListener('click', () => {
  demoPaused = true;
  updateDemo();
}));
document.querySelectorAll('[data-workflow-kind], [data-usecase]').forEach(trigger => trigger.addEventListener('click', updateDemo));
reducedMotion.addEventListener('change', updateDemo);
document.addEventListener('visibilitychange', updateDemo);
new IntersectionObserver(entries => {
  studioVisible = entries[0].isIntersecting;
  updateDemo();
}, { threshold: 0.35 }).observe(document.querySelector('[data-workflow]'));
