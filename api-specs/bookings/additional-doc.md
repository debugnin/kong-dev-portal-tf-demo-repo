# Bookings API

The Bookings API lets you create and retrieve KongAir reservations on behalf of
customers. Typical use cases include powering digital check-in, travel agency
portals, and self-service itinerary changes.

## Authentication

All endpoints require an API key registered with your portal application:

```
apikey: <YOUR_API_KEY>
```

Register an application in the portal and copy the issued key.

## Endpoints

- `GET /bookings` — retrieve current bookings for the authenticated application
- `POST /bookings` — create a new booking

## Example

```bash
curl -X POST https://<your-gateway-host>/bookings \
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

## Notes

- Booking creation is idempotent by `flight_number` + `seat`. Retries with the
  same payload return the first issued ticket number.
