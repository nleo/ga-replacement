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

flush_pings_cache = () ->
  console.log 'flush_pings_cache started'
  if pings_cache.length > 0
    pings_stream = clickhouse.insert('INSERT INTO pings').stream()
    for ping in pings_cache
      await pings_stream.writeRow ping
    await pings_stream.exec()
  pings_cache = []


app.get '/', (req, res) =>
  res.send ''

app.post '/visits', (req, res) =>
  body = req.body
  console.log 'Visit: ',  body
  console.log body
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
  console.log "Example app listening on port #{port}!"
