module Engine
  class FireHandler < TurnHandler
    MAX_SKEW = 10

    attr_reader :skew

    def initialize(robot, str, skew)
      super robot, str
      @skew = skew || 0
      @skew = MAX_SKEW * -1 if @skew < MAX_SKEW * -1
      @skew = MAX_SKEW      if @skew > MAX_SKEW
    end

    def execute(base_turn)
      return if ! robot.can_fire?

      rotation = base_turn.rotation + skew
      ammo = base_turn.ammo - 1
      hit = robot.line_of_fire(@skew).last
      if hit
        fire = Fire.new x: hit.x, y: hit.y, hit: true
      else
        fire = Fire.new hit: false
      end

      base_turn.extend value: @value, fire: fire, rotation: rotation, ammo: ammo
    end
  end
end
