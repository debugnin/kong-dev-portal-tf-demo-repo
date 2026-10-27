# Bookings API

The Bookings API lets you create and retrieve KongAir reservations on behalf of
customers. Typical use cases include powering digital check-in, travel agency
portals, and self-service itinerary changes.

## Authentication

The Bookings API is protected by OAuth2 client credentials with JWT bearer
tokens. To call any endpoint you need to:

1. Register an application in the Dev Portal to get a `client_id` and
   `client_secret`.
2. Exchange those credentials for a JWT access token.
3. Send the access token as a `Bearer` token on every request.

### 1. Register an application

In the Dev Portal, open the Bookings API page and create an application.
This dynamically registers an OAuth2 client with the identity provider
(Auth0) and issues you a `client_id` and `client_secret` — copy both, the
secret is only shown once.

### 2. Get an access token

Exchange your `client_id`/`client_secret` for an access token using the
OAuth2 `client_credentials` grant:

```bash
curl -X POST "__OIDC_TOKEN_URL__" \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "<CLIENT_ID>",
    "client_secret": "<CLIENT_SECRET>",
    "audience": "https://kongair.com/api/v1",
    "scope": "bookings:read bookings:write"
  }'
```

Only request the scopes your application actually needs — the identity
provider will only grant scopes your application is authorized for. Reading
bookings only needs `bookings:read`; creating a booking needs
`bookings:write`.

The response contains your access token:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIs...",
  "scope": "bookings:read bookings:write",
  "expires_in": 86400,
  "token_type": "Bearer"
}
```

Tokens expire (`expires_in` is in seconds) — repeat this step to get a new
one once it does. There's no need to register a new application each time.

### 3. Call the API with the token

Send the `access_token` from step 2 as a `Bearer` token in the
`Authorization` header:

```bash
curl -X POST __DATAPLANE_BASE_URL__/bookings \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{
        "flight_number": "KA924",
        "seat": "32A"
      }'
```

A successful response returns:

```json
{
  "ticket_number": "CDF3412"
}
```

A request with a missing, expired, or invalid token returns `401
Unauthorized`. A request with a valid token but insufficient scope (e.g. a
`bookings:read`-only token on `POST /bookings`) returns `403 Forbidden`.

## Endpoints

- `GET /bookings` — retrieve current bookings for the authenticated application (requires `bookings:read`)
- `POST /bookings` — create a new booking (requires `bookings:write`)

## Full example

```bash
# 1. Get a token (do this once, then reuse until it expires)
TOKEN=$(curl -s -X POST "__OIDC_TOKEN_URL__" \
  -H "Content-Type: application/json" \
  -d '{
    "grant_type": "client_credentials",
    "client_id": "<CLIENT_ID>",
    "client_secret": "<CLIENT_SECRET>",
    "audience": "https://kongair.com/api/v1",
    "scope": "bookings:write"
  }' | jq -r '.access_token')

# 2. Call the API with it
curl -X POST __DATAPLANE_BASE_URL__/bookings \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
        "flight_number": "KA924",
        "seat": "32A"
      }'
```

## Notes

- Booking creation is idempotent by `flight_number` + `seat`. Retries with the
  same payload return the first issued ticket number.
