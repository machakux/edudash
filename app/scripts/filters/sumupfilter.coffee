'use strict'

###*
 # @ngdoc filter
 # @name edudashApp.filter:sumUpFilter
 # @function
 # @description
 # # sumUpFilter
 # Filter in the edudashApp.
###
angular.module 'edudashApp'
.filter 'sumUpFilter', [
    '$log'
    ($log) ->
      (input, key) ->
        if(input.length == 1)
          val = input[0][key]
        else
          val = input.reduce (t, s) ->
            number1 = parseInt(t if t?) or 0
            number2 = parseInt(s[key] if (s[key]?)) or 0
            number1 + number2
        val
  ]
