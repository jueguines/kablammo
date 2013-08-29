class Tank
  include MongoMapper::EmbeddedDocument

  MAX_AMMO  = 10
  MAX_ARMOR = 5

  key :username,  String,  required: true
  key :rotation,  Integer, required: true, default: 0
  key :ammo,      Integer, required: true, default: MAX_AMMO
  key :armor,     Integer, required: true, default: MAX_ARMOR
  key :last_turn, String

  # this will go away
  key :agg, Float

  embedded_in :square

  def strategy
    Strategy::Combination.new @agg
  end

  def rest
    @ammo  = [MAX_AMMO,  @ammo  + 1].min
  end

  def hit
    @armor -= 1
  end

  def fire
    @ammo -= 1
  end

  def rotate_to(rotation)
    @rotation = rotation
  end

  def alive?
    @armor >= 0
  end

  def dead?
    ! alive?
  end

  def can_fire?
    @ammo > 0
  end

  def direction_to(enemy)
    square.board.direction_to(square, enemy.square)
  end

  def distance_to(enemy)
    square.board.distance_to(square, enemy.square)
  end

  def line_of_sight_to(enemy)
    pixels = square.board.line_of_sight(square, direction_to(enemy))
    pixels.map { |p| square.board.square_at(p.x, p.y) }
  end

  def line_of_sight(skew = 0)
    pixels = square.board.line_of_sight(square, @rotation + skew)
    pixels.map { |p| square.board.square_at(p.x, p.y) }
  end

  def line_of_fire(skew = 0)
    los = line_of_sight skew
    hit = los.index { |s| ! s.empty? }
    hit ? los[0..hit] : los
  end

  def last_fire
    turn = Engine::Turn.parse last_turn
    turn.tank = self
    return unless turn && turn.is_a?(Engine::FireTurn)
    turn.line_of_fire.map {|s| [s.x, s.y]}
  end
end
