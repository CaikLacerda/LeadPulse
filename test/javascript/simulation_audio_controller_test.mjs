import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { test } from "node:test"
import vm from "node:vm"

const code = readFileSync(new URL("../../app/javascript/controllers/simulation_audio_controller.js", import.meta.url), "utf8")
  .replace('import { Controller } from "@hotwired/stimulus"', "class Controller { dispatch(name, options) { this.events.push({ name, ...options.detail }) } }")
  .replace("export default class", "globalThis.AudioController = class")

function harness() {
  const contexts = [], sockets = [], timers = new Map(), pageListeners = new Set()
  let timerId = 0
  class AudioContext {
    constructor() { this.currentTime = 0; this.state = "running"; this.nodes = []; contexts.push(this) }
    createGain() { return { gain: { value: 1, setTargetAtTime() {} }, connect() {} } }
    createStereoPanner() { return { pan: {}, connect() {}, disconnect() {} } }
    createBuffer(channels, samples, rate) { return { duration: samples / rate, copyToChannel() {} } }
    createBufferSource() {
      const context = this
      const node = { connect() {}, disconnect() {}, start(at) { this.startAt = at }, stop() { this.stopAt = context.currentTime; this.stops = (this.stops || 0) + 1 } }
      this.nodes.push(node); return node
    }
    resume() { return Promise.resolve() }
    close() { this.state = "closed"; return Promise.resolve() }
  }
  class Socket {
    constructor() { this.listeners = new Map(); this.closed = false; sockets.push(this) }
    addEventListener(event, handler) { this.listeners.set(event, handler) }
    removeEventListener(event, handler) { if (this.listeners.get(event) === handler) this.listeners.delete(event) }
    emit(event, data) { this.listeners.get(event)?.(data) }
    close() { this.closed = true; this.emit("close") }
  }
  const scope = {
    ArrayBuffer, Uint8Array, Float32Array, DataView, URL, console,
    window: { AudioContext, addEventListener: (name, handler) => pageListeners.add(handler), removeEventListener: (name, handler) => pageListeners.delete(handler),
      setTimeout(handler) { const id = ++timerId; timers.set(id, handler); return id }, clearTimeout(id) { timers.delete(id) } },
    document: { querySelector() { return null } }, WebSocket: Socket,
    fetch: async () => ({ ok: true, json: async () => ({ url: "wss://example.test/audio", ticket: "offline" }) })
  }
  vm.runInNewContext(code, scope)
  function controller(element = { dataset: {} }) {
    const c = new scope.AudioController(); c.element = element; c.events = []; c.activeValue = true; c.debugValue = true; c.ticketUrlValue = "/ticket"; c.connect(); return c
  }
  return { scope, controller, contexts, sockets, timers, pageListeners }
}
function overlap(nodes) {
  const spans = nodes.map(node => ({ start: node.startAt, end: Math.min(node.startAt + node.buffer.duration, node.stopAt ?? Infinity) }))
    .filter(span => span.end > span.start).sort((a, b) => a.start - b.start)
  return spans.some((span, i) => i > 0 && span.start < spans[i - 1].end)
}
// 100 ms de PCM16 8 kHz com 1 byte de origem; fala = amostras não nulas, silêncio = padding da linha.
function frame(origin = 0, { silent = false } = {}) { const data = new Uint8Array(1601); data[0] = origin; if (!silent) data.fill(0x10, 1); return data.buffer }
// A FastAPI envia cada janela como o par (agente, fornecedor), nessa ordem.
function pair(c, { agent = {}, counterpart = { silent: true } } = {}) { c.handleFrame(frame(0, agent)); c.handleFrame(frame(1, counterpart)) }
const EXPLICIT_DISCARDS = ["reconnect", "socket_closed", "teardown"]
// Cada node criado corresponde, em ordem, a um evento "scheduled".
function nodesOf(c, origin) {
  const scheduled = c.events.filter(row => row.name === "scheduled")
  return c.audioContext.nodes.map((node, i) => ({ node, ...scheduled[i] })).filter(row => row.origin === origin)
}
function playedFully({ node }) { return node.stopAt === undefined || node.stopAt >= node.startAt + node.buffer.duration }
// DROPPED_AUDIO_SEGMENT: chunk que deixa de tocar inteiro sem descarte explícito.
function droppedSegments(c, origin) {
  const stopped = new Map(c.events.filter(row => row.name === "stopped").map(row => [row.node_id, row]))
  return nodesOf(c, origin).filter(row => !playedFully(row) && !EXPLICIT_DISCARDS.includes(stopped.get(row.node_id)?.stop_reason))
}
function contiguous(rows) { return rows.every((row, i) => i === 0 || Math.abs(row.scheduled_start - rows[i - 1].scheduled_end) < 1e-9) }

