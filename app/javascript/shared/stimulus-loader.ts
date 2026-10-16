import type { Application, ControllerConstructor } from '@hotwired/stimulus';
import invariant from 'tiny-invariant';

type Module = Record<string, unknown>;
type Loader = () => Promise<Module>;

const controllerAttribute = 'data-controller';
const controllers = import.meta.glob<Module>(
  ['../controllers/*.{ts,tsx}', '!**/*.test.*'],
  {
    eager: true
  }
);
const lazyControllers = import.meta.glob<Module>([
  '../controllers/lazy/*.{ts,tsx}',
  '!**/*.test.*'
]);
const controllerLoaders = new Map<string, Loader>();

export function registerControllers(application: Application) {
  for (const [path, module] of Object.entries(controllers)) {
    registerController(controllerName(path), module, application);
  }
  for (const [path, loader] of Object.entries(lazyControllers)) {
    registerControllerLoader(controllerName(path), loader);
  }
  lazyLoadExistingControllers(application);
  lazyLoadNewControllers(application);
}

function lazyLoadExistingControllers(
  application: Application,
  element?: Element
) {
  queryControllerNamesWithin(element ?? application.element).forEach(
    (controllerName) => loadController(controllerName, application)
  );
}

function lazyLoadNewControllers(application: Application) {
  new MutationObserver((mutationsList) => {
    for (const { attributeName, target, type } of mutationsList) {
      const element = target as Element;
      switch (type) {
        case 'attributes': {
          if (
            attributeName == controllerAttribute &&
            element.getAttribute(controllerAttribute)
          ) {
            extractControllerNamesFrom(element).forEach((controllerName) =>
              loadController(controllerName, application)
            );
          }
          break;
        }

        case 'childList':
          lazyLoadExistingControllers(application, element);
          break;
      }
    }
  }).observe(application.element, {
    attributes: true,
    attributeFilter: [controllerAttribute],
    subtree: true,
    childList: true
  });
}

function queryControllerNamesWithin(element: Element) {
  return Array.from(
    element.querySelectorAll(`[${controllerAttribute}]`)
  ).flatMap(extractControllerNamesFrom);
}

function extractControllerNamesFrom(element: Element) {
  return (
    element
      .getAttribute(controllerAttribute)
      ?.split(/\s+/)
      .filter((content) => content.length) ?? []
  );
}

function loadController(name: string, application: Application) {
  const loader = controllerLoaders.get(name);
  controllerLoaders.delete(name);
  if (loader) {
    loader()
      .then((module) => registerController(name, module, application))
      .catch((error) =>
        console.error(`Failed to autoload controller: ${name}`, error)
      );
  }
}

function controllerName(path: string) {
  const [filename] = path.split('/').reverse();
  return filename.replace(/_/g, '-').replace(/-controller\.(ts|tsx)$/, '');
}

function registerController(
  name: string,
  module: Awaited<ReturnType<Loader>>,
  application: Application
) {
  if (module.default) {
    console.debug(`Registered default export for "${name}" controller`);
    application.register(name, module.default as ControllerConstructor);
  } else {
    const exports = Object.entries(module);
    invariant(
      exports.length == 1,
      `Expected a single export but ${exports.length} exports were found for "${name}" controller`
    );
    const [exportName, exportModule] = exports[0];
    console.debug(
      `Registered named export "${exportName}" for "${name}" controller`
    );
    application.register(name, exportModule as ControllerConstructor);
  }
}

function registerControllerLoader(name: string, loader: Loader) {
  console.debug(`Registered loader for "${name}" controller`);
  controllerLoaders.set(name, loader);
}
