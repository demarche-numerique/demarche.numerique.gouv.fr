import { session } from '@hotwired/turbo';
import * as s from 'superstruct';

function nullish<T, S>(struct: s.Struct<T, S>) {
  return s.optional(s.union([s.literal(null), struct]));
}

const Gon = s.defaulted(
  s.type({
    autosave: s.defaulted(
      s.type({
        debounce_delay: s.defaulted(s.number(), 0),
        status_visible_duration: s.defaulted(s.number(), 0)
      }),
      {}
    ),
    autocomplete: s.defaulted(
      s.partial(
        s.type({
          api_geo_url: s.string(),
          api_adresse_url: s.string(),
          api_education_url: s.string()
        })
      ),
      {}
    ),
    locale: s.defaulted(s.string(), 'fr'),
    matomo: s.defaulted(
      s.type({
        cookieDomain: s.optional(s.string()),
        domain: s.optional(s.string()),
        enabled: s.defaulted(s.boolean(), false),
        host: s.optional(s.string()),
        key: nullish(s.union([s.string(), s.number()]))
      }),
      {}
    ),
    sentry: s.defaulted(
      s.type({
        key: nullish(s.string()),
        enabled: s.defaulted(s.boolean(), false),
        environment: nullish(s.string()),
        user: s.defaulted(s.type({ id: s.string() }), { id: '' }),
        browser: s.defaulted(s.type({ modern: s.boolean() }), {
          modern: false
        }),
        release: nullish(s.string())
      }),
      {}
    ),
    crisp: s.defaulted(
      s.type({
        websiteId: nullish(s.string()),
        enabled: s.defaulted(s.boolean(), false),
        user: s.defaulted(
          s.type({
            email: s.string(),
            emailSignature: nullish(s.string()),
            segments: s.defaulted(s.array(s.string()), [])
          }),
          {
            email: '',
            emailSignature: null,
            segments: []
          }
        )
      }),
      {}
    ),
    defaultQuery: s.optional(s.string()),
    defaultVariables: s.optional(s.string())
  }),
  {}
);
declare const window: Window & typeof globalThis & { gon: unknown };

export function getConfig() {
  return s.create(window.gon, Gon);
}

export function show(el: Element | null) {
  el?.classList.remove('hidden');
}

export function hide(el: Element | null) {
  el?.classList.add('hidden');
}

export function toggle(el: Element | null, force?: boolean) {
  if (force == undefined) {
    el?.classList.toggle('hidden');
  } else if (force) {
    el?.classList.remove('hidden');
  } else {
    el?.classList.add('hidden');
  }
}

export function toggleExpandIcon(icon: Element | null) {
  icon?.classList.toggle('fr-icon-arrow-down-s-line');
  icon?.classList?.toggle('fr-icon-arrow-up-s-line');
}

export function enable(
  el: HTMLSelectElement | HTMLInputElement | HTMLButtonElement | null
) {
  if (el) {
    el.disabled = false;
  }
}

export function disable(
  el: HTMLSelectElement | HTMLInputElement | HTMLButtonElement | null
) {
  if (el) {
    el.disabled = true;
  }
}

export function hasClass(el: HTMLElement | null, cssClass: string) {
  return el?.classList.contains(cssClass);
}

export function addClass(el: HTMLElement | null, cssClass: string) {
  el?.classList.add(cssClass);
}

export function removeClass(el: HTMLElement | null, cssClass: string) {
  el?.classList.remove(cssClass);
}

export function delegate<E extends Event = Event>(
  eventNames: string,
  selector: string,
  callback: (event: E) => void
): () => void {
  const subscriptions = eventNames
    .split(' ')
    .map((eventName) =>
      delegateEvent(
        document,
        selector,
        eventName,
        callback as (event: Event) => void
      )
    );
  return () => subscriptions.forEach((unsubscribe) => unsubscribe());
}

export class ResponseError extends Error {
  readonly response: Response;
  readonly errors: string[];
  readonly isNetworkError: boolean;

  constructor(response: Response, errors?: string[], isNetworkError = false) {
    super(String(response.statusText || errors?.at(0) || response.status));
    this.response = response;
    this.errors = errors || [];
    this.isNetworkError = isNetworkError;
  }
}

