// Simple dialogue box. show(lines) resolves when the player has advanced
// through every line. Lines may carry a `flag` that is reported via onFlag.
export function createDialogue({ root, onFlag = () => {} }) {
  const speakerEl = root.querySelector('#speaker');
  const lineEl = root.querySelector('#line');
  let resolveCurrent = null;
  let queue = [];

  function render(line) {
    speakerEl.textContent = line.speaker || '';
    speakerEl.hidden = !line.speaker;
    lineEl.textContent = line.text;
    if (line.flag) onFlag(line.flag);
  }

  function next() {
    if (!queue.length) {
      root.hidden = true;
      const r = resolveCurrent; resolveCurrent = null;
      r?.();
      return;
    }
    render(queue.shift());
  }

  return {
    get active() { return !root.hidden; },
    show(lines) {
      queue = [...lines];
      root.hidden = false;
      return new Promise((resolve) => { resolveCurrent = resolve; next(); });
    },
    advance() { if (!root.hidden) next(); },
  };
}
