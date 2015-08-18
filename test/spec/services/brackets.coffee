'use strict'

describe 'watchComputeSrv', ->

  # load the service's module
  beforeEach module 'edudashAppSrv'

  # grab the service
  b = null
  beforeEach inject (_bracketsSrv_) ->
    b = _bracketsSrv_

  it 'should validate getMetric parameters', ->
    expect -> b.getMetric()
      .toThrow new Error "Unknown school type 'undefined'"
    expect -> b.getMetric 'bad school type'
      .toThrow new Error "Unknown school type 'bad school type'"
    expect -> b.getMetric 'primary'
      .toThrow new Error "Unknown criteria 'undefined'"
    expect -> b.getMetric 'primary', 'bad criteria'
      .toThrow new Error "Unknown criteria 'bad criteria'"

  it 'should provide the correct metric from getMetric', ->
    # exhaustive check because we can
    expect b.getMetric 'primary', 'performance'
      .toEqual 'PASS_RATE'
    expect b.getMetric 'primary', 'improvement'
      .toEqual 'PASS_RATE'
    expect b.getMetric 'secondary', 'performance'
      .toEqual 'AVG_GPA'
    expect b.getMetric 'secondary', 'improvement'
      .toEqual 'AVG_GPA'

  it 'should validate getSortMetric parameters', ->
    expect -> b.getSortMetric()
      .toThrow new Error "Unknown school type 'undefined'"
    expect -> b.getSortMetric 'bad school type'
      .toThrow new Error "Unknown school type 'bad school type'"
    expect -> b.getSortMetric 'primary'
      .toThrow new Error "Unknown criteria 'undefined'"
    expect -> b.getSortMetric 'primary', 'bad criteria'
      .toThrow new Error "Unknown criteria 'bad criteria'"

  it 'should provide the correct metric from getSortMetric', ->
    # exhaustive check because we can
    expect b.getSortMetric 'primary', 'performance'
      .toEqual ['AVG_MARK', true]
    expect b.getSortMetric 'primary', 'improvement'
      .toEqual ['CHANGE_PREVIOUS_YEAR', true]
    expect b.getSortMetric 'secondary', 'performance'
      .toEqual ['AVG_GPA', false]
    expect b.getSortMetric 'secondary', 'improvement'
      .toEqual ['CHANGE_PREVIOUS_YEAR_GPA', false]

  it 'should validate getBracket parameters', ->
    expect(b.getBracket 'x', 'AVG_MARK').toEqual 'UNKNOWN'
