class kablammo.Board
  constructor: (@parent, @args) ->
    @el = '.board'
    @viz = @createVisualization()
    @viz.addEventListener 'hit', ((data) -> console.log('hit',data))
    @viz.addEventListener 'turn', (turn) => @updateStats(turn)
    @viz.addEventListener 'gameOver', (index) => console.log('gameOver',index)

  $el: ->
    @parent.$el().find @el

  render: ->
    @viz.play()

  play: ->
    @viz.play()

  stop: ->
    @viz.stop()

  createVisualization: ->
    walls = @createWalls()
    robots = @createRobots()
    console.log robots
    board = @firstBoard()
    $('#board').css { height: "#{board.height * 83}px", width: "#{board.width * 83}px" }
    kablammo.Visualization 'board', board.width, board.height, walls, robots

  updateStats: (turn) =>
    board = @args[turn.index].board
    _(board.robots).each (robot, i) ->
      $turns = $('.turns')
      console.log(turn)
      $turns.append("<div>Turn #{turn.index} [#{robot.username}] #{turn.turns[i].last_turn}</div>").scrollTop($turns[0].scrollHeight)
      stats = $("#stats-#{robot.username}")
      stats.find('.progress-bar').css 'width', "#{robot.armor * 20}%"
      ammos = stats.find('.ammo')
      ammos.find("li:lt(#{robot.ammo})").removeClass('ammo-empty').addClass('ammo-full')
      if robot.ammo == 0
        ammos.find("li").removeClass('ammo-full').addClass('ammo-empty')
      else
        ammos.find("li:gt(#{robot.ammo-1})").removeClass('ammo-full').addClass('ammo-empty')

  createWalls: ->
    walls = []
    for w in @firstBoard().walls
      (walls[w.x] ||= [])[w.y] = true
    walls

  createRobots: ->
    robots = @firstBoard().robots
    _(robots).map (robot) =>
      hash = robot.username.hashCode()
      {
        id: hash
        color: Math.abs(hash % 4)
        turns: _(@args).map (turn) =>
          @toTurn turn, robot
      }

  toTurn: (turn, robot) =>
    t = _(turn.board.robots).find (r) -> r.username == robot.username
    t.turretAngle = @convertToRadians(t.rotation + 90)
    t

  firstBoard: =>
    _(@args).first().board

  convertToRadians: (degrees) ->
    (degrees * Math.PI) / 180.0
