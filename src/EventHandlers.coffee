#= require utils
#= require OneChange

#This is all page wide data and functions.
class EventHandlers
  @initialized = false

  @set_focus: (new_focus) ->
    if @_focus != new_focus
      @dom.has_focus(false) if @_focus

      @_focus = new_focus
      unless @focus().is_null
        @camera = @_focus.world3d.camera
        @dom = @_focus.dom

        @dom.has_focus(true)

  NO_FOCUS = {
    add_changer: -> {}
    is_null: true
  }
  @focus: ->
    @_focus || NO_FOCUS

  @initialize: ->
    return if @initialized

    @down_keys = {}

    $('body').keydown (e) -> EventHandlers.key_down(e)
    $('body').keyup   (e) -> EventHandlers.key_up(e)

    $(document).on('mousedown', '.roofpig', (e) -> EventHandlers.mouse_down(e, $(this).data('cube-id')))
    $('body').mousemove  (e) -> EventHandlers.mouse_move(e)
    $('body').mouseup    (e) -> EventHandlers.mouse_end(e)
    $('body').mouseleave (e) -> EventHandlers.mouse_end(e)

    $(document).on('click', '.roofpig', (e) ->
      cube = CubeAnimation.by_id[$(this).data('cube-id')]
      EventHandlers.set_focus(cube)
    )
    $(document).on('click', '.focus .mouse_target', (e) ->
      EventHandlers.left_cube_click(e, $(this).data('side'))
    )
    $(document).on('contextmenu', '.focus .mouse_target', (e) ->
      EventHandlers.right_cube_click(e, $(this).data('side'))
    )
    $(document).on('click', '.roofpig button', (e) ->
      [button_name, cube_id] = $(this).attr('id').split('-')
      CubeAnimation.by_id[cube_id].button_click(button_name, e.shiftKey)
    )
    $(document).on('click', '.roofpig-help-button', (e) ->
      [_, cube_id] = $(this).attr('id').split('-')
      CubeAnimation.by_id[cube_id].dom.show_help()
    )

    @initialized = true

  @mouse_down: (e, clicked_cube_id) ->
    @dom.remove_help()
    
    if clicked_cube_id == @focus().id
      @bend_start_x = e.pageX
      @bend_start_y = e.pageY

      @bending = true

  @mouse_end: (e) ->
    @focus().add_changer('camera', new OneChange( => @camera.bend(0, 0)))
    @bending = false

  @mouse_move: (e) ->
    if @bending
      dx = -0.02 * (e.pageX - @bend_start_x) / @dom.scale
      dy = -0.02 * (e.pageY - @bend_start_y) / @dom.scale
      if e.shiftKey
        dy = 0
      @focus().add_changer('camera', new OneChange( => @camera.bend(dx, dy)))

  @left_cube_click: (e, click_side) ->
    this._handle_cube_click(e, click_side)

  @right_cube_click: (e, click_side) ->
    this._handle_cube_click(e, click_side)
    e.preventDefault() # no context menu

  @_handle_cube_click: (e, click_side) ->
    return false unless @focus().user_controlled()

    third_key = e.metaKey || e.ctrlKey
    opposite = false
    side_map = switch e.which
      when 1 # left button
        opposite = third_key
        if third_key then {F: 'B', U: 'D', R: 'L'} else {F: 'F', U: 'U', R: 'R'}
      when 3 # right button
        if third_key then {F: 'f', U: 'u', R: 'r'} else {F: 'z', U: 'y', R: 'x'}
      when 2 # middle button
        opposite = third_key
        if third_key then {F: 'b', U: 'd', R: 'l'} else {F: 'f', U: 'u', R: 'r'}

    @focus().external_move(side_map[click_side]+this._turns(e, opposite))


  @_turns: (e, opposite = false) ->
    result = if e.shiftKey then -1 else if e.altKey then 2 else 1
    result = -result if opposite
    { 1: '', 2: '2', '-1': "'", '-2': 'Z'}[result]

