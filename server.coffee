{ ClickHouse } = require('clickhouse');
clickhouse = new ClickHouse();

express = require('express')
cors = require('cors');
app = express()
port = 3334

app.use(cors())
app.use(express.json());
app.use(express.static('public'))

pings_cache = []
last_flush_pings_cache_at = null

flush_pings_cache = () ->
  last_flush_pings_cache_at = new Date()
  console.log 'flush_pings_cache started'
  if pings_cache.length > 0
    pings_stream = clickhouse.insert('INSERT INTO pings').stream()
    for ping in pings_cache
      await pings_stream.writeRow ping
    await pings_stream.exec()
  pings_cache = []

setInterval flush_pings_cache, 60000

onExit = () ->
  console.log "Exiting..."
  await flush_pings_cache()
  console.log "Exit: done."
  process.exit()

app.get '/', (req, res) =>
  res.send ''

app.post '/visits', (req, res) =>
  body = req.body
  console.log 'Visit: ',  body
  visits_stream = clickhouse.insert('INSERT INTO visits').stream()
  await visits_stream.writeRow [new Date(), body.userId, body.url]
  await visits_stream.exec()
  res.send 'OK'

app.post '/pings', (req, res) =>
  body = req.body
  console.log 'Ping: ',  body
  pings_cache.push [new Date(), body.userId, body.reportInterval, body.time, body.pageTypeId, body.url]
  if pings_cache.length > 75
    flush_pings_cache()
  res.send 'OK'

app.listen port, () =>
  console.log "Analytics service listening on port #{port}!"

# Начинайте чтение из stdin, чтобы процесс не закрылся
process.stdin.resume()

process.on 'exit', onExit

# catches ctrl+c event
process.on 'SIGINT', onExit

# catches "kill pid" (for example: nodemon restart)
process.on 'SIGUSR1', onExit
process.on 'SIGUSR2', onExit

# catches uncaught exceptions
process.on 'uncaughtException', onExit
