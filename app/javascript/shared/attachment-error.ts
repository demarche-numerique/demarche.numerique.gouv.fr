export function fileSizeErrorMessage(
  input: HTMLInputElement,
  file: File
): string | null {
  const maxSize = input.dataset.maxFileSize
    ? parseInt(input.dataset.maxFileSize, 10)
    : 0;

  if (!maxSize || file.size <= maxSize) return null;

  const maxSizeMB = (maxSize / (1024 * 1024)).toFixed(0);

  return `La taille maximale du fichier autorisée est de&nbsp;<strong>${maxSizeMB} Mo</strong>.`;
}

/**
 * Trouve le container attachment field depuis un input
 */
function findContainer(input: HTMLInputElement): Element | null {
  return input.closest('.attachment-field');
}

/**
 * Affiche une liste de messages d'erreur inline
 * Chaque message sera affiché dans un <p class="fr-message fr-message--error">
 * Les erreurs restent visibles jusqu'à ce que l'utilisateur sélectionne un nouveau fichier.
 */
export function showAttachmentError(
  input: HTMLInputElement,
  messages: string[]
): void {
  const container = findContainer(input);
  if (!container) return;

  const errorZone = container.querySelector<HTMLElement>(
    '[data-attachment-error]'
  );

  if (!errorZone) {
    console.warn('Attachment error zone not found');
    return;
  }

  // Vider le contenu précédent
  errorZone.innerHTML = '';

  // Créer un <p> pour chaque message
  for (const message of messages) {
    const p = document.createElement('p');
    p.className = 'fr-message fr-message--error wrap flex';
    p.innerHTML = message; // Utiliser innerHTML pour supporter <strong>
    errorZone.appendChild(p);
  }

  // Afficher la zone
  errorZone.classList.remove('hidden');
}

/**
 * Masque les messages d'erreur
 */
export function hideAttachmentError(input: HTMLInputElement): void {
  const container = findContainer(input);
  if (!container) return;

  const errorZone = container.querySelector<HTMLElement>(
    '[data-attachment-error]'
  );

  if (errorZone) {
    errorZone.classList.add('hidden');
    errorZone.innerHTML = ''; // Nettoyer le contenu
  }
}
