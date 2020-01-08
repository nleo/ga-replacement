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

globalPingsCache = []
lastFlushPingsCacheAt = new Date()
exitAttempts = 0
flushPingsCacheLock = false

flushPingsCache = ()->
  if flushPingsCacheLock
    console.log('flushPingsCacheLock locked')
    return
  lastFlushPingsCacheAt = new Date()
  console.log 'flushPingsCache started'
  if globalPingsCache.length > 0
    flushPingsCacheLock = true
    # делаем локальную копию кеша, чтобы, если сохранение будет идти долго,
    # новые пинги не затёрлись
    localPings = globalPingsCache
    globalPingsCache = []
    pings = []
    try
      # clickhouse принимает 100 записей за раз
      # если вдруг по каким-то причинам мы долго не могли скинуть кеш
      # и у нас накопилось много записей, то пишем по 100
      while (pings = localPings.splice(0, 100)).length > 0
        pingsStream = clickhouse.insert('INSERT INTO pings').stream()
        for ping in pings
          await pingsStream.writeRow ping
        await pingsStream.exec()
    catch error
      console.log(error)
      # если ошибка - вернём пинги в общий пул
      globalPingsCache = pings.concat(localPings).concat(globalPingsCache)
    finally
      flushPingsCacheLock = false


flushPingsCacheInterval = ()->
  if (new Date() - lastFlushPingsCacheAt) > 59000 && globalPingsCache.length > 0
    await flushPingsCache()

setInterval flushPingsCacheInterval, 60000

onExit = ()->
  exitAttempts++
  if exitAttempts <= 3
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
  globalPingsCache.push [new Date(), body.userId, body.reportInterval, body.time, body.pageTypeId,
    body.courseId, body.url]
  if globalPingsCache.length >= process.env.MAX_CACHED_PINGS && (new Date() - lastFlushPingsCacheAt) > 5000
    # здесь await не нужен, т.к. нам не нужны результаты вычисления этой функции
    # мы их здесь не используем и она вообще задумана, что бы выполняться в "фоне", асинхронно
    flushPingsCache()
  res.send 'OK'

# Returns user spend time in platform in seconds
app.get '/time_spend/:user_id/:from/:to/:type/:course_id', auth.connect(basic), (req, res) =>
  sql = "SELECT SUM(timeInSeconds) FROM daily_time_spent WHERE UserId = #{req.params.user_id}"
  sql += " AND Day >= toDateTime('#{req.params.from}')
           AND Day <= toDateTime('#{req.params.to}')"
  if parseInt(req.params.type) > 0
    sql += " AND PageTypeId = #{req.params.type}"
  if parseInt(req.params.course_id) > 0
    sql += " AND CourseId = #{req.params.course_id}"
  rows = await clickhouse.query(sql).toPromise()
  res.json {time: Object.values(rows[0])[0]}

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
