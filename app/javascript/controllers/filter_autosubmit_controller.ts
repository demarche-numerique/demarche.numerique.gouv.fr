import { Controller } from '@hotwired/stimulus';

export default class FilterAutosubmitController extends Controller<HTMLFormElement> {
  submit() {
    this.element.requestSubmit();
  }
}