#    expect -> b.getBracket 'z'
#      .toThrow new Error "val must be a number. Got: 'z' which is 'string'"
    expect -> b.getBracket 1
      .toThrow new Error "Unknown metric: 'undefined'"
    expect -> b.getBracket 1, 'not a metric'
      .toThrow new Error "Unknown metric: 'not a metric'"

  it 'should return UNKNOWN for NaN', ->
    expect(b.getBracket NaN, 'AVG_MARK').toEqual 'UNKNOWN'
    expect(b.getBracket NaN, 'AVG_GPA').toEqual 'UNKNOWN'
    expect(b.getBracket NaN, 'CHANGE_PREVIOUS_YEAR').toEqual 'UNKNOWN'
    expect(b.getBracket NaN, 'CHANGE_PREVIOUS_YEAR_GPA').toEqual 'UNKNOWN'
    expect(b.getBracket undefined, 'AVG_MARK').toEqual 'UNKNOWN'

  it 'AVG_MARK ranges', ->
    expect -> b.getBracket 0,  'AVG_MARK'
      .toThrow new Error "AVG_MARK shall not be bracket"
    expect -> b.getBracket -1, 'AVG_MARK'
      .toThrow new Error "AVG_MARK shall not be bracket"
    expect -> b.getBracket 1,  'AVG_MARK'
      .toThrow new Error "AVG_MARK shall not be bracket"

  it 'AVG_GPA ranges', ->
    expect(b.getBracket 1,  'AVG_GPA').toEqual 'GOOD'
    expect(b.getBracket 3,  'AVG_GPA').toEqual 'GOOD'
    expect(b.getBracket 3.1,'AVG_GPA').toEqual 'MEDIUM'
    expect(b.getBracket 4.2,'AVG_GPA').toEqual 'MEDIUM'
    expect(b.getBracket 4.3,'AVG_GPA').toEqual 'POOR'
    expect(b.getBracket 5,  'AVG_GPA').toEqual 'POOR'


  it 'CHANGE_PREVIOUS_YEAR ranges', ->
    expect(b.getBracket -1,'CHANGE_PREVIOUS_YEAR').toEqual 'POOR'
    expect(b.getBracket 0, 'CHANGE_PREVIOUS_YEAR').toEqual 'MEDIUM'
    expect(b.getBracket 1, 'CHANGE_PREVIOUS_YEAR').toEqual 'GOOD'

  it 'CHANGE_PREVIOUS_YEAR_GPA ranges', ->
    expect(b.getBracket -1,'CHANGE_PREVIOUS_YEAR_GPA').toEqual 'GOOD'
    expect(b.getBracket 0, 'CHANGE_PREVIOUS_YEAR_GPA').toEqual 'MEDIUM'
    expect(b.getBracket 1, 'CHANGE_PREVIOUS_YEAR_GPA').toEqual 'POOR'
    expect(b.getBracket '-1','CHANGE_PREVIOUS_YEAR_GPA').toEqual 'GOOD'
    expect(b.getBracket '0', 'CHANGE_PREVIOUS_YEAR_GPA').toEqual 'MEDIUM'
    expect(b.getBracket '1', 'CHANGE_PREVIOUS_YEAR_GPA').toEqual 'POOR'

  it 'PASS_RATE ranges', ->
    expect(b.getBracket -1, 'PASS_RATE').toEqual 'UNKNOWN'
    expect(b.getBracket 0,  'PASS_RATE').toEqual 'POOR'
    expect(b.getBracket 39, 'PASS_RATE').toEqual 'POOR'
    expect(b.getBracket 40, 'PASS_RATE').toEqual 'MEDIUM'
    expect(b.getBracket 60, 'PASS_RATE').toEqual 'MEDIUM'
    expect(b.getBracket 61, 'PASS_RATE').toEqual 'GOOD'
    expect(b.getBracket 100,'PASS_RATE').toEqual 'GOOD'
    expect(b.getBracket 101,'PASS_RATE').toEqual 'UNKNOWN'

  it 'PUPIL_TEACHER_RATIO ranges', ->
    expect(b.getBracket 0, 'PUPIL_TEACHER_RATIO').toEqual 'UNKNOWN'
    expect(b.getBracket 1,  'PUPIL_TEACHER_RATIO').toEqual 'GOOD'
    expect(b.getBracket 34, 'PUPIL_TEACHER_RATIO').toEqual 'GOOD'
    expect(b.getBracket 35, 'PUPIL_TEACHER_RATIO').toEqual 'MEDIUM'
    expect(b.getBracket 50, 'PUPIL_TEACHER_RATIO').toEqual 'MEDIUM'
    expect(b.getBracket 51, 'PUPIL_TEACHER_RATIO').toEqual 'POOR'
    expect(b.getBracket 100,'PUPIL_TEACHER_RATIO').toEqual 'POOR'

  it 'getRank by school', ->
    expect(b.getRank 'primary').toEqual ['AVG_MARK', true]
    expect(b.getRank 'secondary').toEqual ['AVG_GPA', false]

  it 'should validate getRank parameter', ->
    expect -> b.getRank 'z'
    .toThrow new Error "Unknown school type 'z'"
    expect -> b.getRank undefined
    .toThrow new Error "Unknown school type 'undefined'"
