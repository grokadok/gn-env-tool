#!/bin/bash
set -e

until mongosh --host localhost --eval 'quit(db.runCommand({ ping: 1 }).ok ? 0 : 1)' > /dev/null 2>&1
do
  echo "### Waiting for mongod to be available..."
  sleep 2
done

echo "Restoring dump..."
if [ -f /dump/${MONGO_DB}.archive ]; then
  mongorestore mongodb://localhost:27017/${MONGO_DB} --archive=/dump/${MONGO_DB}.archive
else
  mongorestore mongodb://localhost:27017/${MONGO_DB} /dump/${MONGO_DB}
fi

# Run data masking logic
echo "Masking data..."
echo "use ${MONGO_DB}
$(cat masking_logic.js)" | mongosh

# Dump the masked database to a new archive file
echo "Creating dump of masked database..."
rm -f /dump/masked.archive
mongodump --archive=/dump/masked.archive --db ${MONGO_DB}

echo "Masking complete. Shutting down mongod."
mongod --shutdown