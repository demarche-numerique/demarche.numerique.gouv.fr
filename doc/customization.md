# Front end customization

Do you want to customize your instance ? Here is a step by step guide.

## Step 1. Understanding

For your information, you can overide any view in our app by replicating the
view structure from `app/views` to `app/custom_views/`.

You can also overide locales by replicating the locales structure from
`config/locales` to `config/custom_locales`.

## Step 2. Customize the views

So let's imagine you want to customize the `app/views/root/_footer.html.haml`.
Here is how to do:

```
$ mkdir app/custom_views/root
$ cp app/views/root/_footer.html.haml app/custom_views/root
```

And _voila!_ You can edit your own template. No need for env var, no need to
worry about conflicts.

## Step 3. Customize the locales

Now let's imagine you want to customize the `config/locales/links.fr.yml`.
Here is how to do:

```
$ cp config/locales/links.fr.yml config/custom_locales
```

And _voila!_ You can now edit your own locales.

## Step 4. Customize institution logos and document headers

Institution logos are used in **emails** and **PDF documents** (deposit receipt, etc.).
Place your image files in `app/assets/images/` and configure the following environment variables:

| Variable | Default | Description | Can be empty |
|---|---|---|---|
| `LOGO_SRC` | `logo-demarche-numerique@2x.png` | Institution logo displayed in email headers and PDF documents. | No |
| `LOGO_DARK_SRC` | `logo-demarche-numerique@2x.png` | Dark variant of the institution logo, for dark mode email clients. | No |
| `LOGO_MARIANNE_SRC` | `Marianne-Light@2x.png` | Marianne logo displayed on the left of email/PDF headers. | Yes — hides the Marianne logo entirely |
| `LOGO_MARIANNE_DARK_SRC` | `Marianne-Dark@2x.png` | Dark variant of the Marianne logo, for dark mode email clients. | No |
| `DIRECTION_LABEL` | _(empty)_ | Label displayed above the platform name in email and PDF headers (e.g. `Direction Interministérielle du Numérique`). | Yes — hides the label |

Example `.env` configuration:

```bash
LOGO_SRC=my-institution-logo.png
LOGO_DARK_SRC=my-institution-logo-dark.png
LOGO_MARIANNE_SRC=Marianne-Light@2x.png
LOGO_MARIANNE_DARK_SRC=Marianne-Dark@2x.png
DIRECTION_LABEL=My Department Name
```

For deeper customization of email layout, you can override these partials in `app/custom_views/`:
- `layouts/mailers/_dsfr_header.html.erb`
- `layouts/mailers/_dsfr_identity.html.erb`
- `layouts/mailers/_dsfr_footer.html.erb`