// Same Web Audio contract, with clock and network entirely controlled offline.
test("a burst never schedules overlapping live nodes for the same origin", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  for (let i = 0; i < 12; i++) pair(c)
  for (const origin of ["agent", "counterpart"]) assert.equal(overlap(nodesOf(c, origin).map(row => row.node)), false)
  const records = c.events.filter(x => x.name === "scheduled")
  assert.ok(records.every(row => row.scheduled_start >= row.previous_end))
  assert.equal(records.length, 24)
  for (const row of records) for (const key of ["origin", "node_id", "chunk_sequence", "scheduled_start", "duration", "scheduled_end", "currentTime", "nextStartTime"]) assert.ok(key in row, key)
})

test("a queue above the target never stops a playing or future node of either origin", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  for (let i = 0; i < 10; i++) pair(c, { counterpart: {} })
  c.audioContext.currentTime = 0.15
  for (let i = 0; i < 5; i++) pair(c, { counterpart: {} })
  assert.ok(c.audioContext.nodes.every(node => node.stops === undefined))
  assert.equal(c.events.filter(row => row.name === "stopped").length, 0)
  for (const origin of ["agent", "counterpart"]) {
    const rows = nodesOf(c, origin)
    assert.deepEqual(rows.map(row => row.chunk_sequence), Array.from({ length: 15 }, (_, i) => i + 1))
    assert.ok(contiguous(rows))
  }
})

test("SIM: 8 chunks of one long sentence crossing the queue target play 1..8 exactly once", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  // Produtor mais rápido que o relógio de áudio: a fila passa do alvo no meio da frase.
  for (let i = 0; i < 4; i++) pair(c)
  c.audioContext.currentTime = 0.05
  for (let i = 0; i < 4; i++) pair(c)
  const rows = nodesOf(c, "agent")
  assert.ok(rows.at(-1).scheduled_start > 0.05 + 0.6, "a fila precisa ultrapassar o alvo")
  assert.deepEqual(rows.filter(playedFully).map(row => row.chunk_sequence), [1, 2, 3, 4, 5, 6, 7, 8])
  assert.ok(contiguous(rows), "sem buraco e sem overlap")
  assert.equal(droppedSegments(c, "agent").length, 0)
  assert.equal(c.events.filter(row => row.name === "silence-trimmed").length, 0)
})

test("an explicit discard (reconnect) after chunk 4 keeps 1..4 and drops 5..8 with the reason", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  for (let i = 0; i < 8; i++) pair(c)
  c.audioContext.currentTime = nodesOf(c, "agent")[3].scheduled_end
  await c.openSocket()
  const rows = nodesOf(c, "agent")
  assert.deepEqual(rows.filter(playedFully).map(row => row.chunk_sequence), [1, 2, 3, 4])
  const stops = c.events.filter(row => row.name === "stopped" && row.origin === "agent" && row.state_before_stop !== "ended")
  assert.deepEqual(stops.map(row => row.chunk_sequence), [5, 6, 7, 8])
  for (const row of stops) {
    // O chunk 5 começa exatamente no instante do descarte: nenhuma amostra de 5..8 toca.
    assert.equal(row.stop_reason, "reconnect"); assert.ok(row.actual_stop_time <= row.scheduled_start + 1e-9)
    for (const key of ["node_id", "scheduled_start", "scheduled_end", "actual_stop_time"]) assert.ok(key in row, key)
  }
  assert.equal(droppedSegments(c, "agent").length, 0)
})

