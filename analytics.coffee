export class Analytics
  constructor: (@report_url, @user_id, @place, @debug=false) ->
    @reportInterval = 15
    @idleTimeout    = 30
    @started = false
    @stopped = false
    @turnedOff = false
    @clockTime = 0
    @startTime = new Date()
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
      @sendEvent(@clockTime);

  sendEvent: (time) ->
    data =
      user_id: @user_id
      time: time
      report_interval: @report_interval
      place: @place
      url: window.location.href
    @sendReport data

  restartClock: ()->
    @stopped = false
    clearInterval(@clockTimer)
    @clockTimer = setInterval(@clock.bind(this), 1000)

  startLogger: ()->
    # Calculate seconds from start to first interaction
    currentTime = new Date()
    diff = currentTime - @startTime
    @started = true
    @sendUserTiming(diff)
    @clockTimer = setInterval(@clock.bind(this), 1000)

  sendUserTiming: (timingValue)->
    data =
      user_id: @user_id
      url: window.location.href
      # type: 2 # First Interaction
      # host: window.location.host
      # path: window.location.pathname
    @sendReport data

  sendReport: (data) ->
    fetch @report_url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json;charset=utf-8'
      },
      body: JSON.stringify(data) }

  reset: ()->
    @startTime = new Date()
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
