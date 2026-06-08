import { ApplicationController } from './application_controller';

type TurboFrameElement = HTMLElement & { src: string | null };

const DATE_DEBOUNCE_DELAY = 500;

export default class FilterPreviewController extends ApplicationController {
  static values = { frame: String };

  declare readonly frameValue: string;

  preview(event: Event) {
    const target = event.target as HTMLInputElement | null;
    if (target?.type === 'date') {
      this.debounce(this.refreshFrame, DATE_DEBOUNCE_DELAY);
    } else {
      this.refreshFrame();
    }
  }

  private refreshFrame = () => {
    const frame = document.getElementById(
      this.frameValue
    ) as TurboFrameElement | null;
    if (!frame) return;

    const form = this.element as HTMLFormElement;
    const formData = new FormData(form);
    const params = new URLSearchParams();
    for (const [key, value] of formData.entries()) {
      if (typeof value === 'string' && value.length > 0) {
        params.append(key, value);
      }
    }

    const url = new URL(form.action, window.location.origin);
    url.search = params.toString();
    url.searchParams.set('filter_panel', '1');
    frame.src = url.toString();
  };
}
