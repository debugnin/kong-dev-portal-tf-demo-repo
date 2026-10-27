# Flights API

The Flights API exposes KongAir's published schedule and flight metadata. Use it
when you need to show upcoming departures, validate a booking, or enrich
operational dashboards with real-time availability.

## Authentication

All endpoints require an API key registered with your portal application:

```
apikey: <YOUR_API_KEY>
```

Register an application in the Dev Portal and copy the issued key — it's
only shown once, so store it securely.

## Endpoints

- `GET /flights` — retrieve the flights scheduled for a given day
- `GET /flights/{flightNumber}` — look up a single flight by flight number
- `GET /flights/{flightNumber}/details` — fetch extended cabin and aircraft data

## Example

```bash
curl -H "apikey: $API_KEY" \
     --get __DATAPLANE_BASE_URL__/flights \
     --data-urlencode "date=2024-04-04"
```

A request with a missing or invalid key returns `401 Unauthorized`.

## Notes

- Flights change infrequently — cache responses client-side for a few minutes
  to stay within published rate limits.
- Pair the Flights API with booking data from the Bookings API to enrich
  itinerary information.
