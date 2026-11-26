import { ApplicationController } from './application_controller';

export class MoveCardsPositionController extends ApplicationController {
  static targets = ['status'];
  static values = { movedMessage: String };

  declare readonly hasStatusTarget: boolean;
  declare readonly statusTarget: HTMLElement;
  declare readonly movedMessageValue: string;

  connect() {
    this.updateButtonsStates();
  }

  async moveUp(event: Event) {
    event.preventDefault();
    if (this.isMoving()) return;
    const button = event.currentTarget as HTMLButtonElement;
    const card = button.closest('.fr-card')!;
    const previousCard = card.previousElementSibling!;

    await this.switchCards(card, previousCard);

    // move the other card so the focused button stays in the DOM and keeps the focus
    card.after(previousCard);
    this.moved(button, card);
  }

  async moveDown(event: Event) {
    event.preventDefault();
    if (this.isMoving()) return;
    const button = event.currentTarget as HTMLButtonElement;
    const card = button.closest('.fr-card')!;
    const nextCard = card.nextElementSibling!;

    await this.switchCards(nextCard, card);

    card.before(nextCard);
    this.moved(button, card);
  }

  private moved(button: HTMLButtonElement, card: Element) {
    this.updateButtonsStates();

    if (button.disabled) {
      card.querySelector<HTMLButtonElement>('button:enabled')?.focus();
    }

    if (this.hasStatusTarget) {
      const cards = [...card.parentElement!.children];
      const message = this.movedMessageValue
        .replace('%{position}', String(cards.indexOf(card) + 1))
        .replace('%{total}', String(cards.length));
      // empty the region first so a message identical to the previous one is announced again
      this.statusTarget.textContent = '';
      requestAnimationFrame(() => (this.statusTarget.textContent = message));
    }
  }

  // ignore repeated presses while cards are still swapping
  private isMoving() {
    return this.element.getAnimations({ subtree: true }).length > 0;
  }

  private async switchCards(upCard: Element, downCard: Element): Promise<void> {
    const upCardRect = upCard.getBoundingClientRect();
    const downCardRect = downCard.getBoundingClientRect();

    const upAnimation = upCard.animate(
      [
        { transform: `translateY(0)` },
        { transform: `translateY(${downCardRect.top - upCardRect.top}px)` }
      ],
      { duration: 300, easing: 'ease-in-out' }
    );

    const downAnimation = downCard.animate(
      [
        { transform: `translateY(0)` },
        { transform: `translateY(${upCardRect.top - downCardRect.top}px)` }
      ],
      { duration: 300, easing: 'ease-in-out' }
    );

    await Promise.all([upAnimation.finished, downAnimation.finished]);
  }

  private updateButtonsStates() {
    const buttons = [
      ...this.element.querySelectorAll('button')
    ] as HTMLButtonElement[];
    buttons.forEach(
      (button, index) =>
        (button.disabled = index == 0 || index == buttons.length - 1)
    );
  }
}
