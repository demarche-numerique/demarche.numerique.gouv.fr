export type PollingStrategy =
  | 'fixed'
  | 'linear'
  | 'exponential'
  | 'fibonacci'
  | 'randomized';

export interface PollOptions {
  strategy: PollingStrategy;
  baseDelay: number;
  maxDelay: number;
  maxAttempts: number;
  jitter: boolean;
  isActive: () => boolean;
}

export function startPolling(
  fn: (signal: AbortSignal) => Promise<void>,
  options?: Partial<PollOptions>
) {
  let timer: ReturnType<typeof setTimeout>;
  let controller: AbortController;
  let discarded = false;

  const isActive = options?.isActive || (() => true);

  const nextDelay = initNextDelay(options ?? {});

  const poll = async () => {
    controller = new AbortController();
    try {
      await fn(controller.signal);
    } catch (error) {
      console.error('poll error', error);
    }
    const delay = nextDelay();
    next(delay);
  };

  const next = (delay: number) => {
    if (discarded || delay == 0) {
      return;
    }
    timer = setTimeout(() => {
      if (discarded) {
        return;
      }
      const active = isActive();
      if (active) {
        poll();
      } else {
        next(delay);
      }
    }, delay);
  };

  poll();

  return () => {
    discarded = true;
    clearTimeout(timer);
    controller?.abort();
  };
}

export function initNextDelay({
  strategy = 'fixed',
  baseDelay = 1000,
  maxDelay = 30_000,
  maxAttempts = 20,
  jitter = false
}: Partial<PollOptions>): () => number {
  let attempt = 0;
  const fib = [baseDelay, baseDelay];

  return () => {
    attempt++;
    let delay: number;

    if (maxAttempts && attempt > maxAttempts) {
      return 0;
    }

    switch (strategy) {
      case 'fixed':
        delay = baseDelay;
        break;
      case 'linear':
        delay = baseDelay * (attempt + 1);
        break;
      case 'exponential':
        delay = baseDelay * 2 ** attempt;
        break;
      case 'fibonacci':
        if (attempt < 2) {
          delay = fib[attempt];
        } else {
          fib[attempt] = fib[attempt - 1] + fib[attempt - 2];
          delay = fib[attempt];
        }
        break;
      case 'randomized':
        delay = baseDelay + Math.random() * baseDelay;
        break;
      default:
        delay = baseDelay;
    }

    if (jitter && strategy !== 'randomized') {
      delay += Math.random() * baseDelay;
    }

    return Math.min(delay, maxDelay);
  };
}
