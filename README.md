# Fat Zebra users API

A Rails 8.1 API for managing users. Each user has a first name, a last name and a date of birth. Users live in an in-memory store, every request needs a bearer token, and each token has scopes that limit what it can do. One command starts it in Docker.

## Run it

You need Docker. From a fresh clone:

```sh
docker compose up --build
```

The API listens on `http://localhost:3000`. It needs no keys, `.env` file or database.

## Try it

The app has two development tokens. They're fake, and this README publishes them on purpose so you can call the API. `compose.yaml` holds only their SHA-256 digests.

| Client | Token | Scope | Allowed |
| --- | --- | --- | --- |
| reader | `fz-dev-reader-NOT-A-SECRET-0001` | `users:read` | List users |
| writer | `fz-dev-writer-NOT-A-SECRET-0002` | `users:write` | Create and update users |

The scopes are independent. The writer can't list users, and the reader can't change them.

```sh
READER=fz-dev-reader-NOT-A-SECRET-0001
WRITER=fz-dev-writer-NOT-A-SECRET-0002

# Create a user (201)
curl -i -X POST http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $WRITER" \
  -H "Content-Type: application/json" \
  -d '{"user": {"first_name": "Ada", "last_name": "Lovelace", "date_of_birth": "1990-12-10"}}'

# List users (200)
curl -i http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $READER"

# Update some fields of a user (200)
curl -i -X PATCH http://localhost:3000/api/v1/users/1 \
  -H "Authorization: Bearer $WRITER" \
  -H "Content-Type: application/json" \
  -d '{"user": {"last_name": "King"}}'
```

These requests show the auth boundary:

```sh
# No token (401)
curl -i http://localhost:3000/api/v1/users

# The reader tries to create a user (403)
curl -i -X POST http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $READER" \
  -H "Content-Type: application/json" \
  -d '{"user": {"first_name": "Ada"}}'

# The writer tries to list users (403)
curl -i http://localhost:3000/api/v1/users \
  -H "Authorization: Bearer $WRITER"
```

## API

| Method | Path | Scope | Success |
| --- | --- | --- | --- |
| `GET` | `/api/v1/users` | `users:read` | 200 with every user, in creation order |
| `POST` | `/api/v1/users` | `users:write` | 201 with the new user |
| `PATCH` | `/api/v1/users/:id` | `users:write` | 200 with the updated user |

### Requests

Send JSON, with the attributes inside a `user` object. `POST` needs every field. `PATCH` changes only the fields you send.

| Field | Rules |
| --- | --- |
| `first_name` | Required string, 50 characters at most. The API trims leading and trailing spaces. |
| `last_name` | Required string, 50 characters at most. The API trims leading and trailing spaces. |
| `date_of_birth` | Required, in `YYYY-MM-DD` format. It can't be in the future or before 1900-01-01. |

The server assigns `id`. A request that sends `id`, or any other field not in the table, gets a 422.

### Responses

A successful response puts the result in `data`:

```json
{"data": {"id": 1, "first_name": "Ada", "last_name": "Lovelace", "date_of_birth": "1990-12-10"}}
```

An error response lists one or more errors. Each error has a stable `code`, the `field` it applies to and a readable `message`:

```json
{"errors": [{"code": "forbidden", "field": "scope", "message": "requires the users:write scope"}]}
```

| Status | Codes | When |
| --- | --- | --- |
| 400 | `parameter_missing`, `malformed_json` | The body has no `user` object, or isn't valid JSON |
| 401 | `unauthorized` | The token is missing, unknown or sent with another scheme |
| 403 | `forbidden` | The token doesn't have the scope the action needs |
| 404 | `not_found` | No user has that id |
| 422 | `unknown_field`, `invalid_type` | The body has a field that isn't writable, or an array or object as a value |
| 422 | `blank`, `too_long`, `not_a_string`, `invalid_format`, `in_the_future`, `too_old` | A field fails validation |

The API runs its checks in this order: token (401), scope (403), body (400 or 422), then the user lookup (404). A reader that sends a bad body still gets a 403. A writer that sends a bad body for an unknown id gets a 422, because the API checks the body first.

The messages are in `config/locales/en.yml` under `api.errors`, keyed by code.

## Authentication and authorisation

Each API client has its own opaque bearer token. The client sends it in the `Authorization` header on every request. There's no login, session or cookie.

- The app stores only the SHA-256 digest of each token, in the `API_CLIENTS` environment variable. For each request, it hashes the presented token and compares the digests with `ActiveSupport::SecurityUtils.secure_compare`.
- A missing token, an unknown token and a token sent with another scheme (such as `Basic`) all get the same 401, with a `WWW-Authenticate: Bearer` header. The response doesn't reveal which tokens exist.
- `Api::V1::BaseController` works out the scope an action needs from the controller and action names. `index` and `show` need `<controller>:read`, and `create`, `update` and `destroy` need `<controller>:write`. Any other action gets a 403 until its controller overrides `required_scope`. A new controller gets this protection without any setup.
- A spec sends a request without a token to every `/api/v1` route and expects a 401, so a new route can't ship without authentication.
- The app reads tokens only from the header, never from the query string. It never logs the header, and it filters `authorization` and `token` from logged parameters.