const FETCH_TIMEOUT = 30 * 1000; // 30 sec

// Perform an HTTP request using `fetch` API,
// and handle the result depending on the MIME type.
//
// Usage:
//
// Execute a GET request, and return the response as parsed JSON
// const parsedJson = await httpRequest(url).json();
//
// Execute a POST request with some JSON payload
// const parsedJson = await httpRequest(url, { method: 'POST', json: '{ "foo": 1 }').json();
//
// Execute a GET request, and apply the Turbo stream in the Response
// await httpRequest(url).turbo();
//
export function httpRequest(
  url: string,
  {
    csrf = true,
    timeout = FETCH_TIMEOUT,
    handleAuth = true,
    json,
    ...init
  }: RequestInit & {
    csrf?: boolean;
    json?: unknown;
    timeout?: number | false;
    handleAuth?: boolean;
  } = {}
) {
  const headers = init.headers ? new Headers(init.headers) : new Headers();
  if (csrf) {
    headers.set('x-csrf-token', csrfToken() ?? '');
    headers.set('x-requested-with', 'XMLHttpRequest');
    init.credentials = 'same-origin';
  }
  init.headers = headers;
  init.method = init.method?.toUpperCase() ?? 'GET';

  if (json) {
    headers.set('content-type', 'application/json');
    init.body = JSON.stringify(json);
  }

  if (timeout != false && AbortSignal.timeout && AbortSignal.any) {
    const abortSignal = AbortSignal.timeout(timeout);
    if (init.signal) {
      init.signal = AbortSignal.any([init.signal, abortSignal]);
    } else {
      init.signal = abortSignal;
    }
  }

  const request = async (
    init: RequestInit,
    accept?: string
  ): Promise<Response | null> => {
    if (accept && init.headers instanceof Headers) {
      init.headers.set('accept', accept);
    }

    const response = await fetch(url, init).catch((error) => {
      if (error instanceof TypeError) {
        throw new ResponseError(
          Response.error(),
          [(error as Error).message],
          true
        );
      }
      throw error;
    });

    if (response.ok) {
      return response;
    } else if (
      handleAuth &&
      (response.status == 401 || response.status == 403)
    ) {
      location.reload();
      return null;
    } else {
      const errors = await getResponseErrors(response);
      throw new ResponseError(response, errors);
    }
  };

  return {
    async json<T>(): Promise<T | null> {
      const response = await request(init, 'application/json');
      if (!response) {
        return null;
      }
      if (response.status == 204) {
        return null;
      }
      return response.json();
    },
    async turbo(): Promise<void> {
      const response = await request(init, 'text/vnd.turbo-stream.html');
      if (response && response.status != 204) {
        const stream = await response.text();
        session.renderStreamMessage(stream);
      }
    }
  };
}

const JSONErrorBody = s.type({ errors: s.array(s.string()) });

async function getResponseErrors(response: Response): Promise<string[]> {
  const contentType = response.headers.get('content-type');
  try {
    if (contentType?.match('json')) {
      const json = await response.clone().json();
      const [, body] = s.validate(json, JSONErrorBody);
      return body?.errors ?? [];
    }
    return [];
  } catch {
    return [];
  }
}

export function isNumeric(s: string) {
  const n = parseFloat(s);
  return !isNaN(n) && isFinite(n);
}

export function fire<T>(obj: EventTarget, name: string, data?: T) {
  const event = new CustomEvent(name, {
    bubbles: true,
    cancelable: true,
    detail: data
  });
  obj.dispatchEvent(event);
  return !event.defaultPrevented;
}

export function csrfToken() {
  const meta = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]');
  return meta?.content;
}

function delegateEvent<E extends Event = Event>(
  element: EventTarget,
  selector: string,
  eventType: string,
  handler: (event: E) => void | boolean
): () => void {
  const listener = function (event: Event) {
    let { target } = event;
    while (!!(target instanceof Element) && !target.matches(selector)) {
      target = target.parentNode;
    }
    if (
      target instanceof Element &&
      handler.call(target, event as E) === false
    ) {
      event.preventDefault();
      event.stopPropagation();
    }
  };
  element.addEventListener(eventType, listener);
  return () => element.removeEventListener(eventType, listener);
}
