'use strict'

###*
 # @ngdoc service
 # @name edudashApp.WorldBankApi
 # @description
 # # WorldBankApi
 # Service in the edudashApp.
###
angular.module('edudashAppSrv').service 'bracketsSrv', ->

  colour: (brace) ->
    switch brace
      when 'GOOD' then '#38a21c'
      when 'MEDIUM' then '#e9c941'
      when 'POOR' then '#f56053'
      when 'UNKNOWN' then '#aaa'
      else throw new Error "Unknown bracket: '#{brace}'"


  getBracket: (val, metric) ->
    unless typeof val in ['number', 'undefined']
      throw new Error "val must be a number. Got: '#{val}' which is '#{typeof val}'"
    if isNaN val  # NaN or undefined
      'UNKNOWN'
    else
      switch metric

        when 'AVG_MARK' then switch
          when 0 <= val < 40 then 'POOR'
          when 40 <= val <= 60 then 'MEDIUM'
          when 60 < val <= 100 then 'GOOD'
          else 'UNKNOWN'

        when 'AVG_GPA' then switch
          when 1 <= val <= 3 then 'POOR'
          when 3 < val <= 4.2 then 'MEDIUM'
          when 4.2 < val <= 5 then 'GOOD'  # what's the upper limit?
          else 'UNKNOWN'

        when 'CHANGE_PREVIOUS_YEAR', 'CHANGE_PREVIOUS_YEAR_GPA' then switch
          when val < 0 then 'POOR'
          when val == 0 then 'MEDIUM'
          when val > 0 then 'GOOD'
          # `when`s are exhaustive: tested typeof === number and !isNaN

        else throw new Error "Unknown metric: '#{metric}'"


  getMetric: (schoolType, criteria) ->
    unless schoolType in ['primary', 'secondary']
      throw new Error "Unknown school type '#{schoolType}'"
    unless criteria in ['performance', 'improvement']
      throw new Error "Unknown criteria '#{criteria}'"
    switch schoolType
      when 'primary' then switch criteria
        when 'performance' then 'AVG_MARK'
        when 'improvement' then 'CHANGE_PREVIOUS_YEAR'
      when 'secondary' then switch criteria
        when 'performance' then 'AVG_GPA'
        when 'improvement' then 'CHANGE_PREVIOUS_YEAR_GPA'
