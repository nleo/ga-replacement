# Свой сервис аналитики на замену Google Analytics
# Скрипт трекает активность пользователя и отправляет данные на наши сервера

export class Analytics
  constructor: (@baseUrl, @userId, @pageTypeId, @courseId, @debug=false) ->
    @reportInterval = 30
    # @reportInterval = 3 # for dev
    @idleTimeout    = 30
    @started = false
    @stopped = false
    @turnedOff = false
    @clockTime = 0
    @clockTimer = null
    @idleTimer = null

    # Basic activity event listeners
    document.addEventListener('keydown', @trigger.bind(this), false)
    document.addEventListener('click', @trigger.bind(this), false)
    window.addEventListener('mousemove', _.throttle(@trigger.bind(this), 500), false)
    window.addEventListener('scroll', _.throttle(@trigger.bind(this), 500), false)

    # Page visibility listeners
    document.addEventListener('visibilitychange', @visibilityChange.bind(this), false)
    window.addEventListener('blur', @setIdle.bind(this))

  visibilityChange: () ->
    if document.hidden
      @setIdle()

  trigger: () ->
    if @turnedOff
      return

    if !@started
      @startLogger()

    if @stopped
      @restartClock()

    clearTimeout(@idleTimer)
    @idleTimer = setTimeout(@setIdle.bind(this), @idleTimeout * 1000 + 100)

  setIdle: () ->
    clearTimeout(@idleTimer)
    @stopClock()

  stopClock: () ->
    @stopped = true
    clearInterval(@clockTimer)

  restartClock: () ->
    @stopped = false
    clearInterval(@clockTimer)
    @clockTimer = setInterval(@clock.bind(this), 1000)

  clock: () ->
    @clockTime += 1;
    if @clockTime > 0 && (@clockTime % @reportInterval == 0)
      @sendPing(@clockTime);

  sendPing: (time) ->
    data =
      userId: @userId
      time: time
      reportInterval: @reportInterval
      pageTypeId: @pageTypeId
      courseId: @courseId
      url: window.location.href
    @sendData data, 'pings'

  sendVisit: ()->
    data =
      userId: @userId
      url: window.location.href
    @sendData data, 'visits'

  restartClock: ()->
    @stopped = false
    clearInterval(@clockTimer)
    @clockTimer = setInterval(@clock.bind(this), 1000)

  startLogger: ()->
    @started = true
    @sendVisit()
    @clockTimer = setInterval(@clock.bind(this), 1000)

  sendData: (data, endpoint) ->
    fetch "#{@baseUrl}/#{endpoint}",
      method: 'POST',
      headers: {
        'Content-Type': 'application/json;charset=utf-8'
      },
      body: JSON.stringify(data)
    .catch (error) =>
      console.log('Analytics service unavailable:', error)
  reset: ()->
    @clockTime = 0
    @started = false
    @stopped = false
    clearInterval(@clockTimer)
    clearTimeout(@idleTimer)

  turnOff: ()->
    @setIdle()
    @turnedOff = true

  turnOn: ()->
    @turnedOff = false

# a = new Analytics 'http://localhost:3334/reports'
