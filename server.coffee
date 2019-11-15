{ ClickHouse } = require('clickhouse')

fs = require('fs')
require('dotenv').config()

HOST = process.env.DB_HOST
DB =  process.env.DB
USER = process.env.DB_USER
PASSWORD = process.env.DB_PASS

clickhouse = new ClickHouse
  url: "https://#{HOST}"
  port: 8443
  database: DB
  basicAuth:
    username: USER
    password: PASSWORD
  reqParams:
    hostname: HOST
    ca: fs.readFileSync('ca.pem')
    port: 8443
    gzip: true
    strictSSL: false
    headers:
      'X-ClickHouse-User': USER
      'X-ClickHouse-Key': PASSWORD

clickhouse.query('SELECT now()').stream()
  .on 'data', () =>
    console.log 'data'
    console.log this
  .on 'error', (err) =>
    console.log err
  .on 'end', () =>
    console.log this

# process.exit()

express = require('express')
cors = require('cors')
app = express()
port = 3334

app.use(cors())
app.use(express.json());
app.use(express.static('public'))

pings_cache = []
lastFlushPingsCacheAt = new Date()

flushPingsCache = () ->
  lastFlushPingsCacheAt = new Date()
  console.log 'flushPingsCache started'
  if pings_cache.length > 0
    pings_stream = clickhouse.insert('INSERT INTO pings').stream()
    for ping in pings_cache
      await pings_stream.writeRow ping
    await pings_stream.exec()
    pings_cache = []

flushPingsCacheInterval = ()->
  if (new Date() - lastFlushPingsCacheAt) > 59000
    flushPingsCache()

setInterval flushPingsCacheInterval, 60000

onExit = () ->
  console.log "Exiting..."
  await flushPingsCache()
  console.log "Exit: done."
  process.exit()

app.get '/', (req, res) =>
  res.send ''

app.post '/visits', (req, res) =>
  body = req.body
  console.log 'Visit: ', body
  visits_stream = clickhouse.insert('INSERT INTO visits').stream()
  await visits_stream.writeRow [new Date(), body.userId, body.url]
  await visits_stream.exec()
  res.send 'OK'

app.post '/pings', (req, res) =>
  body = req.body
  console.log 'Ping: ', body
  pings_cache.push [new Date(), body.userId, body.reportInterval, body.time, body.pageTypeId, body.url]
  if pings_cache.length > 75
    flushPingsCache()
  res.send 'OK'

app.listen port, () =>
  console.log "Analytics service listening on port #{port}!"

# # Начинайте чтение из stdin, чтобы процесс не закрылся
# process.stdin.resume()

# process.on 'exit', onExit

# # catches ctrl+c event
# process.on 'SIGINT', onExit

# # catches "kill pid" (for example: nodemon restart)
# process.on 'SIGUSR1', onExit
# process.on 'SIGUSR2', onExit

# # catches uncaught exceptions
# # process.on 'uncaughtException', onExit
