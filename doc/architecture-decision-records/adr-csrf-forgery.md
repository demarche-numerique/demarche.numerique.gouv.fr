# Protecting against request forgery using CRSF tokens

## Context

Rails has CSRF protection enabled by default, to protect against POST-based CSRF attacks.

To protect from this, Rails stores two copies of a random token (the so-named CSRF token) on each request:

- one copy embedded in each HTML page,
- another copy in the user session.

When performing a POST request, Rails checks that the two copies match – and otherwise denies the request. This protects against an attacker that would generate a form secretly pointing to our website: the attacker can't read the token in the session, and so can't post a form with a valid token.

The problem is that, much more often, this has false positives. There are several cases for that, including:

1. The web browser (often mobile) loads a page containing a form, then is closed by the user. Later, when the browser is re-opened, it restores the page from the cache. But the session cookie has expired, and so is not restored – so the copy of the CSRF token stored in the session is missing. When the user submits the form, they get an "InvalidAuthenticityToken" exception.

2. The user attempts to fill a form, and gets an error message (usually in response to a POST request). They close the browser. When the browser is re-opened, it attempts to restore the page. On Chrome this is blocked by the browser, because the browser denies retrying a (probably non-idempotent) POST request. Safari however happily retries the POST request – but without sending any cookies (in an attempt to avoid having unexpected side-effects). So the copy of the CSRF token in the session is missing (because no cookie was sent), and the user get an "InvalidAuthenticityToken" exception.

## Options considered

### Extend the session cookie duration

We can configure the session cookie to be valid for a longer time (like 2 weeks).

Pros:

- It solves 1., because when the browser restores the page, the session cookie is still valid.

Cons:

- Users would be signed-in for a much longer time by default, which has unacceptable security implications.
- It doesn't solve 2. (because Safari doesn't send any cookie when restoring a page from a POST request)

### Change the cache parameters

We can send a HTTP cache header stating 'Cache-Control: no-store, no-cache'. This instructs the browser to never keep any copy of the page, and to always make a request to the server to restore it.

This solution was attempted during a year in production, and solved 1. – but also introduced another type of InvalidAuthenticityToken errors. In that scenario, the user attempts to fill a form, and gets an error message (usually in response to a POST request). They then navigate on another domain (like FranceConnect), then hit the "Back" button. Crossing back the domain boundary may cause the browser to either block the request or retry an invalid POST request.

Pros:

- It solves 1., because on relaunch the browser requests a fresh page again (instead of serving it from its cache), thus retrieving a fresh session and a fresh matching CSRF token.

Cons:

- It doesn't solve 2.
- It causes another type of InvalidAuthenticityToken errors.

### Using a null-session strategy

We can change the default protect_from_forgery strategy to :null_session. This makes the current request use an empty session for the request duration.

Pros:

- It kind of solves 1., by redirecting to a "Please sign-in" page when a stale form is submitted.

Cons:

- The user is asked to sign-in only after filling and submitting the form, losing their time and data
- The user will not be redirected to their original page after signing-in
- It has potential security implications: as the (potentically malicious) request runs anyway, variables cached by a controller before the Null session is created may allow the form submission to succeed anyway (https://www.veracode.com/blog/managing-appsec/when-rails-protectfromforgery-fails)

### Using a reset-session strategy

We can change the default protect_from_forgery strategy to :reset_session. This clears the user session permanently, logging them out until they log in again.

Pros:

- It kind of solves 1., by redirecting to a "Please sign-in" page when a stale form is submitted.

Cons:

- A forgery error in a browser tab will disconnect the user in all its open tabs
- It has potential security implications: as the (potentically malicious) request runs anyway, variables cached by a controller before the Null session is created may allow the form submission to succeed anyway (https://www.veracode.com/blog/managing-appsec/when-rails-protectfromforgery-fails)
- It allows an attacker to disconnect an user on demand, which is not only inconvenient, but also has security implication (the attacker could then log the user on it's own attacker account, pretending to be the user account)

### Redirect to login form

When a forgery error occurs, we can instead redirect to the login form.

Pros:

- It kind of solves 1., by redirecting to a "Please sign-in" page when a stale form is submitted (but the user data is lost).
- It kind of solves 2., by redirecting to a "Please sign-in" page when a previously POSTed form is reloaded.

Cons:

- Not all forms require authentication – so for public forms there is no point redirecting to the login form.
- The user will not be redirected to their original page after signing-in (because setting the redirect path is a state-changing action, and it is dangerous to let an unauthorized request changing the state – an attacker could control the path where an user is automatically redirected to.)
- The implementation is finicky, and may introduce security errors. For instance, a naive implementation that catches the exception and redirect_to the sign-in page will prevent Devise from running a cleanup code – which means the user will still be logged, and the CSRF protection is bypassed. However a well-tested implementation that lets Devise code run should avoid these pittfalls.

### Using a long-lived cookie for CSRF tokens

Instead of storing the CSRF token in the session cookie (which is deleted when the browser is closed), we can instead store it in a longer-lived cookie. For this we need to patch Rails.

Pros:

- It solves 1., because when the user submits a stale form, even if the session cookie because stale, the long-lived CSRF cookie is still valid.

Cons:

- It doesn't solve 2., because when Safari retries a POST request, it sends none of the cookies (not even long-lived ones).
- Patching Rails may introduce security issues (now or in the future)

## Decision

The only option that fully solves 1. without introducing other issues is the **long-lived CSRF cookie**. This is what we will be using now.

No option solves 2. – but it can be mitigated by a better-looking custom exception page, which we'll also implement.