# ---- Keyboard Events ----

  @key_down: (e) ->
    @down_keys[e.keyCode] = true

    return if @focus().is_null

    help_toggled = @dom.remove_help()

    if e.ctrlKey || e.metaKey || e.altKey
      return true

    [key, shift] = [e.keyCode, e.shiftKey]

    if (key in turn_keys) && @focus().user_controlled()
      this.cube_key_moves(e)
      return true

    if key == key_tab
      new_focus = if shift then @focus().previous_cube() else @focus().next_cube()
      this.set_focus(new_focus)

    else if key == key_end || (key == key_right_arrow && shift)
      @focus().add_changer('pieces', new OneChange( => @focus().alg.to_end(@focus().world3d)))

    else if key in button_keys
      this._fake_click_down(this._button_for(key, shift))

    else if key == key_questionmark
      @focus().dom.show_help() unless help_toggled

    else
      unhandled = true

    unless unhandled
      e.preventDefault()
      e.stopPropagation()


  @cube_key_moves: (e) ->
    sides = {}
    sides[turn_B] = 'B'
    sides[turn_R] = 'R'
    sides[turn_D] = 'D'
    sides[turn_F] = 'F'
    sides[turn_L] = 'L'
    sides[turn_U] = 'U'

    side = sides[e.keyCode]
    turns = (if this._is_down(double_turn) then 2 else 1) * (if this._is_down(reverse_turn) then -1 else 1)

    opposite = this._is_down(opposite_turn) || this._is_down(cube_rotation)
    middle   = this._is_down(slice_turn) || this._is_down(wide_turn) || this._is_down(cube_rotation)
    the_side = this._is_down(regular_turn) || this._is_down(wide_turn) || this._is_down(cube_rotation) || (!opposite && !middle) 

    moves = []

    if the_side && middle && opposite
      rotation_turn_code = Move.turn_code(turns, true)
      moves.push("#{side}#{rotation_turn_code}")

    else
      turn_code      = Move.turn_code(turns)
      anti_turn_code = Move.turn_code(-turns)

      if the_side
        moves.push("#{side}#{turn_code}")

      if middle
        switch side
          when 'B' then moves.push("S"+anti_turn_code)
          when 'R' then moves.push("M"+anti_turn_code)
          when 'D' then moves.push("E"+turn_code)
          when 'F' then moves.push("S"+turn_code)
          when 'L' then moves.push("M"+turn_code)
          when 'U' then moves.push("E"+anti_turn_code)

      if opposite
        switch side
          when 'B' then moves.push("F"+anti_turn_code)
          when 'R' then moves.push("L"+anti_turn_code)
          when 'D' then moves.push("U"+anti_turn_code)
          when 'F' then moves.push("B"+anti_turn_code)
          when 'L' then moves.push("R"+anti_turn_code)
          when 'U' then moves.push("D"+anti_turn_code)

    @focus().external_move(moves.join('+'))


  @_is_down: (logicalKeyCode) ->
    return false if logicalKeyCode == null
    return @down_keys[logicalKeyCode] == true

  @_button_for: (key, shift) ->
    switch key
      when menu_reset
        @dom.reset
      when menu_prev
        unless shift then @dom.prev else @dom.reset
      when menu_next
       @dom.next
      when menu_play
        @dom.play_or_pause

  @key_up: (e) ->
    @down_keys[e.keyCode] = false

    button_key = e.keyCode in button_keys
    if button_key
      if @down_button
        this._fake_click_up(@down_button)
        @down_button = null
    return button_key

  @_fake_click_down: (button) ->
    unless button.attr("disabled")
      @down_button = button
      button.addClass('roofpig-button-fake-active')

  @_fake_click_up: (button) ->
    unless button.attr("disabled")
      button.removeClass('roofpig-button-fake-active')
      button.click()


  # Declare keycodes for physical keys
  # (http://www.cambiaresearch.com/articles/15/javascript-char-codes-key-codes)
  key_tab = 9
  key_space = 32
  key_end = 35
  key_home = 36

  key_left_arrow = 37
  key_up_arrow = 38
  key_right_arrow = 39
  key_down_arrow = 40

  key_A = 65
  key_C = 67
  key_D = 68
  key_F = 70
  key_J = 74
  key_K = 75
  key_L = 76
  key_S = 83
  key_V = 86
  key_X = 88
  key_Z = 90

  numpad_0 = 96
  numpad_1 = 97
  numpad_2 = 98
  numpad_3 = 99
  numpad_4 = 100
  numpad_5 = 101
  numpad_6 = 102
  numpad_7 = 103
  numpad_8 = 104
  numpad_9 = 105
  numpad_decimal = 110

  key_questionmark = 191


  # Map physical keys to logical actions
  # TODO: extract into a config option

  # face turns
  turn_B = numpad_9
  turn_R = numpad_6
  turn_D = numpad_0
  turn_F = numpad_5
  turn_L = numpad_4
  turn_U = numpad_8

  # individual layer modifiers
  regular_turn = null
  slice_turn = key_S
  opposite_turn = null

  # composite layer modifiers
  wide_turn = null              # regular + slice
  cube_rotation = key_D         # regular + slice + opposite

  # turn modifiers
  reverse_turn = key_F
  double_turn = key_V

  # menu buttons
  menu_reset = numpad_decimal
  menu_prev = numpad_1
  menu_next = numpad_2
  menu_play = numpad_3


  # keybindings will be deactivated automatically, if you assign `null` to them in the mapping above
  compact = (array) ->
    item for item in array when item != null

  button_keys = compact([menu_reset, menu_prev, menu_next, menu_play])
  turn_keys   = compact([turn_B, turn_R, turn_D, turn_F, turn_L, turn_U])
