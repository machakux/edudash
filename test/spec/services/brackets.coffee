'use strict'

describe 'watchComputeSrv', ->

  # load the service's module
  beforeEach module 'edudashAppSrv'

  # grab the service
  b = null
  beforeEach inject (_bracketsSrv_) ->
    b = _bracketsSrv_

  # test helper services
  $q = null
  $rootScope = null
  beforeEach inject (_$q_, _$rootScope_) ->
    $q = _$q_
    $rootScope = _$rootScope_


  describe 'getVisMetric', ->
    it 'should validate parameters', ->
      expect -> b.getVisMetric()
        .toThrow new Error "Unknown vis mode 'undefined'"
      expect -> b.getVisMetric 'bad visMode'
        .toThrow new Error "Unknown vis mode 'bad visMode'"

    it 'should provide the correct metric', ->
      # exhaustive check because we can
      expect b.getVisMetric 'passrate'
        .toEqual 'PASS_RATE'
      expect b.getVisMetric 'ptratio'
        .toEqual 'PUPIL_TEACHER_RATIO'
      expect b.getVisMetric 'gpa'
        .toEqual 'AVG_GPA'


  describe 'getSortMetric', ->
    it 'should validate parameters', ->
      expect -> b.getSortMetric()
        .toThrow new Error "Unknown school type 'undefined'"
      expect -> b.getSortMetric 'bad school type'
        .toThrow new Error "Unknown school type 'bad school type'"
      expect -> b.getSortMetric 'primary'
        .toThrow new Error "Unknown criteria 'undefined'"
      expect -> b.getSortMetric 'primary', 'bad criteria'
        .toThrow new Error "Unknown criteria 'bad criteria'"

    it 'should provide the correct metric', ->
      # exhaustive check because we can
      expect b.getSortMetric 'primary', 'performance'
        .toEqual ['AVG_MARK', 'DESC']
      expect b.getSortMetric 'primary', 'improvement'
        .toEqual ['CHANGE_PREVIOUS_YEAR', 'DESC']
      expect b.getSortMetric 'secondary', 'performance'
        .toEqual ['AVG_GPA', 'DESC']
      expect b.getSortMetric 'secondary', 'improvement'
        .toEqual ['CHANGE_PREVIOUS_YEAR_GPA', 'DESC']

  describe 'getBracket', ->
    it 'should validate parameters', ->
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
      # TODO: can we sanity-check some maximum changes for UNDEFINED?
      expect(b.getBracket -1,'CHANGE_PREVIOUS_YEAR').toEqual 'POOR'
      expect(b.getBracket 0, 'CHANGE_PREVIOUS_YEAR').toEqual 'MEDIUM'
      expect(b.getBracket 1, 'CHANGE_PREVIOUS_YEAR').toEqual 'GOOD'

    it 'CHANGE_PREVIOUS_YEAR_PASSRATE ranges', ->
      # TODO: can we sanity-check some maximum changes for UNDEFINED?
      expect(b.getBracket -1,'CHANGE_PREVIOUS_YEAR_PASSRATE').toEqual 'POOR'
      expect(b.getBracket 0, 'CHANGE_PREVIOUS_YEAR_PASSRATE').toEqual 'MEDIUM'
      expect(b.getBracket 1, 'CHANGE_PREVIOUS_YEAR_PASSRATE').toEqual 'GOOD'

    it 'CHANGE_PREVIOUS_YEAR_GPA ranges', ->
      # TODO: can we sanity-check some maximum changes for UNDEFINED?
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

    it 'Should not depend on `this` context (regression)', ->
      alias = b.getBracket
      expect(alias 1, 'PASS_RATE').toEqual 'POOR'


  describe 'getRank', ->
    it 'should rank by school', ->
      expect(b.getRank 'primary').toEqual ['AVG_MARK', 'DESC']
      expect(b.getRank 'secondary').toEqual ['AVG_GPA', 'DESC']

    it 'should validate parameters', ->
      expect -> b.getRank 'z'
        .toThrow new Error "Unknown school type 'z'"
      expect -> b.getRank undefined
        .toThrow new Error "Unknown school type 'undefined'"


  describe 'hasBadge', ->
    # async helper...
    expectThen = (promise) ->
      toBecome: (what) ->
        got = null
        promise.then (result) -> got = result
        $rootScope.$apply()
        expect got
          .toBe what

    it 'should validate parameters', ->
      expect -> b.hasBadge()
        .toThrow new Error "param `rankedSchools` must be a Promise. Got 'undefined'"
      expect -> b.hasBadge undefined, 'bad school type', {}, $q.when undefined
        .toThrow new Error "Unknown schoolType 'bad school type'"
      expect -> b.hasBadge null, 'primary', {}, $q.when undefined
        .toThrow new Error "Unknown primary badge 'null'"
      expect -> b.hasBadge null, 'secondary', {}, $q.when undefined
        .toThrow new Error "Unknown secondary badge 'null'"
      expect -> b.hasBadge 'bad badge', 'primary', {}, $q.when undefined
        .toThrow new Error "Unknown primary badge 'bad badge'"
      expect -> b.hasBadge 'top-100', 'primary', {}, undefined
        .toThrow new Error "param `rankedSchools` must be a Promise. Got 'undefined'"

      caught = null
      b.hasBadge 'top-100', 'primary', {}, $q.when undefined
        .catch (e) -> caught = e
      $rootScope.$apply()
      expect caught
        .toEqual "`rankedSchools` promise must resolve to an Array. Got 'undefined'"

    it 'should apply to top 100 primary', ->
      schools = (AVG_MARK: n for n in [101..1])  # descending
      idxOffset = 1
      s1 = schools[1 - idxOffset]
      s100 = schools[100 - idxOffset]
      s101 = schools[101 - idxOffset]
      expectThen b.hasBadge 'top-100', 'primary', s1, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'top-100', 'primary', s1, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'top-100', 'primary', s100, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'top-100', 'primary', s101, $q.when schools
        .toBecome false

    it 'should apply to top 100 secondary', ->
      schools = (AVG_GPA: n for n in [1..101])
      idxOffset = 1
      s1 = schools[1 - idxOffset]
      s100 = schools[100 - idxOffset]
      s101 = schools[101 - idxOffset]
      expectThen b.hasBadge 'top-100', 'secondary', s1, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'top-100', 'secondary', s100, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'top-100', 'secondary', s101, $q.when schools
        .toBecome false

    it 'should apply to most improved primary', ->
      schools = (CHANGE_PREVIOUS_YEAR: n for n in [301..1])  # descending...
      idxOffset = 1
      s1 = schools[1 - idxOffset]
      s100 = schools[100 - idxOffset]
      s300 = schools[100 - idxOffset]
      s301 = schools[301 - idxOffset]
      expectThen b.hasBadge 'most-improved', 'primary', s1, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'most-improved', 'primary', s100, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'most-improved', 'primary', s300, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'most-improved', 'primary', s301, $q.when schools
        .toBecome false

    it 'should apply to most improved secondary', ->
      schools = (CHANGE_PREVIOUS_YEAR_GPA: n for n in [1..101])
      idxOffset = 1
      s1 = schools[1 - idxOffset]
      s100 = schools[100 - idxOffset]
      s101 = schools[101 - idxOffset]
      expectThen b.hasBadge 'most-improved', 'secondary', s1, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'most-improved', 'secondary', s100, $q.when schools
        .toBecome true
      expectThen b.hasBadge 'most-improved', 'secondary', s101, $q.when schools
        .toBecome false
