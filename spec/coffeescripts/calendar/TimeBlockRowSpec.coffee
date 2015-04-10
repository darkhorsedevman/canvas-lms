define [
  'jquery'
  'compiled/calendar/TimeBlockList'
  'compiled/calendar/TimeBlockRow'
  'timezone'
  'vendor/timezone/America/Detroit'
], ($, TimeBlockList, TimeBlockRow, tz, detroit) ->

  nextYear = new Date().getFullYear() + 1
  start    = tz.parse("#{nextYear}-02-03T12:32:00Z")
  end      = tz.parse("#{nextYear}-02-03T17:32:00Z")

  module "TimeBlockRow",
    setup: ->
      @snapshot = tz.snapshot()
      tz.changeZone(detroit, 'America/Detroit')
      @$holder = $('<table />').appendTo(document.getElementById("fixtures"))
      @timeBlockList = new TimeBlockList(@$holder)

      # fakeTimer'd because the tests with failed validations add an error box
      # that is faded in. if we don't tick past the fade-in, other unrelated
      # tests that use fake timers fail.
      @clock = sinon.useFakeTimers((new Date()).valueOf())

    teardown: ->
      # tick past any remaining errorBox fade-ins
      @clock.tick 250
      @clock.restore()
      @$holder.detach()
      document.getElementById("fixtures").innerHTML = ""
      tz.restore(@snapshot)

  test "should init properly", ->
    me = new TimeBlockRow(@timeBlockList, {start, end})
    # make sure the <input> `value`s are right
    equal me.$date.val().trim(),       start.toString("ddd MMM d, yyyy")
    equal me.$start_time.val().trim(), start.toString("h:mm") + start.toString("tt").toLowerCase()
    equal me.$end_time.val().trim(),     end.toString("h:mm") +   end.toString("tt").toLowerCase()

  test "delete link", ->
    me = @timeBlockList.addRow({start, end})
    ok (me in @timeBlockList.rows), 'make sure I am in the timeBlockList to start out with'
    me.$row.find('.delete-block-link').click()

    ok !(me in @timeBlockList.rows)
    ok !me.$row[0].parentElement, 'make sure I am no longer on the page'

  test 'validate: fields must be individually valid', ->
    me = new TimeBlockRow(@timeBlockList)
    me.$date.val('invalid').change()
    ok !me.validate()

    me.$date.data('instance').setDate(start)
    me.$start_time.val('invalid').change()
    ok !me.validate()

    me.$start_time.data('instance').setDate(start)
    me.$end_time.val('invalid').change()
    ok !me.validate()

  test 'validate: with good data', ->
    me = new TimeBlockRow(@timeBlockList, {start, end})
    ok me.validate(), 'whole row validates if has good info'

  test 'validate: date in past', ->
    me = new TimeBlockRow(@timeBlockList, {start, end})
    me.$date.val('1/1/2000').change()
    ok !me.validate()
    ok me.$end_time.data('associated_error_box').is(':visible'), 'error box is visible'
    ok me.$end_time.hasClass('error'), 'has error class'

  test 'validate: just time in past', ->
    twelveOClock = new Date(new Date().toDateString())
    twelveOOne = new Date(twelveOClock)
    twelveOOne.setMinutes(1)

    me = new TimeBlockRow(@timeBlockList, {start: twelveOClock, end: twelveOOne})
    ok !me.validate(), 'not valid if time in past'
    ok me.$end_time.data('associated_error_box').is(':visible'), 'error box is visible'
    ok me.$end_time.hasClass('error'), 'has error class'

  test 'validate: end before start', ->
    me = new TimeBlockRow(@timeBlockList, {start: end, end: start})
    ok !me.validate()
    ok me.$start_time.data('associated_error_box').parents('#fixtures'), 'error box is visible'
    ok me.$start_time.hasClass('error'), 'has error class'

  test 'valid if whole row is blank', ->
    me = new TimeBlockRow(@timeBlockList)
    ok me.validate()

  test 'getData', ->
    me = new TimeBlockRow(@timeBlockList, {start, end})
    me.validate()
    deepEqual me.getData(), [start, end, false]

  test 'incomplete: false if whole row blank', ->
    me = new TimeBlockRow(@timeBlockList)
    ok !me.incomplete()

  test 'incomplete: false if whole row populated', ->
    me = new TimeBlockRow(@timeBlockList, {start, end})
    ok !me.incomplete()

  test 'incomplete: true if only one field blank', ->
    me = new TimeBlockRow(@timeBlockList, start: start, end: null)
    ok me.incomplete()
