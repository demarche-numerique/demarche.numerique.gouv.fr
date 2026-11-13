// Messages stay in the DOM long enough for a screen reader to pick them up
const MESSAGE_LIFETIME = 7000;
// Safari ignores a message added to a live region that was just created
const REGION_SETTLE_DELAY = 100;

let region: HTMLElement | null = null;

export function isAppleDevice() {
  return /^(Mac|iPhone|iPad)/i.test(navigator.platform);
}

export function announce(message: string) {
  if (region?.isConnected) {
    append(region, message);
    return;
  }
  const created = document.createElement('div');
  created.className = 'fr-sr-only';
  created.setAttribute('role', 'log');
  created.setAttribute('aria-live', 'assertive');
  created.setAttribute('aria-relevant', 'additions');
  // react-aria hides everything outside an open popover from screen readers,
  // except the nodes carrying this attribute.
  created.dataset.liveAnnouncer = 'true';
  document.body.append(created);
  region = created;
  setTimeout(() => append(created, message), REGION_SETTLE_DELAY);
}

function append(region: HTMLElement, message: string) {
  const node = document.createElement('div');
  node.textContent = message;
  region.append(node);
  setTimeout(() => node.remove(), MESSAGE_LIFETIME);
}
