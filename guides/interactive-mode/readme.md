# Interactive Mode

Run brute without arguments to enter interactive mode for multi-turn conversations.

## Starting a Session

```sh
brute
brute> Add input validation to the signup form
brute> Now write tests for it
brute> exit
```

## Setting a Working Directory

```sh
brute -d ~/projects/myapp "Upgrade the Rails version to 7.2"
```

## Examples

### Fix a bug

```sh
brute "The login endpoint returns 500 when the email contains a plus sign. Find and fix it."
```

### Add a feature

```sh
brute "Add a rate limiter middleware to the API. Use Redis with a sliding window of 100 requests per minute per IP."
```

### Refactor

```sh
brute "Extract the payment processing logic from OrdersController into a PaymentService class"
```

### Multi-step task

```sh
brute "Add a /health endpoint that returns JSON with the app version, database status, and redis status. Write tests. Run them to make sure they pass."
```
