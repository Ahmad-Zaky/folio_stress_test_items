# FOLIO Stress Test Items

- we are trying to mimic different users creating multiple items at the same time in the inventory app,
  so we will run multiple batches of post http requests of items in parallel.
- 'BATCHES_NO' variable represents number of users runs in parallel.
- 'CALL_REQUESTS_LIMIT' variable represents the number of items created for each batch.
- in defaults() method there are some default varialbes should be filled 
  before running the script.
- run test.sh without any arguments to add items under specific holding.
- run test.sh cp with 'cp' argument to copy all item ids from items.json to clipboard,
  which could be used later to remvoe the added items.
- run test.sh rm with 'rm' argument to remove items copied from clipboard to the 
  'UUIDS' array variable.