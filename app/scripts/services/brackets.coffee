'use strict'

###*
 # @ngdoc service
 # @name edudashApp.WorldBankApi
 # @description
 # # WorldBankApi
 # Service in the edudashApp.
###
angular.module('edudashAppSrv').service 'bracketsSrv', ->

  getBracket: (val, metric) ->
    unless typeof val in ['number', 'undefined', 'string']
      throw new Error "val must be a number. Got: '#{val}' which is '#{typeof val}'"
    if isNaN val  # NaN or undefined
      'UNKNOWN'
    else
      if typeof val is 'string' # this is a hack since the negative come as string values
        val = parseInt val
      switch metric

        when 'AVG_MARK' then throw new Error "AVG_MARK shall not be bracket"

        # According to Mark we don't have to validate GPA ranges
        when 'AVG_GPA' then switch
          when val <= 3 then 'GOOD'
          when 3 < val <= 4.2 then 'MEDIUM'
          when val > 4.2 then 'POOR'  # what's the upper limit?

        when 'CHANGE_PREVIOUS_YEAR' then switch
          when val < 0 then 'POOR'
          when val == 0 then 'MEDIUM'
          when val > 0 then 'GOOD'

        when 'CHANGE_PREVIOUS_YEAR_PASSRATE' then switch
          when val < 0 then 'POOR'
          when val == 0 then 'MEDIUM'
          when val > 0 then 'GOOD'

        when 'CHANGE_PREVIOUS_YEAR_GPA' then switch
          when val < 0 then 'GOOD'
          when val == 0 then 'MEDIUM'
          when val > 0 then 'POOR'
          # `when`s are exhaustive: tested typeof === number and !isNaN

        when 'PASS_RATE' then switch
          when 0 <= val < 40 then 'POOR'
          when 40 <= val <= 60 then 'MEDIUM'
          when 60 < val <= 100 then 'GOOD'
          else 'UNKNOWN'

        when 'PUPIL_TEACHER_RATIO' then switch
          when 0 < val < 35 then 'GOOD'
          when 35 <= val <= 50 then 'MEDIUM'
          when val > 50 then 'POOR'
          else 'UNKNOWN'

        else throw new Error "Unknown metric: '#{metric}'"

  hasBadge: (badge, schoolType, value) ->
    switch schoolType
      when 'primary' then switch badge

        when 'top-100' then switch
          when 1 <= value <= 100 then true
          when value > 100 then false
          else null  # maybe warn?

        when 'most-improved' then switch
          when value >= 62 then true
          else false

        else throw new Error "Unknown primary badge '#{badge}'"
      when 'secondary' then switch badge

        when 'top-100' then switch
          when 1 <=  value <=  100 then true
          when value > 100 then false
          else null  # maye error out or warn

        when 'most-improved' then switch
          when value >= 55 then true
          else false

        else throw new Error "Unknown secondary badge '#{badge}'"
      else throw new Error "Unknown schoolType '#{schoolType}'"


  getVisMetric: (visMode) ->
    switch visMode
      when 'passrate' then 'PASS_RATE'
      when 'ptratio' then 'PUPIL_TEACHER_RATIO'
      when 'gpa' then 'AVG_GPA'
      else throw new Error "Unknown vis mode '#{visMode}'"

  getSortMetric: (schoolType, criteria) ->
    unless schoolType in ['primary', 'secondary']
      throw new Error "Unknown school type '#{schoolType}'"
    unless criteria in ['performance', 'improvement']
      throw new Error "Unknown criteria '#{criteria}'"
    switch schoolType
      when 'primary' then switch criteria
        when 'performance' then ['AVG_MARK', true]
        when 'improvement' then ['CHANGE_PREVIOUS_YEAR', true]
      when 'secondary' then switch criteria
        when 'performance' then ['AVG_GPA', false]
        when 'improvement' then ['CHANGE_PREVIOUS_YEAR_GPA', false]

  getRank: (schoolType) ->
    unless schoolType in ['primary', 'secondary']
      throw new Error "Unknown school type '#{schoolType}'"
    switch schoolType
      when 'primary' then ['AVG_MARK', true] # AVG_MARK is sum of 5 exam from 0-50, greater the better, order desc
      when 'secondary' then ['AVG_GPA', false] # AVG_GPA lower the better. order asc