The server can revoke an opaque token at any time, because it keeps the list of digests. The alternatives each fall short here:

- A single shared API key has no per-client revocation and no scopes.
- The server can't revoke a JWT before it expires without keeping a denylist. JWTs also need key management and a way to issue tokens.
- OAuth 2.0 client credentials is the production answer, but it needs an authorisation server, which is more than this exercise needs.

### Adding or changing a client

Each `API_CLIENTS` entry has a `name`, a `token_digest` (the lowercase hex SHA-256 of the token) and its `scopes`. To compute a digest, run:

```sh
printf %s 'your-token' | shasum -a 256
```

Edit `API_CLIENTS` in `compose.yaml` (or `mise.toml` outside Docker), then restart the app. The app reads clients once at boot. It won't start if `API_CLIENTS` is missing, isn't valid JSON, has no clients, or has a digest that isn't 64 lowercase hex characters.

## Design decisions

- **In-memory store.** `UserRepository` keeps users in a hash behind one `Mutex`, which serialises every read and write. It stores frozen copies of attributes, so changing a returned user never changes the store. The repository assigns integer ids in creation order. The store empties when the process restarts.
- **One Puma process.** The store lives in process memory, so every request has to reach the same process. `config/puma.rb` sets `workers 0`, which also makes Puma ignore `WEB_CONCURRENCY`. Puma still runs several threads, and they share the store through the `Mutex`.
- **No Active Record.** `User` is a plain ActiveModel class with typed attributes, normalisation and validations. The model owns every validation rule, so the rules apply to any caller, not only HTTP requests.
- **The API rejects unknown fields.** Dropping them without an error would hide client typos and attempts to set server-owned fields such as `id`.
- **Docker runs in development mode.** Production mode needs `config/master.key`, which a fresh clone doesn't have.
- **Compose publishes the port on loopback only.** `compose.yaml` publishes `127.0.0.1:3000`, so other machines on your network can't reach the API. The local run uses plain HTTP, and development mode shows detailed errors, so nothing outside your machine should reach it.
- **The app fails closed on bad configuration.** An invalid `API_CLIENTS` stops the app at boot, instead of failing on the first request.

## Running outside Docker

You need Ruby 4.0.8. With [mise](https://mise.jdx.dev):

```sh
mise install
bundle install
bin/rails server
```

`mise.toml` pins Ruby and sets `API_CLIENTS` to the same two development clients. If you don't use mise, export `API_CLIENTS` from `mise.toml` yourself before you start the server.

In development, Rails reloads code when a file changes, which empties the in-memory store.

## Tests

```sh
bundle exec rspec           # locally
CI=true bundle exec rspec   # with eager loading, as CI runs it
```

In the container, set `RAILS_ENV=test`, because the image runs in development mode:

```sh
docker compose exec -e RAILS_ENV=test api bundle exec rspec
```

The specs cover the model, the serializer, the repository, the API client registry, and request specs for every endpoint. Those include the 401 cases, the scope matrix and the check order. The test environment doesn't read `API_CLIENTS`, because the specs build their own clients.

`bin/ci` runs RuboCop, the specs, bundler-audit and Brakeman. GitHub Actions runs the same checks on every pull request.

## Project layout

```text
app/
├── controllers/api/v1/
│   ├── base_controller.rb    # authentication, authorisation, error responses
│   └── users_controller.rb   # index, create, update
├── models/
│   ├── user.rb               # attributes and validations
│   └── api_client_registry.rb
├── repositories/
│   └── user_repository.rb    # in-memory store
└── serializers/
    └── user_serializer.rb
config/
├── initializers/             # sets up the registry and repository at boot
└── locales/en.yml            # error messages
```

## Known gaps

These are deliberate, to keep the scope close to the brief's time guide:

- The local run has no TLS. In production, TLS would end at a proxy or load balancer, with plain HTTP not exposed and `force_ssl` as a backstop.
- There's no rate limiting, audit log or per-record authorisation. Any client with `users:write` can update any user.
- Changing a token means editing configuration and restarting.
- Scope names follow controller names, so renaming a controller renames its scopes.
- Integer ids reveal how many users exist. Every endpoint needs a token, which limits the risk.
- The API also accepts form-encoded bodies.
- There's no `show` route, so `POST` returns 201 without a `Location` header.

## With more time

- Persist users in Postgres with Active Record models, and drop the repository.
- Keep tokens in a database table with created, last-used and revoked times, or in a secrets manager with rotation. Add a rotation endpoint with an overlap window.
- Move to OAuth 2.0 client credentials with short-lived tokens.
- Add rate limiting on repeated 401s, and pagination on the list endpoint.
- Send `WWW-Authenticate: Bearer error="insufficient_scope"` with a 403.
- Add a `show` route and a health check route.
- Add the React client, which the brief lists as a stretch goal.