test("above the target only windows silent on both sides are skipped, keeping both sides aligned", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  for (let i = 0; i < 8; i++) pair(c)
  pair(c, { agent: { silent: true }, counterpart: {} })
  pair(c, { agent: { silent: true }, counterpart: { silent: true } })
  pair(c, { agent: {}, counterpart: { silent: true } })
  const trimmed = c.events.filter(row => row.name === "silence-trimmed")
  assert.deepEqual(trimmed.map(row => [row.origin, row.chunk_sequence]), [["agent", 10], ["counterpart", 10]])
  const agent = nodesOf(c, "agent"), counterpart = nodesOf(c, "counterpart")
  assert.deepEqual(agent.map(row => row.chunk_sequence), [1, 2, 3, 4, 5, 6, 7, 8, 9, 11])
  assert.deepEqual(agent.map(row => row.scheduled_start), counterpart.map(row => row.scheduled_start))
  assert.ok(contiguous(agent))
})

test("a network stall followed by a burst plays every chunk without stopping nodes", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  for (let i = 0; i < 3; i++) pair(c)
  c.audioContext.currentTime = 1.0
  for (let i = 0; i < 10; i++) pair(c)
  const rows = nodesOf(c, "agent")
  assert.deepEqual(rows.filter(playedFully).map(row => row.chunk_sequence), Array.from({ length: 13 }, (_, i) => i + 1))
  assert.ok(contiguous(rows.slice(3)))
  assert.equal(c.events.filter(row => row.name === "stopped").length, 0)
})

test("an unpaired chunk is still scheduled, never lost", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  c.handleFrame(frame(0)); c.handleFrame(frame(0)); c.handleFrame(frame(1))
  assert.deepEqual(nodesOf(c, "agent").map(row => row.chunk_sequence), [1, 2])
  assert.deepEqual(nodesOf(c, "counterpart").map(row => row.chunk_sequence), [1])
})

test("teardown explicitly stops every future node", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  c.handleFrame(frame()); c.handleFrame(frame(1)); const context = c.audioContext
  c.stop()
  assert.ok(context.nodes.every(node => node.stops === 1))
  assert.ok(c.events.filter(row => row.name === "stopped").every(row => row.stop_reason === "teardown"))
  assert.ok(h.sockets.every(socket => socket.closed))
})

test("reconnect retires old audio and ignores a queued old onmessage/onclose", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  const first = h.sockets[0], oldMessage = first.listeners.get("message"), oldClose = first.listeners.get("close")
  first.emit("message", { data: frame() }); first.emit("message", { data: frame(1) }); const node = c.audioContext.nodes[0]
  await c.openSocket()
  assert.equal(first.closed, true)
  assert.equal(node.stops, 1)
  assert.equal(c.events.find(row => row.name === "stopped").stop_reason, "reconnect")
  const count = c.audioContext.nodes.length
  oldMessage({ data: frame() }); oldClose()
  assert.equal(c.audioContext.nodes.length, count)
  assert.equal(c.socket, h.sockets[1])
  assert.equal(h.timers.size, 0)
})

test("a late ticket cannot reopen the monitor after stop", async () => {
  const h = harness(), c = h.controller(); let resolve
  h.scope.fetch = () => new Promise(done => { resolve = done })
  const activation = c.activate(); c.stop()
  resolve({ ok: true, json: async () => ({ url: "wss://example.test/audio", ticket: "late" }) })
  await activation
  assert.equal(h.sockets.length, 0)
})

test("two concurrent ticket requests create only the newest WebSocket", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  const resolve = []; h.scope.fetch = () => new Promise(done => resolve.push(done))
  const first = c.openSocket(), second = c.openSocket()
  for (const done of resolve.reverse()) done({ ok: true, json: async () => ({ url: "wss://example.test/audio", ticket: "offline" }) })
  await Promise.all([first, second])
  assert.equal(h.sockets.filter(socket => !socket.closed).length, 1)
})

