// app/frontend/controllers/stream_loader_controller.ts
import { ApplicationController } from './application_controller';
import { httpRequest } from '@utils';

export class StreamLoaderController extends ApplicationController {
  static values = {
    url: String
  };

  declare urlValue: string;

  connect() {
    void this.loadStream();
  }

  private async loadStream() {
    try {
      await httpRequest(this.urlValue, { method: 'GET' }).turbo();
    } catch (error) {
      console.error('Failed to load Turbo Stream:', error);
    }
  }
}
