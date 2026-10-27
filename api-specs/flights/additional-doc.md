# Flights API

The Flights API exposes KongAir's published schedule and flight metadata. Use it
when you need to show upcoming departures, validate a booking, or enrich
operational dashboards with real-time availability.

## Authentication

The Flights API is protected by OAuth2 client credentials with JWT bearer
tokens. To call any endpoint you need to:

1. Register an application in the Dev Portal to get a `client_id` and
   `client_secret`.
2. Exchange those credentials for a JWT access token.
3. Send the access token as a `Bearer` token on every request.

### 1. Register an application

In the Dev Portal, open the Flights API page and create an application. This
dynamically registers an OAuth2 client with the identity provider (Auth0) and
issues you a `client_id` and `client_secret` — copy both, the secret is only
shown once.

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
    "scope": "flights:read flights:write"
  }'
```

Only request the scopes your application actually needs — the identity
provider will only grant scopes your application is authorized for. Reading
flight data only needs `flights:read`.

The response contains your access token:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIs...",
  "scope": "flights:read flights:write",
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
curl -H "Authorization: Bearer <access_token>" \
     --get __DATAPLANE_BASE_URL__/flights \
     --data-urlencode "date=2024-04-04"
```

A request with a missing, expired, or invalid token returns `401
Unauthorized`. A request with a valid token but insufficient scope (e.g. a
`flights:read`-only token on a write operation) returns `403 Forbidden`.

## Endpoints

- `GET /flights` — retrieve the flights scheduled for a given day (requires `flights:read`)
- `GET /flights/{flightNumber}` — look up a single flight by flight number (requires `flights:read`)
- `GET /flights/{flightNumber}/details` — fetch extended cabin and aircraft data (requires `flights:read`)

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
    "scope": "flights:read"
  }' | jq -r '.access_token')

# 2. Call the API with it
curl -H "Authorization: Bearer $TOKEN" \
     --get __DATAPLANE_BASE_URL__/flights \
     --data-urlencode "date=2024-04-04"
```

## Notes

- Flights change infrequently — cache responses client-side for a few minutes
  to stay within published rate limits.
- Pair the Flights API with booking data from the Bookings API to enrich
  itinerary information.
