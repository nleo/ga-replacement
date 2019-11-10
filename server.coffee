{ ClickHouse } = require('clickhouse');
clickhouse = new ClickHouse();


express = require('express')
cors = require('cors');
app = express()
port = 3334

app.use(cors())
app.use(express.json());
app.use(express.static('public'))

app.get '/', (req, res) =>
  res.send 'Hellod World!'

app.post '/reports', (req, res) =>
  body = req.body
  console.log body
  if body.time
    console.log "write to pings"
    pings_stream  = clickhouse.insert('INSERT INTO pings').stream()
    await pings_stream.writeRow [new Date(), body.user_id, body.time, body.place, body.url]
    await pings_stream.exec()
  else
    console.log "write to visits"
    visits_stream = clickhouse.insert('INSERT INTO visits').stream()
    await visits_stream.writeRow [new Date(), body.user_id, body.url]
    await visits_stream.exec()

  res.send 'Hellod World!'

app.listen port, () =>
  console.log "Example app listening on port #{port}!"