test("duplicate connect and duplicate controllers on an element do not leak schedulers", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  const context = c.audioContext; pair(c); c.connect()
  assert.equal(c.audioContext, context)
  assert.equal(h.pageListeners.size, 1)
  const replacement = h.controller(c.element); await replacement.activate()
  assert.equal(context.state, "closed")
  assert.ok(context.nodes.every(node => node.stops === 1))
  assert.equal(h.sockets.filter(socket => !socket.closed).length, 1)
})

test("a repeated close notification arms only one reconnect", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  const close = h.sockets[0].listeners.get("close"); close(); close()
  assert.equal(h.timers.size, 1)
})


test("unknown origins cannot create an extra timeline", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  c.handleFrame(frame(7))
  assert.equal(c.audioContext.nodes.length, 0)
})

test("a corrupted nextStartTime is detected and cannot overlap a live node", async () => {
  const h = harness(), c = h.controller(); await c.activate()
  pair(c); c.nextStartTime[0] = c.nextStartTime[1] = 0; pair(c)
  assert.equal(overlap(nodesOf(c, "agent").map(row => row.node)), false)
  assert.ok(c.events.some(row => row.name === "overlap-prevented"))
})

// Replay offline de uma captura real: SIMULATION_AUDIO_REPLAY_DIR=<captura> [SIMULATION_AUDIO_REPLAY_RATE=1.0587].
// Os pares chegam nos instantes dos ticks da linha, com o relógio da linha adiantado em RATE.
test("captured run replay: every chunk plays once or is a trimmed silent window", {
  skip: !process.env.SIMULATION_AUDIO_REPLAY_DIR
}, async () => {
  const dir = process.env.SIMULATION_AUDIO_REPLAY_DIR, rate = Number(process.env.SIMULATION_AUDIO_REPLAY_RATE || 1.0587)
  const h = harness(), c = h.controller(); await c.activate()
  function wavData(name) {
    const wav = readFileSync(`${dir}/${name}`)
    assert.equal(wav.toString("ascii", 0, 4), "RIFF"); assert.equal(wav.readUInt32LE(24), 8000)
    let offset = 12
    while (wav.toString("ascii", offset, offset + 4) !== "data") offset += 8 + wav.readUInt32LE(offset + 4)
    return wav.subarray(offset + 8, offset + 8 + wav.readUInt32LE(offset + 4))
  }
  const data = [wavData("agent_B.wav"), wavData("counterpart_B.wav")]
  const ticks = readFileSync(`${dir}/line_ticks.jsonl`, "utf8").trim().split("\n").map(JSON.parse).filter(t => t.side === "agent")
  const windows = Math.floor(ticks.length / 5)
  for (let k = 0; k < windows; k++) {
    c.audioContext.currentTime = (ticks[k * 5 + 4].t_monotonic - ticks[0].t_monotonic) / rate
    for (const origin of [0, 1]) {
      const part = data[origin].subarray(k * 1600, k * 1600 + 1600), payload = new Uint8Array(part.length + 1)
      payload[0] = origin; payload.set(part, 1); c.handleFrame(payload.buffer)
    }
  }
  assert.equal(c.events.filter(row => row.name === "stopped").length, 0)
  for (const origin of ["agent", "counterpart"]) {
    const scheduled = nodesOf(c, origin).map(row => row.chunk_sequence)
    const trimmed = c.events.filter(row => row.name === "silence-trimmed" && row.origin === origin).map(row => row.chunk_sequence)
    assert.deepEqual([...scheduled, ...trimmed].sort((a, b) => a - b), Array.from({ length: windows }, (_, i) => i + 1))
    for (const sequence of trimmed) assert.ok(data[origin === "agent" ? 0 : 1].subarray((sequence - 1) * 1600, sequence * 1600).every(byte => byte === 0))
    assert.equal(overlap(nodesOf(c, origin).map(row => row.node)), false)
    assert.equal(droppedSegments(c, origin).length, 0)
  }
})


test("AudioContext construction failure preserves the activation error state", async () => {
  const h = harness(), c = h.controller()
  h.scope.window.AudioContext = function () { throw new Error("audio unavailable") }
  h.scope.console = { ...console, error() {} }
  await c.activate()
  assert.equal(c.element.dataset.audioState, "error")
  assert.equal(c.audioContext, null)
  assert.equal(h.sockets.length, 0)
})
