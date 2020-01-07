{ ClickHouse } = require('clickhouse')

fs = require('fs')
require('dotenv').config()

HOST = process.env.DB_HOST
DB   = process.env.DB
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
    ca: fs.readFileSync('ca.pem')

express = require('express')
cors = require('cors')
app = express()
port = 3334

auth = require('http-auth');
basic = auth.basic
  realm: "Protected"
  file: __dirname + "/users.htpasswd"

app.use(cors())
app.use(express.json());
app.use(express.static('public'))

pings_cache = []
lastFlushPingsCacheAt = new Date()
exit_attempts = 0
flushPingsCacheLock = false

flushPingsCache = ()->
  if flushPingsCacheLock
    console.log('flushPingsCacheLock locked')
    return
  lastFlushPingsCacheAt = new Date()
  console.log 'flushPingsCache started'
  if pings_cache.length > 0
    flushPingsCacheLock = true
    try
      pings_stream = clickhouse.insert('INSERT INTO pings').stream()
      for ping in pings_cache
        await pings_stream.writeRow ping
      await pings_stream.exec()
      pings_cache = []
    catch error
      console.log(error)
    finally
      flushPingsCacheLock = false


flushPingsCacheInterval = ()->
  if (new Date() - lastFlushPingsCacheAt) > 59000 && pings_cache.length > 0
    await flushPingsCache()

setInterval flushPingsCacheInterval, 60000

onExit = ()->
  exit_attempts++
  if exit_attempts <= 3
    console.log "Exiting..."
    await flushPingsCache()
    console.log "Exit: done."
    process.exit()
  else
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
  pings_cache.push [new Date(), body.userId, body.reportInterval, body.time, body.pageTypeId,
    body.courseId, body.url]
  if pings_cache.length > process.env.MAX_CACHED_PINGS
    await flushPingsCache()
  res.send 'OK'

# Returns user spend time in platform in seconds
app.get '/time_spend/:user_id/:from/:to/:type/:course_id', auth.connect(basic), (req, res) =>
  sql = "select count(*) from pings where UserId = #{req.params.user_id}"
  sql += " AND CreatedAt >= toDateTime('#{req.params.from}')
           AND CreatedAt <= toDateTime('#{req.params.to}')"
  if parseInt(req.params.type) > 0
    sql += " AND PageTypeId = #{req.params.type}"
  if parseInt(req.params.course_id) > 0
    sql += " AND CourseId = #{req.params.course_id}"
  rows = await clickhouse.query(sql).toPromise()
  res.json {time: rows[0]['count()']*30}

app.listen port, () =>
  console.log "Analytics service listening on port #{port}!"

# # Начинайте чтение из stdin, чтобы процесс не закрылся
process.stdin.resume()

process.on 'exit', onExit

# # catches ctrl+c event
process.on 'SIGINT', onExit

# # catches "kill pid" (for example: nodemon restart)
process.on 'SIGUSR1', onExit
process.on 'SIGUSR2', onExit

# # catches uncaught exceptions
process.on 'uncaughtException', onExit
