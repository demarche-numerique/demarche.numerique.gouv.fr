import { Controller } from '@hotwired/stimulus';

type TurboFrameElement = HTMLElement & { src: string | null };

export default class FilterPreviewController extends Controller<HTMLFormElement> {
  static values = { frame: String };

  declare readonly frameValue: string;

  preview() {
    const frame = document.getElementById(
      this.frameValue
    ) as TurboFrameElement | null;
    if (!frame) return;

    const formData = new FormData(this.element);
    const params = new URLSearchParams();
    for (const [key, value] of formData.entries()) {
      if (typeof value === 'string' && value.length > 0) {
        params.append(key, value);
      }
    }

    const url = new URL(this.element.action, window.location.origin);
    url.search = params.toString();
    frame.src = url.toString();
  }
}
