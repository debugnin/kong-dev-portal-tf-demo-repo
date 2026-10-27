# Bookings API

The Bookings API lets you create and retrieve KongAir reservations on behalf of
customers. Typical use cases include powering digital check-in, travel agency
portals, and self-service itinerary changes.

## Authentication

All endpoints require an API key registered with your portal application:

```
apikey: <YOUR_API_KEY>
```

Register an application in the Dev Portal and copy the issued key — it's
only shown once, so store it securely.

## Endpoints

- `GET /bookings` — retrieve current bookings for the authenticated application
- `POST /bookings` — create a new booking

## Example

```bash
curl -X POST __DATAPLANE_BASE_URL__/bookings \
  -H "apikey: $API_KEY" \
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

A request with a missing or invalid key returns `401 Unauthorized`.

## Notes

- Booking creation is idempotent by `flight_number` + `seat`. Retries with the
  same payload return the first issued ticket number.
